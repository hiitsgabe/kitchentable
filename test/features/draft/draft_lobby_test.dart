import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/decks/model/deck.dart';
import 'package:kitchentable/decks/model/deck_format.dart';
import 'package:kitchentable/features/draft/draft_room.dart';
import 'package:kitchentable/features/draft/draft_state.dart';
import 'package:kitchentable/features/draft/post_draft.dart';
import 'package:kitchentable/features/lobby/lobby.dart';
import 'package:kitchentable/table/actions/table_action.dart';
import 'package:kitchentable/table/room/room.dart';
import 'package:kitchentable/table/setup.dart';

import '../../net/fake_transport.dart';

RoomConfig _draftRoom({int seats = 2}) => RoomConfig(
  format: DeckFormat.draft,
  seats: seats,
  hostName: 'Gabe',
  roomName: 'the shed',
  draft: const DraftOptions(setCode: 'mh3', packs: 1),
);

List<List<List<DraftCard>>> _packs(List<String> seats) => [
  for (var s = 0; s < seats.length; s++)
    [
      [
        DraftCard(uuid: '${seats[s]}-1', oracleId: 'o1', rarity: 'common'),
        DraftCard(uuid: '${seats[s]}-2', oracleId: 'o2', rarity: 'common'),
      ],
    ],
];

