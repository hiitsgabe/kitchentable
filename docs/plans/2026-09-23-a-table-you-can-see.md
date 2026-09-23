# A table you can see, implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The whole battlefield fits the window instead of running off the
bottom, the deck and the commander are the size of the cards beside them, and
the graveyard is a pile you can throw a card into and look inside.

**Architecture:** One number causes most of this. The mat is a fixed 640 by 380
and the board scales it by width alone, so on a wide window the mat is taller
than the screen while the deck and the commander stay pinned at a fixed point
size. The mat's scale becomes the table's scale, and everything on the table
reads it.

**Tech Stack:** Flutter 3.47.5, Dart 3.13.4, flutter_riverpod 3.4.3.

---

## What the screenshot showed, measured

The player sent a 1917 point window on 2026 09 23 with two cards on the board,
one of them cut in half at the bottom edge.

`cursor_board.dart` sizes the mat as `scale = constraints.maxWidth /
matSize.width`, then `height: matSize.height * scale`. With `matSize` at 640 by
380:

| | |
|---|---|
| mat scale | 1917 / 640 = **2.995** |
| a card on the board | 90 * 2.995 = **270 pt** |
| the mat's height | 380 * 2.995 = **1138 pt** |
| the board's viewport | about **550 pt** |
| so you can see | **48%** of your own battlefield |
| the deck | `m.scaled(46) * cardScale` = **46 pt** |
| the commander | `m.scaled(52)` = **52 pt** |

So the deck is **5.9 times smaller** than a card lying next to it, and half the
mat is below the fold. It does scroll, `_pile` is already inside a
`SingleChildScrollView`, but a card parked below the fold is invisible with no
hint that there is a fold, which is indistinguishable from the card being cut
off.

**The fix is not to make the mat scroll better.** It is that the mat should not
be taller than the space it has. Scale by whichever of width or height runs out
first, and the whole board fits with nothing clipped. A wide window then has
room to spare at the sides, which is what a real table looks like.

## Why the hover has to go from the board

The player asked for hover to stop enlarging cards on the battlefield and to
keep press and hold. That is right and the numbers say why: a board card is
270 points already, so a 3.2x preview of it is both unreadable and pointless.
Hover earns its place where cards are drawn small, which is the hand, a
opponent's band and the rows in the deck sheet.

---

## Task 1: The whole board fits

**Files:**
- Modify: `lib/features/play/widgets/cursor_board.dart`
- Test: `test/features/cursor_board_test.dart`

- [ ] **Step 1: Write the failing test**

Append to `test/features/cursor_board_test.dart`:

```dart
  testWidgets('the mat fits the window rather than running off the bottom',
      (tester) async {
    tester.view.physicalSize = const Size(1900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host());
    await tester.pump();

    final mat = tester.getSize(find.byKey(const Key('mat-battlefield-s1')));
    final board = tester.getSize(find.byType(CursorBoard));

    // Scaled by width alone, a 640 by 380 mat on a 1900 point window is 1128
    // tall, which is more than the window. Half the battlefield was below the
    // fold and a card parked there looked cut off rather than scrolled away.
    expect(mat.height, lessThanOrEqualTo(board.height));
    // Not only that it fits. A `Center` passes `constraints.loosen()` to its
    // child, so the SizedBox is clamped to the box it sits in and the line
    // above is structurally true in the fill branch whatever the arithmetic
    // does. Height is what runs out on this window, so the mat has to hand
    // the width back: 1261 across, not 1900.
    expect(mat.width, lessThan(board.width));
  });

  testWidgets('a narrow window still uses the width it has', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host());
    await tester.pump();

    final mat = tester.getSize(find.byKey(const Key('mat-battlefield-s1')));
    final board = tester.getSize(find.byType(CursorBoard));

    // Tall and narrow: width is what runs out, so the mat takes all of it and
    // the height follows the shape. Nothing is wasted sideways.
    expect(mat.width, closeTo(board.width, 1));
  });

  testWidgets('the mat keeps its shape whichever way round the window is',
      (tester) async {
    for (final window in [const Size(1900, 800), const Size(390, 1200)]) {
      tester.view.physicalSize = window;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host());
      await tester.pump();

      final mat = tester.getSize(find.byKey(const Key('mat-battlefield-s1')));

      // The shape is what makes a drop position mean the same thing on a
      // phone and on a television, so it is not negotiable, only the scale is.
      expect(mat.width / mat.height,
          closeTo(matSize.width / matSize.height, 0.01),
          reason: 'the mat is the wrong shape at $window');
    }
  });
```

The file needs `import 'package:kitchentable/features/play/renderers/mat_layout.dart';`
for `matSize`.

- [ ] **Step 2: Run them and watch them fail**

Run: `flutter test test/features/cursor_board_test.dart`
Expected: the first case FAILS with the mat's height above the board's. The
other two pass already.

- [ ] **Step 3: Scale by whichever runs out first**

In `lib/features/play/widgets/cursor_board.dart`, the `LayoutBuilder` inside
`_pile`:

```dart
          LayoutBuilder(
            builder: (context, constraints) {
              // The mat keeps its shape whatever the window does, so a drag on
              // a phone and the same drag on a television land on the same
              // normalized spot. Only the scale moves.
              //
              // Scaled by width alone it was 1138 points tall on a 1917 point
              // window, against a viewport of about 550: half your own
              // battlefield was below the fold, and a card parked there looked
              // cut off rather than scrolled away. Whichever of the two runs
              // out first decides.
              final scale = math.min(
                constraints.maxWidth / matSize.width,
                constraints.maxHeight / matSize.height,
              );
              final size = matSize * scale;

              return Center(
                child: SizedBox(
                  width: size.width,
                  height: size.height,
```

