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

## Task 8: The graveyard leaves the board, and the furniture leaves the mat

The player sent two screenshots of the same three faults.

**The graveyard is drawn twice.** `play_screen.dart` hands `CursorBoard` a
`zones` list of the battlefield and the graveyard, so the board draws a mat
each, stacked. The graveyard is then also a pile in the column beside the mat,
which is the one the player can drop a card onto and open. The mat under the
battlefield is the leftover, and it is the one that has to go.

**That mat is what cuts everything else off.** Two mats share the board's
height, so the column beside them has half the room it should, and the command
corner, the deck and the token button run off the bottom of the screen. The
clipping is not the column's fault.

**On the canvas the furniture is drawn on the mat.** `_Mat._furniture` stacks
the corner, the piles and the token button inside the mat's own rect, so at
any zoom they sit on top of the battlefield and the token button runs off the
bottom edge. The player's words: out of the view, not inside the player view.

So the furniture moves **outside** the mat in both renderers, and the
graveyard moves to the left of it, which is where a graveyard sits at a table
when the library is on the right.

**Files:**
- Modify: `lib/features/play/renderers/mat_layout.dart`
- Modify: `lib/features/play/renderers/free_canvas.dart`
- Modify: `lib/features/play/play_screen.dart`
- Test: `test/features/mat_layout_test.dart`, `test/features/play_screen_test.dart`, `test/features/free_canvas_test.dart`, `test/features/cursor_board_test.dart`

- [ ] **Step 1: Write the failing test for the board**

Append to `test/features/play_screen_test.dart`:

```dart
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

  testWidgets('the graveyard is on the far side from the deck',
      (tester) async {
    final container = await _seatedPod(tester, ['you'], withCommander: true);
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
    final container = await _seatedPod(tester, ['you'],
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
```

The third case needs `SharedPreferences.setMockInitialValues({})` for the same
reason the others that tap the renderer button do.

- [ ] **Step 2: Run them and watch them fail**

Run: `flutter test test/features/play_screen_test.dart`
Expected: the first FAILS on `mat-graveyard-s1` being found, the second on the
graveyard being to the right of the board.

- [ ] **Step 3: Take the graveyard off the board, and split the column**

In `play_screen.dart`, `zones` becomes the battlefield alone.

**This narrows what the D-pad can reach**, and that is a real loss rather than
a tidy up: `BoardCursor` walks the piles the board is given, so a card in the
graveyard was reachable with a shoulder button and now is not. Nothing asserts
it. Say so in your report; the answer is the pile's own sheet, which a D-pad
cannot open either, and that is the follow up.

`_Beside` splits in two. The graveyard goes to a column on the left of the
board and the corner, the deck and the token button stay on the right. The
width arithmetic in the `LayoutBuilder` above takes **two** asides out of the
row now, not one:

```dart
              final room = box.maxWidth - aside * 2 - gap * 2;
```

Read the comment there before editing it: it explains that a card of `w` costs
`w` plus its furniture out of the row, and it is now two lots of that.

- [ ] **Step 4: Run them and watch them pass**

Run: `flutter test && flutter analyze`
Expected: PASS and `No issues found!`.

**Several cases will move.** `cursor_board_test.dart` builds its own zones and
is unaffected, but anything in `play_screen_test.dart` that measures the board
or a card on it sees a narrower board. **Report every case that moved with its
numbers before changing anything.**

- [ ] **Step 5: Write the failing test for the canvas**

Append to `test/features/mat_layout_test.dart`:

```dart
  test('a seat takes more room than its mat', () {
    // The corner, the deck, the graveyard and the token button stand beside
    // the mat and not on it, so a seat's share of the surface is wider than
    // the mat by a strip on each side.
    final station = stationFor(0, 1);
    final mat = matFor(0, 1);

    expect(station.width, greaterThan(mat.width));
    expect(station.height, mat.height);
  });

  test('the mat sits between the two strips', () {
    final station = stationFor(0, 1);
    final mat = matFor(0, 1);

    expect(mat.left, greaterThan(station.left));
    expect(mat.right, lessThan(station.right));
    // Even on both sides, so a table of four does not lean.
    expect(mat.left - station.left, closeTo(station.right - mat.right, 0.01));
  });

  test('the strips are a card wide, with room to breathe', () {
    final station = stationFor(0, 1);
    final mat = matFor(0, 1);

    expect(mat.left - station.left, greaterThan(cardOnMat.width));
  });

  test('the surface holds every station', () {
    for (final count in [1, 2, 3, 4]) {
      final surface = surfaceFor(count);
      for (var i = 0; i < count; i++) {
        final station = stationFor(i, count);
        expect(station.right, lessThanOrEqualTo(surface.width),
            reason: 'station $i of $count runs off the right');
        expect(station.bottom, lessThanOrEqualTo(surface.height),
            reason: 'station $i of $count runs off the bottom');
      }
    }
  });

  test('two stations never overlap', () {
    final stations = [for (var i = 0; i < 4; i++) stationFor(i, 4)];
    for (var i = 0; i < stations.length; i++) {
      for (var j = i + 1; j < stations.length; j++) {
        expect(stations[i].overlaps(stations[j]), isFalse,
            reason: 'station $i overlaps station $j');
      }
    }
  });
```

