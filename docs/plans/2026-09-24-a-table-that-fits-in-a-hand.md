# A table that fits in a hand, implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A card on a phone's battlefield is big enough to read, the screen is
spent on the table rather than on outlines of empty zones, and a phone held
sideways gets a layout that fits it.

**Architecture:** Four changes, in this order. The renderer breakpoint starts
asking for room instead of width. Zones shrink to chips and grow back only
while a card is in the air. The hand peeks and opens on demand. The mat stops
scaling below a readable card and the board scrolls instead.

**Tech Stack:** Flutter 3.47.5, Dart 3.13.4, flutter_riverpod 3.4.3.

The reasoning, the measurements and the sources are in
`docs/specs/2026-09-24-what-a-phone-does-with-a-table.md`. Read it first: this
plan is the how and that is the why, and three of these four tasks undo a
choice an earlier plan made on purpose.

---

## The baseline, measured

At `32ee85c`, 557 tests, `No issues found!`, 139 lines at 80 columns or more
and 47 strictly over. On a 390 by 844 window with one seat, a commander and
one card on the battlefield:

| band | points | share |
|---|---|---|
| top chrome | 88 | 10% |
| battlefield | 455 | 54% |
| furniture row | 133 | 16% |
| hand | 117 | 14% |
| hints below | 51 | 6% |

Card on the mat 50.3 wide. Card in the hand 50.3 wide. Empty graveyard drawn
at 50 by 70. Deck 68 by 88.

**Take your own baseline before Task 1 and report it.** Two numbers in the
last plan's brief were wrong and both mattered.

---

## Task 1: The breakpoint asks for room

**Files:**
- Modify: `lib/features/play/renderers/renderer_choice.dart`
- Modify: `lib/features/play/play_screen.dart:126`
- Test: `test/features/renderer_choice_test.dart`

- [ ] **Step 1: Write the failing test**

Append to `test/features/renderer_choice_test.dart`:

```dart
  test('a phone held sideways is wide and has no room', () {
    // 844 by 390 clears the width cut and is the worst window the canvas
    // gets: one seat's strips take 28 percent of the width and what is left
    // has to hold a 380 unit mat in 390 points less the chrome.
    expect(
      rendererFor(width: 844, height: 390, chosen: null),
      TableRenderer.stackedSeats,
    );
  });

  test('a tablet has room in both directions', () {
    expect(
      rendererFor(width: 820, height: 1180, chosen: null),
      TableRenderer.freeCanvas,
    );
  });
```

- [ ] **Step 2: Run them and watch them fail**

Run: `flutter test test/features/renderer_choice_test.dart`
Expected: the first fails on `stackedSeats` against `freeCanvas`. The second
will not compile until `height` exists, which is a compile red and proves
nothing on its own: say so, and confirm it passes on its own value afterwards.

- [ ] **Step 3: Take the height**

`rendererFor` gains a required `height`. The canvas needs both directions:
say what height you chose and derive it, do not pick a round number. The
honest source is `mat_layout.dart`, where a seat's share is the mat plus a
strip on each side; the canvas is worth choosing only when a seat's mat can be
drawn at a card you can tell apart.

**Seven existing calls pass width only**, six of them in
`renderer_choice_test.dart` and one at `play_screen.dart:126`. Grep the
symbol, do not work from this list.

- [ ] **Step 4: Run everything**

Run: `flutter test && flutter analyze`
Expected: PASS and `No issues found!`, WARNING and Warning both 0.

- [ ] **Step 5: Probe**

- Drop the height term from the condition. The first new case must fail on its
  own value.
- Make the height cut fire at every size. The tablet case must fail.

Name the failing assertion and its line each time. Edit back by hand, never
with `git checkout`, and rerun.

- [ ] **Step 6: Commit**

```bash
git add lib/features/play/renderers/renderer_choice.dart \
        lib/features/play/play_screen.dart test/features/renderer_choice_test.dart
git commit -m "Choose the renderer by the room, not by the width"
```

---

## Task 2: A zone is a chip until you aim at it

**Files:**
- Create: `lib/features/play/widgets/zone_chip.dart`
- Create: `lib/features/play/dragging.dart`
- Modify: `lib/features/play/play_screen.dart`
- Modify: `lib/features/play/widgets/card_drag.dart`
- Test: `test/features/zone_chip_test.dart`
- Test: `test/features/play_screen_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/zone_chip_test.dart` with cases for the chip itself: an
empty one draws its count and no card, one with cards draws the top card's
art, and it is not as tall as a card.

Append to `test/features/play_screen_test.dart`:

```dart
  testWidgets('an empty graveyard does not take a card of room',
      (tester) async {
    await _seatedPod(tester, ['you'], withCommander: true);
    await tester.pumpAndSettle();

    final bin = tester.getRect(find.byKey(const Key('graveyard-stack')));

    // It was 50 by 70, an outline of a card that is not there, and it was the
    // leftmost and most prominent object on a 390 point screen.
    expect(bin.height, lessThan(44));
  });

  testWidgets('a zone grows into a target while a card is in the air',
      (tester) async {
    final container = await _seatedPod(tester, ['you']);
    final play = container.read(playProvider.notifier);
    final card = container.read(playProvider)!.zone('hand-s1')!.cards.first;
    play.run(MoveCard(cardId: card.id, toZoneId: 'battlefield-s1'));
    await tester.pumpAndSettle();

    final resting = tester.getRect(find.byKey(const Key('graveyard-stack')));

    final gesture = await tester.startGesture(
      tester.getCenter(find.descendant(
        of: find.byKey(const Key('your-board')),
        matching: find.byType(TableCard),
      )),
    );
    await gesture.moveBy(const Offset(0, 150));
    await tester.pumpAndSettle();

    final aiming = tester.getRect(find.byKey(const Key('graveyard-stack')));
    expect(aiming.height, greaterThan(resting.height * 1.5),
        reason: 'the chip did not grow into a drop target');

    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const Key('graveyard-stack'))).height,
      resting.height,
      reason: 'the chip did not collapse when the drag ended',
    );
  });
```

A short drag does not register: 137 points does not and 150 does. That is why
the move above is 150 and not a tidier number.

- [ ] **Step 2: Run them and watch them fail**

Run: `flutter test test/features/play_screen_test.dart`
Expected: the first fails on 70 against 44. The second on the chip never
growing. Report which assertion and its line, and if either dies by exception
rather than by value, run a variant that gives a wrong value instead.

- [ ] **Step 3: Build the chip and the drag state**

`ZoneChip` carries a name, a count, and the top card if there is one. About 36
points tall at rest; card sized when it is a target. The existing tap that
opens the pile sheet keeps working, and the existing `onDrop` keeps working.

**The drag state goes in a provider**, `lib/features/play/dragging.dart`, not
in a parameter on `DraggableCard`. `DraggableCard` sets it on drag start and
clears it on end and on cancel, and each chip watches it. A parameter would
create a hand off site per widget between the drag and the chips, and this
codebase has already shipped a dropped hand off of exactly that shape: a
`Game?` threaded through six widgets where `CommandSlot` accepted it and never
passed it on, with a green suite and a clean analyze.

Clear it on **cancel as well as on end**. A drag that is cancelled and leaves
the chips expanded is the failure this will actually have.

- [ ] **Step 4: Run everything**

Run: `flutter test && flutter analyze`
Expected: PASS and `No issues found!`.

**Cases that measure the furniture will move.** `the deck sits to the right,
not in the middle`, `the graveyard is on the far side from the deck`, `the row
under the board is drawn at the board's own card` and `a card dropped on the
graveyard goes there` all touch these widgets or their geometry. **Report
every case that moved with its numbers before changing anything**, and say for
each whether it should be rewritten or whether it is telling you something.

- [ ] **Step 5: Probe**

- Never set the drag state. The second new case must fail on the grow.
- Never clear it. The second must fail on the collapse.
- Clear it on end but not on cancel, then write a case that cancels a drag.
  If nothing fails, say so: that is a real hole and it wants a case.
- Draw the chip at a card's height at rest. The first must fail.
- Delete the count from the chip. Its own case must fail.

- [ ] **Step 6: Commit**

```bash
git add lib/features/play/widgets/zone_chip.dart lib/features/play/dragging.dart \
        lib/features/play/play_screen.dart lib/features/play/widgets/card_drag.dart \
        test/features/zone_chip_test.dart test/features/play_screen_test.dart
git commit -m "Shrink a zone to a chip and grow it while you aim"
```

---

## Task 3: The hand peeks

**Files:**
- Modify: `lib/features/play/widgets/hand_sheet.dart`
- Test: `test/features/hand_sheet_test.dart`
- Test: `test/features/play_screen_test.dart`

- [ ] **Step 1: Write the failing test**

Append to `test/features/play_screen_test.dart`:

```dart
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
```

- [ ] **Step 2: Run them and watch them fail**

Run: `flutter test test/features/play_screen_test.dart`
Expected: the first on the share, the second on the missing handle. Name the
assertion and the line.

- [ ] **Step 3: Let it peek**

Collapsed, the hand shows the tops of its cards and a handle. Opened, it
covers the board. It opens on a tap on the handle and closes the same way.

**Playing a card from an open hand closes it.** Otherwise you drop a card onto
a board you cannot see, which is worse than the strip ever was.

**The hand's card size still follows the board's, up to the ceiling.** That is
the whole of the last plan's Task 1 and it must not be undone. An open hand is
allowed to be the taller thing; it is not allowed to be a different size.

Twelve cases live in `hand_sheet_test.dart` and they construct `HandSheet`
directly. If collapsing is the default, most of them are now looking at a
closed hand. **Report what you found there before changing any of them**, and
prefer giving the widget an initial state to editing twelve cases.

- [ ] **Step 4: Run everything**

Run: `flutter test && flutter analyze`
Expected: PASS and `No issues found!`.