void main() {
  test('a draft seats without a deck and opens when the chairs fill', () async {
    final net = FakeNetwork();
    final hostT = net.join('host');
    final guestT = net.join('ana');

    final host = Lobby.host(transport: hostT, config: _draftRoom());
    final guest = Lobby.guest(transport: guestT);
    await net.settle();

    // The host took its chair on its own; the guest learned it is a draft.
    expect(host.seated.length, 1, reason: 'the host seats itself');
    expect(guest.isDraft, isTrue, reason: 'the guest learned the format');
    expect(host.canStartDraft, isFalse, reason: 'a chair is still empty');

    // The guest takes a chair with a name and no deck.
    guest.attend(name: 'Ana');
    await net.settle();

    expect(host.seated.length, 2);
    expect(host.canStartDraft, isTrue, reason: 'every chair is taken');

    // The host opens the draft; the guest is pulled into it.
    final hostRoom = host.startDraft(
      (seatIds) => DraftRoom.fromPacks(
        transport: hostT,
        seatIds: seatIds,
        sealed: false,
        packsPerSeat: _packs(seatIds),
      ),
    );
    await net.settle();

    expect(guest.drafting, isTrue, reason: 'the guest heard the draft open');
    expect(guest.draft, isNotNull);

    // Each seat has been dealt its own pack of two.
    expect(hostRoom.view?.pack?.length, 2, reason: 'the host sees its pack');
    expect(guest.draft!.view?.pack?.length, 2, reason: 'the guest sees its own');

    host.dispose();
    guest.dispose();
  });

  test('a sealed draft builds decks, and the host deals the table', () async {
    final net = FakeNetwork();
    final hostT = net.join('host');
    final guestT = net.join('ana');

    final host = Lobby.host(
      transport: hostT,
      config: RoomConfig(
        format: DeckFormat.draft,
        seats: 2,
        hostName: 'Gabe',
        roomName: 'sealed',
        draft: const DraftOptions(setCode: 'mh3', sealed: true, packs: 1),
      ),
    );
    final guest = Lobby.guest(transport: guestT);
    await net.settle();
    guest.attend(name: 'Ana');
    await net.settle();

    host.startDraft(
      (seatIds) => DraftRoom.fromPacks(
        transport: hostT,
        seatIds: seatIds,
        sealed: true,
        packsPerSeat: _packs(seatIds),
      ),
    );
    await net.settle();

    // Sealed opens straight into building; each seat turns its pool into a
    // deck and hands it in.
    Deck deck(String id) =>
        Deck(id: id, name: id, format: DeckFormat.draft, slots: const []);
    host.draft!.submit(deck('host-deck'));
    guest.draft!.submit(deck('ana-deck'));
    await net.settle();

    expect(host.draftReadyToDeal, isTrue, reason: 'both decks are in');

    host.dealDraft(
      (players) => sitDownTogether(players: players, seed: 'seed'),
    );
    await net.settle();

    expect(host.dealt, isTrue, reason: 'the host is at the table');
    expect(host.drafting, isFalse, reason: 'the draft is over');
    expect(guest.dealt, isTrue, reason: 'the guest followed to the table');
    expect(guest.drafting, isFalse);

    host.dispose();
    guest.dispose();
  });

  test('four players split into two parallel 1v1 tables', () async {
    final net = FakeNetwork();
    final hostT = net.join('host');
    final g1T = net.join('g1');
    final g2T = net.join('g2');
    final g3T = net.join('g3');

    final host = Lobby.host(
      transport: hostT,
      config: RoomConfig(
        format: DeckFormat.draft,
        seats: 4,
        hostName: 'Gabe',
        roomName: 'pod',
        draft: const DraftOptions(setCode: 'mh3', sealed: true, packs: 1),
      ),
    );
    final guests = {
      'g1': Lobby.guest(transport: g1T),
      'g2': Lobby.guest(transport: g2T),
      'g3': Lobby.guest(transport: g3T),
    };
    await net.settle();
    guests['g1']!.attend(name: 'One');
    guests['g2']!.attend(name: 'Two');
    guests['g3']!.attend(name: 'Three');
    await net.settle();

    host.startDraft(
      (seatIds) => DraftRoom.fromPacks(
        transport: hostT,
        seatIds: seatIds,
        sealed: true,
        packsPerSeat: _packs(seatIds),
      ),
    );
    await net.settle();

    Deck deck(String id) =>
        Deck(id: id, name: id, format: DeckFormat.draft, slots: const []);
    host.draft!.submit(deck('host'));
    for (final e in guests.entries) {
      e.value.draft!.submit(deck(e.key));
    }
    await net.settle();

    host.dealDraftAs(
      PostDraftMode.pairs,
      (players) => sitDownTogether(players: players, seed: 'seed'),
    );
    await net.settle();

    // Host paired with g1 at one game, g2 with g3 at another.
    expect(host.mesh?.scope, 'r0g0');
    expect(guests['g1']!.mesh?.scope, 'r0g0');
    expect(guests['g2']!.mesh?.scope, 'r0g1');
    expect(guests['g3']!.mesh?.scope, 'r0g1');
    for (final l in [host, ...guests.values]) {
      expect(l.dealt, isTrue, reason: 'everyone is at a table');
    }

    // A move in the host's game reaches its opponent and neither of the other
    // table's players.
    host.mesh!.run(const ChangeLife(seatId: 's1', by: -4));
    await net.settle();
    expect(host.mesh!.table!.seat('s1')!.life, 16);
    expect(guests['g1']!.mesh!.table!.seat('s1')!.life, 16);
    expect(guests['g2']!.mesh!.table!.seat('s1')!.life, 20);
    expect(guests['g3']!.mesh!.table!.seat('s1')!.life, 20);

    host.dispose();
    for (final l in guests.values) {
      l.dispose();
    }
  });

  test('a four-player tournament runs two rounds to a champion', () async {
    final net = FakeNetwork();
    final hostT = net.join('host');
    final g1T = net.join('g1');
    final g2T = net.join('g2');
    final g3T = net.join('g3');

    final host = Lobby.host(
      transport: hostT,
      config: RoomConfig(
        format: DeckFormat.draft,
        seats: 4,
        hostName: 'Gabe',
        roomName: 'cup',
        draft: const DraftOptions(setCode: 'mh3', sealed: true, packs: 1),
      ),
    );
    final guests = {
      'g1': Lobby.guest(transport: g1T),
      'g2': Lobby.guest(transport: g2T),
      'g3': Lobby.guest(transport: g3T),
    };
    await net.settle();
    guests['g1']!.attend(name: 'One');
    guests['g2']!.attend(name: 'Two');
    guests['g3']!.attend(name: 'Three');
    await net.settle();

    host.startDraft(
      (seatIds) => DraftRoom.fromPacks(
        transport: hostT,
        seatIds: seatIds,
        sealed: true,
        packsPerSeat: _packs(seatIds),
      ),
    );
    await net.settle();
    Deck deck(String id) =>
        Deck(id: id, name: id, format: DeckFormat.draft, slots: const []);
    host.draft!.submit(deck('host'));
    for (final e in guests.entries) {
      e.value.draft!.submit(deck(e.key));
    }
    await net.settle();

    host.dealDraftAs(
      PostDraftMode.tournament,
      (players) => sitDownTogether(players: players, seed: 'seed'),
    );
    await net.settle();

    expect(host.tourneying, isTrue);
    expect(host.mesh?.scope, 'r0g0', reason: 'host plays the first semi');

    // Round 0 results: host beats g1, g2 beats g3.
    host.reportWinner('r0g0', 'host');
    guests['g2']!.reportWinner('r0g1', 'g2');
    await net.settle();

    // The losers are out and the winners meet in the final.
    expect(guests['g1']!.eliminated, isTrue);
    expect(guests['g3']!.eliminated, isTrue);
    expect(host.mesh?.scope, 'r1g0', reason: 'host advanced to the final');
    expect(guests['g2']!.mesh?.scope, 'r1g0', reason: 'so did g2');

    // The final: host wins the cup.
    host.reportWinner('r1g0', 'host');
    await net.settle();

    expect(host.tournament?.champion, 'host');
    expect(host.bracket?['champion'], 'host');
    expect(guests['g2']!.bracket?['champion'], 'host', reason: 'guests see it');

    host.dispose();
    for (final l in guests.values) {
      l.dispose();
    }
  });
}
