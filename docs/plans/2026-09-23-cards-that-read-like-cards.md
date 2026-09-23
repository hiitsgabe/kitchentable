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

The screenshot showed `+3`, `+1`, `+1` stacked down a card's edge. Three
numbers with no units, which is what `Map<String, int>` looks like when the
screen prints it raw.

The player then sent a photograph of what they meant: a box of the plastic
counters that ship with a set. That settles the design and overrules an
earlier draft of this section, which proposed summing everything into one
`+4/+8` badge. **They are not a sum. They are pieces.**

What the photograph shows:

- **A chevron shape**, not a chip. A squarish tile notched top and bottom, so
  it reads as a bent corner sitting on the card.
- **The value printed twice, mirrored**, top half and bottom half, because a
  counter on a table has to be readable from the other side of it.
- **Denominations to add with, and one marker to read.** The box holds
  `+1/+1`, `+2/+2`, `+4/+4`, `-1/-1`, `+1/+0`, `+2/+0` and `+0/+1`, and those
  are what the player reaches for. But the card draws **one** numeric marker
  carrying the net, so `+4/+4` and four `+0/+1` read as a single `+4/+8`
  rather than as five objects to add up by eye. The player asked for exactly
  that: it can look like the marker in the picture, and it can be a sum.
- **A colour per denomination.** `+1/+1` black, `+2/+2` green, `+4/+4` blue,
  `-1/-1` white, `+1/+0` red, `+2/+0` cyan, `+0/+1` maroon. The summed marker
  takes the colour of the piece it happens to equal, so a net of `+4/+4` is
  blue and a net of `+2/+2` is green, and falls back to the `+1/+1` black for
  a sum nobody printed and the `-1/-1` white when the net is negative.
  Recognition where recognition exists, and no invented colours.
- **Keyword counters too**, which the app has never had: FLYING, HASTE,
  TRAMPLE, VIGILANCE, MENACE, DEATHTOUCH, LIFELINK, HEXPROOF, FIRST STRIKE,
  DOUBLE STRIKE, INDESTRUCTIBLE, REACH. Each with its own colour.
- **"a little 3d, like a popup illusion"**: the piece sits above the card
  rather than being printed on it, so it wants a shadow under it and a light
  edge along its top.

**No model change, still.** `ChangeCounter` has taken any name since plan 2
and `CardInstance.counters` is a `Map<String, int>`, so `{'+4/+4': 1,
'+0/+1': 4, 'flying': 1}` is already sayable. A `power` and `toughness` pair
would be a second way to say the same thing and the two would disagree within
a week. What is missing is entirely in the drawing and the picking.

So a kind is one of the real pieces, the player picks a denomination rather
than tapping `+1/+1` four times, and the card draws **one numeric marker for
the net**, one marker per keyword, and one for any kind nobody printed.

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

## Task 4: Counters that look like the ones in the box

Read the section headed "The counters, argued once" before this. It carries
the photograph's contents and the reason there is no model change.

**Files:**
- Create: `lib/features/play/counters.dart`
- Create: `lib/features/play/widgets/counter_piece.dart`
- Modify: `lib/features/play/widgets/table_card.dart`
- Modify: `lib/ui/organisms/card_viewer.dart`
- Test: `test/features/counters_test.dart`, `test/features/counter_piece_test.dart`, `test/features/table_card_test.dart`

- [ ] **Step 1: Write the failing test for the pieces themselves**