Append to `test/features/free_canvas_test.dart`:

```dart
  testWidgets('the furniture stands beside the mat, not on it',
      (tester) async {
    await tester.pumpWidget(_host([_seat('s1')], libraryCount: 53));
    await tester.pumpAndSettle();

    final mat = tester.getRect(find.byKey(const Key('mat-s1')));
    final deck = tester.getRect(find.byKey(const Key('canvas-library-s1')));

    // Drawn on the mat it sat over the battlefield at every zoom, and the
    // token button ran off the bottom edge of the mat itself.
    expect(deck.left, greaterThanOrEqualTo(mat.right - 1));
  });
```

- [ ] **Step 6: Give each seat a station**

In `mat_layout.dart`, add the strip and the station, and make `matFor` and
`surfaceFor` read them:

```dart
/// How wide the strip beside a mat is.
///
/// A card, plus the room a pile's own count row and label need around it. The
/// corner, the deck, the graveyard and the token button all stand in one of
/// these rather than on the mat, because drawn on the mat they sit over the
/// battlefield at every zoom.
const matAside = cardOnMat.width + matPadding * 2;

/// A seat's whole share of the surface: the mat, and a strip on each side.
Rect stationFor(int index, int count) { ... }
```

`matFor` returns the mat inside the station, so a drop position is still
normalized against the same box it always was. **`matFor`'s numbers change**,
and `mat_layout_test.dart` asserts several of them, so expect the existing
cases to move and report them.

In `free_canvas.dart`, `_furniture` moves out of the mat's `Stack` and into
`Positioned.fromRect` rects in the station's strips: the graveyard on the
left, the corner and the deck and the token on the right.

- [ ] **Step 7: Run everything**

Run: `flutter test && flutter analyze`
Expected: PASS and `No issues found!`, WARNING and Warning both 0.

- [ ] **Step 8: Probe**

- Put the graveyard back in `zones`: the first screen case must fail on
  `mat-graveyard-s1` being found.
- Take one `aside` back out of the width arithmetic: say what fails. If
  nothing does, the two asides are unpinned and the third screen case should
  be the one catching it, so say whether it earns a tighter assertion.
- Draw the furniture back inside the mat's rect: the canvas case must fail on
  `deck.left`.
- Make `matAside` zero: say which of the station cases fail and on which
  assertion.

Say which assertion each time, with its line. Edit each back by hand, never
with `git checkout`, and rerun.

- [ ] **Step 9: Commit**

```bash
git add lib/features/play test/features
git commit -m "Stand the furniture beside the mat, and stop drawing the graveyard twice"
```

---

## The dice, and what was measured before planning them

The player asked for real tumbling polyhedra on the deck, d20, d12 and d6, and
chose that over a die that turns once and settles. So these are actual solids
with actual faces, projected and culled, not a picture of a die.

No 3D engine. `package:vector_math/vector_math_64.dart` already ships with
Flutter and carries `Vector3` and `Quaternion`, which is all this needs, and a
3D package would be a web asset story and a licence for something that is two
hundred lines of arithmetic.

**Declare it in `pubspec.yaml` anyway.** Flutter re-exports only `Matrix4`, so
the direct import is unavoidable, and `depend_on_referenced_packages` then
costs an info in every file that uses it. Suppressing that lint is the wrong
answer: it is telling the truth, and the day Flutter stops depending on
vector_math the build breaks with no warning. One line in pubspec, not four
`// ignore:` comments.

**The geometry is derived, not typed.** Twenty triangles written out by hand
is twenty chances to transpose an index, and nothing would catch it but the
eye. All four facts below were checked numerically on 2026 09 23 before this
was written:

| | |
|---|---|
| icosahedron vertices, cyclic permutations of `(0, ±1, ±φ)` | **12**, edge exactly **2.0** |
| triangles, being every triple mutually one edge apart | **20** |
| dodecahedron vertices, the centroids of those triangles | **20** |
| pentagons, being the five centroids around each icosahedron vertex | **12**, every one **5** sided |
| those pentagons' planarity | deviation **0.0** |
| those pentagons, wound consistently and convex | **yes** |

