# A phone is not a small desk, implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On a phone the battlefield gets the screen, a card on the table is
not smaller than the same card in your hand, and a counter is a piece of
plastic with thickness rather than a mirrored sticker.

**Architecture:** The furniture stops being two side columns on a narrow
window and becomes a row. The hand's card size stops being a fixed point size
and follows the board's. The counter keeps its chevron and loses the mirror.

**Tech Stack:** Flutter 3.47.5, Dart 3.13.4, flutter_riverpod 3.4.3.

---

## What a phone actually gets, measured

On a 390 by 844 window with one card on the battlefield, measured on
2026 09 24 at `1ebf156`:

| | |
|---|---|
| screen | 390 wide |
| board | `63.3` to `292.3`, so **229 wide, 59% of the screen** |
| card on the battlefield | **32.19** |
| card in the hand | **64.0** |
| board's height | 486, holding a mat 136 tall |

**A card in your hand is exactly twice the size of the same card on the
table.** That is the wrong way round: the hand is a row of things you are
choosing between and the battlefield is the thing you are looking at.

Two independent causes, and they compound.

**The furniture takes 41% of the width.** The graveyard column on the left and
the deck column on the right each cost a card's width plus its furniture, and
the board gets what is left. On a 1900 point window that is a rounding error.
On a 390 point phone it is nearly half the screen.

**The hand's card is a fixed `m.scaled(64)`** and the board's is derived from
whatever space is left over, so the two have never been related to each other.
Nothing made them disagree; nothing stopped them either.

**What is not being changed, and why.** `matSize` stays 640 by 380 and the mat
keeps that shape at every size. It is what makes a normalized drop position
mean the same place on a phone and on a television, which is the whole reason
positions are normalized, and plan 4 replicates them. A portrait mat on a
portrait screen would use the height better and would break that. The board is
486 tall using 136 of it, and that waste is the price of the invariant: say so
rather than quietly trading it away.

## The counters

The player looked at the picker and asked for two changes.

**No vertical mirror.** The real plastic prints its value twice so it reads
from either side of a physical table. On a screen only one person is looking,
and the second copy upside down is just noise. "o marcador pode ser so dois
triângulos mesmo": keep the notched chevron, print the value once.

**Thickness, the way the deck has it.** The deck reads as solid because it
draws leaves offset behind the top card. A counter wants the same trick: the
shape again in a darker shade, offset down and right, so there is a side to
it. Not a perspective transform, for the reason already in that file: the card
it sits on turns in three dimensions and a piece with its own vanishing point
fights it.

---

## Task 1: A phone gets its board back

**Files:**
- Modify: `lib/features/play/play_screen.dart`
- Test: `test/features/play_screen_test.dart`

- [ ] **Step 1: Write the failing test**

Append to `test/features/play_screen_test.dart`:

```dart
  testWidgets('on a phone the board gets the width', (tester) async {
    await _seatedPod(tester, ['you'], withCommander: true);
    await tester.pumpAndSettle();

    final screen = tester.getRect(find.byType(PlayScreen));
    final board = tester.getRect(find.byKey(const Key('your-board')));

    // A graveyard column on one side and a deck column on the other cost 41
    // percent of a 390 point screen. On a television that is a rounding
    // error; here it is nearly half the table.
    expect(board.width / screen.width, greaterThan(0.85),
        reason: 'the furniture is still eating the board');
  });

  testWidgets('a card on the table is not smaller than one in your hand',
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
    final inHand = tester
        .getSize(find.descendant(
          of: find.byType(HandSheet),
          matching: find.byType(TableCard),
        ).first)
        .width;

    // It was exactly half: 32.19 against 64.0. The hand is a row of things
    // you are choosing between and the battlefield is the thing you are
    // looking at, so the board is the one that sets the size.
    expect(onBoard, greaterThanOrEqualTo(inHand * 0.95));
  });

  testWidgets('a wide window keeps the furniture beside the board',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _seatedPod(tester, ['you'],
        window: const Size(1280, 800), withCommander: true);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('switch-renderer')));
    await tester.pumpAndSettle();

    final board = tester.getRect(find.byKey(const Key('your-board')));
    final deck = tester.getRect(find.byKey(const Key('library-stack')));
    final bin = tester.getRect(find.byKey(const Key('graveyard-stack')));

    // The row is for a narrow window. With room at the sides the piles stay
    // where a table puts them, which is beside you and not in front of you.
    expect(deck.left, greaterThanOrEqualTo(board.right));
    expect(bin.right, lessThanOrEqualTo(board.left));
  });
```

