# Cards that read like cards, implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A hand you can see all of, a face down card that looks like a card,
a deck that visibly empties, options on a right click, a commander that goes
where commanders go, and counters that look like the ones in the box.

**Architecture:** No new verb, and no new field on `CardInstance`. The
asymmetric counters the player asked for are already expressible: Magic ships
`+1/+0` and `+0/+1` counters, so `+4/+8` is four of one and eight of the other
and the model has taken any counter name since plan 2. What is missing is a
screen that reads them as one number and draws it like a counter.

**Tech Stack:** Flutter 3.47.5, Dart 3.13.4, flutter_riverpod 3.4.3.

---

## Where this came from

The player used the build on 2026 09 23 and sent ten things. Two are model
questions and the rest are the screen lying about what is underneath it.

**"No way to scroll hand if the hand is bigger than the width size."** Known
and written down since the hand gained reordering: a card's drag wins the
gesture arena over the list's scroll, so on a hand wider than the sheet the
drag rearranges instead of scrolling. It was left alone then and it is biting
now.

**"the face down card should show the default back image for the card."**
`TableCard` draws `CardBack(width: width)` with no game, and a `CardBack` with
no game has no picture to fetch, so it draws the plain outlined box. The real
Magic back has been in the app since the pile learned to draw one.

**"The deck should get smaller (less card) when drawing cards."** The pile's
thickness saturates at twelve leaves, so between 92 cards and 91 nothing
moves, and between 92 and 20 nothing moves either.

**"it would be nice if the card options where shown with right click."**

**"The commander cant go to grayveward."**

**"those attributes should be available for all cards, should be configurable
(a card can have a +4/+8 for example) and should be visible on the card on the
battlefield. the numbers are pretty confusing here... It should look like the
tokens from the real mtg sets."**

**"Grayerd needs pagination on the listing"**, **"the tokens list should
filter to tokens, treasures and etc"**, and **"The list view has a low quality
image for the cards."**

## The counters, argued once

The screenshot shows `+3`, `+1`, `+1` stacked down a card's edge. Three
numbers with no units, which is what `Map<String, int>` looks like when the
screen prints it raw.

**No model change.** `ChangeCounter` has taken any name since plan 2, and
Magic itself answers the asymmetric case: `+1/+0` and `+0/+1` counters are
real, printed cards make them, and `+4/+8` is four of one and eight of the
other. A `power` and `toughness` pair on `CardInstance` would be a second way
to say the same thing and the two would disagree within a week.

What changes is the reading:

- The kinds offered become the ones in the box: `+1/+1`, `-1/-1`, `+1/+0`,
  `+0/+1`, plus whatever is already on the card.
- The card sums them into **one** power and toughness delta and draws it as a
  single badge, `+4/+8`, the way a stack of counters reads at a table.
- Counters that are not about power and toughness, `loyalty`, `charge`,
  `damage`, keep their own badge with their own name, because they are a
  different question.
- The badge is drawn like the plastic: a rounded lozenge in the counter's
  colour with the value on it, not a chip with a bare number.

---

## Task 1: A hand you can see all of

**Files:**
- Modify: `lib/features/play/widgets/hand_sheet.dart`
- Test: `test/features/hand_sheet_test.dart`

- [ ] **Step 1: Write the failing test**

Append to `test/features/hand_sheet_test.dart`:

```dart
  testWidgets('a hand too wide to fit wraps instead of scrolling',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(cards: 16));
    await tester.pump();

    final sheet = tester.getRect(find.byType(HandSheet));
    final first = tester.getRect(find.byType(TableCard).first);
    final last = tester.getRect(find.byType(TableCard).last);

    // Every card on screen, on more than one line. Scrolling was never
    // reachable: a card's own drag wins the gesture arena over the list's,
    // so dragging rearranged the hand instead of moving it, and there was no
    // other way to reach the far end.
    expect(last.right, lessThanOrEqualTo(sheet.right + 1));
    expect(last.top, greaterThan(first.top),
        reason: 'sixteen cards are still on one line');
  });

  testWidgets('a hand that fits stays on one line', (tester) async {
    await tester.pumpWidget(_host(cards: 3));
    await tester.pump();

    final first = tester.getRect(find.byType(TableCard).first);
    final last = tester.getRect(find.byType(TableCard).last);

    expect(last.top, first.top);
  });

  testWidgets('the sheet grows for a second line but not without end',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(cards: 3));
    await tester.pump();
    final one = tester.getSize(find.byType(HandSheet)).height;

    await tester.pumpWidget(_host(cards: 16));
    await tester.pump();
    final two = tester.getSize(find.byType(HandSheet)).height;

    await tester.pumpWidget(_host(cards: 60));
    await tester.pump();
    final many = tester.getSize(find.byType(HandSheet)).height;

    expect(two, greaterThan(one));
    // A hand of sixty is a Battle of Wits deck and it still cannot be allowed
    // to eat the battlefield. Past the cap the cards get smaller instead.
    expect(many, two);
  });
```