- [ ] **Step 5: Probe**

- Make the handle do nothing. The second case must fail on the open.
- Make it open but never close. The second must fail on the third assertion,
  which is the one that says so.
- Make the collapsed strip a card tall. The first must fail.
- Play a card from an open hand without closing it. If nothing fails, write
  the case rather than reporting it as covered.

- [ ] **Step 6: Commit**

```bash
git add lib/features/play/widgets/hand_sheet.dart test/features/hand_sheet_test.dart \
        test/features/play_screen_test.dart
git commit -m "Let the hand peek and open over the board"
```

---

## Task 4: The mat stops shrinking

**Files:**
- Modify: `lib/features/play/renderers/mat_layout.dart`
- Modify: `lib/features/play/widgets/cursor_board.dart`
- Test: `test/features/mat_layout_test.dart`
- Test: `test/features/cursor_board_test.dart`
- Test: `test/features/play_screen_test.dart`

- [ ] **Step 1: Write the failing test**

Append to `test/features/play_screen_test.dart`:

```dart
  testWidgets('a card on a phone is big enough to read', (tester) async {
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

    // It was 50.3, which is a card you cannot read a name on. The printed
    // card on the mat is 90 and this is the floor under it.
    expect(onBoard, greaterThanOrEqualTo(72));
  });

  testWidgets('a mat too big for the phone scrolls rather than shrinking',
      (tester) async {
    await _seatedPod(tester, ['you']);
    await tester.pumpAndSettle();

    final board = tester.getRect(find.byKey(const Key('your-board')));
    final mat = tester.getRect(find.byKey(const Key('mat-battlefield-s1')));

    expect(mat.width, greaterThan(board.width),
        reason: 'the mat still fits, so nothing here is being tested');
    expect(find.byType(Scrollable), findsWidgets);
  });
```

And in `mat_layout_test.dart`, that `matScaleFor` does not go below the floor
on a small box and still fits on a large one.

- [ ] **Step 2: Run them and watch them fail**

Run: `flutter test`
Expected: the first on 50.3 against 72. Report the line.

- [ ] **Step 3: Put a floor under the card and let the board scroll**

`matScaleFor` takes the larger of the fit and the floor. The floor is a card
you can read: **derive it and say where it came from**, do not write 0.8
because this plan wrote 72. `cardOnMat` is 90 wide.

When the mat comes out bigger than its box the board scrolls on both axes.
`_pile` already centres the mat inside a `Center` whose looseness is load
bearing; read the comment at `cursor_board.dart:243` before touching it.

**The drop stays normalized and this is the assertion that says so.** The
offset is divided by the scale at `cursor_board.dart:360` before it is divided
by `matSize`, so a scroll offset must not reach it. Write a case that drops a
card at the same normalized spot on two different window sizes and asserts the
two stored positions are equal to within a rounding error. **That case is the
point of this task**: everything else here is pixels, and that is the
invariant plan 4 replicates across the network.

Predicted, so that you can tell me where I was wrong: at 390 by 844 after
Tasks 2 and 3 the board box is about 358 by 600, the fit is 0.559, the floor
wins, the mat comes out about 512 by 304 and the board scrolls sideways by
about 154 points and not at all vertically. **Measure it and report the real
numbers.**

- [ ] **Step 4: Run everything**

Run: `flutter test && flutter analyze`
Expected: PASS and `No issues found!`.

**Everything that measures a card or a mat moves.** `mat_layout_test.dart`,
`cursor_board_test.dart`, `free_canvas_test.dart` and the board cases in
`play_screen_test.dart` all do. **Report every case that moved with its
numbers before changing anything.** A case that was asserting the mat fits is
not necessarily wrong; it may be a case about a window where it should.

- [ ] **Step 5: Probe**

- Delete the floor. The first case must fail on its own value.
- Delete the fit, leaving only the floor. Say what fails and at which window:
  if nothing does, a large window has no case and wants one.
- Add a scroll offset into the normalized drop. The invariant case must fail.
  This is the probe that matters most in this plan; if it survives, the case
  is wrong and not the code.
- Make the board scroll on one axis only. Say which case fails, and at which
  window, or write one.

- [ ] **Step 6: Commit**

```bash
git add lib/features/play/renderers/mat_layout.dart \
        lib/features/play/widgets/cursor_board.dart test/features/mat_layout_test.dart \
        test/features/cursor_board_test.dart test/features/play_screen_test.dart
git commit -m "Put a floor under the card and let the board scroll"
```

---

## What this plan deliberately leaves out

- **Condensing a permanent into a tile.** The spec argues against it for this
  product and names it as the next idea if the floor plus a pan is not enough.
- **A portrait mat.** It breaks the one invariant that makes a drop mean the
  same place on two devices.
- **The four seat pod on a phone.** Still the screen's vertical budget across
  bands, a hand and two bars, and still untouched.
- **The canvas on a narrow window.** Task 1 stops a phone being handed it by
  accident. Somebody who picks it on purpose still gets the strips.
