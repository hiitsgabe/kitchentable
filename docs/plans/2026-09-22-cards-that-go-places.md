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

  test('Pokemon has no back to fetch, and does not borrow Magic s', () {
    // Game.pokemon.hasCatalog is false and the source registry refuses
    // Pokemon decks, so no Pokemon deck can reach a table at all. A drawn
    // back would be an invention and unreachable code at once.
    expect(backFor(Game.pokemon), isNull);
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

    // Eight leaves and the top card. Counting the art and not just the boxes:
    // `LibraryStack` is already built out of `CardBack`, so asserting that a
    // `CardBack` exists is green before this task starts, and the only red in
    // Step 2 would be the missing `game` parameter taking the file down at
    // load. A compile red is not a behavioural red.
    expect(find.byType(CardBack), findsNWidgets(9));
    expect(find.byKey(const Key('card-back-art')), findsNWidgets(9));
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

`Game.pokemon` returns **null**. The app has no Pokemon catalog,
`Game.pokemon.hasCatalog` is false, and the source registry refuses Pokemon
decks, so no Pokemon deck can reach a table: a drawn back would be an
invention and unreachable code at once, and it would not do the job a back is
here to do, which is to say which game is on the table. Write a comment saying
the back arrives with the catalog that serves it. Do not hotlink a fan site.

Give `backFor` three explicit arms, `Game.magic`, `Game.pokemon` and `null`,
rather than a wildcard, so a third game is a compile error here instead of a
silent null.

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
included.

**The table does not know about games and must not learn.** `TableState` and
`Seat` have no such field and the spec says the table is game agnostic on
purpose. Nothing on the screen can reach a deck either: the `Deck` is only in
scope inside `startPod`. So `PlayController` keeps a
`Map<String, Game> _games` written there and cleared in `leave()`, with a
`Game? gameAt(String seatId)`, and the screen passes
`game: play.gameAt(seat.id)`.

Build that map by zipping `table.seats[i].id` against `players[i].deck.game`
rather than rebuilding the `'s${i + 1}'` string, so it depends on the order
`sitDownTogether` seats people and not on the spelling of the id it mints.

**Nothing will observe that route unless you write a case for it.** Add one to
`play_screen_test.dart` asserting a `card-back-art` descends from
`library-stack`, and probe it by passing `game: null` from the screen. It dies
by a finder, so it proves liveness only, and there is no wrong value to
follow it with: Magic is the only game with a back, so "no game" is the only
wrong answer the app can currently produce on that path. Say that rather than
dressing it up.

- [ ] **Step 4: Run them and watch them pass**

Run: `flutter test test/ui/card_back_test.dart test/features/library_stack_test.dart`
Expected: PASS.

Then `flutter test`: `card_viewer.dart` still has its own `_genericBack`
constant. Point it at `backFor(Game.magic)` and delete the duplicate, or say
why you did not.

- [ ] **Step 5: Probe**

Two, because one cannot reach the Pokemon arm.

Make `backFor` return null for Magic too. Three cases fall: the Magic one on a
wrong value, and the two drawing ones on finders, which is liveness only. The
wrong value is on the same function the two widget cases read, so the three
together are not fooling you about which code they exercise. The no-game case
stays green, correctly.

Then make `Game.pokemon` return the Magic back. The Pokemon case must fail on
a wrong value, which is the assertion doing the work.

Say which assertion failed each time, with its line. Edit each back by hand
and rerun.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/atoms/card_art.dart lib/features/play lib/ui/organisms/card_viewer.dart \
        test/ui/card_back_test.dart test/features/library_stack_test.dart
git commit -m "Make the deck look like a deck"
```

---

## Why `Grabbable` goes, and what replaces it

`Grabbable` works. It solves a real bug, it is tested, and the card moving
live under the finger is the part the player liked. Three things argued about
before replacing it, written down so nobody reverses this by accident:

**It cannot cross a widget boundary.** It reports deltas to whoever owns it.
A card in the hand cannot tell the mat anything, and a card on the mat cannot
tell the command slot anything. Three of the four asks in this plan need
exactly that.

**Keeping it for one case and adding `Draggable` for the other is worse than
either.** A board card that slides under your finger and a hand card that
spawns a ghost are two different gestures in one screen.

**`Draggable` can look identical to `Grabbable`.** `feedback` is what follows
the pointer, so it is the card at full size; `childWhenDragging` is what is
left behind, so it is a faint outline. The card appears to move, and the drop
carries a real pointer position rather than a sum of deltas.

**The slop bug cannot exist under `Draggable`,** which is the point.
`Grabbable`'s whole reason was that the first `kTouchSlop` of travel is never
reported as a delta. `DragTarget.onAcceptWithDetails` is handed where the
pointer actually was, not a running total, so there is nothing to lose.

**The case that measured the slop bug changes meaning and must be rewritten,
not deleted.** `a card lands where the finger let go, not short of it` in
`cursor_board_test.dart` asserts that the card's own rect has moved with the
finger mid drag. Under `Draggable` the card does not move, the feedback does,
so that assertion is about the wrong widget. Rewrite it to assert the
**reported drop position** matches where the pointer was released. That is the
property the old case was reaching for through a proxy, and it is stronger.
Say in your report what the case looked like before and after.

---

## Task 3: One gesture, anywhere

**Files:**
- Delete: `lib/features/play/widgets/grabbable.dart`
- Create: `lib/features/play/widgets/card_drag.dart`
- Modify: `lib/features/play/widgets/cursor_board.dart`
- Modify: `lib/features/play/renderers/free_canvas.dart`
- Modify: `lib/features/play/widgets/hand_sheet.dart`
- Test: `test/features/card_drag_test.dart`, and the existing drag cases

- [ ] **Step 1: Write the failing test**

Create `test/features/card_drag_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/widgets/card_drag.dart';
import 'package:kitchentable/table/model/card_instance.dart';

const _card = CardInstance(id: 'a', oracleId: 'o');

Widget _host({
  void Function(CardInstance, Offset)? onDrop,
  bool canDrag = true,
}) =>
    MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            SizedBox(
              height: 120,
              child: Center(
                child: DraggableCard(
                  card: _card,
                  canDrag: canDrag,
                  child: const SizedBox(
                    key: Key('the-card'),
                    width: 60,
                    height: 84,
                  ),
                ),
                // A bare SizedBox is a RenderConstrainedBox: no hitTestSelf
                // and no child, so nothing in it is ever in a hit path. Every
                // tester.drag on it needs warnIfMissed: false, and the
                // Draggable above needs an opaque hitTestBehavior or the drag
                // never starts at all.
              ),
            ),
            Expanded(
              child: CardDropTarget(
                onDrop: onDrop ?? (_, _) {},
                child: const SizedBox.expand(
                  key: Key('the-target'),
                ),
              ),
            ),
          ],
        ),
      ),
    );

