import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/net/nostr/keys.dart';
import 'package:kitchentable/net/nostr/relay.dart';
import 'package:kitchentable/net/relay_transport.dart';
import 'package:kitchentable/net/connection_report.dart';
import 'package:kitchentable/net/link.dart';
import 'package:kitchentable/net/signaling.dart';
import 'package:kitchentable/net/transport.dart';

import 'nostr/fake_relay.dart';

/// A transport on its own [Relay] against the shared fake relay, with
/// everything it reported collected so a case can read what happened.
class _Phone {
  _Phone(FakeRelay relay, {Duration? announceEvery})
      : transport = RelayTransport(
          relay: Relay([relay.url]),
          keys: Keys.mint(),
          code: _code,
          announceEvery: announceEvery ?? const Duration(seconds: 20),
        ) {
    transport.incoming.listen(got.add);
    transport.presence.listen(saw.add);
    transport.steps.listen(steps.add);
    addTearDown(transport.close);
  }

  final RelayTransport transport;
  final got = <Incoming>[];
  final saw = <PeerEvent>[];
  final steps = <ConnectionStep>[];

  String get me => transport.me;
  Set<String> get peers => transport.peers;
}

const _code = 'abcd-efg';

Future<void> _eventually(bool Function() done, String what) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) fail('waited 5s for $what');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 150));

void main() {
  test('two phones on one relay find each other and carry a message both ways',
      () async {
    final relay = await FakeRelay.start();
    addTearDown(relay.close);
    final a = _Phone(relay);
    final b = _Phone(relay);
    await a.transport.join();
    await b.transport.join();

    // No link, no NAT: hearing each other on the relay is the connection.
    await _eventually(
      () => a.peers.contains(b.me) && b.peers.contains(a.me),
      'each to see the other',
    );
    expect(a.saw.map((e) => e.presence), contains(Presence.arrived));

    a.transport.send(b.me, 'draw a card');
    b.transport.send(a.me, 'countered');
    await _eventually(
      () => b.got.any((i) => i.body == 'draw a card') &&
          a.got.any((i) => i.body == 'countered'),
      'both messages',
    );
    expect(b.got.single.from, a.me, reason: 'the sender is the transport\'s word');
    expect(a.got.single.from, b.me);
  });

  test('a message addressed to one phone does not reach another', () async {
    final relay = await FakeRelay.start();
    addTearDown(relay.close);
    final a = _Phone(relay);
    final b = _Phone(relay);
    final c = _Phone(relay);
    await a.transport.join();
    await b.transport.join();
    await c.transport.join();
    await _eventually(
      () => a.peers.length == 2 && b.peers.contains(a.me),
      'the room to form',
    );

    a.transport.send(b.me, 'for b only');
    await _settle();
    expect(b.got.map((i) => i.body), contains('for b only'));
    expect(c.got.map((i) => i.body), isNot(contains('for b only')),
        reason: 'c is in the room but was not addressed');
  });

  test('leaving says so, and the others drop the seat', () async {
    final relay = await FakeRelay.start();
    addTearDown(relay.close);
    final a = _Phone(relay);
    final b = _Phone(relay);
    await a.transport.join();
    await b.transport.join();
    await _eventually(() => a.peers.contains(b.me), 'b to arrive');

    await b.transport.close();
    await _eventually(() => !a.peers.contains(b.me), 'b to leave');
    expect(a.saw.last.presence, Presence.left);
    expect(a.saw.last.peerId, b.me);
  });

  test('the steps say the relay was reached and the peer turned up', () async {
    final relay = await FakeRelay.start();
    addTearDown(relay.close);
    final a = _Phone(relay);
    final b = _Phone(relay);
    await a.transport.join();
    await b.transport.join();
    await _eventually(() => a.peers.contains(b.me), 'b to arrive');

    final rendezvous = a.steps.whereType<RendezvousStep>().map((s) => s.status.step);
    expect(rendezvous, contains(SignalingStep.relayConnected));
    expect(rendezvous, contains(SignalingStep.announced));
    expect(rendezvous, contains(SignalingStep.peerHere));
    // The seat fills off an opened link step, the same one WebRTC gives, so
    // the room screen does not need to know which transport it is watching.
    expect(
      a.steps.whereType<LinkStep>().map((s) => s.status.stage),
      contains(LinkStage.opened),
    );
  });
}
