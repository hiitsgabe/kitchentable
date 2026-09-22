import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kitchentable/decks/model/deck.dart';
import 'package:kitchentable/decks/model/deck_format.dart';
import 'package:kitchentable/features/play/play_controller.dart';
import 'package:kitchentable/features/menu/menu_controller.dart';
import 'package:kitchentable/features/play/play_screen.dart';
import 'package:kitchentable/features/play/renderers/free_canvas.dart';
import 'package:kitchentable/features/play/renderers/stacked_seats.dart';
import 'package:kitchentable/features/play/widgets/hand_sheet.dart';
import 'package:kitchentable/features/play/widgets/radar_strip.dart';
import 'package:kitchentable/features/play/widgets/table_card.dart';
import 'package:kitchentable/features/play/widgets/seat_band.dart';
import 'package:kitchentable/table/model/seat_owner.dart';
import 'package:kitchentable/table/actions/table_action.dart';
import 'package:kitchentable/table/model/table_state.dart';
import 'package:kitchentable/table/referee/referee.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';

CatalogCard _card(String name) => CatalogCard(
      oracleId: name,
      name: name,
      typeLine: 'Instant',
      cmc: 1,
    );

Deck _deck() => Deck(
      id: 'd1',
      name: 'a deck',
      format: DeckFormat.commander,
      slots: [DeckSlot(card: _card('Mountain'), quantity: 60)],
    );

Future<ProviderContainer> _seated(WidgetTester tester) =>
    _seatedPod(tester, ['you']);

Future<ProviderContainer> _seatedPod(
  WidgetTester tester,
  List<String> names, {
  Size window = const Size(390, 844),
}) async {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(
    overrides: [catalogDbProvider.overrideWithValue(null)],
  );
  addTearDown(container.dispose);
  container.read(playProvider.notifier).startPod(
        players: [
          for (final name in names)
            (deck: _deck(), name: name, owner: const SeatOwner.here()),
        ],
        seed: 'abc',
      );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: PlayScreen()),
    ),
  );
  await tester.pump();
  return container;
}