`constraints.maxHeight` is infinite inside the `SingleChildScrollView` that
wraps `_pile`, and `math.min` of anything and infinity is the anything, so
this changes nothing until that scroll view is dealt with.

**Taking the scroll view out is not enough**, and the pile count is not the
axis this turns on. A `Column` hands its children an unbounded main axis too,
so two `Expanded`s are needed, one around each pile at the board level and one
inside `_pile` around the mat. And two piles do not each need the window: each
takes a share, each mat is scaled to its own share, and both are whole. A
smaller mat is the same shape, and the shape is what a drop position means.

**The scroll view cannot go entirely**, and this is the part worth knowing.
Forcing the pile's inner `Column` to a share height overflows on a phone in a
pod: the board is handed about **28 points of height out of 844**, and the
label, its gap and the pile's bottom gap come to 32, so there is nothing left
for a mat at all. The scroll view was hiding that: the mat drew 212 points
tall inside a 28 point window, which is this plan's bug in its worst form. The
rest of the budget went on the bands, the hand sheet and the two bars, so the
squeeze is the screen's vertical budget and not the mat's arithmetic.

So the board fills when it has the room and scrolls when it does not, on an
exact test rather than a taste threshold: `share <= chrome`, where `chrome` is
the label box plus the two gaps. In the scroll branch `maxHeight` is infinite
and `math.min` picks the width term by itself, so it is one expression rather
than two branches of it. Give the label a fixed height box so `chrome` is a
number the widget knows before laying anything out.

Add `import 'dart:math' as math;`.

- [ ] **Step 4: Run them and watch them pass**

Run: `flutter test test/features/cursor_board_test.dart`
Expected: PASS, all cases.

Then `flutter test`. Several existing cases compute positions from the mat's
size, and the mat is now a different size on the default 800 by 600 surface.
**Report every case that moved with its numbers before changing anything.**
The drop cases assert normalized values, which are scale independent by
construction, so they should not move; if one does, that is a finding.

- [ ] **Step 5: Probe**

Change `math.min` to `math.max`. It must fail on the width line of the first
case and on the shape case, both by value.

**Not on the first case's height line**, which cannot fail: `Center` clamps
the child to the box, so that line is structurally true in the fill branch. It
still earns its place, because it is what caught the height going unbounded at
Step 2, but it is not what kills this mutation.

Then drop the `Center`. **It is load bearing, not decoration.** `Expanded`
gives the `LayoutBuilder` a tight height which it passes straight to the
`SizedBox`, so without `Center` the mat is forced to fill and the shape goes.
The shape case fails at 390 by 1200 with a wrong value; at 1900 by 800 the
forced height happens to be the height `min` picked anyway, so it is right
there by coincidence. That is why the shape case visits two windows, and it
does not need a third case of its own. Edit each back by hand, never with
`git checkout`, and rerun.

- [ ] **Step 6: Commit**

```bash
git add lib/features/play/widgets/cursor_board.dart \
        test/features/cursor_board_test.dart
git commit -m "Fit the whole battlefield in the window"
```

---

## Task 2: The deck and the commander are the size of cards

**Files:**
- Modify: `lib/features/play/play_screen.dart`
- Modify: `lib/features/play/renderers/mat_layout.dart`
- Modify: `lib/features/play/widgets/cursor_board.dart`
- Modify: `lib/features/play/widgets/library_stack.dart`
- Test: `test/features/play_screen_test.dart`

### Where they go, and why not in the column

The obvious answer is to keep the deck and the corner above and below the mat
and size them from the mat's scale. **It does not have an answer in one pass.**
A bigger deck leaves the board less height, which makes the mat smaller, which
makes the deck smaller: a fixed point. `Column` lays its non flex children out
before the `Expanded`, so no `LayoutBuilder` closes it in one frame, and a
callback oscillates to the answer over about ten frames.

Put them **beside** the mat instead, in the horizontal slack Task 1 created:
on a 1900 by 900 window the mat is 1261 wide in an 1868 wide board. Then they
take only width, and the width branch solves in closed form, because a card of
width `w` costs `w` plus its own furniture out of the row. Measured after:

```
Size(1900.0, 900.0)  card=151.105  deck=151.105  cmd=151.105
Size(390.0, 844.0)   card=38.85    deck=40.54    cmd=40.54
```

Exact on a wide window; about 4% apart on a phone, in the deck's favour,
because the deck's count row is wider than the pile when the card is small, so
the column is 65.5 wide where the arithmetic assumed 59.7. Forcing the column
narrower crushes the count row (`RenderFlex overflowed by 5.8 pixels`), so the
column keeps its natural width and the estimate costs the board about a
percent. That is not the six times out this task exists to fix.

- [ ] **Step 1: Write the failing test**

Append to `test/features/play_screen_test.dart`:

```dart
  testWidgets('the deck and the commander are the size of the cards',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = await _seatedPod(tester, ['you'],
        window: const Size(1900, 900), withCommander: true);
    final play = container.read(playProvider.notifier);
    final card = container.read(playProvider)!.zone('hand-s1')!.cards.first;

    play.run(MoveCard(cardId: card.id, toZoneId: 'battlefield-s1'));
    await tester.pumpAndSettle();

    // 1900 points opens the free canvas, which draws no deck and no corner at
    // all, so this has to be the bands. One button.
    await tester.tap(find.byKey(const Key('switch-renderer')));
    await tester.pumpAndSettle();

    // Named by owner. `find.byType(TableCard).first` is the commander, since
    // CommandSlot draws one and comes first in the column, so the plan's
    // first draft compared the deck against the corner.
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
    final corner = tester
        .getSize(find.descendant(
          of: find.byType(CommandSlot),
          matching: find.byType(TableCard),
        ))
        .width;

    // Both sides. `greaterThan` alone passes a deck that is twice too big,
    // which is the failure this arithmetic can actually make: sizing from the
    // whole seat column instead of the row put it at 186 against a 99 card.
    expect(deck, greaterThan(onBoard * 0.6),
        reason: 'the deck is a pile of these cards, not a thumbnail');
    expect(deck, lessThan(onBoard * 1.4),
        reason: 'the deck is a pile of these cards, not a monument');
    expect(corner, greaterThan(onBoard * 0.6),
        reason: 'the commander is a card, not a stamp');
  });
```

**Measure the pile's top `CardBack`, not the `library-stack` box.** The box is
the card plus its leaves, 65.2 against a card of 46, which already clears
`onBoard * 0.6` once Task 1 has shrunk the board. The card is the number this
task is about.

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/play_screen_test.dart`
Expected: FAIL on the deck at 46 against a card of about 99.

- [ ] **Step 3: One card size, published**

Move `_cardOnMat` out of the two files that each have a copy into
`mat_layout.dart` as `cardOnMat`, and add:

```dart
/// How much bigger or smaller than a mat unit, for a box this size.
///
/// Whichever of width and height runs out first, so the whole mat fits.
double matScaleFor(Size box) => math.min(
      box.width / matSize.width,
      box.height / matSize.height,
    );
```

Then give `CursorBoard` a static saying what scale it will use in a given box,
and `LibraryStack` one saying how far past a card its pile reaches, so the
screen can lay the row out without reaching inside either widget:

```dart
  static double scaleFor(Size box) => ...;
  static double spreadFor(double cardWidth) => ...;
```

The screen wraps the row in a `LayoutBuilder`, subtracts the deck's and the
corner's furniture from the width, and gives the rest to the board. The row
scrolls rather than overflowing, for the same phone squeeze Task 1 found.

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test && flutter analyze`
Expected: PASS and `No issues found!`.

- [ ] **Step 5: Probe**

**`matScaleFor` returning 1 does not fail this case**, and that is not a
weakness: the board and the deck read the same function, so forcing it moves
both together and the ratio is untouched. It is caught, by Task 1's shape
case. Three that do aim here:

- the deck back at its fixed point size: fails on the first assertion;
- the corner back at `m.scaled(52)`: fails on the third;
- `math.min` to `math.max` in the card sum: fails on the second, which is why
  both bounds are asserted.

Say which assertion each time, with its line. Edit each back by hand and
rerun.

- [ ] **Step 6: Commit**

```bash
git add lib/features/play test/features/play_screen_test.dart
git commit -m "Draw the deck and the commander at card size"
```

---

## Task 3: Hover only where cards are small

**Files:**
- Modify: `lib/features/play/widgets/table_card.dart`
- Modify: callers
- Test: `test/features/hover_card_test.dart`, `test/features/cursor_board_test.dart`

- [ ] **Step 1: Write the failing test**

Append to `test/features/cursor_board_test.dart`:

```dart
  testWidgets('a card on the battlefield does not grow under the pointer',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await tester.pump();

    await mouse.moveTo(tester.getCenter(find.byType(TableCard).first));
    await tester.pumpAndSettle();

    // A card on the board is already drawn big, so a preview of it is both
    // unreadable and in the way while you are dragging. Press and hold still
    // opens the real thing.
    expect(find.byKey(const Key('hover-preview')), findsNothing);
  });
```

and to `test/features/hand_sheet_test.dart`:

```dart
  testWidgets('a card in hand does grow under the pointer', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await tester.pump();

    await mouse.moveTo(tester.getCenter(find.byType(TableCard).first));
    await tester.pumpAndSettle();

    // The hand draws at 64 points, where you cannot read a word.
    expect(find.byKey(const Key('hover-preview')), findsOneWidget);
  });
```

Both files need `import 'package:flutter/gestures.dart';`. The hand case needs
a printing to preview, so give its `_host` a `printings` map with an entry for
the first card, following `hover_card_test.dart`.

- [ ] **Step 2: Run them and watch them fail**

Run: `flutter test test/features/cursor_board_test.dart test/features/hand_sheet_test.dart`
Expected: the board case FAILS with a preview found. The hand case may also
fail, for the printings reason rather than the behaviour: say which.

- [ ] **Step 3: Make it a choice**

`TableCard` wraps everything in `HoverCard` today. Give it
`bool hoverPreview = true` and pass `false` from `cursor_board.dart` and from
`free_canvas.dart`. The hand, the seat bands and the deck sheet keep it.

Default true or false is a real decision: **default true**, so a new caller
drawing small cards gets the help, and the two places that draw big ones opt
out and say why in a comment.

- [ ] **Step 4: Run everything**

Run: `flutter test && flutter analyze`
Expected: PASS and `No issues found!`, WARNING and Warning both 0.

- [ ] **Step 5: Probe**

Make `hoverPreview` ignored. The board case must fail on the preview being
found. Then default it to false: the hand case must fail. Say which assertion
each time. Edit back by hand and rerun.

- [ ] **Step 6: Commit**