Create `test/features/counters_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/counters.dart';

void main() {
  test('the box holds the denominations the box holds', () {
    final names = counterPieces.map((p) => p.name).toList();

    // Straight off the photograph. Four power and four toughness is a +4/+4,
    // not four +1/+1s in a pile, which is the whole reason these are
    // denominations and not a count.
    expect(names, containsAll(
        ['+1/+1', '+2/+2', '+4/+4', '-1/-1', '+1/+0', '+2/+0', '+0/+1']));
  });

  test('the keyword counters are there too', () {
    final names = counterPieces.map((p) => p.name).toList();

    expect(names, containsAll([
      'flying', 'haste', 'trample', 'vigilance', 'menace', 'deathtouch',
      'lifelink', 'hexproof', 'first strike', 'double strike',
      'indestructible', 'reach',
    ]));
  });

  test('every piece has its own colour', () {
    final colours = counterPieces.map((p) => p.colour.toARGB32()).toList();

    // A box where two pieces are the same colour is a box you have to read
    // rather than recognise.
    expect(colours.toSet(), hasLength(colours.length));
  });

  test('a number piece says what it does to power and toughness', () {
    expect(pieceNamed('+4/+4')!.power, 4);
    expect(pieceNamed('+4/+4')!.toughness, 4);
    expect(pieceNamed('-1/-1')!.power, -1);
    expect(pieceNamed('+1/+0')!.toughness, 0);
    expect(pieceNamed('+0/+1')!.power, 0);
  });

  test('a keyword piece changes no numbers', () {
    for (final piece in counterPieces.where((p) => p.isKeyword)) {
      expect(piece.power, 0);
      expect(piece.toughness, 0);
    }
  });

  test('a kind nobody printed is still a counter', () {
    // `ChangeCounter` has taken any name since plan 2 and a card can arrive
    // carrying `charge` or `loyalty`. Those are not in the box and still have
    // to draw.
    expect(pieceNamed('loyalty'), isNull);
    expect(unknownPiece('loyalty').name, 'loyalty');
    expect(unknownPiece('loyalty').power, 0);
  });

  test('what a pile of pieces does to a creature', () {
    final on = {'+4/+4': 1, '+0/+1': 4, 'flying': 1, 'charge': 3};

    // Four and four from the one piece, four more toughness from the four,
    // and nothing at all from the keyword or from the kind nobody printed.
    expect(powerFrom(on), 4);
    expect(toughnessFrom(on), 8);
  });

  test('nothing on a card is nothing added', () {
    expect(powerFrom(const {}), 0);
    expect(toughnessFrom(const {}), 0);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/counters_test.dart`
Expected: FAIL, `Error when reading 'lib/features/play/counters.dart'`.

- [ ] **Step 3: Write the box**

A `CounterPiece` is a name, a colour, and what it does to power and toughness.
`counterPieces` is the list from the photograph, `pieceNamed` finds one,
`unknownPiece` makes a grey one for a kind nobody printed, and `powerFrom`
and `toughnessFrom` sum a card's map.

The colours are from the photograph and belong in a comment saying so:
`+1/+1` black, `+2/+2` green, `+4/+4` blue, `-1/-1` white, `+1/+0` red,
`+2/+0` cyan, `+0/+1` maroon, and the keywords as they appear there.

`Palette` is the app's chrome and these are not chrome: they are printed
objects with their own colours. Put them here rather than in `Palette`, and
say why in a comment.

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/features/counters_test.dart`
Expected: PASS, 8 tests.

- [ ] **Step 5: Write the failing test for the piece**

Create `test/features/counter_piece_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/counters.dart';
import 'package:kitchentable/features/play/widgets/counter_piece.dart';

Widget _host(String kind, {int count = 1}) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: CounterPieceView(
            piece: pieceNamed(kind) ?? unknownPiece(kind),
            count: count,
            width: 40,
          ),
        ),
      ),
    );