- [ ] **Step 2: Run them and watch them fail**

Run: `flutter test test/features/play_screen_test.dart`
Expected: the first two FAIL, at roughly `0.587` and `32.19` against `60.8`.
The third passes already.

- [ ] **Step 3: Lay a phone out differently**

Below a width the implementer picks and justifies, `yours` becomes the board
over a **row** of furniture rather than a board between two columns. The row
holds what the two columns held: the corner, the deck, the graveyard, the
token control and the dice.

**Pick the threshold from the arithmetic, not from a round number.** The
columns cost `aside * 2 + gap * 2`; below some width that is a share of the
screen nobody would accept. Say what share you chose and what width it falls
out to, and put both in a comment.

With the columns gone the board's width arithmetic loses its two subtractions
in that branch, so read the `LayoutBuilder` above `CursorBoard` before editing
it: it is the same arithmetic three plans have now touched.

**The hand follows the board.** Its card is `m.scaled(64)` today, unrelated to
anything. Give `HandSheet` the board's card width and let it draw at that, so
the two cannot drift apart again. The hand wraps at two lines and shrinks past
that, which already exists, so a bigger card there simply wraps sooner.

- [ ] **Step 4: Run everything**

Run: `flutter test && flutter analyze`
Expected: PASS and `No issues found!`, WARNING and Warning both 0.

**Several cases measure this layout.** `the board is budgeted for both columns,
not one` guards the width arithmetic with a ratio whose two ends were measured
at 1.160 and 1.239; a phone with no columns may put it outside both. `nothing
in the aside runs off the bottom`, `the graveyard is on the far side from the
deck` and `the token control is on the same side in both views` all assume
columns. **Report every case that moved with its numbers before changing
anything**, and for each one say whether it should now be scoped to a wide
window or whether it is telling you something.

- [ ] **Step 5: Probe**

- Make the narrow branch never fire. The first two cases must fail.
- Make it always fire. The third must fail.
- Give the hand back its fixed size. The second must fail, and say by how
  much: if it still passes, the two sizes happen to agree at this window and
  the case needs a window where they do not.

Say which assertion each time, with its line. Edit each back by hand, never
with `git checkout`, and rerun.

- [ ] **Step 6: Commit**

```bash
git add lib/features/play/play_screen.dart lib/features/play/widgets/hand_sheet.dart \
        test/features/play_screen_test.dart
git commit -m "Give a phone's battlefield the screen"
```

---

### What running Task 1 found

**The threshold came out at one tenth of the row**, which is 584 points of row
and a 616 point window at handheld metrics: `widest * 2 + gap * 2` is 58.4,
with `widest` read as `max(LibraryStack.spreadFor(1, 1), m.scaled(6))` rather
than as the live `aside`. Read live, the threshold walks from a 616 point
window down to a 240 point one as the deck thins, which would move the
furniture from a row to two columns around the fourth turn of a game. One
tenth and not one eighth because 577.5 points of row is also where the card
this arithmetic budgets for stops coming out under 64. Confirmed by
measurement: a 600 point window takes the row, a 616 point one takes the
columns.

**The hand's 64 became a ceiling, not a following size.** `HandSheet` draws at
`min(board's card, m.scaled(64))`. Following the board upward changes the
hand's line height, which changes the hand's height, which changes the board's
height budget, which inflates the furniture at exactly the wide windows where
height binds, and `nothing in the aside runs off the bottom` at 1280 by 800 is
the case that would then go. With the ceiling the wide branch is unchanged:
the hand's card is 64 on every window that still has columns.

**The hand's card is worked out outside the board's `LayoutBuilder`**, from the
media width, because `HandSheet` is a sibling of the board's `Expanded` and
cannot be handed a number computed inside it. Width only, which is all the
board's card depends on in the row branch. The cost is a window short enough
for the board to be height bound: at 390 by 500 the hand draws 50.34 against a
board card of 23.49. That window was 64 against 32.19 before, so both are
wrong and neither is a phone.

