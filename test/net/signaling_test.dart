import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/net/nostr/keys.dart';
import 'package:kitchentable/net/nostr/relay.dart';
import 'package:kitchentable/net/signaling.dart';

import 'nostr/fake_relay.dart';

const _code = 'k7-42q';
const _otherCode = 'zz-99z';

Future<FakeRelay> _relay() async {
  final relay = await FakeRelay.start();
  addTearDown(relay.close);
  return relay;
}

Relay _client(FakeRelay relay) {
  final client = Relay(
    [relay.url],
    reconnectAfter: const Duration(milliseconds: 20),
  );
  addTearDown(client.close);
  return client;
}

/// One peer in the room, answering every offer it is handed.
///
/// The offer and answer bodies name the key they came from, so a test can
/// tell whose description arrived where without WebRTC being anywhere near.
Signaling _peer(
  FakeRelay relay,
  Keys keys, {
  String code = _code,
  Duration announceEvery = const Duration(seconds: 30),
}) {
  final signaling = Signaling(
    relay: _client(relay),
    keys: keys,
    code: code,
    makeOffer: (peer) async => 'offer from ${keys.public}',
    announceEvery: announceEvery,
  );
  addTearDown(signaling.close);
  return signaling;
}

/// Everything [signaling] surfaces, with offers answered as they arrive.
List<Signal> _answering(Signaling signaling) {
  final got = <Signal>[];
  signaling.signals.listen((signal) {
    got.add(signal);
    if (signal.kind == SignalKind.offer) {
      signaling.answer(signal.from, 'answer from ${signaling.me}');
    }
  });
  return got;
}

/// What actually crossed the relay under [_code], decoded, in order.
///
/// A count taken here is a count of messages on the wire, not of what a
/// peer chose to report about itself.
typedef _Seen = ({String from, String type, String? to, String body});

Future<List<_Seen>> _watch(FakeRelay relay) async {
  final sub = _client(relay).subscribe(
    const Filter(kinds: [handshakeKind], tags: {'d': [_code]}),
  );
  final seen = <_Seen>[];
  sub.events.listen((event) {
    final content = jsonDecode(event.content) as Map<String, dynamic>;
    seen.add((
      from: event.pubkey,
      type: content['type'] as String,
      to: event.tag('p'),
      body: content['body'] as String,
    ));
  });
  await sub.established;
  return seen;
}

/// A message the way a peer running this code would sign it, so a test can
/// speak as a peer that does not run this code: one that offers when it
/// should not, or answers what it was never asked.
NostrEvent _raw(
  Keys keys,
  String type, {
  String code = _code,
  String? to,
  String body = '',
}) =>
    NostrEvent.sign(
      keys,
      kind: handshakeKind,
      tags: [
        ['d', code],
        if (to != null) ['p', to],
      ],
      content: jsonEncode({'type': type, 'body': body}),
    );

/// Waits for [condition]; the only honest way to wait on another socket.
Future<void> _eventually(bool Function() condition, String what) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('waited 5s for $what');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

/// Time for whatever is already on the wire to land. There is no future to
/// await for "nothing else is coming", so an assertion that something did
/// not happen waits this long first.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 100));

/// Two minted identities, sorted so that [low] is the one the rule picks.
({Keys low, Keys high}) _pair() {
  final a = Keys.mint();
  final b = Keys.mint();
  return a.public.compareTo(b.public) < 0
      ? (low: a, high: b)
      : (low: b, high: a);
}