void main() {
  testWidgets('a card dropped on a target arrives there', (tester) async {
    CardInstance? dropped;
    await tester.pumpWidget(_host(onDrop: (c, _) => dropped = c));
    await tester.pump();

    await tester.drag(
      find.byKey(const Key('the-card')),
      tester.getCenter(find.byKey(const Key('the-target'))) -
          tester.getCenter(find.byKey(const Key('the-card'))),
    );
    await tester.pumpAndSettle();

    expect(dropped?.id, 'a');
  });

  testWidgets('where it was let go is reported in the target s own space',
      (tester) async {
    Offset? at;
    await tester.pumpWidget(_host(onDrop: (_, where) => at = where));
    await tester.pump();

    final target = tester.getRect(find.byKey(const Key('the-target')));
    final from = tester.getCenter(find.byKey(const Key('the-card')));
    final to = target.topLeft + const Offset(40, 30);

    await tester.drag(find.byKey(const Key('the-card')), to - from);
    await tester.pumpAndSettle();

    // Local to the target, so a mat can normalise it without knowing where on
    // the screen it happens to be. The pointer's real position, not a sum of
    // deltas, which is why the slop that Grabbable existed to fix cannot come
    // back here.
    expect(at!.dx, closeTo(40, 2));
    expect(at!.dy, closeTo(30, 2));
  });

  testWidgets('a card nobody may move does not move', (tester) async {
    CardInstance? dropped;
    await tester.pumpWidget(_host(canDrag: false, onDrop: (c, _) => dropped = c));
    await tester.pump();

    await tester.drag(find.byKey(const Key('the-card')), const Offset(0, 200));
    await tester.pumpAndSettle();

    // Somebody else's card on somebody else's mat.
    expect(dropped, isNull);
  });

  testWidgets('a drop outside every target reports nothing', (tester) async {
    CardInstance? dropped;
    await tester.pumpWidget(_host(onDrop: (c, _) => dropped = c));
    await tester.pump();

    await tester.drag(
      find.byKey(const Key('the-card')),
      const Offset(0, -60),
    );
    await tester.pumpAndSettle();

    expect(dropped, isNull);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/card_drag_test.dart`
Expected: FAIL, `Error when reading
'lib/features/play/widgets/card_drag.dart'`.

- [ ] **Step 3: Write the pair**

Create `lib/features/play/widgets/card_drag.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../table/model/card_instance.dart';

/// A card you can pick up and drop somewhere else.
///
/// This replaces a pan based `Grabbable`, which could only tell its own
/// parent anything and so could never move a card from a hand onto a mat or
/// from a mat into a corner.
///
/// The feedback is the card itself at full size and what is left behind is a
/// faint outline, so it still looks like the card is moving rather than like
/// a ghost being spawned. That was the part worth keeping.
class DraggableCard extends StatelessWidget {
  const DraggableCard({
    super.key,
    required this.card,
    required this.child,
    this.canDrag = true,
  });

  final CardInstance card;
  final Widget child;

  /// False for a card on somebody else's mat. It is theirs to move.
  final bool canDrag;

  @override
  Widget build(BuildContext context) {
    if (!canDrag) return child;

    return Draggable<CardInstance>(
      data: card,
      // The whole card rectangle is the grab area, rounded corners and
      // transparent gaps included. Without this the default is
      // HitTestBehavior.deferToChild, and a child that is not itself in a hit
      // path, which a bare SizedBox never is, means the drag never starts.
      hitTestBehavior: HitTestBehavior.opaque,
      // Anchored on the pointer, so `details.offset` IS the pointer rather
      // than the feedback's top left, and the feedback is counter translated
      // so the card still rides under the finger. Two things fall out of it
      // that the default anchor gets wrong: _DragAvatar hit tests at the
      // feedback's top left, so the target that accepts would be the one
      // under the card's corner and not under your finger; and the reported
      // drop is the card's new centre, which makes spotFor its exact inverse.
      // The cost is that the card recentres on your finger when you pick it
      // up instead of keeping the exact grab point.
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: FractionalTranslation(
          translation: const Offset(-0.5, -0.5),
          child: Opacity(opacity: 0.92, child: child),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: child),
      child: child,
    );
  }
}

/// Somewhere a card can land.
///
/// Reports where the pointer was when it was released, in this widget's own
/// coordinates, so a mat can normalise against itself without knowing where
/// on the screen it is. The position comes from the pointer rather than from
/// a sum of deltas, which is why the `kTouchSlop` that the old pan based drag
/// had to compensate for cannot come back here.
class CardDropTarget extends StatelessWidget {
  const CardDropTarget({
    super.key,
    required this.onDrop,
    required this.child,
  });

  final void Function(CardInstance card, Offset at) onDrop;
  final Widget child;

  @override
  Widget build(BuildContext context) => DragTarget<CardInstance>(
        onAcceptWithDetails: (details) {
          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          onDrop(details.data, box.globalToLocal(details.offset));
        },
        builder: (context, _, _) => child,
      );
}
```

**Do not correct `details.offset` with arithmetic.** By default it is the
global top left of the feedback, and the miss is exactly half the card,
because `tester.drag` always grabs the centre. In the field a finger can grab
a corner, so "half the card" is the wrong general rule and the test cannot
tell it apart from the right one. `DragTargetDetails` carries no grab offset,
so the correction is structural: anchor the drag on the pointer, as the block
above does.

With that anchor the reported position is **exact**, not approximate. Assert
equality rather than a tolerance: a tolerance there is room for the old bug to
hide in.

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/features/card_drag_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Move the three callers over**

`cursor_board.dart`, `free_canvas.dart` and `hand_sheet.dart` all use
`Grabbable`. Replace each with `DraggableCard`, and make the mat in the first
two a `CardDropTarget` that normalises the reported offset against its own
size and calls the `onPlace` it already has.

The hand's reorder is the odd one: it is a drop on the hand itself, and the
index comes from the x it is dropped at over the card pitch. Same
`CardDropTarget`, different arithmetic.

Delete `grabbable.dart`. `grep -rn Grabbable lib/ test/` must come back empty.

- [ ] **Step 6: Rewrite the slop case**

In `cursor_board_test.dart`, `a card lands where the finger let go, not short
of it` measures the card's own rect mid drag. Under `Draggable` the card does
not move, so that assertion is about the wrong widget now. Rewrite it to
assert the **reported** position:

```dart
  testWidgets('a card lands where the finger let go, not short of it',
      (tester) async {
    double? x;
    await tester.pumpWidget(_host(onPlace: (_, at, _) => x = at));
    await tester.pump();

    final card = tester.getCenter(find.byType(TableCard).first);
    await tester.drag(find.byType(TableCard).first, const Offset(200, 0));
    await tester.pumpAndSettle();

    final mat = tester.getRect(find.byKey(const Key('mat-surface')));
    // Where the pointer actually ended, normalised. A drag driven by summed
    // deltas used to land about kTouchSlop short of this; a drop position
    // taken from the pointer cannot.
    expect(x, closeTo((card.dx + 200 - mat.left) / mat.width, 0.02));
  });
```

There is no single `mat-surface`: `cursor_board` draws one mat per pile, so
the key is `Key('mat-${zone.id}')` and the case reads
`Key('mat-battlefield-s1')`.

**Key the surface, not the mat.** The mat's `Container` has a
`Border.all(width: 1)`, and a `BoxDecoration` border insets its child, so the
box a drop is normalised against is the `Stack` inside: one unit in and two
narrower. Measuring against the mat's own rect is off by `1/640`. The cards
are laid out inside that same `Stack` in `matSize` units, so production is
right and it is the test that has to point at the surface.

Exact equality misses by one ULP, because the two sides divide in a different
order: `Expected: <0.3528125> Actual: <0.35281250000000003>`. Use `1e-9`,
which is seven orders of magnitude below the eighteen pixels of an eight
hundred pixel mat that the bug would cost.

- [ ] **Step 7: Run everything**

Run: `flutter test && flutter analyze`
Expected: PASS and `No issues found!`, WARNING count 0.

Every existing drag case in `cursor_board_test.dart`, `free_canvas_test.dart`,
`hand_sheet_test.dart` and `play_screen_test.dart` has to keep passing. They
use `tester.drag`, which drives `Draggable` as well as it drove the pan, but
they assert **reported** values and those may now be exact where they were
approximate. If a `closeTo` starts passing with a tighter tolerance, tighten
it and say so. If one fails, report the numbers before changing anything.

- [ ] **Step 8: Probe**

Return `details.offset` without `globalToLocal`. The second case fails on
**`at!.dy`**, not `at!.dx`: the target spans the host's full width, so its
left edge is 0 and the global and local x are the same number.

Then make `canDrag` ignored. The third case must fail on
`expect(dropped, isNull)`.

Then revert the pointer anchor to Flutter's default. The rewritten slop case
must fail short by about half a card.

Then flip the sign of the `matPadding` correction in `free_canvas._drop`.
**It survives**, because nothing in `free_canvas_test.dart` asserts the
vertical at all: every case there checks `x`. Add a round trip case, drop a
card, hand the reported position straight back to the mat, assert it is drawn
where the finger let go, and the flip then costs exactly two `matPadding`.

Say which assertion failed each time, with its line. Edit each back by hand
and rerun.

- [ ] **Step 9: Commit**

```bash
git add lib/features/play test/features
git commit -m "One gesture for moving a card, wherever it is going"
```

---

## Task 4: Your hand onto the table

**Files:**
- Modify: `lib/features/play/widgets/hand_sheet.dart`
- Modify: `lib/features/play/play_screen.dart`
- Test: `test/features/play_screen_test.dart`

- [ ] **Step 1: Write the failing test**

Append to `test/features/play_screen_test.dart`:

```dart
  testWidgets('a card dragged out of your hand lands where you dropped it',
      (tester) async {
    final container = await _seatedPod(tester, ['you']);
    // cards[3] and not cards.first. At index 0 the `at` argument is 0 either
    // way and an empty battlefield accepts insert(0, ...), so the case would
    // pass with or without the guard that stops a card arriving from another
    // zone carrying its old index. Without that guard this throws
    // `RangeError: Only valid value is 0: 3` inside Zone.add.
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
```

- [ ] **Step 2: Run them and watch them fail**

Run: `flutter test test/features/play_screen_test.dart`
Expected: the drag case FAILS on the battlefield not containing the card. The
tap case passes already.

- [ ] **Step 3: Wire it**

**The empty battlefield is not a drop target at all.** `CursorBoard.build`
returns early with a bare centred `Text` when `BoardCursor.start` is null, and
`_pile` only runs for a zone with cards in it. So on a fresh table there is
nowhere for the first card out of your hand to land, and the rest of this step
has nothing to accept with. Keep the first pile's mat while it is empty, with
the words inside it as a `Positioned.fill`, and let `cursor` be nullable
through `_pile` and `_card`.

**`onPlace` must name the pile.** `CursorBoard` renders one target per pile,
so passing `battlefield.id` blindly moves a graveyard card onto the
battlefield: a silent regression of what Task 3 shipped, covered by nothing.
The signature is `(String zoneId, String cardId, double x, double y)`. In
`FreeCanvas` there is one target, the viewer's own mat, so it passes its own.

The hand's cards are already `DraggableCard` after Task 3. The board's
`CardDropTarget` has to accept a card that is not already on it: when the
dropped card is in another zone, the move is
`MoveCard(cardId: ..., toZoneId: battlefield, position: ...)` with no `at`,
and when it is already there it is the reposition Task 3 wired.

In `play_screen.dart`, `_place` already takes `(cardId, x, y)` and looks the
card up. It works for both: `found.zone.id` is where the card **is**, so a
card coming from the hand would be moved back into the hand. Give `_place` the
destination zone explicitly instead, and pass `battlefield.id` from the board's
target.

Keep `at` only when the card is already in that zone. A card arriving from
elsewhere has no index to preserve.

- [ ] **Step 4: Run everything**

Run: `flutter test && flutter analyze`
Expected: PASS and `No issues found!`.

- [ ] **Step 5: Probe**

Make the board's target always pass `found.zone.id` as the destination. The
drag case must fail on the battlefield not containing the card. Then drop the
`position` from the move: it must fail on `position, isNotNull`.

Then drop the `already` guard and pass the source index unconditionally.
**Against `cards.first` this survives**, which is why the case drags
`cards[3]`: at index 0 the guard makes no difference.

Say which assertion each time. Edit back by hand and rerun.

- [ ] **Step 6: Commit**

```bash
git add lib/features/play test/features/play_screen_test.dart
git commit -m "Put a card where you want it straight out of your hand"
```

---

## Task 5: The commander goes home

Two ways, because a commander leaves the battlefield in two circumstances: you
put it back, and it dies while your finger is nowhere near it.

**Files:**
- Modify: `lib/features/play/widgets/command_slot.dart`
- Modify: `lib/ui/organisms/card_viewer.dart`
- Modify: `lib/features/play/play_screen.dart`
- Test: `test/features/command_slot_test.dart`, `test/ui/card_viewer_actions_test.dart`, `test/features/play_screen_test.dart`

- [ ] **Step 1: Write the failing tests**

Append to `test/features/command_slot_test.dart`:

```dart
  testWidgets('a card dropped on the corner is reported', (tester) async {
    CardInstance? sent;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            DraggableCard(
              card: const CardInstance(id: 'x', oracleId: 'General'),
              child: const SizedBox(key: Key('loose'), width: 40, height: 56),
            ),
            Expanded(
              child: CommandSlot(
                metrics: Metrics.of(DeviceClass.handheld),
                cards: const [],
                printings: const {},
                width: 60,
                onTap: (_) {},
                onInspect: (_) {},
                onSendHome: (c) => sent = c,
              ),
            ),
          ],
        ),
      ),
    ));
    await tester.pump();

    final to = tester.getCenter(find.byType(CommandSlot));
    final from = tester.getCenter(find.byKey(const Key('loose')));
    await tester.dragFrom(from, to - from);
    await tester.pumpAndSettle();

    expect(sent?.id, 'x');
  });
