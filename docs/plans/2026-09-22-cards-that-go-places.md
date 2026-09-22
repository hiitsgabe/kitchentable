# Cards that go places, implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The deck sits where a deck sits and looks like one, a card can be
dragged out of your hand straight onto the spot you want it, and a commander
can be put back in its corner.

**Architecture:** Dragging inside one pile and dragging between piles are the
same gesture, so they become one mechanism. `Grabbable` is replaced by
Flutter's own `Draggable` and `DragTarget`, which already carry a payload
across widget boundaries and hand the drop's global offset to whoever caught
it. Still eleven verbs: every drop is a `MoveCard`.

**Tech Stack:** Flutter 3.47.5, Dart 3.13.4, flutter_riverpod 3.4.3.

---

## Where this came from

The player used the build on 2026 09 22 with a real Commander deck.

**"o comandante, se você arrasta ele de volta para a zona de comandante, ele
deve voltar"**, and the same when it dies.

**"a parte do deck precisa ficar mais pro canto direito, não no meio".**

**"seria interessante que a primeira carta do deck tenha o background da carta"**
of whatever game it is. Today the pile is blank tiles.

**"seria muito bom se você pudesse segurar a carta e deixá-la já na posição que
você quer do tabuleiro"**, instead of tapping a card in hand to play it.

## What this changes about dragging

Plan A and plan B built dragging as a pan inside one widget, with `Grabbable`
handing back the travel `kTouchSlop` swallows. That is correct for moving a
card around its own mat and cannot cross a widget boundary at all, which is
what three of the four asks need.

`Draggable` and `DragTarget` do cross boundaries, and `onAcceptWithDetails`
gives the drop's global offset, which a mat converts to its own normalized
spot exactly as `Grabbable` did. So the two mechanisms collapse into one and
`Grabbable` goes.

**The touch slop fix must not go with it.** `Draggable` has the same
recogniser underneath. The case that measured the original bug,
`a card lands where the finger let go, not short of it` in
`cursor_board_test.dart`, stays and must still pass: `DragTarget` reports
where the pointer actually was, not an accumulated delta, so it should pass
for a better reason than before. If it does not, say so rather than relaxing
it.

---

## Task 1: The deck sits where a deck sits

**Files:**
- Modify: `lib/features/play/play_screen.dart`
- Test: `test/features/play_screen_test.dart`

- [ ] **Step 1: Write the failing test**

Append to `test/features/play_screen_test.dart`:

```dart
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
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/play_screen_test.dart`
Expected: FAIL on `the deck must be on the right half`, with the deck's centre
at roughly the screen's centre.

- [ ] **Step 3: Move it**

In `lib/features/play/play_screen.dart`, the `LibraryStack` inside `yours` is
a plain child of a stretched `Column`, so it centres. Wrap it:

```dart
        Align(
          alignment: Alignment.centerRight,
          child: LibraryStack(
```

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/features/play_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Probe**

Change `Alignment.centerRight` to `Alignment.centerLeft`. The new case must
fail on the first assertion, `the deck must be on the right half`. Say which
assertion failed. Edit it back by hand, never with `git checkout`, and rerun.

- [ ] **Step 6: Commit**

```bash
git add lib/features/play/play_screen.dart test/features/play_screen_test.dart
git commit -m "Put the deck by your right hand"
```

---

## Task 2: A pile that looks like cards

The pile is blank tiles. A deck at a table is a stack of card backs, and which
back it is says which game you are playing before you read anything.

**Files:**
- Modify: `lib/ui/atoms/card_art.dart`
- Modify: `lib/features/play/widgets/library_stack.dart`
- Modify: `lib/features/play/play_screen.dart`
- Test: `test/ui/card_back_test.dart`, `test/features/library_stack_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/ui/card_back_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/decks/model/game.dart';
import 'package:kitchentable/ui/atoms/card_art.dart';

void main() {
  test('Magic has a back and it is the real one', () {
    // Scryfall serves the Magic back, which the card viewer has used since
    // plan 1 for a card with no second face.
    expect(backFor(Game.magic), isNotNull);
    expect(backFor(Game.magic), contains('scryfall'));
  });

  test('Pokemon has its own', () {
    expect(backFor(Game.pokemon), isNotNull);
    expect(backFor(Game.pokemon), isNot(backFor(Game.magic)));
  });

  testWidgets('a back with a picture draws it', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CardBack(width: 60, game: Game.magic),
      ),
    ));
    await tester.pump();

    expect(find.byKey(const Key('card-back-art')), findsOneWidget);
  });

  testWidgets('a back with no picture is still a card shaped box',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: CardBack(width: 60)),
    ));
    await tester.pump();

    // No game means no back to fetch, which is a token or a card the table
    // knows nothing about. It still has to occupy a card's worth of space.
    expect(find.byKey(const Key('card-back-art')), findsNothing);
    expect(
      tester.getSize(find.byType(CardBack)),
      const Size(60, 60 * 88 / 63),
    );
  });
}
```