void main() {
  test('two peers under one code find each other and exactly one offers',
      () async {
    final relay = await _relay();
    final wire = await _watch(relay);
    final keys = _pair();
    final a = _peer(relay, keys.low);
    final b = _peer(relay, keys.high);
    final aGot = _answering(a);
    final bGot = _answering(b);

    await Future.wait([a.join(), b.join()]);
    // Waited for on the wire and not on a surfaced signal, so that two
    // offers crossing, which would leave both answers unsurfaced, fails on
    // the count below rather than on a wait.
    await _eventually(
      () => wire.any((m) => m.type == 'answer'),
      'an answer to cross the relay',
    );
    await _settle();

    expect(a.peers, {b.me});
    expect(b.peers, {a.me});
    expect(wire.where((m) => m.type == 'offer'), hasLength(1));
    expect(wire.where((m) => m.type == 'answer'), hasLength(1));
    expect([...aGot, ...bGot].where((s) => s.kind == SignalKind.answer),
        hasLength(1));
  });

  test('the lower key is the one that offers, and the other answers',
      () async {
    final relay = await _relay();
    final wire = await _watch(relay);
    final keys = _pair();
    final low = _peer(relay, keys.low);
    final high = _peer(relay, keys.high);
    final lowGot = _answering(low);
    final highGot = _answering(high);

    // Joined in the wrong order on purpose: the higher key is in the room
    // first, and must still not be the one that offers.
    await high.join();
    await low.join();
    await _eventually(
      () => wire.any((m) => m.type == 'answer'),
      'an answer to cross the relay',
    );
    await _settle();

    final offer = wire.singleWhere((m) => m.type == 'offer');
    expect(offer.from, keys.low.public);
    expect(offer.to, keys.high.public);
    expect(offer.body, 'offer from ${keys.low.public}');

    final answer = wire.singleWhere((m) => m.type == 'answer');
    expect(answer.from, keys.high.public);
    expect(answer.to, keys.low.public);

    // Each side saw exactly the half of the exchange that was for it.
    expect(highGot, hasLength(1));
    expect(highGot.single.kind, SignalKind.offer);
    expect(highGot.single.from, keys.low.public);
    expect(highGot.single.body, 'offer from ${keys.low.public}');
    expect(highGot.single.replacesOwnOffer, isFalse);
    expect(lowGot, hasLength(1));
    expect(lowGot.single.kind, SignalKind.answer);
    expect(lowGot.single.from, keys.high.public);
    expect(lowGot.single.body, 'answer from ${keys.high.public}');
  });

  test('a peer joining late sees the two already there', () async {
    final relay = await _relay();
    final wire = await _watch(relay);
    final a = _peer(relay, Keys.mint());
    final b = _peer(relay, Keys.mint());
    _answering(a);
    _answering(b);
    await Future.wait([a.join(), b.join()]);
    await _eventually(
      () => a.peers.contains(b.me) && b.peers.contains(a.me),
      'the first two to find each other',
    );

    // Nothing is stored on a relay, so the late one hears nothing of what
    // was said before it arrived. It has to be told, and it is.
    final c = _peer(relay, Keys.mint());
    _answering(c);
    await c.join();
    await _eventually(
      () => c.peers.length == 2,
      'the late peer to see both',
    );
    expect(c.peers, {a.me, b.me});
    await _eventually(
      () => a.peers.contains(c.me) && b.peers.contains(c.me),
      'the first two to see the late one',
    );
    expect(a.peers, {b.me, c.me});
    expect(b.peers, {a.me, c.me});

    // Three pairs, three introductions, each one offer and one answer.
    await _eventually(
      () => wire.where((m) => m.type == 'answer').length == 3,
      'every pair to finish introducing itself',
    );
    await _settle();
    expect(wire.where((m) => m.type == 'offer'), hasLength(3));
    expect(wire.where((m) => m.type == 'answer'), hasLength(3));
  });

  test('a here under another code is never seen', () async {
    final relay = await _relay();
    final a = _peer(relay, Keys.mint());
    final aGot = _answering(a);
    final elsewhere = _peer(relay, Keys.mint(), code: _otherCode);
    await a.join();
    await elsewhere.join();

    // The stranger's `here` is on the relay before this one joins, and the
    // relay fans out before it says OK, so if it leaked it would already be
    // on a's socket ahead of anything d says.
    final d = _peer(relay, Keys.mint());
    final dGot = _answering(d);
    await d.join();
    await _eventually(() => a.peers.isNotEmpty, 'a to see d');
    expect(a.peers, {d.me});
    expect(elsewhere.peers, isEmpty);
    await _eventually(
      () => [...aGot, ...dGot].any((s) => s.kind == SignalKind.answer),
      'a and d to finish introducing themselves',
    );
    expect(elsewhere.peers, isEmpty);
  });

  test('an offer addressed to somebody else is never surfaced', () async {
    final relay = await _relay();
    final a = _peer(relay, Keys.mint());
    final aGot = _answering(a);
    await a.join();

    final speaker = _client(relay);
    final stranger = Keys.mint();
    final somebodyElse = Keys.mint().public;
    // Wrong address first, right one second, on one socket: if the first
    // got through it would be the first thing a saw.
    await speaker.publish(
      _raw(stranger, 'offer', to: somebodyElse, body: 'not for you'),
    );
    await speaker.publish(_raw(stranger, 'offer', to: a.me, body: 'for you'));

    await _eventually(() => aGot.isNotEmpty, 'the offer that was for a');
    expect(aGot.first.body, 'for you');
    expect(aGot.first.from, stranger.public);
    expect(aGot, hasLength(1));
    expect(a.dropped, 1, reason: 'the misaddressed one is counted');
  });

  test('a message whose signature does not verify is dropped and reported',
      () async {
    final relay = await _relay();
    final a = _peer(relay, Keys.mint());
    final aGot = _answering(a);
    final reports = <SignalingStatus>[];
    a.status.listen(reports.add);
    await a.join();

    final stranger = Keys.mint();
    final good = _raw(stranger, 'offer', to: a.me, body: 'for you');
    final forged = <String, dynamic>{
      ...good.toJson(),
      'content': jsonEncode({'type': 'offer', 'body': 'i am the host now'}),
    };
    forged['id'] = NostrEvent.idOf(NostrEvent.fromJson(forged));

    // The forgery first, from a relay that checks nothing; the real one
    // after, on the same socket.
    relay.inject(forged);
    await _client(relay).publish(good);

    await _eventually(() => aGot.isNotEmpty, 'the good offer');
    expect(aGot.first.body, 'for you');
    expect(aGot, hasLength(1));
    expect(a.dropped, 1, reason: 'the forgery is counted, not thrown');
  });

  test('a peer that receives an offer while holding its own drops its own',
      () async {
    final relay = await _relay();
    final wire = await _watch(relay);
    final keys = _pair();
    final low = _peer(relay, keys.low);
    final lowGot = _answering(low);
    final reports = <SignalingStatus>[];
    low.status.listen(reports.add);
    await low.join();

    // The higher key, run by hand: it announces, so low offers to it, and
    // then it offers anyway, which this code never does and an older or
    // modified one might.
    final speaker = _client(relay);
    await speaker.publish(_raw(keys.high, 'here'));
    await _eventually(
      () => wire.any((m) => m.type == 'offer' && m.from == keys.low.public),
      'low to offer',
    );
    await speaker.publish(
      _raw(keys.high, 'offer', to: keys.low.public, body: 'mine first'),
    );

    await _eventually(() => lowGot.isNotEmpty, 'the crossing offer');
    expect(lowGot.single.kind, SignalKind.offer);
    expect(lowGot.single.from, keys.high.public);
    expect(lowGot.single.body, 'mine first');
    expect(lowGot.single.replacesOwnOffer, isTrue,
        reason: 'the link has to roll back what it described');
    expect(
      reports,
      contains(
        SignalingStatus(SignalingStep.ownOfferDropped, peer: keys.high.public),
      ),
    );
    await _settle();
    expect(wire.where((m) => m.type == 'answer').map((m) => m.from),
        [keys.low.public]);

    // And an answer to the offer low dropped is an answer to nothing.
    await speaker.publish(
      _raw(keys.high, 'answer', to: keys.low.public, body: 'to the dropped'),
    );
    await _settle();
    expect(lowGot, hasLength(1), reason: 'the stray answer is not surfaced');
    expect(low.dropped, 1, reason: 'and it is counted');
  });

  test('a peer keeps announcing itself while in the room', () async {
    final relay = await _relay();
    final wire = await _watch(relay);
    final a = _peer(relay, Keys.mint(),
        announceEvery: const Duration(milliseconds: 30));
    await a.join();
    await _eventually(
      () => wire.where((m) => m.type == 'here').length >= 3,
      'three announcements',
    );
    expect(wire.map((m) => m.type).toSet(), {'here'});
    expect(wire.map((m) => m.from).toSet(), {a.me});
    expect(wire.map((m) => m.to).toSet(), {null},
        reason: 'here is for the room, not for one peer');
  });

  test('the status stream says whether the rendezvous is alive', () async {
    final relay = await _relay();
    final keys = _pair();
    final low = _peer(relay, keys.low);
    final high = _peer(relay, keys.high);
    final lowSaw = <SignalingStatus>[];
    final highSaw = <SignalingStatus>[];
    low.status.listen(lowSaw.add);
    high.status.listen(highSaw.add);
    final lowGot = _answering(low);
    _answering(high);

    await Future.wait([low.join(), high.join()]);
    await _eventually(
      () => lowGot.any((s) => s.kind == SignalKind.answer),
      'the answer',
    );

    // The relay and the announcement are facts about this peer; the rest
    // is one conversation with the other, in the order it happened. The
    // announcement is not ordered against the conversation: the other
    // peer's `here` can land while ours is still waiting for the relay's
    // OK.
    expect(lowSaw.first,
        SignalingStatus(SignalingStep.relayConnected, relay: relay.url));
    expect(lowSaw, contains(const SignalingStatus(SignalingStep.announced)));
    expect(
      lowSaw,
      containsAllInOrder([
        SignalingStatus(SignalingStep.peerHere, peer: keys.high.public),
        SignalingStatus(SignalingStep.offerSent, peer: keys.high.public),
        SignalingStatus(SignalingStep.answerReceived, peer: keys.high.public),
      ]),
    );
    expect(highSaw, contains(const SignalingStatus(SignalingStep.announced)));
    expect(
      highSaw,
      containsAllInOrder([
        SignalingStatus(SignalingStep.peerHere, peer: keys.low.public),
        SignalingStatus(SignalingStep.offerReceived, peer: keys.low.public),
        SignalingStatus(SignalingStep.answerSent, peer: keys.low.public),
      ]),
    );
    expect(lowSaw.where((s) => s.step == SignalingStep.relayUnreachable),
        isEmpty);

    // The relay goes away and comes back: said, and the room is told again
    // that this peer is here, since the relay kept no copy.
    final before = lowSaw.length;
    final highBefore = highSaw.length;
    await relay.dropConnections();
    await _eventually(
      () =>
          lowSaw.skip(before).any((s) => s.step == SignalingStep.announced) &&
          highSaw
              .skip(highBefore)
              .any((s) => s.step == SignalingStep.announced),
      'a fresh announcement from each after reconnecting',
    );
    expect(
      lowSaw.skip(before),
      containsAllInOrder([
        SignalingStatus(SignalingStep.relayLost, relay: relay.url),
        SignalingStatus(SignalingStep.relayConnected, relay: relay.url),
        const SignalingStatus(SignalingStep.announced),
      ]),
    );
  });

  test('a relay nobody answers on is reported as unreachable', () async {
    final gone = await FakeRelay.start();
    final url = gone.url;
    await gone.close();

    final client = Relay(
      [url],
      reconnectAfter: const Duration(seconds: 10),
    );
    addTearDown(client.close);
    final a = Signaling(
      relay: client,
      keys: Keys.mint(),
      code: _code,
      makeOffer: (peer) async => 'never asked',
    );
    addTearDown(a.close);
    final saw = <SignalingStatus>[];
    a.status.listen(saw.add);

    await a.join();
    expect(saw, contains(const SignalingStatus(SignalingStep.relayUnreachable)));
    expect(saw.where((s) => s.step == SignalingStep.announced), isEmpty,
        reason: 'nothing was said to anybody');
  });
}