```bash
git add lib/features/play test/features
git commit -m "Stop previewing cards that are already big"
```

---

## Task 4: Your deck is on the table you are looking at

The player opened the free canvas and asked where the deck went. It was never
there: `FreeCanvas` draws mats and the cards on them and nothing else, so the
deck, the commander and the graveyard exist only in the bands. Task 2 sized
them for the bands and left the canvas untouched.

They go **on** the mat, in mat units, so they pan and zoom with everything
else. That is what they are: objects on your side of the table, not chrome
around it.

**Files:**
- Modify: `lib/features/play/renderers/free_canvas.dart`
- Modify: `lib/features/play/play_screen.dart`
- Test: `test/features/free_canvas_test.dart`

- [ ] **Step 1: Write the failing test**

Append to `test/features/free_canvas_test.dart`:

```dart
  testWidgets('your own deck is on the table', (tester) async {
    await tester.pumpWidget(_host(
      [_seat('s1'), _seat('s2')],
      libraryCount: 53,
    ));
    await tester.pump();

    expect(find.byKey(const Key('canvas-library-s1')), findsOneWidget);
    expect(find.text('53'), findsOneWidget);
  });

  testWidgets('nobody else s deck is', (tester) async {
    await tester.pumpWidget(_host(
      [_seat('s1'), _seat('s2')],
      libraryCount: 53,
    ));
    await tester.pump();

    // How many cards somebody else has left is public at a real table, but
    // their pile is theirs and drawing it here would mean drawing a control
    // that does nothing. The bands already say the number.
    expect(find.byKey(const Key('canvas-library-s2')), findsNothing);
  });

  testWidgets('a spectator sees nobody s deck', (tester) async {
    await tester.pumpWidget(_host(
      [_seat('s1'), _seat('s2')],
      viewer: '',
      libraryCount: 53,
    ));
    await tester.pump();

    expect(find.byKey(const Key('canvas-library-s1')), findsNothing);
    expect(find.byKey(const Key('canvas-library-s2')), findsNothing);
  });

  testWidgets('tapping it draws', (tester) async {
    var drew = 0;
    await tester.pumpWidget(_host(
      [_seat('s1')],
      libraryCount: 53,
      onDraw: () => drew++,
    ));
    await tester.pump();

    await tester.tap(find.byKey(const Key('library-draw')));
    await tester.pump();

    expect(drew, 1);
  });

  testWidgets('the whole table is on screen when it opens', (tester) async {
    tester.view.physicalSize = const Size(1294, 986);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host([_seat('s1'), _seat('s2'), _seat('s3')]));
    await tester.pumpAndSettle();

    final viewport = tester.getRect(find.byType(FreeCanvas));
    for (final id in ['s1', 's2', 's3']) {
      final mat = tester.getRect(find.byKey(Key('mat-$id')));
      // An InteractiveViewer with constrained false starts at one to one with
      // the surface pinned to the top left, so a three seat table opened with
      // two of its mats off the screen and the player had to find them.
      expect(viewport.contains(mat.topLeft), isTrue, reason: 'mat $id starts off screen');
      expect(viewport.contains(mat.bottomRight), isTrue, reason: 'mat $id runs off screen');
    }
  });
```

`_host` gains `int libraryCount = 0`, `VoidCallback? onDraw` and
`VoidCallback? onWorkDeck`, all passed through.

- [ ] **Step 2: Run them and watch them fail**

Run: `flutter test test/features/free_canvas_test.dart`
Expected: FAIL to compile on the new `_host` arguments, then on the missing
keys. The fit case fails on a mat running off the screen.

- [ ] **Step 3: Draw them, and open fitted**

`FreeCanvas` gains `libraryCount`, `commandCards`, `onDraw` and `onWorkDeck`,
and `_Mat` draws a `LibraryStack` and a `CommandSlot` when `isViewer`, in mat
coordinates: the corner at the mat's top right, the pile below it, both at
`cardOnMat.width` so they are the size of the cards beside them. Key the pile
`canvas-library-${seat.seatId}` around whatever `LibraryStack` already keys
inside itself, so both this task's cases and the existing `library-draw` tap
keep working.

The cards on a battlefield flow from the top left and a player drags them
where they like, so nothing reserves that corner. A real table has the same
problem and the same answer.

For the fit, give the `InteractiveViewer` a `TransformationController` and set
it once from a `LayoutBuilder`, after the first layout:

```dart
  /// Fits the whole table in the window the first time it is laid out.
  ///
  /// `InteractiveViewer` with `constrained: false` starts at one to one with
  /// the surface pinned to the top left, so a table of three opened with two
  /// of its mats past the edge and nothing saying so. Only the first time:
  /// after that the view is the player's.
  void _fitOnce(Size viewport, Size surface) {
    if (_fitted) return;
    _fitted = true;
    // A matGap off each axis first. Without it a three seat surface of 1320
    // by 800 in a 1294 by 986 window scales to exactly 1294 / 1320 and the
    // far mat's right edge lands on 1294.0, which `Rect.contains` excludes
    // because it tests `dx < right`. It also stops the table being drawn
    // flush against two window edges.
    final scale = math.min(
      (viewport.width - matGap) / surface.width,
      (viewport.height - matGap) / surface.height,
    );
    // `Matrix4..scale(double)` is deprecated and takes analyze off clean.
    _view.value = Matrix4.identity()..scaleByDouble(scale, scale, scale, 1);
  }
```

Call it from a post frame callback, not during build: setting a
`TransformationController` inside `build` notifies its listeners mid layout.