**And the rotation convention, which is the one that would have cost a day.**
`Quaternion.axisAngle` turns the **opposite way to the right hand rule**.
Measured: `Quaternion.axisAngle(Vector3(0,0,1), pi/2).rotated(Vector3(1,0,0))`
is `(0, -1, 0)`, not `(0, 1, 0)`. So bringing a face's normal to the camera
takes a **negative** angle:

```
    axisAngle(n.cross(z).normalized(), -acos(n.dot(z))).rotated(n) == (0, 0, 1)
```

exactly, to machine zero. With the positive angle it lands on
`(0.667, 0.667, -0.333)`, which is a die showing the wrong face and looking
almost right, which is worse.

---

## Task 9: The solids

Pure arithmetic, no widgets, no Flutter beyond `vector_math`.

**Files:**
- Create: `lib/features/play/dice/polyhedron.dart`
- Test: `test/features/polyhedron_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/polyhedron_test.dart`:

```dart
// No `dart:math` here: none of these eleven cases says `math.`, and an
// unused import is a warning.
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/dice/polyhedron.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('a d6 is a cube', () {
    final die = Polyhedron.d6;
    expect(die.faces, hasLength(6));
    expect(die.faces.every((f) => f.length == 4), isTrue);
    expect(die.vertices, hasLength(8));
  });

  test('a d20 has twenty triangles on twelve corners', () {
    final die = Polyhedron.d20;
    expect(die.vertices, hasLength(12));
    expect(die.faces, hasLength(20));
    expect(die.faces.every((f) => f.length == 3), isTrue);
  });

  test('a d12 has twelve pentagons on twenty corners', () {
    final die = Polyhedron.d12;
    expect(die.vertices, hasLength(20));
    expect(die.faces, hasLength(12));
    expect(die.faces.every((f) => f.length == 5), isTrue);
  });

  test('every face is flat', () {
    for (final die in [Polyhedron.d6, Polyhedron.d12, Polyhedron.d20]) {
      for (final face in die.faces) {
        final points = [for (final i in face) die.vertices[i]];
        final centre = points.reduce((a, b) => a + b) / points.length.toDouble();
        final normal = die.normalOf(face);
        for (final p in points) {
          expect((p - centre).dot(normal).abs(), lessThan(1e-9),
              reason: 'a face of a ${die.sides} sided die is not flat');
        }
      }
    }
  });

  test('every face looks outwards', () {
    for (final die in [Polyhedron.d6, Polyhedron.d12, Polyhedron.d20]) {
      for (final face in die.faces) {
        final points = [for (final i in face) die.vertices[i]];
        final centre = points.reduce((a, b) => a + b) / points.length.toDouble();
        // A normal pointing inwards makes the culling draw the far side of
        // the die and hide the near one, which looks like a hole.
        expect(die.normalOf(face).dot(centre), greaterThan(0));
      }
    }
  });

  test('every face is wound the same way round', () {
    for (final die in [Polyhedron.d12, Polyhedron.d20]) {
      for (final face in die.faces) {
        final points = [for (final i in face) die.vertices[i]];
        final normal = die.normalOf(face);
        for (var i = 0; i < points.length; i++) {
          final a = points[i];
          final b = points[(i + 1) % points.length];
          final c = points[(i + 2) % points.length];
          expect((b - a).cross(c - b).dot(normal), greaterThan(0),
              reason: 'a face of a ${die.sides} sided die turns back on itself');
        }
      }
    }
  });

  test('every corner is the same distance out', () {
    for (final die in [Polyhedron.d6, Polyhedron.d12, Polyhedron.d20]) {
      final radius = die.vertices.first.length;
      for (final v in die.vertices) {
        expect(v.length, closeTo(radius, 1e-9));
      }
    }
  });

  test('a rolled face is turned to face you, exactly', () {
    for (final die in [Polyhedron.d6, Polyhedron.d12, Polyhedron.d20]) {
      for (var i = 0; i < die.faces.length; i++) {
        final landed = die.settle(i).rotated(die.normalOf(die.faces[i]));
        expect(landed.x.abs(), lessThan(1e-9));
        expect(landed.y.abs(), lessThan(1e-9));
        expect(landed.z, closeTo(1, 1e-9),
            reason: 'face $i of a ${die.sides} sided die landed away from you');
      }
    }
  });

  test('the face already facing you needs no turning', () {
    final die = Polyhedron.d6;
    final facing = die.faces.indexWhere(
      (f) => (die.normalOf(f) - Vector3(0, 0, 1)).length < 1e-9,
    );
    expect(facing, isNot(-1), reason: 'a cube has a face pointing at you');

    // The axis is the cross product of two parallel vectors, which is zero
    // and cannot be normalized. The identity is the answer, not a crash.
    final landed = die.settle(facing).rotated(die.normalOf(die.faces[facing]));
    expect(landed.z, closeTo(1, 1e-9));
  });

  test('the face pointing away turns all the way round', () {
    final die = Polyhedron.d6;
    final away = die.faces.indexWhere(
      (f) => (die.normalOf(f) - Vector3(0, 0, -1)).length < 1e-9,
    );
    expect(away, isNot(-1));

    // The other degenerate axis: opposite vectors also cross to zero, and
    // this one needs half a turn about any perpendicular rather than none.
    final landed = die.settle(away).rotated(die.normalOf(die.faces[away]));
    expect(landed.z, closeTo(1, 1e-9),
        reason: 'the far face never came round');
  });

  test('a die has as many faces as it has sides', () {
    expect(Polyhedron.d6.sides, 6);
    expect(Polyhedron.d12.sides, 12);
    expect(Polyhedron.d20.sides, 20);
    for (final die in [Polyhedron.d6, Polyhedron.d12, Polyhedron.d20]) {
      expect(die.faces.length, die.sides);
    }
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/polyhedron_test.dart`
Expected: FAIL, `Error when reading
'lib/features/play/dice/polyhedron.dart'`.

