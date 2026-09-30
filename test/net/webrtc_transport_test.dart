import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' show StatsReport;
import 'package:kitchentable/net/link.dart';
import 'package:kitchentable/net/mesh.dart';
import 'package:kitchentable/net/nostr/keys.dart';
import 'package:kitchentable/net/nostr/relay.dart';
import 'package:kitchentable/net/signaling.dart';
import 'package:kitchentable/net/transport.dart';
import 'package:kitchentable/net/webrtc_link.dart';
import 'package:kitchentable/net/webrtc_transport.dart';
import 'package:kitchentable/table/actions/table_action.dart';
import 'package:kitchentable/table/model/seat.dart';
import 'package:kitchentable/table/model/seat_owner.dart';
import 'package:kitchentable/table/model/table_state.dart';

import 'fake_link.dart';
import 'nostr/fake_relay.dart';

const _code = 'k7-42q';

Future<FakeRelay> _relay() async {
  final relay = await FakeRelay.start();
  addTearDown(relay.close);
  return relay;
}

Relay _client(FakeRelay relay) {
  final client = Relay([
    relay.url,
  ], reconnectAfter: const Duration(milliseconds: 20));
  addTearDown(client.close);
  return client;
}

/// One phone: a minted identity, a client on the fake relay, and links from
/// [links]. Everything it says on [WebRtcTransport.steps], everything that
/// arrived and everybody who came or went, collected from before it joins,
/// because a case that subscribes later misses what it is about.
class _Phone {
  _Phone(
    FakeRelay relay,
    FakeLinks links,
    this.keys, {
    Duration? openWithin,
    TurnServer? turn,
  }) : transport = WebRtcTransport(
        relay: _client(relay),
        keys: keys,
        code: _code,
        links: links,
        openWithin: openWithin ?? const Duration(seconds: 20),
        turn: turn,
      ) {
    transport.steps.listen(steps.add);
    transport.incoming.listen(got.add);
    transport.presence.listen(saw.add);
    addTearDown(transport.close);
  }

  final Keys keys;
  final WebRtcTransport transport;
  final steps = <ConnectionStep>[];
  final got = <Incoming>[];
  final saw = <PeerEvent>[];

  String get me => keys.public;
  Set<String> get peers => transport.peers;

  Iterable<SignalingStep> get rendezvous =>
      steps.whereType<RendezvousStep>().map((s) => s.status.step);
  Iterable<LinkStatus> get link =>
      steps.whereType<LinkStep>().map((s) => s.status);
  Iterable<LinkFailure> get failures =>
      link.map((s) => s.failure).whereType<LinkFailure>();
}

Future<_Phone> _phone(
  FakeRelay relay,
  FakeLinks links, [
  Keys? keys,
  Duration? openWithin,
]) async =>
    _Phone(relay, links, keys ?? Keys.mint(), openWithin: openWithin);

/// [n] phones under one code, joined and every link between them open.
Future<List<_Phone>> _phones(int n, {FakeLinks? links}) async {
  final relay = await _relay();
  final fakes = links ?? FakeLinks();
  final phones = [for (var i = 0; i < n; i++) await _phone(relay, fakes)];
  await Future.wait([for (final p in phones) p.transport.join()]);
  await _eventually(
    () => phones.every((p) => p.peers.length == n - 1),
    'every phone to see every other',
  );
  return phones;
}

/// A table with one seat, which is all a verb needs to land on. Owned by the
/// key of the phone that dealt it: a seat that travels is held by a key.
TableState _aTable(String owner) => TableState(
  seats: [
    Seat(
      id: 's1',
      name: 'you',
      life: 40,
      owner: SeatOwner.peer(owner),
      zones: const [],
    ),
  ],
);