- [ ] **Step 4: Run them and watch them pass**

Run: `flutter test && flutter analyze`
Expected: PASS and `No issues found!`, WARNING and Warning both 0.

The existing canvas cases assert positions and drops. The fit changes the
scale the surface is drawn at, so a `getRect` on a card now reports a scaled
rect. **Report every case that moved with its numbers before changing
anything.** The drop cases report normalized values and should not move.

**One of them breaks anyway, and not on its assertion.** `a drop on a zoomed
table is still in mat units` pinches at two hardcoded screen points. The fit
scales a one seat surface *up* to 1.1875 in an 800 by 600 window, which moves
the card to `Rect.fromLTRB(327.8, 171.2, 434.6, 320.5)`, so the left finger at
(340, 300) now lands on the `Draggable`. The card takes that pointer,
`InteractiveViewer` is left holding one, a one finger pinch has a span of
zero, and it asserts `scale != 0.0` before the case's own assertion runs.
Derive the two fingers from the card's own rect instead, either side of it and
never on it, which pinches about the card's centre and keeps it still while
the table opens around it.

While you are in that case: its `expect(zoom, greaterThan(1.2))` is 0.0125
from passing with no pinch at all, since the fit alone is 1.1875. Read the
scale before the pinch and ask for a third more after, so it cannot go vacuous
the next time a seat is added.

**Four cases do not move, and the reason is a small lie worth knowing.**
`every seat gets a mat`, `a battlefield is drawn for everybody`, `no hand is
on the canvas` and `a card that says where it is goes there` never pump a
second frame, and setting the controller only marks the viewer for rebuild, so
those four measure an unfitted canvas: a state the app no longer ever shows.
Leave them; re-measuring four sets of positions belongs in its own change.

- [ ] **Step 5: Probe**

Make `isViewer` always false where the pile is drawn. The first case must fail
on the key, which is a finder and so liveness only: follow it by drawing the
pile for every seat, which must fail the second case on a wrong finder count.

Then make `_fitOnce` return immediately. The fit case must fail on a mat
running off the screen, and say which of the six assertions.

Say which assertion each time, with its line. Edit each back by hand, never
with `git checkout`, and rerun.

- [ ] **Step 6: Commit**

```bash
git add lib/features/play test/features/free_canvas_test.dart
git commit -m "Put your deck on the table in the wide view too"
```

---

## Task 5: The graveyard

Two halves, and they are the two the player asked for: how a card gets there,
and how you look inside.

The zone already exists and is already public. What is missing is a pile to
throw a card at and a sheet to read it. Both are shapes this app already has:
`LibraryStack` and `DeckSheet`.

**Files:**
- Create: `lib/features/play/widgets/pile_sheet.dart`
- Create: `lib/features/play/widgets/sheet_parts.dart` (what the two sheets share)
- Modify: `lib/features/play/widgets/deck_sheet.dart` (it gives the shared parts up)
- Modify: `lib/features/play/widgets/library_stack.dart`
- Modify: `lib/features/play/look_at_top.dart` (`arrange` gains `fromLibrary`)
- Modify: `lib/features/play/play_screen.dart`
- Modify: `lib/features/play/renderers/free_canvas.dart`
- Test: `test/features/pile_sheet_test.dart`, `test/features/play_screen_test.dart`, `test/features/look_at_top_test.dart`

The canvas gets no case in the steps below and needs one, at a wide window,
or the canvas half of Step 6 ships untested. It needs
`SharedPreferences.setMockInitialValues({})`, because a case above it taps the
renderer button and the stored choice beats the width.

- [ ] **Step 1: Write the failing test for looking inside**

Create `test/features/pile_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/look_at_top.dart';
import 'package:kitchentable/features/play/widgets/pile_sheet.dart';
import 'package:kitchentable/table/model/card_instance.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

List<CardInstance> _cards(int n) => [
      for (var i = 0; i < n; i++)
        CardInstance(id: 'c$i', oracleId: 'card$i'),
    ];

Widget _host({
  List<CardInstance> cards = const [],
  void Function(List<Placement>)? onArrange,
}) =>
    MaterialApp(
      home: Scaffold(
        body: PileSheet(
          metrics: Metrics.of(DeviceClass.handheld),
          label: 'Graveyard',
          cards: cards,
          printings: const {},
          onArrange: onArrange ?? (_) {},
        ),
      ),
    );

void main() {
  testWidgets('everything in the pile is there to read', (tester) async {
    await tester.pumpWidget(_host(cards: _cards(4)));
    await tester.pump();

    // A graveyard is public and always has been: unlike the deck, opening
    // this reveals nothing that was hidden, so there is no first step asking
    // whether you are sure.
    for (var i = 0; i < 4; i++) {
      expect(find.byKey(Key('pile-card-c$i')), findsOneWidget);
    }
  });

  testWidgets('an empty pile says so', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    expect(find.textContaining('Nothing'), findsOneWidget);
  });

  testWidgets('a card can be taken back out', (tester) async {
    List<Placement>? arranged;
    await tester.pumpWidget(
      _host(cards: _cards(3), onArrange: (p) => arranged = p),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('hand-c1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('pile-done')));
    await tester.pumpAndSettle();

    // Only what was moved. A graveyard is not ordered in any way anybody
    // cares about, so a card nobody touched has nowhere to be put back to.
    expect(arranged, [(cardId: 'c1', to: Landing.hand)]);
  });

  testWidgets('nothing chosen reports nothing', (tester) async {
    List<Placement>? arranged;
    await tester.pumpWidget(
      _host(cards: _cards(3), onArrange: (p) => arranged = p),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('pile-done')));
    await tester.pumpAndSettle();

    expect(arranged, isEmpty);
  });

  testWidgets('a card can go to the top of the deck or to the bottom',
      (tester) async {
    List<Placement>? arranged;
    await tester.pumpWidget(
      _host(cards: _cards(2), onArrange: (p) => arranged = p),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('top-c0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('bottom-c1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('pile-done')));
    await tester.pumpAndSettle();

    expect(arranged, hasLength(2));
    expect(arranged, contains((cardId: 'c0', to: Landing.top)));
    expect(arranged, contains((cardId: 'c1', to: Landing.bottom)));
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/pile_sheet_test.dart`
Expected: FAIL, `Error when reading
'lib/features/play/widgets/pile_sheet.dart'`.