```

Append to `test/ui/card_viewer_actions_test.dart`:

```dart
  testWidgets('a card can be sent to the command zone from the big view',
      (tester) async {
    CardAction? acted;
    await tester.pumpWidget(_host(
      instance: const CardInstance(id: 'a', oracleId: 'o'),
      onAct: (a) => acted = a,
      hasCommandZone: true,
    ));
    await tester.pump();

    await tester.tap(find.byKey(const Key('act-command')));
    await tester.pump();

    expect(acted, CardAction.commandZone);
  });

  testWidgets('a table with no command zone does not offer it',
      (tester) async {
    await tester.pumpWidget(
      _host(instance: const CardInstance(id: 'a', oracleId: 'o')),
    );
    await tester.pump();

    // Standard and Pauper have no such corner, and an action that moves a
    // card into a zone that does not exist is a silent no op.
    expect(find.byKey(const Key('act-command')), findsNothing);
  });
```

`_host` in that file needs a `hasCommandZone` argument, defaulting false.

Append to `test/features/play_screen_test.dart`:

```dart
  testWidgets('a commander dropped on its corner goes home', (tester) async {
    // This file's _deck() is sixty Mountains with no commander slot, so the
    // command zone exists and is empty and `.cards.first` throws. Add
    // off-by-default `commander` to _deck and `withCommander` to _seatedPod,
    // with the commander an extra card on top of the sixty so the `53 after a
    // hand of seven` assertion stays true and `find.byType(TableCard).first`
    // still points at the battlefield.
    final container =
        await _seatedPod(tester, ['you'], withCommander: true);
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
```

- [ ] **Step 2: Run them and watch them fail**

Run: `flutter test test/features/command_slot_test.dart test/ui/card_viewer_actions_test.dart test/features/play_screen_test.dart`
Expected: FAIL to compile on `onSendHome`, `hasCommandZone` and
`CardAction.commandZone`.

- [ ] **Step 3: Write it**

- `CommandSlot` gains `required this.onSendHome` and wraps its whole column in
  a `CardDropTarget`.
- `CardAction` gains `commandZone`. `CardViewer` gains
  `bool hasCommandZone = false` and shows an `act-command` button only when it
  is true and `instance` is not null.
- `play_screen.dart` passes `hasCommandZone: table.zone('command-$viewerId')
  != null` into the viewer, handles the new case with
  `MoveCard(cardId: ..., toZoneId: 'command-$viewerId')`, and wires
  `onSendHome` to the same move.

**A commander is not the only thing that belongs in a command zone.** Emblems
and companions live there too, and the app has no notion of either, so the
corner accepts any card rather than checking. Do not add an `accepts` that
filters on the deck's commander: the player is the one who knows.

- [ ] **Step 4: Run them and watch them pass**

Run the three files. Expected: PASS.

- [ ] **Step 5: Run everything**

Run: `flutter test && flutter analyze`
Expected: PASS and `No issues found!`, WARNING count 0.

- [ ] **Step 6: Probe**

Make `CommandSlot`'s target ignore the drop. The slot case and the screen case
must both fail, and say on which assertion. Then remove the `hasCommandZone`
guard on the viewer button: the case about a table with no command zone must
fail. Edit each back by hand and rerun.

- [ ] **Step 7: Commit**

```bash
git add lib/features/play lib/ui/organisms/card_viewer.dart test/features test/ui
git commit -m "Send the commander home, by hand or from the big view"
```

---

## What running it found, after it was written

Three things nothing in the suite could have caught, all fixed in `6bb079d`.

**The viewer's action row did not fit a phone.** It overflowed by 152 points
at 390 wide, and by 141 before this plan added a button to it. Every case in
that file runs at the default 800, where it has always fitted. It is a `Wrap`
now, and a case at phone width fails if it goes back to a `Row`.

**The screen's half of the viewer wiring was unpinned.** `hasCommandZone:
false` left the whole suite green. It could not be tested because the screen
refuses to open the big view for a card with no printing, and the pod harness
runs with no catalog. The harness takes an optional in memory one now, off for
every other case.

**The shuffle case compared the top card**, which collides at 1/53, measured
at 1.904% over two hundred thousand shuffles. It compares the whole order now.

## What this plan deliberately leaves out

- **Dropping on a graveyard or an exile.** `CardDropTarget` makes it a few
  lines each and there is no screen room decided for them yet.
- **Dragging onto somebody else's mat.** It needs an answer to what that even
  means, which is a rules question and the referee's chair is still empty.
- **A Pokemon card back.** The app has no Pokemon catalog and no source that
  serves one, so the back arrives with the catalog.
