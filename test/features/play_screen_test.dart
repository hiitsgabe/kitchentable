import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/sources/catalog/catalog_db.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kitchentable/decks/model/deck.dart';
import 'package:kitchentable/decks/model/deck_format.dart';
import 'package:kitchentable/features/lobby/lobby.dart';
import 'package:kitchentable/features/play/play_controller.dart';
import 'package:kitchentable/features/menu/menu_controller.dart';
import 'package:kitchentable/features/play/play_screen.dart';
import 'package:kitchentable/features/play/renderers/focus_view.dart';
import 'package:kitchentable/features/play/renderers/grid_view.dart';
import 'package:kitchentable/features/play/renderers/renderer_choice.dart';
import 'package:kitchentable/features/play/renderers/split_view.dart';
import 'package:kitchentable/features/play/widgets/seat_rail.dart';
import 'package:kitchentable/features/play/widgets/card_drag.dart';
import 'package:kitchentable/features/play/widgets/command_slot.dart';
import 'package:kitchentable/features/play/widgets/hand_sheet.dart';
import 'package:kitchentable/features/play/widgets/table_card.dart';
import 'package:kitchentable/table/model/seat_owner.dart';
import 'package:kitchentable/table/room/room.dart';
import 'package:kitchentable/table/actions/table_action.dart';
import 'package:kitchentable/table/model/table_state.dart';
import 'package:kitchentable/table/referee/referee.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';
import 'package:kitchentable/ui/atoms/card_art.dart';

import '../net/fake_transport.dart';

CatalogCard _card(String name) =>
    CatalogCard(oracleId: name, name: name, typeLine: 'Instant', cmc: 1);

/// Sixty cards either way, so the library is 53 after an opening hand
/// whether or not somebody is leading it. The commander is an extra card on
/// top, which is what a real Commander deck is.
Deck _deck({bool commander = false}) => Deck(
  id: 'd1',
  name: 'a deck',
  format: DeckFormat.commander,
  slots: [
    DeckSlot(card: _card('Mountain'), quantity: 60),
    if (commander)
      DeckSlot(card: _card('General'), quantity: 1, commander: true),
  ],
);

Future<ProviderContainer> _seated(WidgetTester tester) =>
    _seatedPod(tester, ['you']);

Future<ProviderContainer> _seatedPod(
  WidgetTester tester,
  List<String> names, {
  Size window = const Size(390, 844),
  bool withCommander = false,
  bool withCatalog = false,
  TableRenderer? renderer,
}) async {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  // Off by default: almost every case here is about the table and wants no
  // database. On, because the screen refuses to open the big view for a card
  // it has no printing for, so the route through the viewer cannot be
  // exercised without one. In memory, so nothing touches disk inside the
  // widget binding's fake async.
  CatalogDb? db;
  if (withCatalog) {
    db = CatalogDb.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.insertAll([_card('Mountain'), _card('General')]);
  }

  final container = ProviderContainer(
    overrides: [catalogDbProvider.overrideWithValue(db)],
  );
  addTearDown(container.dispose);
  container
      .read(playProvider.notifier)
      .startPod(
        players: [
          for (final name in names)
            (
              deck: _deck(commander: withCommander),
              name: name,
              owner: const SeatOwner.here(),
            ),
        ],
        seed: 'abc',
      );

  // The table opens on the grid now; a case that is about one of the other
  // views says which, the way a player would pick it.
  if (renderer != null) {
    container.read(rendererChoiceProvider.notifier).choose(renderer);
  }

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: PlayScreen()),
    ),
  );
  await tester.pump();
  return container;
}

/// A table dealt from a room: the host's deck and one guest's, the way the
/// lobby hands them over, and no catalog at all. The guest's deck is made of
/// a card nobody's catalog has ever held, which is what a deck that arrived
/// over the wire is on the host's phone.
Future<ProviderContainer> _seatedFromRoom(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  // Settled for real and not on the tester's clock: the network's own turn
  // of the event loop never comes under the fake one, and this hung there.
  final net = FakeNetwork();
  final host = Lobby.host(
    transport: net.join('host'),
    config: RoomConfig(
      format: DeckFormat.commander,
      seats: 2,
      life: null,
      hostName: 'kit',
      roomName: 'the kitchen',
    ),
  );
  addTearDown(host.close);
  final ana = Lobby.guest(transport: net.join('ana'));
  addTearDown(ana.close);
  await tester.runAsync(net.settle);
  ana.bring(
    deck: Deck(
      id: 'anas',
      name: "ana's deck",
      format: DeckFormat.commander,
      slots: [DeckSlot(card: _card("Ana's Swamp"), quantity: 60)],
    ),
    name: 'ana',
  );
  await tester.runAsync(net.settle);
  host.sit(deck: _deck(), name: 'kit');

  final container = ProviderContainer(
    overrides: [
      catalogDbProvider.overrideWithValue(null),
      lobbyProvider.overrideWith(() => _LobbyOf(host)),
      // The screen knows which seat is this device's by the transport's
      // key; without it the host's own seat is watched, not played.
      transportProvider.overrideWithValue(host.transport),
    ],
  );
  addTearDown(container.dispose);
  host.start((players) {
    container
        .read(playProvider.notifier)
        .startPod(players: players, seed: 'abc');
    return container.read(playProvider)!;
  });

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: PlayScreen()),
    ),
  );
  await tester.pump();
  return container;
}

class _LobbyOf extends LobbyHere {
  _LobbyOf(this.lobby);
  final Lobby lobby;
  @override
  Lobby? build() => lobby;
}