void main() {
  testWidgets('it says its value twice, the way the plastic does',
      (tester) async {
    await tester.pumpWidget(_host('+1/+1'));
    await tester.pump();

    // Printed at both ends so it reads from the other side of the table,
    // which is what the real ones do and why they are shaped the way they
    // are.
    expect(find.text('+1/+1'), findsNWidgets(2));
  });

  testWidgets('more than one of a kind says how many', (tester) async {
    await tester.pumpWidget(_host('+1/+1', count: 3));
    await tester.pump();

    // Three pieces drawn three times would cover the card. One piece and a
    // number is what a stack of three looks like from above anyway.
    expect(find.textContaining('3'), findsWidgets);
  });

  testWidgets('a single one does not count itself', (tester) async {
    await tester.pumpWidget(_host('+2/+2'));
    await tester.pump();

    expect(find.text('1'), findsNothing);
    expect(find.textContaining('x'), findsNothing);
  });

  testWidgets('a keyword piece says the word', (tester) async {
    await tester.pumpWidget(_host('flying'));
    await tester.pump();

    expect(find.text('FLYING'), findsNWidgets(2));
  });

  testWidgets('it stands off the card', (tester) async {
    await tester.pumpWidget(_host('+4/+4'));
    await tester.pump();

    // "a little 3d, like a popup illusion". A shadow under it and a light
    // edge along its top is what makes a printed shape read as an object
    // lying on the card rather than as ink on it.
    final decorated = tester.widgetList<DecoratedBox>(
      find.byType(DecoratedBox),
    );
    expect(
      decorated.any((d) => (d.decoration as BoxDecoration).boxShadow != null),
      isTrue,
      reason: 'nothing here casts a shadow, so nothing is on top of anything',
    );
  });
}
```

- [ ] **Step 6: Write the piece**

`CounterPieceView` draws the chevron. The shape from the photograph is a
squarish tile notched into a V at the top and the bottom, so the silhouette
reads as a bent corner. A `CustomPainter` with a `Path`, or a `ClipPath` over
a gradient, either is fine: the shape is the part to get right and the
implementer's eye is better than a plan's words here.

The 3D is a `boxShadow` below and a lighter gradient stop along the top edge.
Do not reach for a `Transform` with a perspective matrix: the card itself
already turns, and a piece with its own vanishing point fights it.

**A count of one draws no number.** One `+1/+1` is a piece, not a pile.

- [ ] **Step 7: Put them on the card and in the viewer**

`TableCard` replaces its column of pills with a row of pieces along the bottom
edge of the card, overlapping slightly the way they do in a pile. The viewer's
kind picker offers `counterPieces` rather than the five names it has now, each
drawn as its own piece so the player picks the object rather than a word.

Append to `test/features/table_card_test.dart`:

```dart
  testWidgets('a card wearing counters shows the pieces', (tester) async {
    await tester.pumpWidget(_host(
      const CardInstance(
        id: 'a',
        oracleId: 'o',
        counters: {'+4/+4': 1, 'flying': 1},
      ),
    ));
    await tester.pump();

    expect(find.byType(CounterPieceView), findsNWidgets(2));
  });

  testWidgets('a pile of numbers reads as one marker', (tester) async {
    await tester.pumpWidget(_host(
      const CardInstance(
        id: 'a',
        oracleId: 'o',
        counters: {'+4/+4': 1, '+0/+1': 4, 'flying': 1},
      ),
    ));
    await tester.pump();

    // Five objects to add up by eye is what the raw map looked like. One
    // marker saying the net, plus the keyword, which is not a number and has
    // nothing to add to.
    expect(find.byType(CounterPieceView), findsNWidgets(2));
    expect(find.text('+4/+8'), findsNWidgets(2));
  });

  testWidgets('a kind nobody printed keeps its own name', (tester) async {
    await tester.pumpWidget(_host(
      const CardInstance(
        id: 'a',
        oracleId: 'o',
        counters: {'+1/+1': 2, 'charge': 3},
      ),
    ));
    await tester.pump();

    // `charge` does nothing to power or toughness, so it cannot join the sum
    // and has to stand on its own with its count.
    expect(find.text('+2/+2'), findsNWidgets(2));
    expect(find.textContaining('charge'), findsWidgets);
  });
```

**The existing case `two kinds of counter are told apart` asserts
`Key('counter-+1/+1')` and `Key('counter-damage')`.** Keep those keys on the
pieces so it goes on meaning what it means, or say why it had to change and
what the replacement asserts.

- [ ] **Step 8: Run everything**

Run: `flutter test && flutter analyze`
Expected: PASS and `No issues found!`, WARNING and Warning both 0.

**Measure the card on the board at 390 by 844 before and after.** Pieces along
a card's edge are inside the card's own box and should cost the board nothing,
but that is the third thing this project has added to a card and the first two
both cost 9.7 percent. Say the two numbers.

- [ ] **Step 9: Probe**

- Make every piece the same colour. The colour case must fail on the set's
  length.
- Give a keyword piece a power of 1. Say which cases fail, and whether
  `what a pile of pieces does to a creature` is one of them.
- Make the summed marker take the `+1/+1` black always. The colour is not
  asserted by any case above: **say so** rather than claiming it is covered,
  and say what a case for it would have to read. A `find.byType` on the view
  can reach its `piece`, so it is reachable without a golden.
- Draw the value once rather than twice. The first piece case must fail on
  `findsNWidgets(2)`.
- Take the shadow off. The standing off case must fail. If it does not, the
  shadow is on a widget the finder cannot see and the case is worthless: say
  so and fix the case rather than the code.
- Make `count: 1` draw its number. The third piece case must fail.

Say which assertion each time, with its line. Edit each back by hand and
rerun.

- [ ] **Step 10: Commit**

```bash
git add lib/features/play lib/ui/organisms/card_viewer.dart test/features
git commit -m "Put the counters from the box on the cards"
```

---

## Tasks 5 onward

The rest of what the player sent, written after the counters land:

- **Right click opens a card's options**, the same menu a press and hold
  opens, on a second gesture rather than behind a second menu.
- **The commander goes to its own zone** rather than to the graveyard.
- **The graveyard pages** rather than listing a hundred cards in one scroll.
- **The token search finds tokens**, filtered on the type line the catalog
  already stores.
- **The list draws a readable card.** `artFor` already picks by drawn width
  times pixel ratio, so this has to be measured before it is fixed: either a
  list asks for less than it draws, or the file it picks is not the one
  reaching the screen.
