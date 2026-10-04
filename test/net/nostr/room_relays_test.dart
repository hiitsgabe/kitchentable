import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/net/nostr/room_relays.dart';

void main() {
  group('which relays a room is on', () {
    test('every phone holding the code picks the same ones', () {
      // The whole point. Two people who agree on nothing but a seven
      // character code have to end up on the same relays or they never see
      // each other.
      expect(relaysFor('abcd-efg'), relaysFor('abcd-efg'));
    });

    test('two rooms are almost never on the same five', () {
      // Spreading rooms across the pool is what stops one relay carrying
      // the whole app, which is what got this client banned from the
      // busiest one.
      final a = relaysFor('abcd-efg').toSet();
      final b = relaysFor('hijk-lmn').toSet();

      expect(a.intersection(b).length, lessThan(a.length));
    });

    test('it takes as many as it was asked for, and they are distinct', () {
      final five = relaysFor('abcd-efg');

      expect(five, hasLength(relayRedundancy));
      expect(five.toSet(), hasLength(relayRedundancy));
      expect(five.every((u) => u.scheme == 'wss'), isTrue);
    });

    test('asking for more than the pool holds gives the pool', () {
      expect(
        relaysFor('abcd-efg', redundancy: 999),
        hasLength(relayPool.length),
      );
    });

    test('the pool holds none of the three that banned us', () {
      // Not a style choice. This client has been rate limited and banned by
      // relay.damus.io, and the fix for that is not to send less.
      for (final busy in ['damus', 'nos.lol', 'primal']) {
        expect(
          relayPool.where((u) => u.contains(busy)),
          isEmpty,
          reason: '$busy is the queue, not the relay',
        );
      }
    });
  });

  group('which kind a room rides on', () {
    test('it is in the ephemeral range, which relays forward and forget', () {
      for (final code in ['abcd-efg', 'zzzz-zzz', 'a', '']) {
        expect(handshakeKindFor(code), inInclusiveRange(20000, 29999));
        expect(roomDataKindFor(code), inInclusiveRange(20000, 29999));
      }
    });

    test('the game rides one above the handshake', () {
      // Two kinds so a subscription can tell the introduction from the
      // game, which is what the two fixed kinds used to do.
      expect(roomDataKindFor('abcd-efg'), handshakeKindFor('abcd-efg') + 1);
    });

    test('it is nobody else s kind', () {
      // 25050 is the kind the NIP-RTC draft reserves for WebRTC signalling,
      // and this app used to send every room's traffic on it.
      final taken = {
        for (final code in ['abcd-efg', 'hijk-lmn', 'opqr-stu'])
          roomDataKindFor(code),
      };

      expect(taken, isNot(contains(25050)));
    });

    test('two rooms almost never share one', () {
      final kinds = {for (var i = 0; i < 200; i++) roomDataKindFor('room-$i')};

      // Across two hundred rooms in a range of ten thousand, a handful of
      // collisions is birthday arithmetic and not a bug. A dozen would mean
      // the hash is not spreading.
      expect(kinds.length, greaterThan(190));
    });
  });

  test('the hash is the same number on every run', () {
    // String.hashCode is seeded per isolate in Dart and is explicitly not
    // stable across runs. Using it here would put two phones holding one
    // code on two different kinds, and they would never meet.
    expect(stableHash("abcd-efg"), 1411438980);
    expect(stableHash(''), 0x811c9dc5 & 0x7fffffff);
    expect(stableHash('a'), isNot(stableHash('b')));
  });
}