- [ ] **Step 3: Write the sheet**

`PileSheet` is `DeckSheet`'s looking stage with no stages in front of it, so
read `deck_sheet.dart` first and follow its idioms rather than inventing new
ones. The differences, all of them because a graveyard is not a library:

- **It opens on the cards.** There is nothing hidden to reveal.
- **There is no shuffle.**
- **There is no default destination.** In the deck sheet every card is going
  back on top unless you say otherwise; here a card nobody touched stays where
  it is, so `onArrange` reports only what was moved.

  **`arrange` does not handle this already, whatever an earlier draft of this
  sentence said.** Its bottom index is `librarySize - gone - 1`, and the minus
  one is there because `_move` lifts a card out of the library before putting
  it back. A graveyard card was never in the library, so the pile is one
  longer when it lands and bottoming it puts it second from the bottom. Give
  `arrange` a `fromLibrary` and a case: no existing case covers it.
- **The destinations are `hand`, `top` and `bottom`**, which is enough for
  regrowth, for a tutor that puts a card back, and for the two thirds of
  Magic's graveyard effects that do one of those.

Take whatever the two sheets genuinely share into one place rather than
copying the row: two sheets that drift apart is how the deck sheet's four
destination chips and this one's three stop looking alike.

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/features/pile_sheet_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Write the failing test for the pile on the table**

Append to `test/features/play_screen_test.dart`:

```dart
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
```

- [ ] **Step 6: Put the pile on the table**

`LibraryStack` already draws a pile that shrinks, takes a tap and takes a drop
target around it. Give it what it needs to be either pile: a `label`, a
`faceUp` that draws the top card's art instead of a back, and a key from its
caller. Do not fork it.

A graveyard is face up and ordered, so the top card is the last one in. An
empty graveyard still draws its outline, the way the command corner does: a
corner that appears and disappears reads as a bug, and it is also the thing
you are trying to drop a card on.

Wire it in both renderers, beside the deck in the bands and on the mat in the
canvas.

- [ ] **Step 7: Run everything**

Run: `flutter test && flutter analyze`
Expected: PASS and `No issues found!`, WARNING and Warning both 0.

- [ ] **Step 8: Probe**

Make the graveyard's drop target ignore the drop: the first screen case fails
on the graveyard not containing the card. Then make `onArrange` report every
card rather than only the moved ones: the fourth sheet case fails on
`isEmpty`. Then draw the graveyard face down. **Nothing fails**, because the only cases
with a card in the graveyard run without a catalog, so `_printings` is empty
and both ends draw a card back whatever `faceUp` says: the flag is
unobservable from the suite. Face up is the whole difference between this pile
and the deck beside it, so it earns a case, with a catalog.

Then draw the other end of the pile. `MoveCard` with no `at` reaches
`Zone.add`, which inserts at nought, so the newest card is `cards.first`,
which is what `Zone.top` returns for an ordered zone. The trap resolves in
`Zone.top`'s favour and a case is what stops somebody tidying it to `.last`.

Say which assertion each time, with its line. Edit each back by hand and
rerun.

- [ ] **Step 9: Commit**

```bash
git add lib/features/play test/features
git commit -m "Throw a card in the graveyard, and go back in after it"
```

---

## Task 6: Tokens

`CreateToken` has existed since plan 2 and nothing has ever constructed it.
The reducer is three lines and correct: it mints a `CardInstance` with an id
the caller chose, so replaying a game gives the same game.

What is missing is where a token's **face** comes from. A `CardInstance`
carries an `oracleId` and nothing else, so a token whose oracle id is not in
the catalog draws as a blank back with no name on it, which is worse than no
token at all.

So a token is made **out of a card**, two ways, and neither invents anything:

- **Copy what you are looking at.** The big view gets an action. Most tokens
  in Magic are a copy of something already on the table, and this needs no
  search at all.
- **Find one.** A search over the catalog, the same `searchByName` the deck
  builder uses. Scryfall's bulk data carries real token cards, so `Goblin` and
  `Treasure` are findable if the player imported them; if not, the search says
  nothing found rather than minting a faceless card.

**Files:**
- Create: `lib/features/play/widgets/token_sheet.dart`
- Modify: `lib/ui/organisms/card_viewer.dart`
- Modify: `lib/features/play/play_screen.dart`
- Test: `test/features/token_sheet_test.dart`, `test/ui/card_viewer_actions_test.dart`, `test/features/play_screen_test.dart`

- [ ] **Step 1: Write the failing test for copying**

Append to `test/ui/card_viewer_actions_test.dart`:

```dart
  testWidgets('a card on the table can be copied', (tester) async {
    CardAction? acted;
    await tester.pumpWidget(_host(
      instance: const CardInstance(id: 'a', oracleId: 'o'),
      onAct: (a) => acted = a,
    ));
    await tester.pump();

    await tester.tap(find.byKey(const Key('act-copy')));
    await tester.pump();

    expect(acted, CardAction.copy);
  });

  testWidgets('a printing with no card behind it cannot be copied',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    // The deck builder opens this on a printing that is on no table. There is
    // nothing to copy onto a battlefield that does not exist.
    expect(find.byKey(const Key('act-copy')), findsNothing);
  });
```

Append to `test/features/play_screen_test.dart`:

```dart
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
```

- [ ] **Step 2: Run them and watch them fail**

Run: `flutter test test/ui/card_viewer_actions_test.dart test/features/play_screen_test.dart`
Expected: FAIL to compile on `CardAction.copy`, then the screen case on the
board having one card.

- [ ] **Step 3: Copy**

`CardAction` gains `copy`. `CardViewer` shows `act-copy` when `instance` is
not null, beside the others. The screen runs:

```dart
      case CardAction.copy:
        final found = ref.read(playProvider)?.locate(instance.id);
        if (found == null) return;
        play.run(CreateToken(
          zoneId: found.zone.id,
          oracleId: instance.oracleId,
          // Minted here and not in the reducer, which is what keeps `apply` a
          // function: plan 3 replays these and has to get the same table.
          cardId: 'token-${DateTime.now().microsecondsSinceEpoch}',
        ));
```

**That id is not good enough and the next task should know it.** Two copies
made inside the same microsecond collide, and on the web
`microsecondsSinceEpoch` is a double with millisecond resolution, so two
copies in the same millisecond collide for certain. Use `freshSeed()`, which
already mixes a random into the clock and is already the app's answer to this
exact question.

- [ ] **Step 4: Run them and watch them pass**

Run: `flutter test && flutter analyze`
Expected: PASS and `No issues found!`.

- [ ] **Step 5: Write the failing test for finding one**

Create `test/features/token_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/widgets/token_sheet.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

CatalogCard _card(String name) =>
    CatalogCard(oracleId: name, name: name, typeLine: 'Token', cmc: 0);

Widget _host({
  Future<List<CatalogCard>> Function(String)? search,
  void Function(CatalogCard)? onPick,
}) =>
    MaterialApp(
      home: Scaffold(
        body: TokenSheet(
          metrics: Metrics.of(DeviceClass.handheld),
          search: search ?? (term) async => [_card('Goblin'), _card('Goblin Chieftain')],
          onPick: onPick ?? (_) {},
        ),
      ),
    );

void main() {
  testWidgets('it opens empty, with nothing searched for yet', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    expect(find.byKey(const Key('token-Goblin')), findsNothing);
  });

  testWidgets('typing finds cards', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'gob');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('token-Goblin')), findsOneWidget);
    expect(find.byKey(const Key('token-Goblin Chieftain')), findsOneWidget);
  });

  testWidgets('picking one reports it', (tester) async {
    CatalogCard? picked;
    await tester.pumpWidget(_host(onPick: (c) => picked = c));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'gob');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('token-Goblin')));
    await tester.pumpAndSettle();

    expect(picked?.name, 'Goblin');
  });

  testWidgets('a catalog with nothing in it says so rather than nothing',
      (tester) async {
    await tester.pumpWidget(_host(search: (term) async => []));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'gob');
    await tester.pumpAndSettle();

    // A token whose face is not in the catalog would draw as a blank back
    // with no name, which is worse than no token. Saying so is the honest
    // answer, and the fix is on the sources screen.
    expect(find.textContaining('Nothing'), findsOneWidget);
  });
}
```

- [ ] **Step 6: Write the sheet, and a way in**

`TokenSheet` is a text field and a list, following the deck builder's search
screen for its idiom rather than inventing one: read
`lib/features/decks/add_cards_screen.dart` first.

The way in is a control keyed `make-token` that opens it, and the screen runs
`CreateToken` onto the viewer's battlefield with the picked card's oracle id.

**Put it in both renderers.** The column beside the mat belongs to the bands,
and the canvas is the default above 720 points, so a control that lives only
there is missing from the view most people open. Build it once in the screen
and hand it to `FreeCanvas` as a widget, the way the graveyard pile already
arrives, and add a case at a wide window: without one the canvas half ships
untested, which is what happened.

The sheet is **not debounced**, unlike `add_cards_screen.dart`. It cannot be:
`pumpAndSettle` returns as soon as no frame is scheduled, so a 300 ms `Timer`
never fires and three of its four cases would fail against a debounced sheet.
A token name is typed once and picked rather than browsed, so this is the
right place not to have one, but the constraint came from the cases.

- [ ] **Step 7: Run everything**

Run: `flutter test && flutter analyze`
Expected: PASS and `No issues found!`, WARNING and Warning both 0.

- [ ] **Step 8: Probe**

Make `CreateToken` reuse the copied card's own id rather than a fresh one. The
screen case must fail, and **say which of its three assertions**: `hasLength(2)`
would still pass if the reducer added the card twice under one id, so the one
that matters is the third.

Then make the search eager. **Not by lowering the two letter floor**, which
sits on code the "opens empty" case never reaches, because `onChanged` never
fires when nobody types: that mutation survives and looks like a correct
sheet. Call `widget.search('')` from `initState` instead, and the first sheet
case fails on the assertion it is named for. Say which assertion each time. Edit each back by hand,
never with `git checkout`, and rerun.