- [ ] **Step 2: Run them and watch them fail**

Run: `flutter test test/features/hand_sheet_test.dart`
Expected: the first FAILS on `last.right` running past the sheet, because a
sixteen card hand is a scrolling row today.

- [ ] **Step 3: Wrap it**

Replace the scrolling branch with a `Wrap`. The centred branch already exists
and a `Wrap` centres by itself, so the two branches collapse into one:
`Wrap(alignment: WrapAlignment.center, ...)`.

Cap the sheet at two lines. Past what two lines hold, shrink the cards to fit
rather than growing the sheet: the hand sits under the board and every point
it takes is a point the battlefield loses, which is the arithmetic Task 2 of
the last plan spent itself on.

**The reorder still has to work.** `hand_sheet_test.dart` has a case that
drags a card sideways and asserts the index it reports. A `Wrap` changes how
an index is worked out from a drop position: it is no longer x over the card
pitch, it is a row and a column. If that case fails, report the numbers.

- [ ] **Step 4: Run them and watch them pass**

Run: `flutter test && flutter analyze`
Expected: PASS and `No issues found!`.

- [ ] **Step 5: Probe**

Take the two line cap off. The third case must fail on `many` being greater
than `two`. Then centre the `Wrap` to the left: the case from the last plan
about a few cards sitting in the middle must fail. Say which assertion each.
Edit each back by hand, never with `git checkout`, and rerun.

- [ ] **Step 6: Commit**

```bash
git add lib/features/play/widgets/hand_sheet.dart test/features/hand_sheet_test.dart
git commit -m "Wrap the hand so every card is reachable"
```

---

## Task 2: A face down card looks like a card

**Files:**
- Modify: `lib/features/play/widgets/table_card.dart`
- Modify: its callers
- Test: `test/features/table_card_test.dart`

- [ ] **Step 1: Write the failing test**

Append to `test/features/table_card_test.dart`:

```dart
  testWidgets('a face down card shows the game s own back', (tester) async {
    await tester.pumpWidget(_host(
      const CardInstance(id: 'a', oracleId: 'o', faceDown: true),
      game: Game.magic,
    ));
    await tester.pump();

    // The real back, not the outlined box a CardBack draws when it does not
    // know which game it is. That box is for a token and for a card the
    // catalog has never heard of.
    expect(find.byKey(const Key('card-back-art')), findsOneWidget);
  });

  testWidgets('a card of no game still draws something', (tester) async {
    await tester.pumpWidget(_host(
      const CardInstance(id: 'a', oracleId: 'o', faceDown: true),
    ));
    await tester.pump();

    expect(find.byType(CardBack), findsOneWidget);
    expect(find.byKey(const Key('card-back-art')), findsNothing);
  });
```

`_host` in that file needs a `Game? game` passed through.

- [ ] **Step 2: Run them and watch them fail**

Expected: the first FAILS on `card-back-art` not being found.

- [ ] **Step 3: Tell the card which game it is**

`TableCard` gains `Game? game` and passes it to `CardBack`. Its callers have
it or can reach it: `play_screen.dart` reads `play.gameAt(seat.id)` already
for the pile, `free_canvas.dart` and `cursor_board.dart` take it as a
parameter, and `hand_sheet.dart` and `seat_band.dart` need it threading the
same way.

**Grep every construction of `TableCard` before you start** and list them in
your report. A default of null is right: a widget that draws a card in a test
harness has no game and should still draw.

- [ ] **Step 4: Run everything**

Run: `flutter test && flutter analyze`
Expected: PASS and `No issues found!`.

- [ ] **Step 5: Probe**

Drop the game where `TableCard` passes it on. The first case must fail on the
key. Say which assertion. Edit it back by hand and rerun.