**The ratio guard's bound had to change, and the old one would have stopped
working.** `the board is budgeted for both columns, not one` fell into the row
branch at 390 and passed at 1.0000 with no subject left, so it moved to a 700
by 844 window. Re-measured there by mutating `aside * 2 - gap * 2` to `* 1`:
1.1209 correct against 1.1883 mutated. **1.19 does not catch that**, so the
bound is now 1.155.

**`the graveyard is on the far side from the deck` was rewritten, not scoped.**
Scoped to a wide window it would have duplicated the new `a wide window keeps
the furniture beside the board`. It now asserts at the phone window that the
furniture went below the board and that the graveyard and the deck are still
at opposite ends of the row.

**`_Underneath` spreads across the row rather than left aligning.** Left
aligned, the deck ended 43.27 points from the screen edge against `the deck
sits to the right, not in the middle`'s bound of 78; spread, it is 16.0.

**A fourth case was needed.** Probe 4, budgeting 70 percent of the row in the
new branch, survived: the board is `Expanded` and computes its own scale, so a
wrong budget only shrinks the furniture and the suite stays green with the deck
at 0.700 of the card beside it. `the row under the board is drawn at the
board's own card` is the row branch's half of the case Step 4 pointed at.

**One thing is knowingly unpinned.** The narrow branch takes a card's height
out of the height budget, and probe 5 survives: at a phone's width it is the
width that binds and the term changes nothing there. It shows up only on a
window too short for the mat it is wide enough for, 1.53 against 2.45 at 390 by
500. Both numbers are in the comment.

**Measured at 390 by 844, before and after:** the board went from 228.92 wide
and 58.70 percent of the screen to 358.0 and 91.79 percent; the card on the
board from 32.19 to 50.34; the card in hand from 64.0 to 50.34, a ratio of
1.0000 where it was 0.503. The row fits without scrolling, 16 to 374.

## Task 2: A counter with a side to it

**Files:**
- Modify: `lib/features/play/widgets/counter_piece.dart`
- Test: `test/features/counter_piece_test.dart`

- [ ] **Step 1: Write the failing test**

The existing cases assert the mirror. Replace, do not append:

```dart
  testWidgets('it says its value once', (tester) async {
    await tester.pumpWidget(_host('+1/+1'));
    await tester.pump();

    // The plastic prints it twice so it reads from either side of a physical
    // table. On a screen one person is looking and the upside down copy is
    // noise.
    expect(find.text('+1/+1'), findsOneWidget);
  });

  testWidgets('a keyword piece says the word once', (tester) async {
    await tester.pumpWidget(_host('flying'));
    await tester.pump();

    expect(find.text('FLYING'), findsOneWidget);
  });

  testWidgets('it has a side, not just a face', (tester) async {
    await tester.pumpWidget(_host('+4/+4'));
    await tester.pump();

    // The deck reads as solid because it draws leaves behind its top card.
    // A counter gets its thickness the same way: the shape again, darker,
    // offset down and right, so there is an edge to catch the light.
    expect(find.byKey(const Key('counter-side')), findsOneWidget);
    final side = tester.getRect(find.byKey(const Key('counter-side')));
    final face = tester.getRect(find.byKey(const Key('counter-face')));
    expect(side.left, greaterThan(face.left));
    expect(side.top, greaterThan(face.top));
  });

  testWidgets('the side is darker than the face', (tester) async {
    await tester.pumpWidget(_host('+2/+2'));
    await tester.pump();

    double lightness(Key k) {
      final box = tester.widget<DecoratedBox>(find.descendant(
        of: find.byKey(k),
        matching: find.byType(DecoratedBox),
      ).first);
      return HSLColor.fromColor(
        (box.decoration as BoxDecoration).color!,
      ).lightness;
    }

    // Lit from above, which is what says the face is on top rather than the
    // two being two shapes next to each other.
    expect(lightness(const Key('counter-side')),
        lessThan(lightness(const Key('counter-face'))));
  });
```

Keep the other existing cases: the count, the single one drawing no number,
and the shadow.