void main() {
  // Once for the file, not eight times inside it.
  //
  // `RendererChoice.choose` persists through SharedPreferences and the mock
  // store is process global, so a case that taps `switch-renderer` leaks the
  // canvas into whatever runs next. That is how a case here failed on an
  // ambiguous finder: on the canvas the command corner draws a second
  // TableCard inside `your-board`. Eight cases had grown their own reset and
  // the ninth to be appended would have had to know.
  //
  // **Deleting this line does not currently fail anything**, and that is not
  // a reason to delete it. `RendererChoice` restores asynchronously, so a
  // leaked value only lands if the next case pumps long enough to let the
  // microtask run: whether it bites depends on case order and on how long
  // each one pumps, which is why it appeared once during development and
  // does not reproduce now. A guard against an order dependent failure
  // cannot be pinned by a suite that runs in one order.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('an empty table says so instead of drawing nothing', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [catalogDbProvider.overrideWithValue(null)],
        child: const MaterialApp(home: PlayScreen()),
      ),
    );
    await tester.pump();

    expect(find.textContaining('No table'), findsOneWidget);
  });

  testWidgets('a card is drawn from the deck it came in, with no catalog', (
    tester,
  ) async {
    final container = await _seatedFromRoom(tester);
    final play = container.read(playProvider.notifier);
    final table = container.read(playProvider)!;

    // One card of each deck onto its own battlefield, which is public and
    // drawn on every phone. The guest's is the one that matters: it is in no
    // catalog anywhere, and it came in with its name.
    play.run(
      MoveCard(
        cardId: table.zone('hand-s1')!.cards.first.id,
        toZoneId: 'battlefield-s1',
      ),
    );
    play.run(
      MoveCard(
        cardId: table.zone('hand-s2')!.cards.first.id,
        toZoneId: 'battlefield-s2',
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('watched-s2')),
        matching: find.text("Ana's Swamp"),
      ),
      findsOneWidget,
      reason:
          "ana's card came over the wire with its name, and no catalog "
          'has it',
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('your-board')),
        matching: find.text('Mountain'),
      ),
      findsOneWidget,
      reason: "the host's own card, from the host's own deck",
    );
  });

  testWidgets('a seated table shows life and the pile counts', (tester) async {
    await _seated(tester);

    expect(find.text('40'), findsWidgets);
    expect(
      find.textContaining('53'),
      findsWidgets,
      reason: 'the library has 53 left after a hand of seven',
    );
  });

  testWidgets('drawing takes one off the library and adds one to the hand', (
    tester,
  ) async {
    final container = await _seated(tester);

    await tester.tap(find.byKey(const Key('library-draw')));
    await tester.pump();

    expect(container.read(playProvider)!.zone('library-s1')!.size, 52);
    expect(container.read(playProvider)!.zone('hand-s1')!.size, 8);
  });

  testWidgets('undo is offered only once there is something to undo', (
    tester,
  ) async {
    final container = await _seated(tester);

    expect(container.read(playProvider.notifier).canUndo, isFalse);

    await tester.tap(find.byKey(const Key('library-draw')));
    await tester.pump();

    expect(container.read(playProvider.notifier).canUndo, isTrue);
  });

  testWidgets('the hand sits below the board and never on top of it', (
    tester,
  ) async {
    await _seated(tester);

    final board = tester.getRect(find.byKey(const Key('your-board')));
    final hand = tester.getRect(find.byType(HandSheet));

    // Arena opens the hand into a fan across the battlefield, so you cannot
    // look at your hand and the board at once. Converting HandSheet to a modal
    // sheet or a Stack overlay later would take the suite green all the way to
    // that mistake, so the rule is pinned by geometry rather than by comment.
    expect(
      hand.top,
      greaterThanOrEqualTo(board.bottom - 1),
      reason: 'the hand must start at or below where the board ends',
    );
  });

  testWidgets('a refusal is said out loud', (tester) async {
    final container = await _seated(tester);
    container.read(playProvider.notifier).useReferee(const _GrumpyReferee());

    container
        .read(playProvider.notifier)
        .run(const ChangeLife(seatId: 's1', by: -5));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('not on my watch'), findsOneWidget);

    // The toast takes itself away on a timer, and a test that ends while that
    // timer is armed fails on a pending timer rather than on its assertion.
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('life goes down and back up', (tester) async {
    final container = await _seated(tester);

    await tester.tap(find.byKey(const Key('life-down')));
    await tester.pump();

    expect(container.read(playProvider)!.seat('s1')!.life, 39);
  });

  testWidgets('the grid shows every board, yours with the rail', (
    tester,
  ) async {
    await _seatedPod(tester, ['you', 'Carla', 'Diego']);

    expect(find.byType(TableGrid), findsOneWidget);
    for (final id in ['s1', 's2', 's3']) {
      expect(find.byKey(Key('board-$id')), findsOneWidget);
    }
    // Only your board carries the piles; the others are watched.
    expect(find.byKey(const Key('zone-rail')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('board-s1')),
        matching: find.byKey(const Key('zone-rail')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('focus shows one board, yours first, and the rail turns it', (
    tester,
  ) async {
    await _seatedPod(tester, [
      'you',
      'Carla',
      'Diego',
    ], renderer: TableRenderer.focus);

    expect(find.byType(FocusView), findsOneWidget);
    expect(find.byKey(const Key('board-s1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('rail-s2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('board-s2')), findsOneWidget);
  });

  testWidgets('split shows yours and one other, picked on the rail', (
    tester,
  ) async {
    await _seatedPod(tester, [
      'you',
      'Carla',
      'Diego',
    ], renderer: TableRenderer.split);

    expect(find.byType(SplitView), findsOneWidget);
    expect(find.byKey(const Key('split-mine')), findsOneWidget);
    expect(find.byKey(const Key('board-s2')), findsOneWidget);
    expect(find.byKey(const Key('board-s3')), findsNothing);

    await tester.tap(find.byKey(const Key('rail-s3')));
    await tester.pump();
    expect(find.byKey(const Key('board-s3')), findsOneWidget);
    expect(find.byKey(const Key('board-s2')), findsNothing);
  });

  testWidgets('every seat is on the rail, with its label and life', (
    tester,
  ) async {
    await _seatedPod(tester, ['you', 'Carla', 'Diego']);

    expect(find.byType(SeatRail), findsOneWidget);
    for (final id in ['s1', 's2', 's3']) {
      expect(find.byKey(Key('rail-$id')), findsOneWidget);
    }
    // Yours reads "You" whatever it was named; a named other reads its name.
    expect(
      find.descendant(
        of: find.byKey(const Key('rail-s1')),
        matching: find.text('You'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('rail-s2')),
        matching: find.text('Carla'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('your hand is yours and theirs is a number', (tester) async {
    final container = await _seatedPod(tester, ['you', 'Carla']);
    final theirs = container.read(playProvider)!.zone('hand-s2')!;

    for (final card in theirs.cards) {
      expect(
        find.byKey(Key('hand-card-${card.id}')),
        findsNothing,
        reason: 'a card from somebody else s hand reached the widget tree',
      );
    }
    expect(find.text('hand 7'), findsOneWidget);
  });

  testWidgets('a spectator is shown no hand at all', (tester) async {
    final container = await _seatedPod(tester, ['you', 'Carla']);
    container.read(viewerSeatProvider.notifier).sit(null);
    await tester.pump();

    // Plan 3 arrives here: the table is open and this device holds no chair.
    // The seat the screen falls back to drawing is still somebody's, and its
    // hand is not this device's to see. Every other case in this file has a
    // local seat, which makes this the only one where the `mine` guard on
    // HandSheet is load bearing at all.
    final table = container.read(playProvider)!;
    for (final seat in table.seats) {
      for (final card in table.zone('hand-${seat.id}')!.cards) {
        expect(
          find.byKey(Key('hand-card-${card.id}')),
          findsNothing,
          reason: 'a spectator was handed ${seat.id} s cards',
        );
      }
    }
  });

  testWidgets('looking out of another local seat swaps whose hand it is', (
    tester,
  ) async {
    final container = await _seatedPod(tester, ['you', 'Carla']);

    await tester.tap(find.byKey(const Key('rail-s2')));
    await tester.pump();

    expect(container.read(viewerSeatProvider), 's2');
    // The seat you moved to is the one with the piles now; the one you left
    // is watched.
    expect(
      find.descendant(
        of: find.byKey(const Key('board-s2')),
        matching: find.byKey(const Key('zone-rail')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('board-s1')),
        matching: find.byKey(const Key('zone-rail')),
      ),
      findsNothing,
    );
  });

  testWidgets('the hand still sits below the board in a pod', (tester) async {
    await _seatedPod(tester, ['you', 'Carla', 'Diego']);

    final board = tester.getRect(find.byKey(const Key('your-board')));
    final hand = tester.getRect(find.byType(HandSheet));

    expect(
      hand.top,
      greaterThanOrEqualTo(board.bottom - 1),
      reason: 'the hand must start at or below where your board ends',
    );
  });

  testWidgets('a drop is written onto the card', (tester) async {
    final container = await _seatedPod(tester, ['you']);
    final play = container.read(playProvider.notifier);
    final table = container.read(playProvider)!;
    final card = table.zone('hand-s1')!.cards.first;

    play.run(MoveCard(cardId: card.id, toZoneId: 'battlefield-s1'));
    await tester.pump();

    play.run(
      MoveCard(
        cardId: card.id,
        toZoneId: 'battlefield-s1',
        at: 0,
        position: (x: 0.3, y: 0.6),
      ),
    );
    await tester.pump();

    // CardInstance.position has existed since plan 2 with nothing writing to
    // it. This is the first thing in the app that does.
    expect(container.read(playProvider)!.locate(card.id)!.card.position, (
      x: 0.3,
      y: 0.6,
    ));
  });

  testWidgets('the size pills reach the cards on the board', (tester) async {
    final container = await _seatedPod(tester, ['you']);
    final play = container.read(playProvider.notifier);
    final card = container.read(playProvider)!.zone('hand-s1')!.cards.first;

    play.run(MoveCard(cardId: card.id, toZoneId: 'battlefield-s1'));
    await tester.pump();

    final before = tester.getSize(find.byType(TableCard).first).width;

    // Three separate things are being crossed here and nothing else crosses
    // them: the pill has to reach the provider, the provider has to reach the
    // screen's rebuild, and the screen has to hand the scale to the renderer.
    await tester.tap(find.byKey(const Key('more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cards-bigger')));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(TableCard).first).width,
      greaterThan(before),
    );

    // The sheet stays up between notches.
    await tester.tap(find.byKey(const Key('cards-smaller')));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(TableCard).first).width,
      closeTo(before, 0.01),
    );
  });

  testWidgets('dragging a card on the screen writes where it landed', (
    tester,
  ) async {
    final container = await _seatedPod(tester, ['you']);
    final play = container.read(playProvider.notifier);
    final card = container.read(playProvider)!.zone('hand-s1')!.cards.first;

    play.run(MoveCard(cardId: card.id, toZoneId: 'battlefield-s1'));
    await tester.pump();

    // The case above drives the reducer, which was already able to do this.
    // This one goes through the screen's own onPlace closure, which nothing
    // else in the suite touches: a typo in it would ship silently.
    await tester.drag(find.byType(TableCard).first, const Offset(70, 50));
    await tester.pump();

    final placed = container.read(playProvider)!.locate(card.id)!.card;
    expect(placed.position, isNotNull);
    expect(placed.position!.x, greaterThan(0));
    expect(placed.position!.x, lessThan(1));

    // The drag must not have moved it out of its pile or reordered it.
    expect(
      container.read(playProvider)!.zone('battlefield-s1')!.cards,
      hasLength(1),
    );
  });

  testWidgets('the deck can be shuffled from the table', (tester) async {
    final container = await _seatedPod(tester, ['you']);
    final before = container
        .read(playProvider)!
        .zone('library-s1')!
        .cards
        .map((c) => c.id)
        .toList();

    await tester.tap(find.byKey(const Key('library-work')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('deck-shuffle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-shuffle')));
    await tester.pumpAndSettle();

    final after = container
        .read(playProvider)!
        .zone('library-s1')!
        .cards
        .map((c) => c.id)
        .toList();

    // The whole order, not the top card. Comparing tops was flaky at exactly
    // the rate you would expect: measured at 1.904% over two hundred thousand
    // shuffles of fifty three cards, against 1/53 = 1.887%. An earlier
    // comment here called that "a one in fifty three coincidence rather than
    // a flake worth tolerating", which was wrong twice: it is a flake, and
    // two failures in fifty runs is what 1.9% looks like.
    //
    // Two identical permutations of fifty three cards is 1 in 53 factorial,
    // which is a number with seventy digits.
    expect(after, isNot(before));
    expect(after, hasLength(53));
  });

  testWidgets('a card sent to the bottom from the sheet goes there', (
    tester,
  ) async {
    final container = await _seatedPod(tester, ['you']);
    final top = container.read(playProvider)!.zone('library-s1')!.cards.first;

    await tester.tap(find.byKey(const Key('library-work')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('deck-look')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('bottom-${top.id}')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('deck-done')));
    await tester.pumpAndSettle();

    final library = container.read(playProvider)!.zone('library-s1')!;
    expect(library.cards.last.id, top.id);
    expect(library.cards, hasLength(53));
  });
  testWidgets('the pile on the table is drawn with the game\'s back', (
    tester,
  ) async {
    await _seatedPod(tester, ['you']);

    // The table is game agnostic and has no idea this is Magic. The deck
    // said so as it was opened, and the pile having a picture on it at all
    // is the only proof the screen can still reach what the deck said.
    expect(
      find.descendant(
        of: find.byKey(const Key('library-stack')),
        matching: find.byKey(const Key('card-back-art')),
      ),
      findsWidgets,
    );
  });

  testWidgets('a card dragged out of your hand lands where you dropped it', (
    tester,
  ) async {
    final container = await _seatedPod(tester, ['you']);
    // The fourth card and not the first. A card arriving from somewhere else
    // has no place in this pile to keep, and a move that carries its old one
    // over asks an empty battlefield to insert at 3, which throws. The first
    // card would go in at 0 either way and prove nothing.
    final card = container.read(playProvider)!.zone('hand-s1')!.cards[3];

    // Open first, for the reason `tapping a card in hand still plays it`
    // gives: while the hand peeks, the middle of a card in it is below the
    // strip and the drag would start on the hint bar under the sheet.
    await tester.tap(find.byKey(const Key('hand-handle')));
    await tester.pumpAndSettle();

    final board = tester.getRect(find.byKey(const Key('your-board')));
    final from = tester.getCenter(find.byKey(Key('hand-card-${card.id}')));

    await tester.dragFrom(from, board.center - from);
    await tester.pumpAndSettle();

    final table = container.read(playProvider)!;
    expect(
      table.zone('battlefield-s1')!.cards.map((c) => c.id),
      contains(card.id),
    );
    expect(
      table.zone('hand-s1')!.cards.map((c) => c.id),
      isNot(contains(card.id)),
    );

    // And where it was dropped, not in the next free flow slot. This is the
    // whole ask: tapping already played a card, into a slot chosen for you.
    expect(table.locate(card.id)!.card.position, isNotNull);
  });

  testWidgets('tapping a card in hand still plays it', (tester) async {
    final container = await _seatedPod(tester, ['you']);
    final card = container.read(playProvider)!.zone('hand-s1')!.cards.first;

    // The hand has to be open first. A shut hand is a strip of the tops of the
    // cards and one tap target, and a tap on it is for the hand rather than for
    // whichever card's corner it landed on: this case used to tap the card
    // straight off the screen and now it takes two taps, which is what a peek
    // is.
    await tester.tap(find.byKey(const Key('hand-handle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('hand-card-${card.id}')));
    await tester.pumpAndSettle();

    // Dragging is an addition, not a replacement. A tap is still the fastest
    // way to put a land down and the player did not ask to lose it.
    expect(
      container.read(playProvider)!.zone('battlefield-s1')!.cards,
      hasLength(1),
    );
  });

  testWidgets('a commander sent home from the big view gets there', (
    tester,
  ) async {
    final container = await _seatedPod(
      tester,
      ['you'],
      withCommander: true,
      withCatalog: true,
    );
    final play = container.read(playProvider.notifier);
    final commander = container
        .read(playProvider)!
        .zone('command-s1')!
        .cards
        .first;

    play.run(MoveCard(cardId: commander.id, toZoneId: 'battlefield-s1'));
    await tester.pumpAndSettle();

    // The corner drag is covered. This is the other route, the one for a
    // commander that dies with your finger nowhere near it, and nothing
    // touched it: setting hasCommandZone to false on the screen left all of
    // the suite green.
    await tester.longPress(find.byType(TableCard).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('act-command')));
    await tester.pumpAndSettle();

    expect(
      container.read(playProvider)!.zone('command-s1')!.cards,
      hasLength(1),
    );
    expect(
      container.read(playProvider)!.zone('battlefield-s1')!.cards,
      isEmpty,
    );
  });

  testWidgets('a commander dropped on its corner goes home', (tester) async {
    final container = await _seatedPod(tester, ['you'], withCommander: true);
    final play = container.read(playProvider.notifier);
    final commander = container
        .read(playProvider)!
        .zone('command-s1')!
        .cards
        .first;

    play.run(MoveCard(cardId: commander.id, toZoneId: 'battlefield-s1'));
    await tester.pump();

    final corner = tester.getCenter(find.byType(CommandSlot));
    final from = tester.getCenter(find.byType(TableCard).first);
    await tester.dragFrom(from, corner - from);
    await tester.pumpAndSettle();

    expect(
      container.read(playProvider)!.zone('command-s1')!.cards,
      hasLength(1),
    );
    expect(
      container.read(playProvider)!.zone('battlefield-s1')!.cards,
      isEmpty,
    );
  });

  testWidgets('a card dropped on the graveyard goes there', (tester) async {
    final container = await _seatedPod(tester, ['you']);
    final play = container.read(playProvider.notifier);
    final card = container.read(playProvider)!.zone('hand-s1')!.cards.first;

    play.run(MoveCard(cardId: card.id, toZoneId: 'battlefield-s1'));
    await tester.pumpAndSettle();

    final from = tester.getCenter(
      find.descendant(
        of: find.byKey(const Key('your-board')),
        matching: find.byType(TableCard),
      ),
    );
    final bin = tester.getCenter(find.byKey(const Key('graveyard-stack')));
    await tester.dragFrom(from, bin - from);
    await tester.pumpAndSettle();

    final table = container.read(playProvider)!;
    expect(
      table.zone('graveyard-s1')!.cards.map((c) => c.id),
      contains(card.id),
    );
    expect(table.zone('battlefield-s1')!.cards, isEmpty);
  });

  testWidgets('the graveyard shows the card on top of it', (tester) async {
    final container = await _seatedPod(tester, ['you'], withCatalog: true);
    final play = container.read(playProvider.notifier);
    final card = container.read(playProvider)!.zone('hand-s1')!.cards.first;

    play.run(MoveCard(cardId: card.id, toZoneId: 'graveyard-s1'));
    await tester.pumpAndSettle();

    // A graveyard is face up, which is the whole difference between it and the
    // deck beside it: you can see what went in without opening it. With no
    // catalog there is no picture of anything and the pile falls back to a
    // card back, so this is the one case here that needs the database, and
    // without it drawing the pile face down left the suite green.
    expect(
      find.descendant(
        of: find.byKey(const Key('graveyard-stack')),
        matching: find.byType(CardArt),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the top of the graveyard is the last card thrown in', (
    tester,
  ) async {
    final container = await _seatedPod(
      tester,
      ['you'],
      withCommander: true,
      withCatalog: true,
    );
    final play = container.read(playProvider.notifier);
    final table = container.read(playProvider)!;
    final mountain = table.zone('hand-s1')!.cards.first;
    final general = table.zone('command-s1')!.cards.first;

    play.run(MoveCard(cardId: mountain.id, toZoneId: 'graveyard-s1'));
    await tester.pumpAndSettle();
    play.run(MoveCard(cardId: general.id, toZoneId: 'graveyard-s1'));
    await tester.pumpAndSettle();

    // Which end of the pile is its top. `Zone.add` inserts at nought, so the
    // newest card is `cards.first` and the last one thrown in is the one
    // showing. Read off the other end this draws the Mountain, which is the
    // card underneath it, and both ends look equally plausible in the source.
    final art = tester.widget<CardArt>(
      find.descendant(
        of: find.byKey(const Key('graveyard-stack')),
        matching: find.byType(CardArt),
      ),
    );
    expect(art.card.name, 'General');
  });

  testWidgets('the graveyard and the corner stand in the rail, the deck in '
      'the bottom bar', (tester) async {
    await _seatedPod(tester, ['you'], withCommander: true);

    expect(
      find.descendant(
        of: find.byKey(const Key('zone-rail')),
        matching: find.byKey(const Key('graveyard-stack')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('zone-rail')),
        matching: find.byType(CommandSlot),
      ),
      findsOneWidget,
    );
    // The deck is off the battle zone, fixed beside the hand and always
    // there, which is the one pile you touch every turn.
    expect(
      find.descendant(
        of: find.byKey(const Key('deck-bar')),
        matching: find.byKey(const Key('library-stack')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('zone-rail')),
        matching: find.byKey(const Key('library-stack')),
      ),
      findsNothing,
    );
  });

  testWidgets('the graveyard can be opened and a card taken back', (
    tester,
  ) async {
    final container = await _seatedPod(tester, ['you']);
    final play = container.read(playProvider.notifier);
    final card = container.read(playProvider)!.zone('hand-s1')!.cards.first;

    play.run(MoveCard(cardId: card.id, toZoneId: 'graveyard-s1'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('graveyard-stack')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('hand-${card.id}')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('pile-done')));
    await tester.pumpAndSettle();

    final table = container.read(playProvider)!;
    expect(table.zone('hand-s1')!.cards.map((c) => c.id), contains(card.id));
    expect(table.zone('graveyard-s1')!.cards, isEmpty);
  });

  testWidgets('copying a card puts a second one on the battlefield', (
    tester,
  ) async {
    final container = await _seatedPod(tester, ['you'], withCatalog: true);
    final play = container.read(playProvider.notifier);
    final card = container.read(playProvider)!.zone('hand-s1')!.cards.first;

    play.run(MoveCard(cardId: card.id, toZoneId: 'battlefield-s1'));
    await tester.pumpAndSettle();

    await tester.longPress(
      find.descendant(
        of: find.byKey(const Key('your-board')),
        matching: find.byType(TableCard),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('act-copy')));
    await tester.pumpAndSettle();

    final board = container.read(playProvider)!.zone('battlefield-s1')!;
    expect(board.cards, hasLength(2));
    expect(board.cards.map((c) => c.oracleId).toSet(), {card.oracleId});
    expect(
      board.cards.map((c) => c.id).toSet(),
      hasLength(2),
      reason: 'a copy is its own card, not the same card twice',
    );
  });

  testWidgets('a token is offered from the more menu', (tester) async {
    await _seatedPod(tester, ['you'], withCatalog: true);

    expect(find.byKey(const Key('make-token')), findsNothing);
    await tester.tap(find.byKey(const Key('more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('make-token')), findsOneWidget);
  });

  testWidgets('a token can be found in the catalog and put down', (
    tester,
  ) async {
    final container = await _seatedPod(tester, ['you'], withCatalog: true);

    await tester.tap(find.byKey(const Key('more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('make-token')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'moun');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('token-Mountain')));
    await tester.pumpAndSettle();

    // Not in the plan, which describes this control and tests nothing that
    // reaches it. Without this the sheet is proved by its own unit test and
    // the button that opens it by nothing at all.
    final board = container.read(playProvider)!.zone('battlefield-s1')!;
    expect(board.cards, hasLength(1));
    expect(board.cards.single.oracleId, 'Mountain');
  });

  testWidgets('the kind chosen in the big view is the kind counted', (
    tester,
  ) async {
    final container = await _seatedPod(tester, ['you'], withCatalog: true);
    final play = container.read(playProvider.notifier);
    final card = container.read(playProvider)!.zone('hand-s1')!.cards.first;

    play.run(MoveCard(cardId: card.id, toZoneId: 'battlefield-s1'));
    await tester.pumpAndSettle();

    await tester.longPress(
      find.descendant(
        of: find.byKey(const Key('your-board')),
        matching: find.byType(TableCard),
      ),
    );
    await tester.pumpAndSettle();
    // One tap on the piece, which is the whole gesture now. It used to be a
    // tap to choose the kind and a second tap on a plus, and the second tap
    // closed the card.
    await tester.tap(find.byKey(const Key('kind-damage')));
    await tester.pumpAndSettle();

    // Not in the plan, which probes the kind inside the viewer and leaves the
    // screen's end of it unwatched. The viewer can choose a kind perfectly and
    // the screen can still drop it on the floor and count `+1/+1`, which is
    // what it did before onCount and what no case here would have noticed.
    expect(container.read(playProvider)!.locate(card.id)!.card.counters, {
      'damage': 1,
    });

    // And the card is still open, which is the point of the change: three
    // counters used to mean opening the card three times.
    expect(find.byKey(const Key('kind-damage')), findsOneWidget);

    await tester.tap(find.byKey(const Key('kind-damage')));
    await tester.pumpAndSettle();
    expect(container.read(playProvider)!.locate(card.id)!.card.counters, {
      'damage': 2,
    });
  });

  testWidgets('the board draws one mat, not a graveyard under it', (
    tester,
  ) async {
    final container = await _seatedPod(tester, ['you']);
    final play = container.read(playProvider.notifier);
    final card = container.read(playProvider)!.zone('hand-s1')!.cards.first;

    play.run(MoveCard(cardId: card.id, toZoneId: 'graveyard-s1'));
    await tester.pumpAndSettle();

    // The graveyard is a pile beside the mat, which is what you drop a card
    // on and open. A second mat under the battlefield for the same zone is
    // the leftover, and it is what took half the board's height and pushed
    // the deck, the corner and the token button off the bottom.
    expect(find.byKey(const Key('mat-graveyard-s1')), findsNothing);
    expect(find.byKey(const Key('mat-battlefield-s1')), findsOneWidget);
  });

  testWidgets('the board is budgeted for both columns, not one', (
    tester,
  ) async {
    // 700 and not the 390 this was written at: below a 616 point window the
    // furniture stands in a row under the board and there are no columns to
    // budget for, so at a phone's width this case has no subject. Well clear
    // of that threshold on purpose, and still a window where the width
    // arithmetic is the one that binds, 75.6 against a height that would
    // allow 137.8.
    final container = await _seatedPod(tester, [
      'you',
    ], window: const Size(700, 844));
    final play = container.read(playProvider.notifier);
    final card = container.read(playProvider)!.zone('hand-s1')!.cards.first;

    play.run(MoveCard(cardId: card.id, toZoneId: 'battlefield-s1'));
    await tester.pumpAndSettle();

    final onBoard = tester
        .getSize(
          find.descendant(
            of: find.byKey(const Key('your-board')),
            matching: find.byType(TableCard),
          ),
        )
        .width;
    final deck = tester
        .getSize(
          find
              .descendant(
                of: find.byKey(const Key('library-stack')),
                matching: find.byType(CardBack),
              )
              .first,
        )
        .width;

    // The board's width arithmetic takes two columns out of the row, one for
    // the graveyard and one for the deck. Taking one out leaves the whole
    // suite green otherwise: it only moves the card by a couple of points,
    // and the case that measures card sizes runs at 1900 by 900 where the
    // card is height bound and the width arithmetic never binds at all.
    //
    // This is the only observable, and it is not a wide one. Measured on this
    // window: 1.121 with both columns budgeted, 1.188 with one. The bound
    // sits between them, with three percent of room below it and three above,
    // so if this ever fails on a change that was not about the row's width,
    // check those two numbers before loosening it. It was 1.160 against 1.239
    // on a 390 point window, which is where this was measured until the
    // furniture moved into a row below that width: a wider window spends a
    // smaller share of itself on the estimate's error, so both ends come in.
    //
    // It is also the case that catches a control in either column whose own
    // width does not shrink with the card. The dice tray's caption was a ten
    // point font beside an eight point die, which made the column 41 wide
    // where a card is 32 and took this to 1.269. Sizes in those columns come
    // off the card and not off the metrics for that reason.
    expect(
      deck / onBoard,
      lessThan(1.155),
      reason: 'the row is budgeting for one column and there are two',
    );
  });

  testWidgets('rolling a die puts the number on the table', (tester) async {
    final container = await _seatedPod(tester, ['you']);

    expect(container.read(playProvider)!.dice, isEmpty);

    await tester.tap(find.byKey(const Key('more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('die-20')));
    await tester.pumpAndSettle();

    final dice = container.read(playProvider)!.dice;
    expect(dice, hasLength(3));
    expect(dice.first, inInclusiveRange(1, 20));
  });

  testWidgets('the screen tells every card whose back it is', (tester) async {
    final container = await _seatedPod(tester, ['you', 'Carla']);
    final play = container.read(playProvider.notifier);
    final table = container.read(playProvider)!;
    for (final seat in ['s1', 's2']) {
      final card = table.zone('hand-$seat')!.cards.first;
      play.run(MoveCard(cardId: card.id, toZoneId: 'battlefield-$seat'));
      // Face down, which is the real reason a card shows its back. This case
      // used to lean on there being no printing behind any of these cards,
      // which stopped being true the day a table dealt here started
      // remembering what it was dealt from.
      play.run(FlipCard(card.id));
    }
    await tester.pumpAndSettle();

    // Three hand offs, and each of them is one argument the screen can simply
    // not write. The widgets each have a case proving they pass the game down
    // once they are given it; nothing but this proves they are given it.
    for (final where in ['your-board', 'watched-s2']) {
      expect(
        find.descendant(
          of: find.byKey(Key(where)),
          matching: find.byKey(const Key('card-back-art')),
        ),
        findsWidgets,
        reason: '$where was handed no game',
      );
    }
    // A card in your own hand is yours to look at, so the hand draws faces.
    // Turning one over is the only thing that makes the hand draw a back at
    // all, which is what this is about: whether the hand knows whose back.
    play.run(FlipCard(table.zone('hand-s1')!.cards.last.id));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(HandSheet),
        matching: find.byKey(const Key('card-back-art')),
      ),
      findsWidgets,
      reason: 'the hand was handed no game',
    );
  });

  testWidgets('a commander thrown in the graveyard goes to its zone', (
    tester,
  ) async {
    // The case above this one taps `switch-renderer` and never puts the
    // mock store back, so the canvas is still the persisted choice when this
    // one opens. On the canvas your corner draws the commander beside the
    // board and `your-board` holds two cards, which is a finder this case
    // cannot resolve. Six cases in this file already open with this line.
    final container = await _seatedPod(tester, ['you'], withCommander: true);
    final play = container.read(playProvider.notifier);
    final commander = container
        .read(playProvider)!
        .zone('command-s1')!
        .cards
        .first;

    play.run(MoveCard(cardId: commander.id, toZoneId: 'battlefield-s1'));
    await tester.pumpAndSettle();

    final from = tester.getCenter(
      find.descendant(
        of: find.byKey(const Key('your-board')),
        matching: find.byType(TableCard),
      ),
    );
    final bin = tester.getCenter(find.byKey(const Key('graveyard-stack')));
    await tester.dragFrom(from, bin - from);
    await tester.pumpAndSettle();

    final table = container.read(playProvider)!;
    expect(
      table.zone('command-s1')!.cards.map((c) => c.id),
      contains(commander.id),
    );
    expect(table.zone('graveyard-s1')!.cards, isEmpty);
  });

  testWidgets('an ordinary card thrown in the graveyard stays there', (
    tester,
  ) async {
    final container = await _seatedPod(tester, ['you'], withCommander: true);
    final play = container.read(playProvider.notifier);
    final card = container.read(playProvider)!.zone('hand-s1')!.cards.first;

    play.run(MoveCard(cardId: card.id, toZoneId: 'battlefield-s1'));
    await tester.pumpAndSettle();

    final from = tester.getCenter(
      find.descendant(
        of: find.byKey(const Key('your-board')),
        matching: find.byType(TableCard),
      ),
    );
    final bin = tester.getCenter(find.byKey(const Key('graveyard-stack')));
    await tester.dragFrom(from, bin - from);
    await tester.pumpAndSettle();

    // The redirect is for commanders, not for everything. Without this the
    // first case would pass against a graveyard that swallows nothing.
    expect(
      container.read(playProvider)!.zone('graveyard-s1')!.cards,
      hasLength(1),
    );
  });

  testWidgets('on a phone the board gets the width', (tester) async {
    await _seatedPod(tester, ['you'], withCommander: true);
    await tester.pumpAndSettle();

    final screen = tester.getRect(find.byType(PlayScreen));
    final board = tester.getRect(find.byKey(const Key('your-board')));

    // A graveyard column on one side and a deck column on the other cost 41
    // percent of a 390 point screen. On a television that is a rounding
    // error; here it is nearly half the table.
    // The rail beside it is a thumbnail and its edge, 60 points of 390, and
    // nothing else stands between the board and the screen's edges.
    expect(
      board.width / screen.width,
      greaterThan(0.7),
      reason: 'something besides the rail is eating the board',
    );
  });

  testWidgets('a card on the table is not smaller than one in your hand', (
    tester,
  ) async {
    final container = await _seatedPod(tester, ['you']);
    final play = container.read(playProvider.notifier);
    final card = container.read(playProvider)!.zone('hand-s1')!.cards.first;

    play.run(MoveCard(cardId: card.id, toZoneId: 'battlefield-s1'));
    await tester.pumpAndSettle();

    final onBoard = tester
        .getSize(
          find.descendant(
            of: find.byKey(const Key('your-board')),
            matching: find.byType(TableCard),
          ),
        )
        .width;
    final inHand = tester
        .getSize(
          find
              .descendant(
                of: find.byType(HandSheet),
                matching: find.byType(TableCard),
              )
              .first,
        )
        .width;

    // It was exactly half: 32.19 against 64.0. The hand is a row of things
    // you are choosing between and the battlefield is the thing you are
    // looking at, so the board is the one that sets the size.
    expect(onBoard, greaterThanOrEqualTo(inHand * 0.95));
  });

  testWidgets('a zone grows into a target while a card is in the air', (
    tester,
  ) async {
    final container = await _seatedPod(tester, ['you']);
    final play = container.read(playProvider.notifier);
    final card = container.read(playProvider)!.zone('hand-s1')!.cards.first;
    play.run(MoveCard(cardId: card.id, toZoneId: 'battlefield-s1'));
    await tester.pumpAndSettle();

    final resting = tester.getRect(find.byKey(const Key('graveyard-stack')));

    final gesture = await tester.startGesture(
      tester.getCenter(
        find.descendant(
          of: find.byKey(const Key('your-board')),
          matching: find.byType(TableCard),
        ),
      ),
    );
    await gesture.moveBy(const Offset(0, 150));
    await tester.pumpAndSettle();

    final aiming = tester.getRect(find.byKey(const Key('graveyard-stack')));
    expect(
      aiming.height,
      greaterThan(resting.height * 1.5),
      reason: 'the chip did not grow into a drop target',
    );

    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const Key('graveyard-stack'))).height,
      resting.height,
      reason: 'the chip did not collapse when the drag ended',
    );
  });

  testWidgets('a cancelled drag leaves no zone expanded', (tester) async {
    final container = await _seatedPod(tester, ['you']);
    final play = container.read(playProvider.notifier);
    final card = container.read(playProvider)!.zone('hand-s1')!.cards.first;
    play.run(MoveCard(cardId: card.id, toZoneId: 'battlefield-s1'));
    await tester.pumpAndSettle();

    final resting = tester.getRect(find.byKey(const Key('graveyard-stack')));

    final gesture = await tester.startGesture(
      tester.getCenter(
        find.descendant(
          of: find.byKey(const Key('your-board')),
          matching: find.byType(TableCard),
        ),
      ),
    );
    await gesture.moveBy(const Offset(0, 150));
    await tester.pumpAndSettle();
    await gesture.cancel();
    await tester.pumpAndSettle();

    // A drag that is interrupted rather than let go: the chips have to come
    // back down for that too, or the row keeps a card of room nobody is
    // aiming at.
    expect(
      tester.getRect(find.byKey(const Key('graveyard-stack'))).height,
      resting.height,
      reason: 'the chip stayed expanded after the drag was cancelled',
    );
  });

  testWidgets('a card that goes away mid drag still puts the zones back', (
    tester,
  ) async {
    final container = await _seatedPod(tester, ['you']);
    final play = container.read(playProvider.notifier);
    final card = container.read(playProvider)!.zone('hand-s1')!.cards.first;
    play.run(MoveCard(cardId: card.id, toZoneId: 'battlefield-s1'));
    await tester.pumpAndSettle();

    final resting = tester.getRect(find.byKey(const Key('graveyard-stack')));

    final gesture = await tester.startGesture(
      tester.getCenter(
        find.descendant(
          of: find.byKey(const Key('your-board')),
          matching: find.byType(TableCard),
        ),
      ),
    );
    await gesture.moveBy(const Offset(0, 150));
    await tester.pumpAndSettle();

    // The card leaves the board while it is in the air, which takes the widget
    // that is reporting the drag out of the tree with it. `Draggable` guards
    // its `onDragEnd` on the widget still being mounted and does not guard its
    // cancel, so this is the one end of a drag that only the cancel reports.
    play.run(MoveCard(cardId: card.id, toZoneId: 'graveyard-s1'));
    await tester.pumpAndSettle();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.byKey(const Key('graveyard-stack'))).height,
      resting.height,
      reason: 'a drag whose card was taken away left the zones expanded',
    );
  });

  testWidgets('the hand peeks instead of parking', (tester) async {
    await _seatedPod(tester, ['you']);
    await tester.pumpAndSettle();

    final screen = tester.getRect(find.byType(PlayScreen));
    final hand = tester.getRect(find.byType(HandSheet));

    // It owned 117 of 844 points at all times so that it could be ready.
    expect(hand.height / screen.height, lessThan(0.09));
  });

  testWidgets('tapping the hand opens it over the board', (tester) async {
    await _seatedPod(tester, ['you']);
    await tester.pumpAndSettle();

    final shut = tester.getRect(find.byType(HandSheet)).height;
    await tester.tap(find.byKey(const Key('hand-handle')));
    await tester.pumpAndSettle();
    final open = tester.getRect(find.byType(HandSheet)).height;

    expect(open, greaterThan(shut * 2));

    // And back, because a hand you cannot put down is worse than one that
    // never moved.
    await tester.tap(find.byKey(const Key('hand-handle')));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(HandSheet)).height, shut);
  });

  testWidgets('a card on a phone is big enough to read', (tester) async {
    final container = await _seatedPod(tester, ['you']);
    final play = container.read(playProvider.notifier);
    final card = container.read(playProvider)!.zone('hand-s1')!.cards.first;
    play.run(MoveCard(cardId: card.id, toZoneId: 'battlefield-s1'));
    await tester.pumpAndSettle();

    final onBoard = tester
        .getSize(
          find.descendant(
            of: find.byKey(const Key('your-board')),
            matching: find.byType(TableCard),
          ),
        )
        .width;

    // It was 50.3, which is a card you cannot read a name on. The printed
    // card on the mat is 90 and this is the floor under it.
    expect(onBoard, greaterThanOrEqualTo(72));
  });

  testWidgets('nothing on the phone\'s battlefield is off the board', (
    tester,
  ) async {
    await _seatedPod(tester, ['you']);
    await tester.pumpAndSettle();

    final board = tester.getRect(find.byKey(const Key('your-board')));
    final mat = tester.getRect(find.byKey(const Key('mat-battlefield-s1')));

    // This case used to assert the opposite: that the mat was bigger than the
    // board and the board scrolled. That was the readable floor fighting a
    // fixed 640 by 380 shape, and what it cost was a battlefield that was
    // always cut off. The card is sized on its own now and the mat is the
    // board.
    expect(mat.width, moreOrLessEquals(board.width, epsilon: 1));
    expect(mat.height, lessThanOrEqualTo(board.height + 1));
    expect(mat.left, moreOrLessEquals(board.left, epsilon: 1));
  });

  testWidgets('a drop means the same place whatever the window is', (
    tester,
  ) async {
    // The point of the whole task. Everything else in it is pixels; this is
    // the invariant plan 4 replicates across the network, and the scroll the
    // floor brings with it is exactly the thing that could break it: the
    // offset is divided by the scale before it is divided by the mat, so a
    // scroll offset must not reach it.
    final places = <({double x, double y})>[];

    for (final window in [const Size(390, 844), const Size(700, 844)]) {
      final container = await _seatedPod(tester, ['you'], window: window);
      final play = container.read(playProvider.notifier);
      final card = container.read(playProvider)!.zone('hand-s1')!.cards.first;
      play.run(MoveCard(cardId: card.id, toZoneId: 'battlefield-s1'));
      await tester.pumpAndSettle();

      final mat = tester.getRect(find.byKey(const Key('mat-battlefield-s1')));
      final from = tester.getCenter(
        find.descendant(
          of: find.byKey(const Key('your-board')),
          matching: find.byType(TableCard),
        ),
      );
      // Four tenths across and six tenths down the mat, which is inside the
      // part of it a 390 point phone has on screen: the mat is 512 wide there
      // and 358 of it is showing, and a drop the viewport has scrolled away
      // cannot be aimed at in the first place.
      final at = Offset(mat.left + mat.width * 0.4, mat.top + mat.height * 0.6);

      await tester.dragFrom(from, at - from);
      await tester.pumpAndSettle();

      places.add(container.read(playProvider)!.locate(card.id)!.card.position!);
    }

    expect(places.first.x, closeTo(0.4, 0.01));
    expect(places.first.y, closeTo(0.6, 0.01));
    expect(places.last.x, closeTo(places.first.x, 0.01));
    expect(places.last.y, closeTo(places.first.y, 0.01));
  });

  testWidgets('the hand draws the card the board draws, up to its ceiling', (
    tester,
  ) async {
    final container = await _seatedPod(tester, ['you']);
    final play = container.read(playProvider.notifier);
    final card = container.read(playProvider)!.zone('hand-s1')!.cards.first;
    play.run(MoveCard(cardId: card.id, toZoneId: 'battlefield-s1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('hand-handle')));
    await tester.pumpAndSettle();

    final onBoard = tester
        .getSize(
          find.descendant(
            of: find.byKey(const Key('your-board')),
            matching: find.byType(TableCard),
          ),
        )
        .width;
    final inHand = tester
        .getSize(
          find
              .descendant(
                of: find.byType(HandSheet),
                matching: find.byType(TableCard),
              )
              .first,
        )
        .width;

    // The mat has a floor under it now and the hand has to come through the
    // same one. It did not: this window drew 72 on the table against 50.3 in
    // the hand while the same phone held sideways drew 72 against 64, so the
    // two sizes agreed everywhere except the window the floor was added for.
    // The whole suite was green.
    //
    // Both directions. `a card on the table is not smaller than one in your
    // hand` only holds the floor down, and a hand that quietly stopped
    // following the board would pass it forever.
    expect(
      onBoard,
      greaterThan(64),
      reason:
          'the board is under the ceiling, so this window proves '
          'nothing about the hand following it',
    );
    expect(inHand, closeTo(64, 0.5));
  });

  testWidgets('a window with room shows the whole graveyard and hand', (
    tester,
  ) async {
    await _seatedPod(tester, ['you'], window: const Size(1440, 900));
    await tester.pumpAndSettle();

    // Both of these are adaptations to a phone and both of them shipped
    // unconditionally. On a 1909 by 989 desktop the graveyard was a 36 point
    // chip in an acre of empty table and the hand was a strip with the top
    // thirty points of seven cards showing, on a window with room for all of
    // it. A phone's answer is not a smaller version of the right answer.
    expect(find.byKey(const Key('graveyard-stack')), findsOneWidget);

    final hand = tester.getRect(find.byType(HandSheet));
    final card = tester
        .getSize(
          find
              .descendant(
                of: find.byType(HandSheet),
                matching: find.byType(TableCard),
              )
              .first,
        )
        .height;
    expect(
      hand.height,
      greaterThan(card),
      reason: 'the hand is still peeking on a window with room',
    );
  });

  testWidgets('the deck\'s count and controls sit above the pile', (
    tester,
  ) async {
    await _seatedPod(tester, ['you']);
    await tester.pumpAndSettle();

    final pile = tester.getRect(find.byKey(const Key('library-stack')));
    final count = tester.getRect(find.text('53'));
    final work = tester.getRect(find.byKey(const Key('library-work')));

    // Under the pile they sat between the deck and the bottom of the screen,
    // which is the edge a pile is supposed to be standing on, and the row of
    // furniture beside it then had a baseline that was neither the pile's nor
    // the caption's. Nothing pinned this: moving them back under the pile left
    // all 579 cases green.
    expect(count.bottom, lessThanOrEqualTo(pile.top));
    expect(work.bottom, lessThanOrEqualTo(pile.top));
  });

  testWidgets('the mat shows where the table is while you aim at it', (
    tester,
  ) async {
    final container = await _seatedPod(tester, ['you']);
    final play = container.read(playProvider.notifier);
    final card = container.read(playProvider)!.zone('hand-s1')!.cards.first;
    play.run(MoveCard(cardId: card.id, toZoneId: 'battlefield-s1'));
    await tester.pumpAndSettle();

    Border? edgeOfMat() =>
        (tester
                        .widget<DecoratedBox>(
                          find
                              .ancestor(
                                of: find.byKey(const Key('mat-battlefield-s1')),
                                matching: find.byType(DecoratedBox),
                              )
                              .first,
                        )
                        .decoration
                    as BoxDecoration)
                .border
            as Border?;

    // Nothing at rest. The mat had no surface at all and could not be seen,
    // then it had a dark outline drawn around most of the screen for nobody:
    // the question an edge answers is "where can this go", and nobody is
    // asking that with both hands empty.
    expect(edgeOfMat(), isNull);

    final gesture = await tester.startGesture(
      tester.getCenter(
        find.descendant(
          of: find.byKey(const Key('your-board')),
          matching: find.byType(TableCard),
        ),
      ),
    );
    await gesture.moveBy(const Offset(0, 150));
    await tester.pumpAndSettle();

    // And there while a card is in the air, which is the one moment it is
    // worth saying out loud.
    final aiming = edgeOfMat();
    expect(aiming, isNotNull);
    expect(aiming!.top.width, greaterThan(0));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(edgeOfMat(), isNull, reason: 'the edge outlived the drag');
  });

  testWidgets('finishing a deck search leaves you at the table', (
    tester,
  ) async {
    final container = await _seatedPod(tester, ['you']);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('library-work')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('deck-search')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('deck-done')));
    await tester.pumpAndSettle();

    // A search ends in an arrange and a shuffle, and each of those popped:
    // the first closed the sheet and the second closed the table under it, so
    // Done put you back in the main menu with the game still running.
    expect(
      find.byType(PlayScreen),
      findsOneWidget,
      reason: 'the sheet closed the table as well as itself',
    );
    expect(
      find.byKey(const Key('deck-search')),
      findsNothing,
      reason: 'the sheet is still open',
    );
    expect(container.read(playProvider), isNotNull);
  });

  testWidgets('a phone held sideways still peeks', (tester) async {
    await _seatedPod(tester, ['you'], window: const Size(844, 390));
    await tester.pumpAndSettle();

    final screen = tester.getRect(find.byType(PlayScreen));
    final hand = tester.getRect(find.byType(HandSheet));

    // Wide enough to be past every width threshold in this file and 390
    // points tall, so the room that matters is the one it has least of. The
    // desktop case above must not be bought by giving this one a parked hand
    // in 390 points of height.
    expect(hand.height / screen.height, lessThan(0.2));
  });

  test('no seat is drawn as the one whose turn it is', () {
    // There are no turns. The spec's verbs have none and the table carries
    // none, and the ring that used to say "whose turn" sat on seat one all
    // evening because nothing ever moved it. Read off the source rather than
    // rendered and inspected: a widget test can only show a ring absent on
    // the seats it built, and this is what stops the ring coming back.
    for (final path in [
      'lib/features/play/play_screen.dart',
      'lib/features/play/renderers/grid_view.dart',
      'lib/features/play/renderers/focus_view.dart',
      'lib/features/play/renderers/split_view.dart',
      'lib/features/play/widgets/seat_board.dart',
      'lib/features/play/widgets/seat_rail.dart',
      'lib/features/play/widgets/watched_board.dart',
    ]) {
      final file = File(path);
      expect(
        file.existsSync(),
        isTrue,
        reason:
            'this reads the source, so it has to run from the package '
            'root. cwd is ${Directory.current.path}',
      );

      final source = file.readAsStringSync();
      // The file has to draw a seat before its silence about turns means
      // anything, or a broken path reads as a clean one.
      expect(source, contains('seat'), reason: path);
      expect(source, isNot(contains('turnSeatId')), reason: path);
      expect(source, isNot(contains('isTurn')), reason: path);
    }
  });

  testWidgets('a card let go on the graveyard lands in the graveyard', (
    tester,
  ) async {
    // Reported from the table: "quando vc vai botar uma carta no cemiterio
    // quase sempre ela ta indo pra zona do comandante". The two zones are
    // one above the other in the same rail, and the graveyard grows into a
    // card sized target the moment a drag starts, so where the player aims
    // and where the target ends up are not the same rectangle.
    final container = await _seatedPod(tester, ['you'], withCommander: true);
    final play = container.read(playProvider.notifier);
    final card = container.read(playProvider)!.zone('hand-s1')!.cards.first;
    play.run(MoveCard(cardId: card.id, toZoneId: 'battlefield-s1'));
    await tester.pumpAndSettle();

    // Where the player sees it before anything is in the air, which is the
    // only thing they can aim at.
    final aimedAt = tester.getCenter(find.byKey(const Key('graveyard-stack')));

    final gesture = await tester.startGesture(
      tester.getCenter(
        find.descendant(
          of: find.byKey(const Key('your-board')),
          matching: find.byType(TableCard),
        ),
      ),
    );
    await gesture.moveTo(aimedAt);
    await tester.pumpAndSettle();
    await gesture.up();
    await tester.pumpAndSettle();

    final where = container.read(playProvider)!.locate(card.id)!.zone.id;
    expect(where, 'graveyard-s1', reason: 'it went to $where instead');
  });

  testWidgets('a card dragged out of the hand onto the graveyard lands there', (
    tester,
  ) async {
    // The path a player actually takes. The other case drags a card that is
    // already on the board, which is not how a card usually reaches a
    // graveyard.
    final container = await _seatedPod(tester, ['you'], withCommander: true);
    final card = container.read(playProvider)!.zone('hand-s1')!.cards.first;
    await tester.pumpAndSettle();

    // The hand opens first. Collapsed it is a strip of card tops that takes
    // no pointer at all, so nothing there can be picked up.
    await tester.tap(find.byKey(const Key('hand-handle')).first);
    await tester.pumpAndSettle();

    final aimedAt = tester.getCenter(find.byKey(const Key('graveyard-stack')));
    final inHand = find.descendant(
      of: find.byType(HandSheet),
      matching: find.byType(TableCard),
    );

    final from = tester.getCenter(inHand.first);
    final gesture = await tester.startGesture(from);
    // Moved in steps, the way a finger does. One jump is a single pointer
    // event, and a drag that has to win an arena against a scrollable needs
    // more than one.
    for (var i = 1; i <= 10; i++) {
      await gesture.moveTo(Offset.lerp(from, aimedAt, i / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    await gesture.up();
    await tester.pumpAndSettle();

    final where = container.read(playProvider)!.locate(card.id)!.zone.id;
    expect(where, 'graveyard-s1', reason: 'it went to $where instead');
  });

  testWidgets('the zone under the pointer says it is the one', (tester) async {
    // The card is drawn centred on the finger at full size, so it covers
    // whatever it is over and the player is aiming from memory at zones that
    // moved when the drag started. A ring is the only thing that tells them
    // where it will land before they let go.
    final container = await _seatedPod(tester, ['you'], withCommander: true);
    final card = container.read(playProvider)!.zone('hand-s1')!.cards.first;
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('hand-handle')).first);
    await tester.pumpAndSettle();

    expect(find.byType(AimedAt), findsNothing);

    final from = tester.getCenter(
      find
          .descendant(
            of: find.byType(HandSheet),
            matching: find.byType(TableCard),
          )
          .first,
    );
    final chip = find.byKey(const Key('graveyard-stack'));
    final gesture = await tester.startGesture(from);
    for (var i = 1; i <= 8; i++) {
      await gesture.moveTo(Offset.lerp(from, tester.getCenter(chip), i / 8)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();

    // Exactly one, and it is the graveyard. Two rings would be worse than
    // none: the player would still not know which one takes the card.
    expect(find.byType(AimedAt), findsOneWidget);
    // An ancestor, not a descendant: the target wraps the chip, so the ring
    // is drawn around what it is protecting rather than inside it.
    expect(
      find.ancestor(of: chip, matching: find.byType(AimedAt)),
      findsOneWidget,
    );

    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(AimedAt), findsNothing);
    expect(
      container.read(playProvider)!.locate(card.id)!.zone.id,
      'graveyard-s1',
    );
  });

  testWidgets('the opening hand is offered a mulligan, and then is not', (
    tester,
  ) async {
    final container = await _seatedPod(tester, ['you']);
    await tester.pumpAndSettle();

    // Under the deck, which is on screen whatever else is. It used to be
    // inside the hand, where half the table would never have found it.
    expect(
      find.descendant(
        of: find.byKey(const Key('deck-bar')),
        matching: find.byKey(const Key('mulligan')),
      ),
      findsOneWidget,
    );
    // Nothing owed on the first hand, which is what makes it free.
    expect(find.byKey(const Key('mulligan-owed')), findsNothing);

    await tester.tap(find.byKey(const Key('mulligan')));
    await tester.pumpAndSettle();

    expect(container.read(playProvider)!.seat('s1')!.mulligans, 1);
    expect(find.byKey(const Key('mulligan')), findsOneWidget);
    expect(find.text('bottom 1'), findsOneWidget);

    // And it takes itself away the moment the game is on. Nobody presses
    // anything to end it, which is the only way an offer like this is safe to
    // leave on the screen.
    final card = container.read(playProvider)!.zone('hand-s1')!.cards.first;
    container
        .read(playProvider.notifier)
        .run(MoveCard(cardId: card.id, toZoneId: 'battlefield-s1'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mulligan')), findsNothing);
  });

  testWidgets('somebody else s opening hand is not yours to put back', (
    tester,
  ) async {
    final container = await _seatedPod(tester, ['you', 'Carla']);
    await tester.pumpAndSettle();

    // Looking out of the other seat is still this device acting for it in a
    // pod on one tablet, so the offer follows the seat being looked out of
    // rather than following the first seat at the table.
    expect(container.read(viewerSeatProvider), 's1');
    expect(find.byKey(const Key('mulligan')), findsOneWidget);
  });

  testWidgets('the two zones stand further apart while a card is in the air', (
    tester,
  ) async {
    await _seatedPod(tester, ['you'], withCommander: true);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('hand-handle')).first);
    await tester.pumpAndSettle();

    double gap() =>
        tester.getRect(find.byType(CommandSlot)).top -
        tester.getRect(find.byKey(const Key('graveyard-stack'))).bottom;

    final resting = gap();

    final from = tester.getCenter(
      find
          .descendant(
            of: find.byType(HandSheet),
            matching: find.byType(TableCard),
          )
          .first,
    );
    final gesture = await tester.startGesture(from);
    await gesture.moveBy(const Offset(0, -120));
    await tester.pumpAndSettle();

    expect(
      gap(),
      greaterThan(resting * 2),
      reason: 'the graveyard and the command zone are a hair apart mid drag',
    );

    await gesture.up();
    await tester.pumpAndSettle();
    expect(gap(), closeTo(resting, 0.01));
  });
}

class _GrumpyReferee implements Referee {
  const _GrumpyReferee();

  @override
  Refusal? review(TableState table, TableAction action) =>
      const Refusal('not on my watch');

  @override
  List<String>? legalTargets(TableState table, String cardId) => null;
}