- [ ] **Step 3: Derive the solids**

Create `lib/features/play/dice/polyhedron.dart`.

The d20's vertices are the cyclic permutations of `(0, ±1, ±φ)` with
`φ = (1 + sqrt(5)) / 2`. Its faces are every triple of vertices that are
mutually one edge apart, where the edge is the smallest distance between any
two of them, which measures exactly 2.0.

The d12 is the d20's dual: its vertices are the centroids of the d20's faces,
and each of its pentagons is the five centroids around one d20 vertex, sorted
by angle about that vertex's direction so the winding comes out consistent.

The d6 is the eight `(±1, ±1, ±1)` corners and six faces of four.

**Derive them and do not type index lists.** Twenty triangles written by hand
is twenty chances to transpose an index, and the only thing that would catch
it is somebody's eye on a rolling die.

`settle(face)` returns the `Quaternion` that brings that face's normal to the
camera:

```dart
  /// The turn that brings [face] round to face you.
  ///
  /// The angle is negative. `Quaternion.axisAngle` turns the opposite way to
  /// the right hand rule: measured, `axisAngle(z, pi/2).rotated(x)` is
  /// `(0, -1, 0)`. With a positive angle a face lands at
  /// `(0.667, 0.667, -0.333)`, which is the wrong face, showing almost
  /// straight, which is worse than obviously wrong.
  Quaternion settle(int face) {
    final n = normalOf(faces[face]);
    final axis = n.cross(Vector3(0, 0, 1));
    // Two degenerate cases, and they are not the same. A face already facing
    // you crosses to zero and needs no turn; a face pointing away also
    // crosses to zero and needs half a turn about any perpendicular.
    if (axis.length2 < 1e-18) {
      return n.z > 0
          ? Quaternion.identity()
          : Quaternion.axisAngle(Vector3(1, 0, 0), math.pi);
    }
    return Quaternion.axisAngle(
      axis.normalized(),
      -math.acos(n.dot(Vector3(0, 0, 1)).clamp(-1.0, 1.0)),
    );
  }
```

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/features/polyhedron_test.dart`
Expected: PASS, 11 tests.

- [ ] **Step 5: Probe**

Four, and say which assertion each fails on.

- Drop the minus from the settle's angle. Every face of every die lands
  wrong: the settle case fails on `landed.z`.
- Reverse the pentagon sort, so the winding goes the other way. The winding
  case must fail, and **say whether the flatness or the outward case also
  fails**: they should not, and if one does the sort is doing more than
  ordering.
- Take the far face's half turn out, returning the identity for both
  degenerate axes. **Two cases fail, not one**: the named one says why, and
  the sweep over every face of all three dice hits the d6's far face as well.
  Only the d6 has faces on the degenerate axes, so the sweep's extra failure
  is a single face.
- Widen the edge tolerance to **1.24**, and not to 0.5. The pair distances
  are 2.0, 3.236 and 3.804 with nothing in between, so any tolerance below
  1.236 picks exactly the thirty edges and `<=` does too: 0.5 is a forced
  value that lands inside the innocent band and survives. At 1.24 the count
  goes to 160 and five cases fall, which is the failure this derivation
  exists to make impossible.

- Turn the normal inwards. The outward case must fail. **The settle sweep
  will not**, because it rotates the same normal `settle` used, so a sign
  error moves both sides of it: that one case is the only thing holding the
  convention.

Edit each back by hand, never with `git checkout`, and rerun.

- [ ] **Step 6: Commit**

```bash
git add lib/features/play/dice test/features/polyhedron_test.dart
git commit -m "Build the three solids out of their own geometry"
```

---

## Task 10: A die you can see

**Files:**
- Create: `lib/features/play/dice/die_view.dart`
- Test: `test/features/die_view_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/die_view_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/dice/die_view.dart';
import 'package:kitchentable/features/play/dice/polyhedron.dart';
import 'package:vector_math/vector_math_64.dart';