- [ ] **Step 9: Commit**

```bash
git add lib/features/play lib/ui/organisms/card_viewer.dart test/features test/ui
git commit -m "Make a token, by copying a card or by finding one"
```

---

## Task 7: Markers

`ChangeCounter` takes any name. The big view hardcodes `+1/+1`, so a
planeswalker's loyalty, a Pokemon's damage and an artifact's charge all have
to be counted as if they were the same thing.

`TableCard` already draws whatever counters a card has, as one pill of the
values joined. That pill is about to be wrong for two kinds at once, since
`{'+1/+1': 2, 'damage': 3}` reads as `+2 +3`.

**Files:**
- Modify: `lib/ui/organisms/card_viewer.dart`
- Modify: `lib/features/play/widgets/table_card.dart`
- Modify: `lib/features/play/play_screen.dart`
- Test: `test/ui/card_viewer_actions_test.dart`, `test/features/table_card_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/features/table_card_test.dart` if it does not exist, and add:

```dart
  testWidgets('two kinds of counter are told apart', (tester) async {
    await tester.pumpWidget(_host(
      const CardInstance(
        id: 'a',
        oracleId: 'o',
        counters: {'+1/+1': 2, 'damage': 3},
      ),
    ));
    await tester.pump();

    // Joined into one pill these read as `+2 +3`, which is a number nobody
    // can act on. A Pokemon takes damage and grows at the same time, and so
    // does a creature with a Wither fight behind it.
    expect(find.textContaining('+2'), findsOneWidget);
    expect(find.textContaining('3'), findsWidgets);
    expect(find.byKey(const Key('counter-+1/+1')), findsOneWidget);
    expect(find.byKey(const Key('counter-damage')), findsOneWidget);
  });
```

Append to `test/ui/card_viewer_actions_test.dart`:

```dart
  testWidgets('the kind of counter is the player s choice', (tester) async {
    final acted = <CardAction>[];
    await tester.pumpWidget(_host(
      instance: const CardInstance(id: 'a', oracleId: 'o'),
      onAct: acted.add,
    ));
    await tester.pump();

    await tester.tap(find.byKey(const Key('kind-loyalty')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('act-counter-up')));
    await tester.pump();

    expect(acted, [CardAction.counterUp]);
  });

  testWidgets('a kind nobody put on the list is offered too', (tester) async {
    await tester.pumpWidget(_host(
      instance: const CardInstance(
        id: 'a',
        oracleId: 'o',
        counters: {'energy': 4},
      ),
    ));
    await tester.pump();

    // `energy` and not `charge`. An earlier draft used `charge`, which is in
    // `counterKinds` below, so the case passed against a viewer that never
    // read the card at all and proved only that the kind was not offered
    // twice. It has to be a kind no list carries.
    expect(find.byKey(const Key('kind-energy')), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('the counter shown is the kind that is chosen', (tester) async {
    await tester.pumpWidget(_host(
      instance: const CardInstance(
        id: 'a',
        oracleId: 'o',
        counters: {'+1/+1': 2, 'damage': 7},
      ),
    ));
    await tester.pump();

    await tester.tap(find.byKey(const Key('kind-damage')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('counter-count')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('counter-count'))).data,
      '7',
    );
  });
```

- [ ] **Step 2: Run them and watch them fail**

Expected: the viewer cases FAIL on the missing `kind-` keys, the card case on
the counters being one pill.

- [ ] **Step 3: Let the player choose**

The viewer keeps a chosen kind, defaulting to `+1/+1`. The kinds offered are a
fixed list plus whatever is already on the card, so a card that arrived
carrying `charge` offers `charge` without anybody having to have thought of
it:

```dart
/// The counters a table puts on cards often enough to be worth a button.
///
/// Not a closed list: whatever is already on the card is offered too, so a
/// card that arrives carrying a kind nobody listed can still be counted. The
/// table has never cared what these are called, which is why they are strings
/// and not an enum, and it is also why Pokemon needs nothing added here.
const counterKinds = ['+1/+1', '-1/-1', 'loyalty', 'charge', 'damage'];
```

`CardAction.counterUp` and `counterDown` do not change; the screen reads the
chosen kind off the viewer. That means `show` returns more than an action:
return a record, or give `CardViewer` an `onCount(String kind, int by)` beside
`onAct` and keep the enum for the rest. **Prefer the second**: the other six
actions carry no argument and widening all of them for one is how an enum
turns into a variant type nobody meant to write.

`TableCard` draws one pill per kind, each keyed `counter-<kind>`, stacked. A
card with four kinds on it will look busy, which is what a card with four
kinds of counter on it looks like on a table.

- [ ] **Step 4: Run everything**

Run: `flutter test && flutter analyze`
Expected: PASS and `No issues found!`.

- [ ] **Step 5: Probe**

Make the chosen kind always `+1/+1`. The third viewer case must fail on the
count being 2 where 7 was expected, which is a wrong value rather than a
finder. Then draw all the counters in one pill again: the card case must fail,
and say which of its four assertions. Edit each back by hand and rerun.

- [ ] **Step 6: Commit**

```bash
git add lib/features/play lib/ui/organisms/card_viewer.dart test/features test/ui
git commit -m "Count the thing you meant to count"
```

---

## Task 8 onward

The dice, written after the tokens and the markers land: three dimensional,
on the deck, d20, d12 and d6. `RollDice` has existed since plan 2 with no
caller, and the reducer already takes the results from the caller so a replay
gives the same roll.
