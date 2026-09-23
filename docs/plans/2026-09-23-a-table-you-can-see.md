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

## Tasks 4 onward

Written after these three, because all of them draw against a scale that does
not exist yet. They cover the four questions the player asked:

- **The graveyard**, a pile beside the deck you can drop a card onto and open,
  reusing the shape of the deck sheet.
- **Tokens.** `CreateToken` has existed since plan 2 and nothing constructs it.
- **Markers.** `ChangeCounter` takes any name and the viewer hardcodes
  `+1/+1`.
- **Dice**, three dimensional, on top of the deck, d20, d12 and d6.
  `RollDice` has existed since plan 2 and nothing constructs it either.