// `Polyhedron? die` and not `Polyhedron die = Polyhedron.d20`: a parameter
// default has to be a constant expression and the solids are derived at
// startup, so they are `static final`.
Widget _host({
  Polyhedron? die,
  int showing = 0,
  Quaternion? turn,
}) =>
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: DieView(
            die: die,
            showing: showing,
            turn: turn ?? die.settle(showing),
            size: 80,
          ),
        ),
      ),
    );

void main() {
  testWidgets('it draws something for each of the three', (tester) async {
    for (final die in [Polyhedron.d6, Polyhedron.d12, Polyhedron.d20]) {
      await tester.pumpWidget(_host(die: die));
      await tester.pump();
      expect(find.byType(DieView), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  test('only the faces turned towards you are drawn', () {
    for (final die in [Polyhedron.d6, Polyhedron.d12, Polyhedron.d20]) {
      final turn = die.settle(0);
      final seen = visibleFaces(die, turn);

      // Never all of them and never none: a solid shows about half its faces,
      // and a die that drew all of them would paint its own far side over its
      // near one.
      expect(seen, isNotEmpty);
      expect(seen.length, lessThan(die.faces.length));
      expect(seen, contains(0), reason: 'the face that was rolled is hidden');
    }
  });

  test('the rolled face is the one nearest the middle', () {
    for (final die in [Polyhedron.d6, Polyhedron.d12, Polyhedron.d20]) {
      final turn = die.settle(3 % die.faces.length);
      final rolled = 3 % die.faces.length;
      final centre = Offset.zero;

      var nearest = -1;
      var best = double.infinity;
      for (final f in visibleFaces(die, turn)) {
        final at = project(die, f, turn, 80);
        final d = (at - centre).distance;
        if (d < best) {
          best = d;
          nearest = f;
        }
      }
      expect(nearest, rolled,
          reason: 'a ${die.sides} sided die showing $rolled points elsewhere');
    }
  });

  test('a face turned edge on is not drawn', () {
    final die = Polyhedron.d6;
    // A quarter turn puts two faces exactly edge on. Drawn, they are a line
    // of pixels that flickers; culled, they are nothing, which is what a real
    // die does.
    final turn = Quaternion.axisAngle(Vector3(0, 1, 0), math.pi / 2);
    final seen = visibleFaces(die, turn);
    expect(seen.length, lessThanOrEqualTo(4));
  });
}
```

Add `import 'dart:math' as math;` to that file.

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/die_view_test.dart`
Expected: FAIL, `Error when reading
'lib/features/play/dice/die_view.dart'`.

- [ ] **Step 3: Draw it**

`DieView` is a `CustomPaint`. `visibleFaces` and `project` are top level so
the arithmetic is testable without pumping a widget, which is the whole reason
the cases above are mostly plain `test` and not `testWidgets`.

- A face is visible when its rotated normal has a positive z. That is the
  culling, and it is one line.
- Faces are painted far to near, sorted by the rotated centroid's z, so the
  near ones land on top. Painter's algorithm: it is exact for a convex solid,
  which all three of these are.
- The number goes at the projected centroid, scaled by how square on the face
  is, which is the dot of its normal with the camera. A face at a glancing
  angle gets a small number, which is what foreshortening looks like without
  having to skew the text into the face's plane.
- Shade each face by that same dot, so the solid reads as solid. The palette
  has `accent` for the rolled face and `tile` and `tileEdge` for the rest.

Perspective is not worth it here: a die is small and nearly orthographic at
this size, and a projection with a vanishing point needs a depth that has to
be tuned against the die's radius. Say so in a comment.

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/features/die_view_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Probe**

- Cull on negative z instead of positive. The visibility case fails on
  `contains(0)`, and the nearest case fails too: say which assertion each.
- Paint near to far. Nothing notices, and **a case that read pixels would not
  either**: with backface culling on a convex solid under an orthographic
  projection the visible faces tile the silhouette with disjoint interiors, so
  no visible face ever covers another. Only the seams are shared and the
  stroke is the same colour on both sides. What would pin the order is the
  order itself, a recording canvas collecting the `drawPath` calls and
  asserting the face sequence rises in rotated centroid z. Until a translucent
  face or a wider outline arrives, the sort is insurance rather than
  behaviour: say that rather than claiming coverage.
- Drop the foreshortening on the number's size. Say what fails. If nothing
  does, say that too.

Edit each back by hand and rerun.

- [ ] **Step 6: Commit**

```bash
git add lib/features/play/dice test/features/die_view_test.dart
git commit -m "Draw a solid, near faces over far ones"
```

---

## Task 11: The roll

Three dice standing on the deck. Tap one and it tumbles and settles on its
number. `RollDice` finally gets a caller: it has existed since plan 2 and its
reducer already takes the results from whoever rolled, so replaying a game
gives the same roll.

**Files:**
- Create: `lib/features/play/dice/tumble.dart`
- Create: `lib/features/play/dice/dice_tray.dart`
- Modify: `lib/features/play/play_screen.dart`
- Test: `test/features/tumble_test.dart`, `test/features/dice_tray_test.dart`, `test/features/play_screen_test.dart`

### The composition order has to be measured, not assumed

`Quaternion.axisAngle` already turned out to run against the right hand rule.
Do not assume which side of a product applies first either. Measure it in the
first case you write, and if the plan's order below is backwards, say so with
the numbers and use the other one.

- [ ] **Step 1: Write the failing test**

Create `test/features/tumble_test.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/dice/polyhedron.dart';
import 'package:kitchentable/features/play/dice/tumble.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('which side of a product applies first', () {
    // Measured rather than assumed, because axisAngle already turned out to
    // run against the right hand rule. A quarter turn about z followed by a
    // quarter turn about x, applied to the x axis.
    final aboutZ = Quaternion.axisAngle(Vector3(0, 0, 1), math.pi / 2);
    final aboutX = Quaternion.axisAngle(Vector3(1, 0, 0), math.pi / 2);
    final v = Vector3(1, 0, 0);

    // Components, not lengths. A unit quaternion cannot change a vector's
    // length whichever way round the product is written, so asserting the
    // length passes on either convention and on a tumble that composes
    // backwards. The first draft of this case did exactly that.
    //
    // Measured: the LEFT factor applies first. `(aboutZ * aboutX)` is the
    // same vector as `aboutX.rotated(aboutZ.rotated(v))`.
    expect((aboutZ * aboutX).rotated(v).z, closeTo(1, 1e-9));
    expect((aboutX * aboutZ).rotated(v).y, closeTo(-1, 1e-9));

    // And the invariant that pins `tumble`'s own order. With the settle on
    // the left the spin is a world axis applied after it, so the one body
    // direction a roll never moves maps to that axis at every point of the
    // throw. Composed the other way the spin acts in the die's own frame and
    // this walks off by about 1.58.
    final die = Polyhedron.d20;
    final axis = tumbleAxisOf(die, 0);
    final still = die.settle(0).inverted().rotated(axis);
    for (final at in [0.2, 0.6, 0.9]) {
      expect((tumble(die: die, face: 0, spin: 3, at: at).rotated(still) - axis)
          .length, lessThan(1e-9),
          reason: 'face 0 at $at turns about somewhere else');
    }
  });

  test('a tumble ends exactly where the die settles', () {
    for (final die in [Polyhedron.d6, Polyhedron.d12, Polyhedron.d20]) {
      for (var face = 0; face < die.faces.length; face++) {
        final landed =
            tumble(die: die, face: face, spin: 3, at: 1).rotated(
          die.normalOf(die.faces[face]),
        );

        // Not close to the camera. On it. A die that settles a degree out
        // reads as a die resting on an edge.
        expect(landed.z, closeTo(1, 1e-9),
            reason: 'face $face of a ${die.sides} sided die did not land');
      }
    }
  });

  test('a tumble actually moves', () {
    final die = Polyhedron.d20;
    final settled = tumble(die: die, face: 0, spin: 3, at: 1);
    final middle = tumble(die: die, face: 0, spin: 3, at: 0.5);

    // A "tumble" that is the settle all the way through is a die that
    // teleports to its answer, which is what a still picture looks like.
    expect((middle.rotated(Vector3(0, 0, 1)) -
                settled.rotated(Vector3(0, 0, 1)))
            .length,
        greaterThan(0.1));
  });

  test('more spin is more turning', () {
    final die = Polyhedron.d20;
    var far = 0.0;
    var near = 0.0;
    for (var i = 1; i < 20; i++) {
      final t = i / 20;
      far += (tumble(die: die, face: 0, spin: 6, at: t).rotated(Vector3(1, 0, 0)) -
              tumble(die: die, face: 0, spin: 6, at: t - 0.05)
                  .rotated(Vector3(1, 0, 0)))
          .length;
      near += (tumble(die: die, face: 0, spin: 1, at: t).rotated(Vector3(1, 0, 0)) -
              tumble(die: die, face: 0, spin: 1, at: t - 0.05)
                  .rotated(Vector3(1, 0, 0)))
          .length;
    }
    expect(far, greaterThan(near));
  });

  test('the same roll tumbles the same way twice', () {
    final die = Polyhedron.d12;
    final once = tumble(die: die, face: 4, spin: 3, at: 0.37);
    final twice = tumble(die: die, face: 4, spin: 3, at: 0.37);

    // No randomness inside. What is random is the number, which is rolled by
    // the caller, because `apply` has to be a function or replaying a game
    // gives a different game.
    expect((once.rotated(Vector3(1, 2, 3)) - twice.rotated(Vector3(1, 2, 3)))
        .length, lessThan(1e-12));
  });

  test('a roll is a number on the die', () {
    final rolled = <int>{};
    for (var i = 0; i < 400; i++) {
      final n = rollOne(Polyhedron.d20, math.Random(i));
      expect(n, greaterThanOrEqualTo(1));
      expect(n, lessThanOrEqualTo(20));
      rolled.add(n);
    }
    // Four hundred rolls of a d20 that never show a twenty is a d19.
    expect(rolled, hasLength(20));
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/tumble_test.dart`
Expected: FAIL, `Error when reading 'lib/features/play/dice/tumble.dart'`.

- [ ] **Step 3: Write the tumble**

```dart
/// Where the die is pointing, part way through a roll.
///
/// Composed so the settle wins outright at the end: the spin decays to
/// nothing as `at` reaches one, so the last frame is the settle exactly and
/// not the settle plus a rounding error. A die that stops a degree off reads
/// as one resting on an edge.
///
/// Nothing random in here. The number is rolled by the caller, because
/// `apply` has to be a function or replaying a game gives a different game,
/// which is the same reason `CreateToken` takes its id from outside.
Quaternion tumble({
  required Polyhedron die,
  required int face,
  required double spin,
  required double at,
}) { ... }
```

The eased fraction wants to decelerate: a die thrown across a table slows into
its answer rather than stopping dead. `Curves.easeOutCubic` transforms a
`double` without a widget, so it can be used here.

`rollOne(die, random)` returns `1 + random.nextInt(die.sides)`.

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/features/tumble_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 5: Probe**

- Make the spin not decay, so it is still turning at `at: 1`. **Do not do
  this by deleting the `(1 - eased)` factor**: at `spin: 3` that leaves six pi,
  three whole turns, which is the identity, and the landing case passes. It
  kills the moving case and the more spin case instead. To make the landing
  case fail, leave a residue that is not a whole turn, `(1 - eased * 0.75)`,
  and it falls on `landed.z` at face 0 of the d6.
- Return the settle for every `at`. The moving case must fail.
- Make `rollOne` return `random.nextInt(die.sides)`, off by one. Say which
  assertion fails: it should be the lower bound, and if it is the
  `hasLength(20)` instead, that tells you the bound was never tested.

Edit each back by hand, never with `git checkout`, and rerun.

- [ ] **Step 6: Write the failing test for the tray**

Create `test/features/dice_tray_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/dice/dice_tray.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

Widget _host({
  List<int> showing = const [20, 12, 6],
  void Function(List<int>)? onRoll,
}) =>
    MaterialApp(
      home: Scaffold(
        body: DiceTray(
          metrics: Metrics.of(DeviceClass.handheld),
          showing: showing,
          width: 120,
          onRoll: onRoll ?? (_) {},
        ),
      ),
    );

void main() {
  testWidgets('there are three of them', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    expect(find.byKey(const Key('die-20')), findsOneWidget);
    expect(find.byKey(const Key('die-12')), findsOneWidget);
    expect(find.byKey(const Key('die-6')), findsOneWidget);
  });

  testWidgets('each shows what it last landed on', (tester) async {
    await tester.pumpWidget(_host(showing: const [17, 3, 5]));
    await tester.pumpAndSettle();

    expect(find.text('17'), findsWidgets);
    expect(find.text('3'), findsWidgets);
    expect(find.text('5'), findsWidgets);
  });

  testWidgets('tapping one rolls that one and leaves the others',
      (tester) async {
    List<int>? rolled;
    await tester.pumpWidget(
      _host(showing: const [17, 3, 5], onRoll: (r) => rolled = r),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('die-12')));
    await tester.pumpAndSettle();

    expect(rolled, hasLength(3));
    expect(rolled![0], 17, reason: 'the d20 was not touched');
    expect(rolled![2], 5, reason: 'the d6 was not touched');
    expect(rolled![1], inInclusiveRange(1, 12));
  });

  testWidgets('a die that has not been rolled yet still draws', (tester) async {
    await tester.pumpWidget(_host(showing: const []));
    await tester.pump();

    // A table opens with no dice thrown. Three blanks would be three holes.
    expect(find.byKey(const Key('die-20')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 7: Write the tray and put it on the deck**

`DiceTray` is a row of three `DieView`s, each animating through `tumble` when
its number changes. An `AnimationController` per die, or one controller and
three start times: the second is simpler and a roll is one die at a time.

On the screen it goes **across the board from the deck**, with the graveyard
and the token control, and into `FreeCanvas`'s furniture the same way they
are: **built once in the screen and handed to both renderers**, because that
is the third time this has come up and the two views drifting apart is the
failure each time.

Not above the deck. In the wide view that column is a fixed 380 unit strip
and the corner and the deck already stand 333 of it, leaving 46.3 against the
48.3 a tray and its gap want: `A RenderFlex overflowed by 2.0 pixels`.
Shaving the dice to fit 46.3 would be fitting them to whatever the corner and
the deck happen to leave this week. The things that are not piles of cards
cross the mat, which is the argument the token control already makes.

**Derive every size in the tray from the tray's own width**, not from
`Metrics`. A first draft gave each die a `m.scaled(10)` caption under it; at
390 by 844 the die slot is about 8 points and the caption is 11, so each die's
intrinsic width was its caption's, the column came out 41 wide where a card is
32, and the board paid 9.7 percent of its card. With every size off the width
the shipped board measures bit identical to before the dice existed.

`onRoll` runs `RollDice(results)`. The screen reads the current three off
`table.dice`, replaces the one that was tapped, and sends all three, so the
table's `dice` list is the whole tray and a replay gives the same table.

- [ ] **Step 8: Bite the wiring**

Append to `test/features/play_screen_test.dart`:

```dart
  testWidgets('rolling a die puts the number on the table', (tester) async {
    final container = await _seatedPod(tester, ['you']);

    expect(container.read(playProvider)!.dice, isEmpty);

    await tester.tap(find.byKey(const Key('die-20')));
    await tester.pumpAndSettle();

    final dice = container.read(playProvider)!.dice;
    expect(dice, hasLength(3));
    expect(dice.first, inInclusiveRange(1, 20));
  });
```

- [ ] **Step 9: Run everything**

Run: `flutter test && flutter analyze`
Expected: PASS and `No issues found!`, WARNING and Warning both 0.

The column beside the mat now carries a corner, a deck, a graveyard, a token
control and three dice. **On a phone that column is already the thing that
overflows**, and the aside's width is what the board's own scale is read from.
Run the case named `nothing in the aside runs off the bottom` and say what it
reports, and measure the card on the board at 390 by 844 before and after.
If the board loses more than a point or two, say so rather than shipping it:
the dice may need to be smaller than a card, or to sit along the top of the
tray rather than down the column.

- [ ] **Step 10: Probe**

- Make `onRoll` send only the rolled die. The tray case must fail on
  `hasLength(3)`.
- Make the screen not run `RollDice`. The wiring case must fail on `dice`
  being empty, which is a wrong value rather than a finder.
- Make the tapped die's number come from the die beside it. **It survives the
  whole file**: every number a d6 shows is a number a d12 shows, and the
  wiring case is blind too since a d12 result sits inside a d20's range.
  Reading the *other* neighbour, a d20, is caught by the range only two times
  in five.

  What catches both is tapping enough times to exercise the range. Add a case
  that taps forty times and asserts the best roll clears six and does not
  exceed twelve: forty taps of a d12 never clearing a six is 2^-40, and forty
  of a d20 never clearing a twelve is about 1.3e-9.

Edit each back by hand and rerun.

- [ ] **Step 11: Commit**

```bash
git add lib/features/play test/features
git commit -m "Throw three dice on the deck and let them land"
```

---

## What this plan deliberately leaves out

- **Dice anybody else can see.** `RollDice` writes to the table, so plan 3
  replicates it for free, but nothing draws somebody else's roll yet.
- **A die you can throw.** Tapping rolls it. Flinging it across the table is a
  gesture, a physics step and a resting place, and none of those is the
  number.
- **Perspective on the solids.** They are small and nearly orthographic at
  this size, and a vanishing point needs a depth tuned against the radius.
- **The paint order under anything translucent.** It is unobservable while the
  faces are opaque and culled, and the instrument for it is a recording canvas
  rather than a pixel.