- [ ] **Step 6: Commit**

```bash
git add lib/features/play lib/ui test/features/table_card_test.dart
git commit -m "Turn a card over onto its own back"
```

---

## Task 3: A deck that empties

**Files:**
- Modify: `lib/features/play/widgets/library_stack.dart`
- Test: `test/features/library_stack_test.dart`

- [ ] **Step 1: Write the failing test**

Append to `test/features/library_stack_test.dart`:

```dart
  testWidgets('drawing from a full deck makes it visibly thinner',
      (tester) async {
    await tester.pumpWidget(_host(count: 92, of: 100));
    await tester.pump();
    final full = tester.getSize(find.byKey(const Key('library-stack'))).height;

    await tester.pumpWidget(_host(count: 46, of: 100));
    await tester.pump();
    final half = tester.getSize(find.byKey(const Key('library-stack'))).height;

    await tester.pumpWidget(_host(count: 4, of: 100));
    await tester.pump();
    final nearly = tester.getSize(find.byKey(const Key('library-stack'))).height;

    // The thickness used to saturate at twelve cards, so a Commander deck sat
    // at its full height from 100 all the way down to 12 and then dropped.
    // Drawing eighty cards changed nothing on the table.
    expect(half, lessThan(full));
    expect(nearly, lessThan(half));
  });

  testWidgets('a deck of sixty and a deck of a hundred both start full',
      (tester) async {
    await tester.pumpWidget(_host(count: 60, of: 60));
    await tester.pump();
    final sixty = tester.getSize(find.byKey(const Key('library-stack'))).height;

    await tester.pumpWidget(_host(count: 100, of: 100));
    await tester.pump();
    final hundred =
        tester.getSize(find.byKey(const Key('library-stack'))).height;

    // Thickness is how much is left of what there was, not an absolute count.
    // A Pauper deck at sixty is a full deck and should look like one.
    expect(sixty, hundred);
  });

  testWidgets('an empty deck is flat', (tester) async {
    await tester.pumpWidget(_host(count: 0, of: 60));
    await tester.pump();

    final flat = tester.getSize(find.byKey(const Key('library-stack')));
    expect(flat.height, closeTo(flat.width * 88 / 63, 1));
  });
```

`_host` needs an `of` for the deck's starting size.

- [ ] **Step 2: Run them and watch them fail**

Expected: the first FAILS with `half` equal to `full`, both saturated.

- [ ] **Step 3: Make the thickness a fraction**

`LibraryStack` gains `int? of`, the size the deck started at. The leaf count
becomes the fraction of it that is left, scaled to `_mostLeaves`, so a full
deck of any size is full and drawing thins it all the way down.

`of` is null for a pile that has no starting size, which is the graveyard: a
graveyard grows rather than empties, so its thickness stays the count it
already used. **`spreadFor` is read by the screen's width arithmetic**, so
whatever it returns has to stay a function of what it is given: check its
callers before changing its signature.

- [ ] **Step 4: Run everything**

Run: `flutter test && flutter analyze`
Expected: PASS and `No issues found!`. `play_screen.dart` has to pass `of`:
the deck's starting size is the decklist's size, which `PlayController` knows
at `startPod` and the table does not. Put it where the game already lives.

- [ ] **Step 5: Probe**

Make the fraction always 1. The first case must fail, and say on which of its
two assertions. Then make the leaf count the raw count again: say what fails,
and whether the second case catches it.

- [ ] **Step 6: Commit**

```bash
git add lib/features/play test/features/library_stack_test.dart
git commit -m "Thin the deck as it is drawn"
```

---

## Tasks 4 onward

Written after these three land. They cover the rest of what the player sent:

- **Right click opens a card's options**, which is the same menu a press and
  hold opens and needs a second gesture rather than a second menu.
- **The commander goes to its own zone** rather than to the graveyard.
- **Counters that look like the ones in the box**, summed into one power and
  toughness delta, as argued at the top of this plan.
- **The graveyard pages** rather than listing a hundred cards in one scroll.
- **The token search finds tokens**, filtered by the type line the catalog
  already stores.
- **The list draws a readable card**, which has to be measured before it is
  fixed: `artFor` already picks by drawn width times pixel ratio, so either a
  list is asking for less than it draws or the picked file is not the one
  reaching the screen.
