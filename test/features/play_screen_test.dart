import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/sources/catalog/catalog_db.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kitchentable/decks/model/deck.dart';
import 'package:kitchentable/decks/model/deck_format.dart';
import 'package:kitchentable/features/play/play_controller.dart';
import 'package:kitchentable/features/menu/menu_controller.dart';
import 'package:kitchentable/features/play/play_screen.dart';
import 'package:kitchentable/features/play/renderers/free_canvas.dart';
import 'package:kitchentable/features/play/renderers/stacked_seats.dart';
import 'package:kitchentable/features/play/widgets/command_slot.dart';
import 'package:kitchentable/features/play/widgets/cursor_board.dart';
import 'package:kitchentable/features/play/widgets/hand_sheet.dart';
import 'package:kitchentable/features/play/widgets/radar_strip.dart';
import 'package:kitchentable/features/play/widgets/table_card.dart';
import 'package:kitchentable/features/play/widgets/seat_band.dart';
import 'package:kitchentable/table/model/seat_owner.dart';
import 'package:kitchentable/table/actions/table_action.dart';
import 'package:kitchentable/table/model/table_state.dart';
import 'package:kitchentable/table/referee/referee.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';
import 'package:kitchentable/ui/atoms/card_art.dart';

CatalogCard _card(String name) => CatalogCard(
      oracleId: name,
      name: name,
      typeLine: 'Instant',
      cmc: 1,
    );

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
  container.read(playProvider.notifier).startPod(
        players: [
          for (final name in names)
            (
              deck: _deck(commander: withCommander),
              name: name,
              owner: const SeatOwner.here()
            ),
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

  testWidgets('a commander sent home from the big view gets there',
      (tester) async {
    final container = await _seatedPod(tester, ['you'],
        withCommander: true, withCatalog: true);
    final play = container.read(playProvider.notifier);
    final commander =
        container.read(playProvider)!.zone('command-s1')!.cards.first;

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

    expect(container.read(playProvider)!.zone('command-s1')!.cards,
        hasLength(1));
    expect(container.read(playProvider)!.zone('battlefield-s1')!.cards,
        isEmpty);
  });

  testWidgets('a commander dropped on its corner goes home', (tester) async {
    final container = await _seatedPod(tester, ['you'], withCommander: true);
    final play = container.read(playProvider.notifier);
    final commander =
        container.read(playProvider)!.zone('command-s1')!.cards.first;

    play.run(MoveCard(cardId: commander.id, toZoneId: 'battlefield-s1'));
    await tester.pump();

    final corner = tester.getCenter(find.byType(CommandSlot));
    final from = tester.getCenter(find.byType(TableCard).first);
    await tester.dragFrom(from, corner - from);
    await tester.pumpAndSettle();

    expect(container.read(playProvider)!.zone('command-s1')!.cards,
        hasLength(1));
    expect(container.read(playProvider)!.zone('battlefield-s1')!.cards,
        isEmpty);
  });

  testWidgets('the deck and the commander are the size of the cards',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = await _seatedPod(tester, ['you'],
        window: const Size(1900, 900), withCommander: true);

    // A window this wide opens the canvas by itself, and the canvas draws
    // neither a deck nor a commander, so there would be nothing to measure.
    // The screenshot this came from was the bands on a wide window, which is
    // one button away and is where the deck sat at 46 points beside a 270
    // point card.
    await tester.tap(find.byKey(const Key('switch-renderer')));
    await tester.pumpAndSettle();

    final play = container.read(playProvider.notifier);
    final card = container.read(playProvider)!.zone('hand-s1')!.cards.first;

    play.run(MoveCard(cardId: card.id, toZoneId: 'battlefield-s1'));
    await tester.pumpAndSettle();

    // Named by the thing that draws it. The commander is a TableCard too and
    // it is drawn first, so `first` on its own would measure the corner and
    // then compare the deck against it rather than against the board.
    final onBoard = tester
        .getSize(find
            .descendant(
              of: find.byType(CursorBoard),
              matching: find.byType(TableCard),
            )
            .first)
        .width;
    // The back of the top card, not the box the pile is drawn in: the box is
    // the card plus a leaf of offset per card in the deck, which is about 19
    // points of thickness on a full library and is not a card's width at all.
    // Measured against the box, a deck at 46 points already cleared the bar
    // below and the case proved nothing.
    final deck = tester
        .getSize(find
            .descendant(
              of: find.byKey(const Key('library-stack')),
              matching: find.byType(CardBack),
            )
            .first)
        .width;
    final commander = tester
        .getSize(find.descendant(
          of: find.byType(CommandSlot),
          matching: find.byType(TableCard),
        ))
        .width;

    // The deck was a fixed 46 points while a card on a wide window was 270,
    // so the pile you draw from was nearly six times smaller than the cards
    // around it. A deck at a table is the same size as the cards in it.
    expect(deck, greaterThan(onBoard * 0.6),
        reason: 'the deck is a pile of these cards, not a thumbnail');

    // And not the other way either. Read off the seat's whole column rather
    // than off the box the board is given, the deck comes out at 186 points
    // beside a 99 point card, measured: that clears the line above and is
    // just as wrong. Too big is the failure this arithmetic can actually
    // make, so the case has to be able to say it.
    expect(deck, lessThan(onBoard * 1.4),
        reason: 'the deck is a pile of these cards, not a monument');

    // And the corner is one of these cards too, at 52 points against 270.
    // Asserted here and not left to the deck, because they are two separate
    // sizes in the screen and one can be fixed while the other is missed.
    expect(commander, greaterThan(onBoard * 0.6),
        reason: 'the commander is a card, not a stamp');
    expect(commander, lessThan(onBoard * 1.4),
        reason: 'the commander is a card, not a poster');
  });

  testWidgets('a card dropped on the graveyard goes there', (tester) async {
    final container = await _seatedPod(tester, ['you']);
    final play = container.read(playProvider.notifier);
    final card = container.read(playProvider)!.zone('hand-s1')!.cards.first;

    play.run(MoveCard(cardId: card.id, toZoneId: 'battlefield-s1'));
    await tester.pumpAndSettle();

    final from = tester.getCenter(find.descendant(
      of: find.byKey(const Key('your-board')),
      matching: find.byType(TableCard),
    ));
    final bin = tester.getCenter(find.byKey(const Key('graveyard-stack')));
    await tester.dragFrom(from, bin - from);
    await tester.pumpAndSettle();

    final table = container.read(playProvider)!;
    expect(table.zone('graveyard-s1')!.cards.map((c) => c.id),
        contains(card.id));
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

  testWidgets('the top of the graveyard is the last card thrown in',
      (tester) async {
    final container = await _seatedPod(tester, ['you'],
        withCommander: true, withCatalog: true);
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
    final art = tester.widget<CardArt>(find.descendant(
      of: find.byKey(const Key('graveyard-stack')),
      matching: find.byType(CardArt),
    ));
    expect(art.card.name, 'General');
  });

  testWidgets('the graveyard is on the mat in the wide view too',
      (tester) async {
    // The case above this one taps the renderer button, which writes the
    // choice to the preferences, and the choice wins over the width. Without
    // this the wide window opened the bands and the pile found below was the
    // one in the column beside the board.
    SharedPreferences.setMockInitialValues({});
    final container = await _seatedPod(tester, ['you'],
        window: const Size(1280, 800));
    final play = container.read(playProvider.notifier);
    final card = container.read(playProvider)!.zone('hand-s1')!.cards.first;

    play.run(MoveCard(cardId: card.id, toZoneId: 'graveyard-s1'));
    await tester.pumpAndSettle();

    // Said out loud, because the whole case rests on it: a window this wide
    // opens the canvas, so a pile found here is the one on the mat and not
    // the one in the bands.
    expect(find.byType(FreeCanvas), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(FreeCanvas),
        matching: find.byKey(const Key('graveyard-stack')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the graveyard can be opened and a card taken back',
      (tester) async {
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

  testWidgets('copying a card puts a second one on the battlefield',
      (tester) async {
    final container =
        await _seatedPod(tester, ['you'], withCatalog: true);
    final play = container.read(playProvider.notifier);
    final card = container.read(playProvider)!.zone('hand-s1')!.cards.first;

    play.run(MoveCard(cardId: card.id, toZoneId: 'battlefield-s1'));
    await tester.pumpAndSettle();

    await tester.longPress(find.descendant(
      of: find.byKey(const Key('your-board')),
      matching: find.byType(TableCard),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('act-copy')));
    await tester.pumpAndSettle();

    final board = container.read(playProvider)!.zone('battlefield-s1')!;
    expect(board.cards, hasLength(2));
    expect(board.cards.map((c) => c.oracleId).toSet(), {card.oracleId});
    expect(board.cards.map((c) => c.id).toSet(), hasLength(2),
        reason: 'a copy is its own card, not the same card twice');
  });

  testWidgets('the wide view can make a token too', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _seatedPod(tester, ['you'],
        window: const Size(1280, 800), withCatalog: true);

    // The default renderer above 720 points is the canvas, and the token
    // control lived only in the column the bands draw beside the mat. Copy
    // worked there and finding one did not, which is the half of tokens that
    // needs a catalog.
    expect(find.byType(FreeCanvas), findsOneWidget);
    expect(find.byKey(const Key('make-token')), findsOneWidget);
  });

  testWidgets('a token can be found in the catalog and put down',
      (tester) async {
    final container = await _seatedPod(tester, ['you'], withCatalog: true);

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

  testWidgets('the kind chosen in the big view is the kind counted',
      (tester) async {
    final container = await _seatedPod(tester, ['you'], withCatalog: true);
    final play = container.read(playProvider.notifier);
    final card = container.read(playProvider)!.zone('hand-s1')!.cards.first;

    play.run(MoveCard(cardId: card.id, toZoneId: 'battlefield-s1'));
    await tester.pumpAndSettle();

    await tester.longPress(find.descendant(
      of: find.byKey(const Key('your-board')),
      matching: find.byType(TableCard),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('kind-damage')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('act-counter-up')));
    await tester.pumpAndSettle();

    // Not in the plan, which probes the kind inside the viewer and leaves the
    // screen's end of it unwatched. The viewer can choose a kind perfectly and
    // the screen can still drop it on the floor and count `+1/+1`, which is
    // what it did before onCount and what no case here would have noticed.
    expect(
      container.read(playProvider)!.locate(card.id)!.card.counters,
      {'damage': 1},
    );
  });

  testWidgets('the board draws one mat, not a graveyard under it',
      (tester) async {
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

  testWidgets('the board is budgeted for both columns, not one',
      (tester) async {
    final container = await _seatedPod(tester, ['you']);
    final play = container.read(playProvider.notifier);
    final card = container.read(playProvider)!.zone('hand-s1')!.cards.first;

    play.run(MoveCard(cardId: card.id, toZoneId: 'battlefield-s1'));
    await tester.pumpAndSettle();

    final onBoard = tester
        .getSize(find.descendant(
          of: find.byKey(const Key('your-board')),
          matching: find.byType(TableCard),
        ))
        .width;
    final deck = tester
        .getSize(find.descendant(
          of: find.byKey(const Key('library-stack')),
          matching: find.byType(CardBack),
        ).first)
        .width;

    // The board's width arithmetic takes two columns out of the row, one for
    // the graveyard and one for the deck. Taking one out leaves the whole
    // suite green otherwise: it only moves the card by a couple of points,
    // and the case that measures card sizes runs at 1900 by 900 where the
    // card is height bound and the width arithmetic never binds at all.
    //
    // This is the only observable, and it is not a wide one. Measured on this
    // window: 1.160 with both columns budgeted, 1.239 with one. The bound
    // sits between them, with two and a half percent of room below it and four
    // above, so if this ever fails on a change that was not about the row's
    // width, check those two numbers before loosening it. It was 1.145 against
    // 1.232 until the pile learned to thin as it is drawn, which narrows the
    // column the row budgets for and so moves both.
    //
    // It is also the case that catches a control in either column whose own
    // width does not shrink with the card. The dice tray's caption was a ten
    // point font beside an eight point die, which made the column 41 wide
    // where a card is 32 and took this to 1.269. Sizes in those columns come
    // off the card and not off the metrics for that reason.
    expect(deck / onBoard, lessThan(1.19),
        reason: 'the row is budgeting for one column and there are two');
  });

  testWidgets('the token control is on the same side in both views',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _seatedPod(tester, ['you'],
        window: const Size(1280, 800), withCommander: true);
    await tester.pumpAndSettle();

    final onCanvas =
        tester.getRect(find.byKey(const Key('make-token'))).center.dx;
    final canvasBoard = tester.getRect(find.byType(FreeCanvas)).center.dx;

    await tester.tap(find.byKey(const Key('switch-renderer')));
    await tester.pumpAndSettle();

    final inBands =
        tester.getRect(find.byKey(const Key('make-token'))).center.dx;
    final bandsBoard =
        tester.getRect(find.byKey(const Key('your-board'))).center.dx;

    // The canvas ran out of room in the right strip and put the token across
    // with the graveyard, so the two views disagreed about which hand you
    // reach with. Same side in both, whichever side that is.
    expect(onCanvas < canvasBoard, inBands < bandsBoard,
        reason: 'the token control swaps sides between the two views');
  });

  testWidgets('the graveyard is on the far side from the deck',
      (tester) async {
    await _seatedPod(tester, ['you'], withCommander: true);
    await tester.pumpAndSettle();

    final board = tester.getRect(find.byKey(const Key('your-board')));
    final bin = tester.getRect(find.byKey(const Key('graveyard-stack')));
    final deck = tester.getRect(find.byKey(const Key('library-stack')));

    // A graveyard sits across the table from the library, not stacked under
    // it: stacked, the column is two cards tall and the corner has nowhere
    // left to go.
    expect(bin.right, lessThanOrEqualTo(board.left));
    expect(deck.left, greaterThanOrEqualTo(board.right));
  });

  testWidgets('nothing in the aside runs off the bottom', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _seatedPod(tester, ['you'],
        window: const Size(1280, 800), withCommander: true);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('switch-renderer')));
    await tester.pumpAndSettle();

    final screen = tester.getRect(find.byType(PlayScreen));
    for (final key in ['library-stack', 'graveyard-stack', 'make-token']) {
      final it = tester.getRect(find.byKey(Key(key)));
      expect(it.bottom, lessThanOrEqualTo(screen.bottom),
          reason: '$key runs off the bottom');
      expect(it.right, lessThanOrEqualTo(screen.right),
          reason: '$key runs off the right');
    }
  });

  testWidgets('rolling a die puts the number on the table', (tester) async {
    final container = await _seatedPod(tester, ['you']);

    expect(container.read(playProvider)!.dice, isEmpty);

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
    play.run(MoveCard(
      cardId: table.zone('hand-s1')!.cards.first.id,
      toZoneId: 'battlefield-s1',
    ));
    play.run(MoveCard(
      cardId: table.zone('hand-s2')!.cards.first.id,
      toZoneId: 'battlefield-s2',
    ));
    await tester.pumpAndSettle();

    // Three hand offs, and each of them is one argument the screen can simply
    // not write. The widgets each have a case proving they pass the game down
    // once they are given it; nothing but this proves they are given it, and
    // with no printings behind these cards the back is what they all draw.
    for (final where in ['your-board', 'band-s2']) {
      expect(
        find.descendant(
          of: find.byKey(Key(where)),
          matching: find.byKey(const Key('card-back-art')),
        ),
        findsWidgets,
        reason: '$where was handed no game',
      );
    }
    expect(
      find.descendant(
        of: find.byType(HandSheet),
        matching: find.byKey(const Key('card-back-art')),
      ),
      findsWidgets,
      reason: 'the hand was handed no game',
    );

    // And the same on the wide view, which reaches a card through a renderer
    // of its own.
    await tester.tap(find.byKey(const Key('switch-renderer')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('mat-s2')),
        matching: find.byKey(const Key('card-back-art')),
      ),
      findsWidgets,
      reason: 'the canvas was handed no game',
    );
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