void main() {
  testWidgets('an empty table says so instead of drawing nothing',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [catalogDbProvider.overrideWithValue(null)],
        child: const MaterialApp(home: PlayScreen()),
      ),
    );
    await tester.pump();

    expect(find.textContaining('No table'), findsOneWidget);
  });

  testWidgets('a seated table shows life and the pile counts', (tester) async {
    await _seated(tester);

    expect(find.text('40'), findsOneWidget);
    expect(find.textContaining('53'), findsWidgets,
        reason: 'the library has 53 left after a hand of seven');
  });

  testWidgets('drawing takes one off the library and adds one to the hand',
      (tester) async {
    final container = await _seated(tester);

    await tester.tap(find.byKey(const Key('library-draw')));
    await tester.pump();

    expect(container.read(playProvider)!.zone('library-s1')!.size, 52);
    expect(container.read(playProvider)!.zone('hand-s1')!.size, 8);
  });

  testWidgets('undo is offered only once there is something to undo',
      (tester) async {
    final container = await _seated(tester);

    expect(container.read(playProvider.notifier).canUndo, isFalse);

    await tester.tap(find.byKey(const Key('library-draw')));
    await tester.pump();

    expect(container.read(playProvider.notifier).canUndo, isTrue);
  });

  testWidgets('the hand sits below the board and never on top of it',
      (tester) async {
    await _seated(tester);

    final board = tester.getRect(find.byKey(const Key('your-board')));
    final hand = tester.getRect(find.byType(HandSheet));

    // Arena opens the hand into a fan across the battlefield, so you cannot
    // look at your hand and the board at once. Converting HandSheet to a modal
    // sheet or a Stack overlay later would take the suite green all the way to
    // that mistake, so the rule is pinned by geometry rather than by comment.
    expect(hand.top, greaterThanOrEqualTo(board.bottom - 1),
        reason: 'the hand must start at or below where the board ends');
  });

  testWidgets('a refusal is said out loud', (tester) async {
    final container = await _seated(tester);
    container.read(playProvider.notifier).useReferee(const _GrumpyReferee());

    container.read(playProvider.notifier).run(
          const ChangeLife(seatId: 's1', by: -5),
        );
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

  testWidgets('a narrow window stacks the bands', (tester) async {
    await _seatedPod(tester, ['you', 'Carla', 'Diego']);

    expect(find.byType(StackedSeats), findsOneWidget);
    expect(find.byType(FreeCanvas), findsNothing);
    expect(find.byType(SeatBand), findsNWidgets(2));
  });

  testWidgets('a wide window opens the canvas', (tester) async {
    await _seatedPod(tester, ['you', 'Carla'],
        window: const Size(1280, 800));

    expect(find.byType(FreeCanvas), findsOneWidget);
    expect(find.byType(StackedSeats), findsNothing);
  });

  testWidgets('every life total is on screen whichever view it is',
      (tester) async {
    await _seatedPod(tester, ['you', 'Carla', 'Diego']);

    expect(find.byType(RadarStrip), findsOneWidget);
  });

  testWidgets('your hand is yours and theirs is a number', (tester) async {
    final container = await _seatedPod(tester, ['you', 'Carla']);
    final theirs = container.read(playProvider)!.zone('hand-s2')!;

    for (final card in theirs.cards) {
      expect(find.byKey(Key('hand-card-${card.id}')), findsNothing,
          reason: 'a card from somebody else s hand reached the widget tree');
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
        expect(find.byKey(Key('hand-card-${card.id}')), findsNothing,
            reason: 'a spectator was handed ${seat.id} s cards');
      }
    }
  });

  testWidgets('looking out of another local seat swaps whose hand it is',
      (tester) async {
    final container = await _seatedPod(tester, ['you', 'Carla']);

    await tester.tap(find.byKey(const Key('band-s2')));
    await tester.pump();

    expect(container.read(viewerSeatProvider), 's2');
    // The seat you left is now the one drawn as a band.
    expect(find.byKey(const Key('band-s1')), findsOneWidget);
    expect(find.byKey(const Key('band-s2')), findsNothing);
  });

  testWidgets('the hand still sits below the board in a pod', (tester) async {
    await _seatedPod(tester, ['you', 'Carla', 'Diego']);

    final board = tester.getRect(find.byKey(const Key('your-board')));
    final hand = tester.getRect(find.byType(HandSheet));

    expect(hand.top, greaterThanOrEqualTo(board.bottom - 1),
        reason: 'the hand must start at or below where your board ends');
  });

  testWidgets('a drop is written onto the card', (tester) async {
    final container = await _seatedPod(tester, ['you']);
    final play = container.read(playProvider.notifier);
    final table = container.read(playProvider)!;
    final card = table.zone('hand-s1')!.cards.first;

    play.run(MoveCard(cardId: card.id, toZoneId: 'battlefield-s1'));
    await tester.pump();

    play.run(MoveCard(
      cardId: card.id,
      toZoneId: 'battlefield-s1',
      at: 0,
      position: (x: 0.3, y: 0.6),
    ));
    await tester.pump();

    // CardInstance.position has existed since plan 2 with nothing writing to
    // it. This is the first thing in the app that does.
    expect(
      container.read(playProvider)!.locate(card.id)!.card.position,
      (x: 0.3, y: 0.6),
    );
  });

  testWidgets('the size pills reach the cards on the board', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = await _seatedPod(tester, ['you']);
    final play = container.read(playProvider.notifier);
    final card = container.read(playProvider)!.zone('hand-s1')!.cards.first;

    play.run(MoveCard(cardId: card.id, toZoneId: 'battlefield-s1'));
    await tester.pump();

    final before = tester.getSize(find.byType(TableCard).first).width;

    // Three separate things are being crossed here and nothing else crosses
    // them: the pill has to reach the provider, the provider has to reach the
    // screen's rebuild, and the screen has to hand the scale to the renderer.
    await tester.tap(find.byKey(const Key('cards-bigger')));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(TableCard).first).width,
        greaterThan(before));

    await tester.tap(find.byKey(const Key('cards-smaller')));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(TableCard).first).width,
        closeTo(before, 0.01));
  });

  testWidgets('dragging a card on the screen writes where it landed',
      (tester) async {
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
    final before =
        container.read(playProvider)!.zone('library-s1')!.cards.first.id;

    await tester.tap(find.byKey(const Key('library-work')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('deck-shuffle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-shuffle')));
    await tester.pumpAndSettle();

    final after =
        container.read(playProvider)!.zone('library-s1')!.cards.first.id;

    // 53 cards, so the same card staying on top is a one in fifty three
    // coincidence rather than a flake worth tolerating. If this is ever seen
    // failing, check the seed before loosening it.
    expect(after, isNot(before));
    expect(container.read(playProvider)!.zone('library-s1')!.cards,
        hasLength(53));
  });

  testWidgets('a card sent to the bottom from the sheet goes there',
      (tester) async {
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
  testWidgets('the deck sits to the right, not in the middle',
      (tester) async {
    await _seatedPod(tester, ['you']);

    final screen = tester.getRect(find.byType(PlayScreen));
    final deck = tester.getRect(find.byKey(const Key('library-stack')));

    // A deck sits by your right hand at a table. In the middle it reads as
    // part of the battlefield.
    expect(deck.center.dx, greaterThan(screen.center.dx),
        reason: 'the deck must be on the right half');
    expect(screen.right - deck.right, lessThan(screen.width * 0.2),
        reason: 'and close to the edge, not adrift');
  });

  testWidgets('the pile on the table is drawn with the game\'s back',
      (tester) async {
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

  testWidgets('a card dragged out of your hand lands where you dropped it',
      (tester) async {
    final container = await _seatedPod(tester, ['you']);
    // The fourth card and not the first. A card arriving from somewhere else
    // has no place in this pile to keep, and a move that carries its old one
    // over asks an empty battlefield to insert at 3, which throws. The first
    // card would go in at 0 either way and prove nothing.
    final card = container.read(playProvider)!.zone('hand-s1')!.cards[3];

    final board = tester.getRect(find.byKey(const Key('your-board')));
    final from = tester.getCenter(find.byKey(Key('hand-card-${card.id}')));

    await tester.dragFrom(from, board.center - from);
    await tester.pumpAndSettle();

    final table = container.read(playProvider)!;
    expect(table.zone('battlefield-s1')!.cards.map((c) => c.id),
        contains(card.id));
    expect(table.zone('hand-s1')!.cards.map((c) => c.id),
        isNot(contains(card.id)));

    // And where it was dropped, not in the next free flow slot. This is the
    // whole ask: tapping already played a card, into a slot chosen for you.
    expect(table.locate(card.id)!.card.position, isNotNull);
  });

  testWidgets('tapping a card in hand still plays it', (tester) async {
    final container = await _seatedPod(tester, ['you']);
    final card = container.read(playProvider)!.zone('hand-s1')!.cards.first;

    await tester.tap(find.byKey(Key('hand-card-${card.id}')));
    await tester.pumpAndSettle();

    // Dragging is an addition, not a replacement. A tap is still the fastest
    // way to put a land down and the player did not ask to lose it.
    expect(container.read(playProvider)!.zone('battlefield-s1')!.cards,
        hasLength(1));
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
