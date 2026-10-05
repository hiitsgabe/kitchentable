import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/draft/booster_roller.dart';
import 'package:kitchentable/features/draft/draft_room.dart';
import 'package:kitchentable/features/draft/draft_state.dart';
import 'package:kitchentable/sources/model/draft_set.dart';

import '../../net/fake_transport.dart';

DraftPrinting _p(String uuid) => DraftPrinting(
  setCode: 'TST',
  uuid: uuid,
  oracleId: 'o-$uuid',
  rarity: 'common',
  number: uuid,
);

/// A roller that hands out scripted packs in order, so a pod is predictable
/// without real booster JSON. The host rolls packCount packs per seat, in
/// seat order, so for two seats and one pack the order is [seat0, seat1].
class _ScriptRoller extends BoosterRoller {
  _ScriptRoller(this._packs)
    : super(booster: const {'play': {}}, printings: {});
  final List<List<DraftPrinting>> _packs;
  var _i = 0;
  @override
  List<DraftPrinting> rollPack() => _packs[_i++];
}

void main() {
  test('each seat is dealt only its own pack, never another seat\'s', () async {
    final net = FakeNetwork();
    final hostT = net.join('host');
    final guestT = net.join('ana');

    DraftView? guestView;
    final guest = DraftRoom.guest(transport: guestT, hostId: 'host');
    addTearDown(guest.close);
    guest.views.listen((v) => guestView = v);

    final host = DraftRoom.host(
      transport: hostT,
      seatIds: const ['host', 'ana'],
      sealed: false,
      packCount: 1,
      roller: _ScriptRoller([
        [_p('h1'), _p('h2')],
        [_p('a1'), _p('a2')],
      ]),
    );
    addTearDown(host.close);
    await net.settle();

    expect(host.view!.pack!.map((c) => c.uuid), [
      'h1',
      'h2',
    ], reason: 'the host sees the pack it cracked');
    expect(guestView!.pack!.map((c) => c.uuid), [
      'a1',
      'a2',
    ], reason: 'ana sees her own pack, not the host\'s');
    expect(guestView!.pack!.map((c) => c.uuid), isNot(contains('h1')));
    expect(host.view!.fresh, isTrue, reason: 'a cracked pack animates');
  });

  test(
    'a guest pick reaches the host, which moves the pack and pushes back',
    () async {
      final net = FakeNetwork();
      final hostT = net.join('host');
      final guestT = net.join('ana');

      DraftView? guestView;
      final guest = DraftRoom.guest(transport: guestT, hostId: 'host');
      addTearDown(guest.close);
      guest.views.listen((v) => guestView = v);

      final host = DraftRoom.host(
        transport: hostT,
        seatIds: const ['host', 'ana'],
        sealed: false,
        packCount: 1,
        roller: _ScriptRoller([
          [_p('h1'), _p('h2')],
          [_p('a1'), _p('a2')],
        ]),
      );
      addTearDown(host.close);
      await net.settle();
      expect(guestView!.pack!.map((c) => c.uuid), ['a1', 'a2']);

      guest.pick('a1');
      await net.settle();

      expect(guestView!.pool.map((c) => c.uuid), ['a1']);
      // a2 passed to the host, where it waits behind the host's own pack.
      expect(host.view!.pack!.map((c) => c.uuid), ['h1', 'h2']);
      expect(host.view!.queueDepth, 1, reason: 'ana\'s pack waits behind');

      // The host picks its own card; next it sees the one ana passed.
      host.pick('h1');
      await net.settle();
      expect(host.view!.pack!.map((c) => c.uuid), ['a2']);
      expect(
        host.view!.fresh,
        isFalse,
        reason: 'a passed pack does not animate',
      );
    },
  );

  test(
    'sealed deals the whole pool at once and everyone is building',
    () async {
      final net = FakeNetwork();
      final hostT = net.join('host');
      final guestT = net.join('ana');

      DraftView? guestView;
      final guest = DraftRoom.guest(transport: guestT, hostId: 'host');
      addTearDown(guest.close);
      guest.views.listen((v) => guestView = v);

      final host = DraftRoom.host(
        transport: hostT,
        seatIds: const ['host', 'ana'],
        sealed: true,
        packCount: 2,
        roller: _ScriptRoller([
          [_p('h1')],
          [_p('h2')],
          [_p('a1')],
          [_p('a2')],
        ]),
      );
      addTearDown(host.close);
      await net.settle();

      expect(host.view!.phase, DraftPhase.building);
      expect(host.view!.pool.map((c) => c.uuid), ['h1', 'h2']);
      expect(guestView!.phase, DraftPhase.building);
      expect(guestView!.pool.map((c) => c.uuid), ['a1', 'a2']);
    },
  );
}