- [ ] **Step 2: Run them and watch them fail**

Run: `flutter test test/features/counter_piece_test.dart`
Expected: the first two FAIL with two matches where one was expected, and the
two side cases on the missing key.

- [ ] **Step 3: One face, and a side under it**

Drop the rotated second print. Draw the chevron twice: once offset down and
right in a darker shade of the piece's own colour, keyed `counter-side`, and
once on top keyed `counter-face`.

The shadow stays: it is what puts the whole piece above the card, and the side
is what gives the piece its own depth. They are different jobs and the
existing shadow case still pins the first.

**Check the card still costs the board nothing.** The pieces are a `Positioned`
in the card's `Clip.none` `Stack` precisely so they have no size of their own,
and a second copy offset outwards is exactly the shape of thing that starts
having one. Measure the card on the board at 390 by 844 before and after and
say the two numbers.

- [ ] **Step 4: Run everything**

Run: `flutter test && flutter analyze`
Expected: PASS and `No issues found!`.

`table_card_test.dart` counts text: `a pile of numbers reads as one marker`
expects `find.text('+4/+8')` **twice** and `the marker takes the colour of the
piece it equals` reads a piece's colour. The first has to become once. Say
what you changed and what it now asserts.

- [ ] **Step 5: Probe**

- Draw the side at the same offset as the face. The third case must fail, and
  say on which of its two comparisons.
- Draw the side in the face's own colour. The fourth must fail.
- Put the second print back. The first must fail.
- Take the shadow off. The existing shadow case must fail, which is what says
  the side did not replace it.

Edit each back by hand and rerun.

- [ ] **Step 6: Commit**

```bash
git add lib/features/play/widgets/counter_piece.dart test/features/counter_piece_test.dart \
        test/features/table_card_test.dart
git commit -m "Give a counter one face and a side"
```

---

### What running Task 2 found

**Step 4 names one case in `table_card_test.dart` that counts the text twice.
There are two.** The second is `a kind nobody printed keeps its own name`,
asserting `+2/+2` twice. `git blame` puts both in c8765f6, so it is a
pre-existing pair and not something Task 1 introduced. Both became
`findsOneWidget`.

**The face's colour had to come out of the gradient.** It was
`[lerp(colour, white, 0.42), colour, lerp(colour, black, 0.26)]`; it is now
`color: colour` under a white-42 / transparent / black-26 sheen, which is the
same pixel. The fourth case reads `(decoration as BoxDecoration).color!` off
the first `DecoratedBox` under `counter-face`, and a gradient-only decoration
has a null colour there, so the case would have died on the null check instead
of comparing two lightnesses.

**Two assertions were added to the side case.** `_shape` ignoring the size it
is handed was probed at 1.4 times the box and the whole suite stayed green: the
piece's own `SizedBox` keeps the box and the `Stack` clips the overflow. The
case now also asserts the face is narrower than the piece and that the side's
bottom edge is the piece's bottom edge to a hundredth of a point. The slack is
not for its own sake: a lift plus a box less a lift lands 3e-14 past the edge
it is the same edge as, and `lessThanOrEqualTo` failed on 323.6 against
323.59999999999997.

**One probe in Step 5 was too weak as written.** Taking the shadow off by
turning `Positioned.fill` into `Positioned` left the whole suite green, because
the `DecoratedBox` carrying the `boxShadow` was still in the tree and the case
only looks for one that has one. Deleting the shadow block fails it.

**The side cost the board nothing.** The card on the board is
50.34374999999999 by 70.32142857142856 at 390 by 844 both before and after,
wearing a `+1/+1` and a `flying`, because face and side are each a lift smaller
than the piece's own box and sit at opposite corners of it.

## What this plan deliberately leaves out

- **The canvas on a phone.** It opens fitted and a single seat's strips still
  take 28 percent of the width, so the mat draws about 253 points wide on a
  390 point screen. The bands are the default below 720 and this plan fixes
  those; the canvas on a narrow window needs its own answer.
- **A portrait mat.** It would use a phone's height, and it would break the
  one invariant that makes a drop position mean the same place on two
  different devices.
- **The 28 point board in a pod on a phone.** Still the screen's vertical
  budget across bands, hand and two bars, and still untouched.
