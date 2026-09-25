import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/net/nostr/keys.dart';
import 'package:kitchentable/net/nostr/relay.dart';

import 'fake_relay.dart';

const _code = 'k7-42q';
const _otherCode = 'zz-99z';

/// A relay that is closed after the test, so a failing case does not leave a
/// port and a listening socket behind for the next one.
Future<FakeRelay> _relay() async {
  final relay = await FakeRelay.start();
  addTearDown(relay.close);
  return relay;
}

Relay _client(List<FakeRelay> relays) {
  final client = Relay(
    [for (final r in relays) r.url],
    reconnectAfter: const Duration(milliseconds: 20),
  );
  addTearDown(client.close);
  return client;
}

NostrEvent _handshake(Keys keys, String code, String content) =>
    NostrEvent.sign(
      keys,
      kind: handshakeKind,
      tags: [
        ['d', code],
      ],
      content: content,
    );

/// Waits for [condition], which is the only honest way to wait on something
/// that happens on another socket: there is no future to await for "the
/// relay has read what I wrote".
Future<void> _eventually(bool Function() condition, String what) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('waited 5s for $what');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  test('the public key derives from the private one and never the other way',
      () {
    final keys = Keys.mint();
    expect(keys.private, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(keys.public, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(keys.public, isNot(keys.private));

    // The same private key gives the same public key, every time, on any
    // device: that is what makes the public key an identity.
    expect(Keys.fromPrivate(keys.private).public, keys.public);

    // And two mintings are two people.
    expect(Keys.mint().public, isNot(keys.public));

    // The private key is the one thing that must never end up in a log, and
    // the way it would is somebody printing the keys.
    expect('$keys', contains(keys.public));
    expect('$keys', isNot(contains(keys.private)));
  });

  test('the handshake kind is ephemeral, so no relay keeps a copy', () {
    // NIP-01: 20000 to 29999 is the range relays fan out and never store.
    // Everything this app ever says to a relay is who it is and how to reach
    // it, and a stored copy of that on a hundred public relays is the one
    // privacy property nothing else in the plan can buy back.
    expect(handshakeKind, inInclusiveRange(20000, 29999));
  });

  test('an event signed here verifies, and a tampered one does not', () {
    final keys = Keys.mint();
    final event = _handshake(keys, _code, 'hello');

    expect(event.pubkey, keys.public);
    expect(event.id, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(event.sig, matches(RegExp(r'^[0-9a-f]{128}$')));
    expect(event.verify(), isTrue);

    // The same event with one byte of content changed and the old signature.
    final tampered = NostrEvent.fromJson({
      ...event.toJson(),
      'content': 'hellp',
    });
    expect(tampered.verify(), isFalse);

    // And a fresh id over the changed content, still with the old signature:
    // this is the one a forger who knows how ids work would send.
    final reHashed = NostrEvent.fromJson({
      ...tampered.toJson(),
      'id': NostrEvent.idOf(tampered),
    });
    expect(reHashed.verify(), isFalse);

    // Round trip, because the wire is JSON and the relay hashes what it gets.
    expect(NostrEvent.fromJson(event.toJson()).verify(), isTrue);
  });

  test('the relay accepts a signed event and rejects a tampered one', () async {
    final relay = await _relay();
    final client = _client([relay]);
    final keys = Keys.mint();

    final good = _handshake(keys, _code, 'hello');
    await client.publish(good);
    expect(relay.accepted, [good.id]);
    expect(relay.rejected, isEmpty);

    final tampered = NostrEvent.fromJson({
      ...good.toJson(),
      'content': 'hellp',
    });
    await client.publish(tampered);
    expect(relay.accepted, [good.id]);
    expect(relay.rejected, {tampered.id: 'invalid: id does not match'});

    final reHashed = NostrEvent.fromJson({
      ...tampered.toJson(),
      'id': NostrEvent.idOf(tampered),
    });
    await client.publish(reHashed);
    expect(relay.accepted, [good.id]);
    expect(relay.rejected[reHashed.id], 'invalid: bad signature');
  });

  test('a hostile relay forwarding a tampered event is dropped by the client',
      () async {
    final relay = await _relay();
    final listener = _client([relay]);
    final speaker = _client([relay]);
    final keys = Keys.mint();

    final sub = listener.subscribe(
      const Filter(kinds: [handshakeKind], tags: {'d': [_code]}),
    );
    final received = <NostrEvent>[];
    sub.events.listen(received.add);
    await sub.established;

    final good = _handshake(keys, _code, 'hello');
    final forged = <String, dynamic>{
      ...good.toJson(),
      'content': 'i am the host now',
    };
    forged['id'] = NostrEvent.idOf(NostrEvent.fromJson(forged));

    // The forgery goes out first on the same socket, so if the client took
    // it, it would be the first thing received and not the second.
    relay.inject(forged);
    await speaker.publish(good);

    await _eventually(() => received.isNotEmpty, 'the good event');
    expect(received.first.id, good.id);
    expect(received.first.content, 'hello');
    expect(received, hasLength(1));
    expect(sub.dropped, 1, reason: 'the forgery is counted, not thrown');
  });

  test('a subscription by kind and code hears its room and no other',
      () async {
    final relay = await _relay();
    final listener = _client([relay]);
    final speaker = _client([relay]);
    final keys = Keys.mint();

    final sub = listener.subscribe(
      const Filter(kinds: [handshakeKind], tags: {'d': [_code]}),
    );
    final received = <NostrEvent>[];
    sub.events.listen(received.add);
    await sub.established;

    // Wrong room first, then the right one, on one socket: if the wrong one
    // got through it would arrive first.
    final elsewhere = _handshake(keys, _otherCode, 'not for you');
    final here = _handshake(keys, _code, 'for you');
    await speaker.publish(elsewhere);
    await speaker.publish(here);
    expect(relay.accepted, [elsewhere.id, here.id],
        reason: 'the relay took both; only the filter keeps one out');

    await _eventually(() => received.isNotEmpty, 'the event under $_code');
    expect(received.first.id, here.id);
    expect(received.first.tags, [
      ['d', _code],
    ]);
    expect(received, hasLength(1));
  });

  test('two relays deliver one event once each, and the client hears it once',
      () async {
    final a = await _relay();
    final b = await _relay();
    final listener = _client([a, b]);
    final speaker = _client([a, b]);
    final keys = Keys.mint();

    final sub = listener.subscribe(
      const Filter(kinds: [handshakeKind], tags: {'d': [_code]}),
    );
    final received = <NostrEvent>[];
    sub.events.listen(received.add);
    await sub.established;

    final event = _handshake(keys, _code, 'hello');
    await speaker.publish(event);

    // Both relays took it and both sent it on.
    expect(a.accepted, [event.id]);
    expect(b.accepted, [event.id]);
    expect(a.forwarded, {sub.id: 1});
    expect(b.forwarded, {sub.id: 1});

    // The second copy is already on the wire when publish returns, since
    // each relay fans out before it says OK. The wait is for it to land.
    await _eventually(() => received.isNotEmpty, 'the first copy');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(received, hasLength(1));
    expect(received.single.id, event.id);
    expect(sub.dropped, 1, reason: 'the duplicate is counted');
  });

  test('a relay that closes the socket is reported and reconnected to',
      () async {
    final relay = await _relay();
    final listener = _client([relay]);
    final speaker = _client([relay]);
    final keys = Keys.mint();

    final sub = listener.subscribe(
      const Filter(kinds: [handshakeKind], tags: {'d': [_code]}),
    );
    final received = <NostrEvent>[];
    sub.events.listen(received.add);
    await sub.established;
    expect(relay.connections, 2, reason: 'listener and speaker');

    final reported = expectLater(
      listener.status,
      emitsInOrder([
        RelayStatus(relay.url, connected: false),
        RelayStatus(relay.url, connected: true),
      ]),
    );
    await relay.dropConnections();
    await reported;

    // Back, and subscribed again without being asked: a subscription is a
    // standing interest, not a message that was sent once.
    await _eventually(
      () => relay.subscriptions.contains(sub.id),
      'the subscription to come back',
    );
    final event = _handshake(keys, _code, 'still here');
    await speaker.publish(event);
    await _eventually(() => received.isNotEmpty, 'an event after reconnect');
    expect(received.single.id, event.id);
  });
}