Append to `test/features/library_stack_test.dart`:

```dart
  testWidgets('the pile is drawn as card backs', (tester) async {
    await tester.pumpWidget(_host(count: 8, game: Game.magic));
    await tester.pump();

    // The top card and the leaves under it. A blank tile reads as a hole in
    // the table rather than as a deck.
    expect(find.byType(CardBack), findsWidgets);
  });
```

and add `Game? game` to that file's `_host`, passing it through.

- [ ] **Step 2: Run them and watch them fail**

Run: `flutter test test/ui/card_back_test.dart test/features/library_stack_test.dart`
Expected: FAIL to compile, `Method not found: 'backFor'` and
`No named parameter with the name 'game'`.

- [ ] **Step 3: Give the back a picture**

In `lib/ui/atoms/card_art.dart`:

```dart
/// The back of a card, per game.
///
/// Magic's is the one Scryfall serves, which `CardViewer` has turned cards
/// over onto since plan 1. Moving it here rather than leaving a second copy
/// in the viewer is the point: there is one back per game and both the viewer
/// and the deck pile want it.
///
/// Null for a game the app has no back for, and for no game at all, which is
/// a token or a card the table knows nothing about.
String? backFor(Game? game) => switch (game) {
      Game.magic =>
        'https://backs.scryfall.io/large/0/a/0aeebaf5-8c7d-4636-9e82-8c27447861f7.jpg',
      Game.pokemon => _pokemonBack,
      null => null,
    };
```

For `_pokemonBack`, the app has no Pokemon catalog and therefore no source
that serves one. **Do not hotlink a fan site.** Two honest choices, and the
implementer picks and says which:

- A null for now, with the box drawing as it does today, and a comment saying
  the back arrives with the catalog that serves it.
- A drawn back: a rounded rectangle in the Pokemon card's colours with the
  app's own mark, generated in code, no asset and no fetch.

Prefer the first if the second cannot be made to look deliberate rather than
broken.

Then give `CardBack` the game and the picture:

```dart
class CardBack extends StatelessWidget {
  const CardBack({super.key, required this.width, this.game});

  final double width;
  final Game? game;

  @override
  Widget build(BuildContext context) {
    final height = width * 88 / 63;
    final url = backFor(game);

    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width * 0.05),
        child: url == null
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: Palette.tile,
                  border: Border.all(color: Palette.tileEdge),
                ),
              )
            : CardImage(
                key: const Key('card-back-art'),
                url: url,
                fallback: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Palette.tile,
                    border: Border.all(color: Palette.tileEdge),
                  ),
                ),
              ),
      ),
    );
  }
}
```

Read `CardImage` first: it is the platform split atom, `Image.network` on web
and `CachedNetworkImage` on io, and its existing parameters may not be these.
Match what is there rather than what is written here.

Give `LibraryStack` a `Game? game` and pass it to every `CardBack`, leaves
included. In `play_screen.dart` pass the seat's deck game. **The table does
not know about games**: `TableState` has no such field, so the screen reads it
from where the deck came in. If nothing on the screen can reach it, add it to
`PlayController` when the table opens rather than putting it on `TableState`,
and say that is what you did.

- [ ] **Step 4: Run them and watch them pass**

Run: `flutter test test/ui/card_back_test.dart test/features/library_stack_test.dart`
Expected: PASS.

Then `flutter test`: `card_viewer.dart` still has its own `_genericBack`
constant. Point it at `backFor(Game.magic)` and delete the duplicate, or say
why you did not.

- [ ] **Step 5: Probe**

Make `backFor` return null for every game. The two drawing cases must fail,
and say which assertion each. Edit it back by hand and rerun.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/atoms/card_art.dart lib/features/play lib/ui/organisms/card_viewer.dart \
        test/ui/card_back_test.dart test/features/library_stack_test.dart
git commit -m "Make the deck look like a deck"
```

---

## Tasks 3 onward

The drag rewrite, written after these two land so it is built against the
layout they leave rather than the one before it. It covers:

- **`Draggable` and `DragTarget` replacing `Grabbable`**, so one gesture
  serves moving a card on its own mat and moving it somewhere else.
- **Your hand onto the table**, dropping a card where you want it instead of
  tapping it into a flow slot.
- **The commander going home**, by dropping it on its corner and by an action
  in the big view for when it dies with a finger nowhere near it.