/// A mesh on each phone, the first one having made the room, started once
/// the links are already up: the order Task 4's lobby will use, since it
/// hands the transport over after the people have arrived.
Future<List<Mesh>> _meshed(List<_Phone> phones) async {
  final meshes = <Mesh>[];
  for (final (i, phone) in phones.indexed) {
    final mesh = Mesh(
      transport: phone.transport,
      table: i == 0 ? _aTable(phone.me) : null,
      creator: i == 0,
    );
    addTearDown(mesh.close);
    mesh.start();
    meshes.add(mesh);
  }
  await _eventually(
    () => meshes.every((m) => m.table != null),
    'every phone to be handed the table',
  );
  return meshes;
}

/// What actually crossed the relay under [_code], decoded, in order.
typedef _Seen = ({String from, String type, String? to, String body});

Future<List<_Seen>> _watch(FakeRelay relay) async {
  final sub = _client(relay).subscribe(
    const Filter(
      kinds: [handshakeKind],
      tags: {
        'd': [_code],
      },
    ),
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
/// speak as one that does not.
NostrEvent _raw(Keys keys, String type, {String? to, String body = ''}) =>
    NostrEvent.sign(
      keys,
      kind: handshakeKind,
      tags: [
        ['d', _code],
        if (to != null) ['p', to],
      ],
      content: jsonEncode({'type': type, 'body': body}),
    );

Future<void> _eventually(bool Function() condition, String what) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('waited 5s for $what');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

/// Time for whatever is already on the wire to land, before asserting that
/// something did not happen.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 100));

/// Two minted identities, sorted so that [low] is the one that offers.
({Keys low, Keys high}) _pair() {
  final a = Keys.mint();
  final b = Keys.mint();
  return a.public.compareTo(b.public) < 0
      ? (low: a, high: b)
      : (low: b, high: a);
}

void main() {
  test('three phones under one code end up with two peers each', () async {
    final links = FakeLinks();
    final phones = await _phones(3, links: links);
    await _settle();

    for (final phone in phones) {
      final others = {
        for (final p in phones)
          if (p != phone) p.me,
      };
      expect(phone.peers, others, reason: phone.me.substring(0, 8));
      expect(phone.saw.map((e) => '${e.presence.name} ${e.peerId}').toSet(), {
        for (final o in others) 'arrived $o',
      }, reason: 'told once about each arrival and nothing else');
    }

    // Each pair negotiated once, in the direction the signaling chose: the
    // lower key's offer landed on the higher key's link and the answer came
    // back, and each end took the other's candidate.
    for (final x in phones) {
      for (final y in phones) {
        if (x.me.compareTo(y.me) >= 0) continue;
        final low = links.between(x.me, y.me)!;
        final high = links.between(y.me, x.me)!;
        expect(high.offerTaken, 'offer from ${x.me}');
        expect(low.answerTaken, 'answer from ${y.me}');
        expect(low.offerTaken, isNull, reason: 'the lower key never answers');
        expect(high.answerTaken, isNull, reason: 'the higher key never offers');
        expect(low.candidatesTaken, ['candidate from ${y.me}']);
        expect(high.candidatesTaken, ['candidate from ${x.me}']);
      }
    }
    expect(links.made, hasLength(6), reason: 'one link per end per pair');
  });

  test('a string sent lands at exactly the one peer it was sent to and nowhere '
      'else', () async {
    final links = FakeLinks();
    final [a, b, c] = await _phones(3, links: links);

    a.transport.send(b.me, 'for b');
    await _eventually(() => b.got.isNotEmpty, 'b to receive it');
    await _settle();

    expect(b.got.single.from, a.me);
    expect(b.got.single.body, 'for b');
    expect(c.got, isEmpty, reason: 'c was not the one it was sent to');
    expect(a.got, isEmpty, reason: 'nor was the sender');
    expect(links.between(c.me, a.me)!.received, isEmpty);
    expect(links.between(b.me, a.me)!.received, ['for b']);

    // And back, from a guest, since a star would pass the case above.
    c.transport.send(a.me, 'for a');
    await _eventually(() => a.got.isNotEmpty, 'a to receive it');
    await _settle();
    expect(a.got.single.from, c.me);
    expect(a.got.single.body, 'for a');
    expect(b.got, hasLength(1));
  });

  test(
    'a link that closes is a left on presence and gone from peers',
    () async {
      final links = FakeLinks();
      final [a, b] = await _phones(2, links: links);

      // The far end hangs up; a's own end sees the channel go.
      await links.between(b.me, a.me)!.close();
      await links.between(a.me, b.me)!.closed;
      await _settle();

      expect(a.peers, isEmpty);
      expect(
        a.saw.where((e) => e.presence == Presence.left).map((e) => e.peerId),
        [b.me],
      );
      expect(a.link, contains(LinkStatus(LinkStage.closed, peer: b.me)));
      expect(a.failures, isEmpty, reason: 'a hang up is not a failure');

      // Sending to somebody who has gone is a datagram dropped, not a throw.
      a.transport.send(b.me, 'anybody there');
      await _settle();
      expect(b.got, isEmpty);
    },
  );

  test('a link that fails to open is a LinkFailure in words and not an '
      'exception', () async {
    final keys = _pair();
    final links = FakeLinks(unreachable: {keys.high.public});
    final relay = await _relay();
    final low = await _phone(relay, links, keys.low);
    final high = await _phone(relay, links, keys.high);

    await Future.wait([low.transport.join(), high.transport.join()]);
    final outcome = await links.between(low.me, high.me)!.open;
    expect(outcome, isNotNull, reason: 'the fake refused to open it');
    await _settle();

    expect(low.failures, [
      LinkFailure(
        peer: high.me,
        reason:
            'ICE finished with no candidate pair between ${low.me} and '
            '${high.me}',
        needsTurn: true,
      ),
    ]);
    expect(low.peers, isEmpty);
    expect(low.saw, isEmpty, reason: 'nobody arrived, so nobody left');
    expect(low.link.map((s) => s.stage), isNot(contains(LinkStage.opened)));
    // The other side saw the same failure from where it stood.
    expect(high.failures.map((f) => f.peer), [low.me]);
    expect(high.failures.single.needsTurn, isTrue);
  });

  test('plugged into the existing mesh, a verb run on one phone lands on the '
      'other two', () async {
    final phones = await _phones(3);
    final [host, a, b] = await _meshed(phones);

    host.run(const ChangeLife(seatId: 's1', by: -3));
    await _eventually(
      () => [a, b].every((m) => m.table!.seat('s1')!.life == 37),
      'the verb to land',
    );
    expect(host.table!.seat('s1')!.life, 37);

    // And back the other way: a guest's verb reaches the host and the other
    // guest, which a transport wired one way would not do.
    a.run(const RollDice([6, 6]));
    await _eventually(
      () => [host, b].every((m) => m.table!.dice.equals([6, 6])),
      'the guest\'s verb to land',
    );
    expect(a.table!.dice, [6, 6]);

    // The host stamped both, over this transport, and everybody agrees.
    for (final m in [host, a, b]) {
      expect(m.hostId, host.me, reason: 'host is ${host.me.substring(0, 8)}');
      expect(m.stamps.keys.toSet(), {host.me, a.me, b.me});
    }
  });

  test('a verb is applied on the other phone before any other message is '
      'exchanged', () async {
    final links = FakeLinks();
    final phones = await _phones(2, links: links);
    final [host, guest] = await _meshed(phones);
    await _settle();
    final guestEnd = links.between(guest.me, host.me)!;
    final received = guestEnd.received.length;
    final sent = guestEnd.sent.length;

    host.run(const ChangeLife(seatId: 's1', by: -5));
    // One turn of the event loop and no more: enough for a message that was
    // handed straight to the channel, and not for a round trip.
    await Future<void>.delayed(Duration.zero);

    expect(guest.table!.seat('s1')!.life, 35);
    expect(
      guestEnd.received.length,
      received + 1,
      reason: 'the verb and nothing before it',
    );
    expect(
      guestEnd.sent.length,
      sent,
      reason: 'the guest asked for nothing and acknowledged nothing',
    );
  });

  test(
    'the steps stream states what the rendezvous and the link did',
    () async {
      final keys = _pair();
      final links = FakeLinks();
      final relay = await _relay();
      final low = await _phone(relay, links, keys.low);
      final high = await _phone(relay, links, keys.high);

      await Future.wait([low.transport.join(), high.transport.join()]);
      await _eventually(
        () => low.peers.contains(high.me) && high.peers.contains(low.me),
        'the link',
      );
      await _settle();

      expect(
        low.rendezvous,
        containsAllInOrder([
          SignalingStep.relayConnected,
          SignalingStep.peerHere,
          SignalingStep.offerSent,
          SignalingStep.answerReceived,
        ]),
      );
      expect(low.rendezvous, contains(SignalingStep.announced));
      expect(low.link, [LinkStatus(LinkStage.opened, peer: high.me)]);
      expect(
        high.rendezvous,
        containsAllInOrder([
          SignalingStep.peerHere,
          SignalingStep.offerReceived,
          SignalingStep.answerSent,
        ]),
      );
      expect(high.link, [LinkStatus(LinkStage.opened, peer: low.me)]);

      // The rendezvous is heard before the link opens, in one stream, so a
      // screen can show them as one story.
      final peerHere = low.steps.indexWhere(
        (s) => s is RendezvousStep && s.status.step == SignalingStep.peerHere,
      );
      final opened = low.steps.indexWhere(
        (s) => s is LinkStep && s.status.stage == LinkStage.opened,
      );
      expect(peerHere, lessThan(opened));

      // What the link itself learns is passed up as it is.
      links.between(low.me, high.me)!.foundReflexive();
      await _settle();
      expect(low.link.last, LinkStatus(LinkStage.reflexive, peer: high.me));
    },
  );

  test('an offer that crossed with ours replaces it on the link', () async {
    final keys = _pair();
    final links = FakeLinks();
    final relay = await _relay();
    final wire = await _watch(relay);
    final low = await _phone(relay, links, keys.low);
    await low.transport.join();

    // The higher key, run by hand: it announces, so low offers to it, and
    // then it offers anyway, which this code never does.
    final speaker = _client(relay);
    await speaker.publish(_raw(keys.high, 'here'));
    await _eventually(
      () => wire.any((m) => m.type == 'offer' && m.from == low.me),
      'low to offer',
    );
    await speaker.publish(
      _raw(keys.high, 'offer', to: low.me, body: 'mine first'),
    );
    await _eventually(
      () => wire.any((m) => m.type == 'answer' && m.from == low.me),
      'low to answer',
    );
    await _settle();

    final end = links.between(low.me, keys.high.public)!;
    expect(end.offerTaken, 'mine first');
    expect(end.rolledBack, isTrue, reason: 'the link was told to roll back');
    expect(end.answerTaken, isNull, reason: 'ours was dropped, unanswered');
    final answer = wire.singleWhere((m) => m.type == 'answer');
    expect(answer.to, keys.high.public);
    expect(answer.body, 'answer from ${low.me}');
    expect(low.rendezvous, contains(SignalingStep.ownOfferDropped));
  });

  test(
    'closing the transport closes every link, and the others see it go',
    () async {
      final links = FakeLinks();
      final [a, b, c] = await _phones(3, links: links);

      await a.transport.close();
      await _eventually(
        () => !b.peers.contains(a.me) && !c.peers.contains(a.me),
        'b and c to see a go',
      );
      await _settle();

      expect(b.peers, {c.me});
      expect(c.peers, {b.me});
      expect(b.saw.last.presence, Presence.left);
      expect(b.saw.last.peerId, a.me);
      expect(links.between(a.me, b.me)!.isOpen, isFalse);
      expect(links.between(a.me, c.me)!.isOpen, isFalse);
      expect(
        links.between(b.me, c.me)!.isOpen,
        isTrue,
        reason: 'the link between the two who stayed is untouched',
      );
    },
  );

  test('the default ICE servers are STUN only, and TURN is what the player '
      'brought', () {
    expect(defaultStunServers, isNotEmpty);
    for (final url in defaultStunServers) {
      expect(url, startsWith('stun:'));
    }

    final plain = iceConfiguration();
    final servers = plain['iceServers'] as List<Map<String, Object>>;
    expect(servers.map((s) => s['urls']), [defaultStunServers]);
    expect(
      servers.any((s) => s.containsKey('credential')),
      isFalse,
      reason: 'no relay of ours, ever',
    );

    final withTurn = iceConfiguration(
      turn: const TurnServer(
        url: 'turn:turn.example.net:3478',
        username: 'kit',
        credential: 'hunter2',
      ),
    );
    final withServers = withTurn['iceServers'] as List<Map<String, Object>>;
    expect(withServers, hasLength(2));
    expect(withServers.last, {
      'urls': ['turn:turn.example.net:3478'],
      'username': 'kit',
      'credential': 'hunter2',
    });
  });
  test('candidates are counted by type and family, out of a description or '
      'one at a time', () {
    const sdp = 'v=0\r\n'
        'a=candidate:1 1 udp 2113937151 3f2a9b1c-6d.local 51234 typ host generation 0\r\n'
        'a=candidate:2 1 udp 1677729535 203.0.113.9 51234 typ srflx raddr 0.0.0.0 rport 0\r\n'
        'a=candidate:3 1 udp 1677729535 2001:db8::9 51234 typ srflx raddr :: rport 0\r\n'
        'a=candidate:4 1 udp 2113937151 7c1d.local 51235 typ host generation 0\r\n'
        'a=end-of-candidates\r\n';
    final lines = candidateLines(sdp);
    expect(lines, hasLength(4));
    expect(lines.first, startsWith('candidate:1 '));
    expect(
      candidatesInWords(lines),
      '2 host mdns, 1 srflx v4, 1 srflx v6',
    );
    expect(candidatesInWords([]), 'none');
    // The third check: a phone on 5G and a laptop at home. Each side's
    // hosts are mDNS names the other cannot resolve, and their srflx
    // families need not match. The sentence has to let that be read.
    expect(
      candidatesInWords(['candidate:9 1 udp 1 198.51.100.4 5 typ relay']),
      '1 relay v4',
    );
  });
  test('the route in a failure is read off the stats, DTLS word first', () {
    StatsReport r(String id, String type, Map<String, Object> v) =>
        StatsReport(id, type, 0, v);
    final chosen = [
      r('T', 'transport', {
        'dtlsState': 'connecting',
        'selectedCandidatePairId': 'P2',
      }),
      // P1 is nominated and P2 is the one the transport says it chose;
      // the transport's word wins, and only without it does nominated.
      r('P1', 'candidate-pair', {
        'localCandidateId': 'L1',
        'remoteCandidateId': 'R1',
        'nominated': true,
      }),
      r('P2', 'candidate-pair', {
        'localCandidateId': 'L2',
        'remoteCandidateId': 'R2',
        'nominated': false,
        'bytesSent': 1840,
        'bytesReceived': 0,
      }),
      r('L1', 'local-candidate', {'candidateType': 'host'}),
      r('L2', 'local-candidate', {
        'candidateType': 'srflx',
        'networkType': 'wifi',
        'protocol': 'udp',
      }),
      r('R2', 'remote-candidate', {'candidateType': 'prflx'}),
    ];
    expect(
      routeInWords(chosen),
      'DTLS "connecting" over srflx/wifi to prflx (udp), '
      '1840 bytes sent and 0 received; candidates: ours 1 host, 1 srflx, '
      'theirs 1 prflx',
    );
    // No selected id on the transport: the nominated pair is the one.
    final nominated = [
      r('T', 'transport', {'dtlsState': 'connected'}),
      ...chosen.skip(1),
    ];
    expect(
      routeInWords(nominated),
      'DTLS "connected" over host to ?, 0 bytes sent and 0 received; '
      'candidates: ours 1 host, 1 srflx, theirs 1 prflx',
    );
    // Nothing chosen and nothing nominated: said so, with the DTLS word,
    // and with the candidates each side had. "theirs none" is the third
    // check: the phone's candidates never crossed the relay.
    expect(
      routeInWords([
        r('T', 'transport', {'dtlsState': 'new'}),
        chosen[2],
        chosen[3],
        chosen[4],
      ]),
      'DTLS "new" and no pair of addresses chosen; candidates: '
      'ours 1 host, 1 srflx, theirs none',
    );
    expect(
      routeInWords([]),
      'DTLS "unknown" and no pair of addresses chosen; candidates: '
      'ours none, theirs none',
    );
  });
  test('a link that never opens is failed by a deadline, in words', () async {
    // ICE that checks forever. The browser reports nothing for half a
    // minute or ever, and on the first two-phone check that was the host's
    // state: the phone heard, a link made, and "connecting" with no end.
    final keys = _pair();
    final links = FakeLinks(stalled: {keys.high.public});
    final relay = await _relay();
    const deadline = Duration(milliseconds: 300);
    final low = await _phone(relay, links, keys.low, deadline);
    final high = await _phone(relay, links, keys.high, deadline);

    await Future.wait([low.transport.join(), high.transport.join()]);
    await _eventually(
      () => links.between(low.me, high.me) != null,
      'the stalled link',
    );
    links.between(low.me, high.me)!.progress('ice connected 1.2s');
    final until = DateTime.now().add(const Duration(seconds: 5));
    while (low.failures.isEmpty && DateTime.now().isBefore(until)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    expect(low.failures, hasLength(1),
        reason: 'the deadline never turned the stall into a failure');
    final failure = low.failures.single;
    expect(failure.peer, high.me);
    expect(failure.reason, contains('nothing changed'));
    expect(failure.reason, contains('States: ice connected 1.2s'),
        reason: 'a deadline with no state is a deadline nobody can read');
    expect(failure.needsTurn, isFalse,
        reason: 'never finishing is not the same verdict as no pair');
    expect(low.peers, isEmpty);
    expect(low.link.map((s) => s.stage), isNot(contains(LinkStage.opened)));
  });
  test("one phone's TURN server is every link's in the room", () async {
    // The fifth check: a phone on a carrier's network against a home
    // router, every address exchanged and no pair connecting. A relay for
    // the connection fixes it, and only one end of a link needs one. So
    // the phone that has one says so in its here, and every other phone
    // makes its links through it, including the links between phones
    // that brought none: in a mesh those are most of them.
    final relay = await _relay();
    final links = FakeLinks();
    const brought = TurnServer(
      url: 'turn:turn.example.net:3478',
      username: 'kit',
      credential: 'hunter2',
    );
    final keys = [Keys.mint(), Keys.mint(), Keys.mint()]
      ..sort((a, b) => a.public.compareTo(b.public));
    // The one with the server is the last to join, so the other two have
    // to hear of it before their link to it, and the link between the two
    // of them, made before it arrived, is the one that must not have it.
    final a = await _phone(relay, links, keys[0]);
    final b = await _phone(relay, links, keys[1]);
    await Future.wait([a.transport.join(), b.transport.join()]);
    await _eventually(() => a.peers.contains(b.me), 'a to b');
    expect(links.between(a.me, b.me)!.turn, isNull);

    final c = _Phone(relay, links, keys[2], turn: brought);
    await c.transport.join();
    await _eventually(
      () => a.peers.contains(c.me) && b.peers.contains(c.me),
      'the room to reach c',
    );
    expect(links.between(a.me, c.me)!.turn, brought);
    expect(links.between(b.me, c.me)!.turn, brought);
    expect(links.between(c.me, a.me)!.turn, brought, reason: 'its own');
    expect(c.transport.turn, brought);
  });
  test('a link that keeps changing is not failed for being slow', () async {
    // The second two-phone check: every hop crosses a public relay at
    // seconds each, and one side gave up on a link the other side had just
    // connected. The deadline counts from the last change, so a link that
    // is still moving lives, and one that has stopped moving does not.
    final keys = _pair();
    final links = FakeLinks(stalled: {keys.high.public});
    final relay = await _relay();
    const deadline = Duration(milliseconds: 300);
    final low = await _phone(relay, links, keys.low, deadline);
    final high = await _phone(relay, links, keys.high, deadline);
    await Future.wait([low.transport.join(), high.transport.join()]);
    await _eventually(
      () => links.between(low.me, high.me) != null,
      'the stalled link',
    );
    final link = links.between(low.me, high.me)!;

    // Moving: a state every 150 ms for 900 ms, three deadlines' worth.
    for (var i = 0; i < 6; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      link.progress('ice checking ${i * 0.15}s');
    }
    expect(low.failures, isEmpty, reason: 'failed a link that was moving');

    // Still: the deadline runs from the last change.
    await Future<void>.delayed(deadline * 2);
    expect(low.failures, hasLength(1));
    expect(low.failures.single.reason, contains('nothing changed'));
  });
  test("a peer's candidate is a change that keeps a link alive", () async {
    // Candidates trickle in from the other side for as long as it gathers,
    // each one a hop over the relay; a link taking them is not stuck.
    final keys = _pair();
    final links = FakeLinks(stalled: {keys.high.public});
    final relay = await _relay();
    const deadline = Duration(milliseconds: 300);
    final low = await _phone(relay, links, keys.low, deadline);
    // The other side is the one gathering; it keeps its link long enough
    // to have something to say, which is not the side under test.
    final high = await _phone(relay, links, keys.high, deadline * 20);
    await Future.wait([low.transport.join(), high.transport.join()]);
    await _eventually(
      () => links.between(high.me, low.me) != null,
      'the stalled link',
    );
    final theirs = links.between(high.me, low.me)!;
    for (var i = 0; i < 6; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      theirs.found('candidate $i from high');
    }
    final taken = links.between(low.me, high.me)!.candidatesTaken;
    expect(taken.where((c) => c.startsWith('candidate ')), isNotEmpty,
        reason: 'the candidates never crossed, so nothing was exercised');
    expect(low.failures, isEmpty, reason: 'failed a link taking candidates');
    await Future<void>.delayed(deadline * 2);
    expect(low.failures, hasLength(1));
  });
  test('a link that failed is tried again when the peer announces again',
      () async {
    // The first two-phone check left the host with one failed link and no
    // way back: the phone went on announcing and every announcement was a
    // repeat. Forgetting the peer on failure is what makes the next one
    // count.
    final keys = _pair();
    final links = FakeLinks(unreachable: {keys.high.public});
    final relay = await _relay();
    final low = await _phone(relay, links, keys.low);
    final high = await _phone(relay, links, keys.high);
    await Future.wait([low.transport.join(), high.transport.join()]);
    await _eventually(() => low.failures.isNotEmpty, 'the first failure');
    expect(low.peers, isEmpty);

    // The phone becomes reachable and announces once more.
    links.unreachable.remove(keys.high.public);
    await high.transport.close();
    final again = await _phone(relay, links, keys.high);
    await again.transport.join();
    await _eventually(() => low.peers.contains(again.me),
        'a fresh link after the failure');
    expect(low.failures, hasLength(1),
        reason: 'the retry opened; nothing failed a second time');
  });

  test('what a link says about its own state reaches the steps', () async {
    final keys = _pair();
    final links = FakeLinks();
    final relay = await _relay();
    final low = await _phone(relay, links, keys.low);
    final high = await _phone(relay, links, keys.high);
    await Future.wait([low.transport.join(), high.transport.join()]);
    await _eventually(() => low.peers.contains(high.me), 'the link');

    links.between(low.me, high.me)!.progress('ice checking');
    await _settle();
    expect(
      low.link.where((s) => s.stage == LinkStage.progress).map((s) => s.detail),
      contains('ice checking'),
    );
  });
}

extension on List<int> {
  bool equals(List<int> other) =>
      length == other.length &&
      indexed.every((entry) => other[entry.$1] == entry.$2);
}
