import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/decks/model/deck.dart';
import 'package:kitchentable/decks/model/deck_format.dart';
import 'package:kitchentable/features/draft/bracket_screen.dart';
import 'package:kitchentable/features/draft/draft_room.dart';
import 'package:kitchentable/features/draft/draft_state.dart';
import 'package:kitchentable/features/draft/post_draft.dart';
import 'package:kitchentable/features/lobby/lobby.dart';
import 'package:kitchentable/table/room/room.dart';
import 'package:kitchentable/table/setup.dart';

import '../../net/fake_transport.dart';

/// Pins the bracket screen to a lobby driven to a known state.
class _Fixed extends LobbyHere {
  _Fixed(this._lobby);
  final Lobby _lobby;
  @override
  Lobby? build() => _lobby;
}

List<List<List<DraftCard>>> _packs(List<String> seats) => [
  for (final s in seats)
    [
      [DraftCard(uuid: '$s-1', oracleId: 'o1', rarity: 'common')],
    ],
];

void main() {
  testWidgets('the bracket shows the standings and the champion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    late Lobby host;
    await tester.runAsync(() async {
      final net = FakeNetwork();
      final hostT = net.join('host');
      final g1T = net.join('g1');
      final g2T = net.join('g2');
      final g3T = net.join('g3');
      host = Lobby.host(
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
      host.reportWinner('r0g0', 'host');
      guests['g2']!.reportWinner('r0g1', 'g2');
      await net.settle();
      host.reportWinner('r1g0', 'host');
      await net.settle();
    });

    expect(host.tournament?.champion, 'host', reason: 'drove it to the end');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [lobbyProvider.overrideWith(() => _Fixed(host))],
        child: const MaterialApp(home: BracketScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('wins the pod'), findsWidgets);
    expect(
      find.textContaining('Gabe'),
      findsWidgets,
      reason: 'in the standings',
    );
  });
}
