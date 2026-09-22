# A table that feels like one, implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cards you can read, resize, hover and rearrange anywhere; a commander
that sits out where it belongs; and a library you can see, shuffle and look
into.

**Architecture:** Still eleven verbs. Looking into the library and putting cards
back is `MoveCard` with an `at`, shuffling is `ShuffleZone`, and the commander
already lives in its own zone that the library never sees. Almost all of this
is screen work over a model that already does it.

**Tech Stack:** Flutter 3.47.5, Dart 3.13.4, flutter_riverpod 3.4.3, drift 2.35.

---

## Where this came from

The player used the pod build on 2026 09 22 and gave a list.

**"qualidade baixa".** Measured rather than guessed: `TableCard` calls
`CardArt` without `large`, so the battlefield draws Scryfall's `small` file,
146 pixels wide. Running the task found it is broader than that: **no call
site anywhere passed `large:`**, all five left it at its default, so the card
viewer that fills the screen was drawing thumbnails too. On the player's window a card is about 270 logical points,
which at devicePixelRatio 2 is 540 device pixels. A thumbnail is being blown
up three and a half times. This is not a `normal` versus `large` question, it
is the board asking for a thumbnail.

**"deveria deixar redimensionar um pouco as cartas".**

**"na visao com todos os jogadores vc deveria conseguir reposicionar as cartas
da sua mesa".** Plan A put dragging on your own board only and said so.

**"tudo que eu pedi tipo hover deck e etc nao foi feito".** True. Hover, the
centred hand, the mat near your hand and the 3D library were split into a
second plan and that plan had not been written. This is it.

**The library needs buttons:** shuffle with a confirmation, and look at the top
X and decide where they go, some to the top and some to the bottom.

**The commander must sit on the table, top right, and never go to the deck.**

## What the model already does

Read these before writing anything, because three of the asks are screen work
over a model that is already correct.

**The commander never enters the library.** `setup.dart` splits each deck by
`slot.commander` into a `command-<seat>` zone and a `library-<seat>` zone
before it shuffles, and `ShuffleZone` names one zone. There is no path by
which a shuffle reaches it. What is missing is that no screen draws the
command zone at all.

**Looking into a library needs no new verb.** `MoveCard` takes an `at`, and
`Zone.add` inserts at that index, so putting a card back on top is `at: 0` and
on the bottom is `at: zone.size`. `apply`'s `_move` lifts the card out before
putting it back, which is what makes a move inside one pile work.

**Zone visibility is already three states.** A library is `hidden`, meaning
nobody reads it, its owner included. Looking at the top N is a deliberate,
temporary act by the owner, and it is a screen state, not a zone state. Do not
change the zone's visibility to implement it.

## File structure

```
lib/
  sources/
    catalog/catalog_db.dart       MODIFY  schema 5: the large image
    model/catalog_card.dart       MODIFY  imageLarge
  ui/atoms/card_art.dart          MODIFY  picks a file by how big it is drawn
  features/play/
    card_size.dart                NEW     how big the player wants cards
    widgets/
      table_card.dart             MODIFY  asks for the right file, and hovers
      hover_card.dart             NEW     a bigger card under the pointer
      library_stack.dart          NEW     the deck as a pile that shrinks
      look_at_top.dart            NEW     top N, and where each one goes
      command_slot.dart           NEW     the commander, top right, always out
    renderers/free_canvas.dart    MODIFY  drag your own cards here too
    widgets/hand_sheet.dart       MODIFY  centred, and reorderable
```

---

## Task 1: Cards you can read

**Files:**
- Modify: `lib/sources/model/catalog_card.dart`
- Modify: `lib/sources/catalog/catalog_db.dart`
- Modify: `lib/ui/atoms/card_art.dart`
- Test: `test/ui/card_art_test.dart`, `test/sources/card_faces_test.dart`
- Modify: `lib/features/sources/` (the stale pictures line and its provider)

`table_card.dart` needs no change: it never passed `large`, which is the bug.

- [ ] **Step 1: Write the failing test for picking a file**

Create `test/ui/card_art_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';
import 'package:kitchentable/ui/atoms/card_art.dart';

const _full = CatalogCard(
  oracleId: 'o',
  name: 'Sol Ring',
  typeLine: 'Artifact',
  cmc: 1,
  imageSmall: 'small.jpg',
  imageNormal: 'normal.jpg',
  imageLarge: 'large.jpg',
);

void main() {
  test('a thumbnail in a list takes the small file', () {
    // Scryfall's small is 146 wide. A deck row draws at about 40 points.
    expect(artFor(_full, width: 40, pixelRatio: 2), 'small.jpg');
  });

  test('a card on the battlefield does not take a thumbnail', () {
    // 90 points at ratio 2 is 180 device pixels, already past small's 146.
    // This is the bug the player reported as "qualidade baixa": the board
    // asked for small and blew it up three and a half times.
    expect(artFor(_full, width: 90, pixelRatio: 2), isNot('small.jpg'));
  });

  test('a card that fills the screen takes the large file', () {
    expect(artFor(_full, width: 340, pixelRatio: 2), 'large.jpg');
  });

  test('the device pixel ratio counts, not the points', () {
    // The same card on a three times screen needs a bigger file than on a one
    // times screen, and the widget only knows points.
    expect(artFor(_full, width: 80, pixelRatio: 1), 'small.jpg');
    expect(artFor(_full, width: 80, pixelRatio: 3), isNot('small.jpg'));
  });

  test('a catalog imported before the large column falls back', () {
    const old = CatalogCard(
      oracleId: 'o',
      name: 'Sol Ring',
      typeLine: 'Artifact',
      cmc: 1,
      imageSmall: 'small.jpg',
      imageNormal: 'normal.jpg',
    );

    // A schema bump does not refetch 36000 rows. Everything imported before
    // this column has a null there and must still draw.
    expect(artFor(old, width: 340, pixelRatio: 2), 'normal.jpg');
  });

  test('a card with no pictures at all returns nothing', () {
    const bare =
        CatalogCard(oracleId: 'o', name: 'Token', typeLine: 'Token', cmc: 0);

    expect(artFor(bare, width: 340, pixelRatio: 2), isNull);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/ui/card_art_test.dart`
Expected: FAIL to compile, `No named parameter with the name 'imageLarge'` and
`Method not found: 'artFor'`.

- [ ] **Step 3: Add the column and the chooser**

In `lib/sources/model/catalog_card.dart`, add the field beside `imageNormal`:

```dart
    this.imageLarge,
```

```dart
  /// Scryfall's `large`, 672 pixels wide. The biggest the app ever needs: the
  /// `png` above it is 745 wide and several times the bytes for a card that
  /// is already sharper than any screen here draws it.
  final String? imageLarge;
```

and in `fromScryfall`, beside the other two (the method is `fromScryfall`,
not `fromJson`):

```dart
      imageLarge: images?['large'] as String?,
```

Read the file first: `fromScryfall` already resolves `images` from
`image_uris` or from the first face, so this is one line using what is there.

**Pin that line.** Throwing the large URL away at import cannot be recovered
without refetching the whole catalog, so append to
`test/sources/card_faces_test.dart`: a record with a `large` keeps it, a
record without one reports null, and a transforming card takes the front
face's. Returning null from that line must fail two of the three.

In `lib/sources/catalog/catalog_db.dart`, add to the `Cards` table beside
`imageNormal`:

```dart
  TextColumn get imageLarge => text().nullable()();
```

Bump `schemaVersion` to 5 and add the arm, following the shape of the
`from < 4` one directly above it:

```dart
          if (from < 5) {
            // Null on every existing row, which falls back to the normal file
            // the way those cards already drew. A reimport fills it in.
            await m.addColumn(cards, cards.imageLarge);
          }
```

Add `imageLarge` to the two mapping sites in that file, beside `imageNormal`:
`Value(c.imageLarge)` going in and `row.imageLarge` coming out.

Then run `dart run build_runner build --delete-conflicting-outputs` to
regenerate `catalog_db.g.dart`. **That file is generated and tracked; commit
it with the rest and do not hand edit it.**

In `lib/ui/atoms/card_art.dart`, above the class:

```dart
/// Which file to fetch for a card drawn this big.
///
/// Scryfall's sizes are small 146, normal 488 and large 672 pixels wide. The
/// board used to ask for small whatever it was drawing, so a card at 90 points
/// on a two times screen was a 146 pixel picture stretched to 180 and then to
/// 540 when the player opened the window wide. That is what "qualidade baixa"
/// was.
///
/// Null when the card has no picture at all, which is a token or a card from a
/// source that was cleared.
String? artFor(
  CatalogCard card, {
  required double width,
  required double pixelRatio,
}) {
  final needed = width * pixelRatio;
  if (needed > 488 && card.imageLarge != null) return card.imageLarge;
  if (needed > 146 && card.imageNormal != null) return card.imageNormal;
  return card.imageSmall ?? card.imageNormal ?? card.imageLarge;
}
```

Replace the `large` parameter's use inside `build`:

```dart
    final url = artFor(
      card,
      width: width,
      pixelRatio: MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
    );
```

Grep `CardArt(` for callers passing `large:` before deciding what to do with
the field. The answer is none, so delete the field and its use outright: an
unused parameter that used to choose the picture is exactly the kind of thing
somebody passes again later expecting it to work.

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/ui/card_art_test.dart`
Expected: PASS, 6 tests.

Then `flutter test && flutter analyze`. Existing tests construct `CatalogCard`
without `imageLarge`, which is fine because it is optional. If analyze reports
`large` as unused, delete the parameter and every call site.

- [ ] **Step 5: Probe**

Change `needed > 146` to `needed > 1460`. Three cases must fail, not two: the
battlefield one, the pixel ratio one, and the fallback one, which crosses the
same threshold on its way to the normal file. Edit it back by hand, never with
`git checkout`, and rerun.

- [ ] **Step 6: Say so in the app**

A catalog imported before this runs has no large images and will keep drawing
the normal file. That is correct and invisible, which is the problem: the
player will re-read this sentence rather than re-import.

**The sources screen shows no card count.** That count lives in the menu
headline, `lib/features/menu/menu_controller.dart:34`. Put the line at the end
of the sources screen's `children` in the faint style `_Note` uses in
`import_screen.dart`, and put the provider in
`lib/features/sources/import_controller.dart` so the commit's `git add` covers
it. The line, shown when any card has a null `imageLarge`:

```dart
  'Imported before sharper pictures were added. Re-import to get them.'
```

Read `lib/features/sources/` first and follow whatever that screen already
does for status lines. Add a `Future<bool> needsBetterPictures()` to
`CatalogDb` that answers with one query rather than loading rows:

```dart
  /// True when anything in the catalog predates the large image column.
  ///
  /// `AsyncValue.value` is already nullable in riverpod 3.4.3, so the screen
  /// reads `ref.watch(...).value ?? false`. There is no `valueOrNull`.
  Future<bool> needsBetterPictures() async {
    final query = select(cards)
      ..where((c) => c.imageLarge.isNull())
      ..limit(1);
    return await query.getSingleOrNull() != null;
  }
```

- [ ] **Step 7: Commit**

Making the sources screen watch the catalog makes its three widget cases
construct a real `CatalogDb`, and drift warns twice about a second instance.
Those cases are about the source list, so add
`catalogDbProvider.overrideWithValue(null)` to
`test/features/sources_screen_test.dart`. The suite's warning count must be
zero before and after this task: `flutter test 2>&1 | grep -c "WARNING"`.

```bash
git add lib/sources lib/ui/atoms/card_art.dart lib/features/sources \
        test/ui/card_art_test.dart test/sources/card_faces_test.dart \
        test/features/sources_screen_test.dart
git commit -m "Stop drawing the board with thumbnails"
```

---

## Task 2: The commander sits out

The model is already right and this is the cheap one. `setup.dart` puts a
commander in `command-<seat>` before the shuffle, so no shuffle can reach it.
Nothing draws that zone.

**Files:**
- Create: `lib/features/play/widgets/command_slot.dart`
- Modify: `lib/features/play/play_screen.dart`
- Test: `test/features/command_slot_test.dart`, `test/table/setup_test.dart`

- [ ] **Step 1: Pin what the model already promises**

Append to `test/table/setup_test.dart`, inside `main()`. Read the file first
and use its existing deck helper rather than adding another:

```dart
  test('a commander is out of the deck before a shuffle can touch it', () {
    final table = sitDown(
      deck: _commanderDeck(),
      seatName: 'you',
      seed: 'abc',
    );

    final command = table.zone('command-s1')!;
    final library = table.zone('library-s1')!;

    expect(command.cards, hasLength(1));
    expect(library.cards.any((c) => c.oracleId == 'General'), isFalse,
        reason: 'the commander must never be in the deck');
    expect(table.zone('hand-s1')!.cards.any((c) => c.oracleId == 'General'),
        isFalse);
  });
```

`_commanderDeck()` is a deck with one `DeckSlot(..., commander: true)` named
`General` and enough other cards to deal seven. If the file already has such a
helper, use it.

- [ ] **Step 2: Run it**

Run: `flutter test test/table/setup_test.dart`
Expected: PASS with no production change. If it fails, the model is not what
this plan measured and the rest of this task is wrong: stop and report.

- [ ] **Step 3: Write the failing test for the slot**

Create `test/features/command_slot_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/widgets/command_slot.dart';
import 'package:kitchentable/features/play/widgets/table_card.dart';
import 'package:kitchentable/table/model/card_instance.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

Widget _host({
  List<CardInstance> cards = const [
    CardInstance(id: 'c0', oracleId: 'General'),
  ],
  void Function(CardInstance)? onTap,
}) =>
    MaterialApp(
      home: Scaffold(
        body: CommandSlot(
          metrics: Metrics.of(DeviceClass.handheld),
          cards: cards,
          printings: const {},
          width: 60,
          onTap: onTap ?? (_) {},
          onInspect: (_) {},
        ),
      ),
    );

void main() {
  testWidgets('the commander is drawn', (tester) async {
    await tester.pumpWidget(_host());

    expect(find.byType(TableCard), findsOneWidget);
    expect(find.text('Command'), findsOneWidget);
  });

  testWidgets('an empty slot still says what it is', (tester) async {
    await tester.pumpWidget(_host(cards: const []));

    // A Commander table always has this corner, even for the moment the
    // commander is on the battlefield. An empty corner that vanishes reads as
    // a bug.
    expect(find.text('Command'), findsOneWidget);
    expect(find.byType(TableCard), findsNothing);
  });

  testWidgets('two commanders both fit', (tester) async {
    await tester.pumpWidget(_host(cards: const [
      CardInstance(id: 'c0', oracleId: 'A'),
      CardInstance(id: 'c1', oracleId: 'B'),
    ]));

    // Partner exists, and so does Background. Two is a real hand of cards.
    expect(find.byType(TableCard), findsNWidgets(2));
  });

  testWidgets('tapping one reports it', (tester) async {
    CardInstance? tapped;
    await tester.pumpWidget(_host(onTap: (c) => tapped = c));

    await tester.tap(find.byType(TableCard).first);
    await tester.pump();

    expect(tapped?.id, 'c0');
  });
}
```

- [ ] **Step 4: Run it and watch it fail**

Run: `flutter test test/features/command_slot_test.dart`
Expected: FAIL, `Error when reading
'lib/features/play/widgets/command_slot.dart'`.

- [ ] **Step 5: Write the slot**

Create `lib/features/play/widgets/command_slot.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../sources/model/catalog_card.dart';
import '../../../table/model/card_instance.dart';
import '../../../ui/tokens/metrics.dart';
import '../../../ui/tokens/palette.dart';
import 'table_card.dart';

/// The commander, out where everybody can see it.
///
/// A commander does not start in the deck and never goes back into it: the
/// table already puts it in its own zone before the first shuffle. This is the
/// corner it sits in, top right of your own mat, and it stays drawn even while
/// the commander is on the battlefield, because a corner that appears and
/// disappears reads as a bug rather than as a rule.
class CommandSlot extends StatelessWidget {
  const CommandSlot({
    super.key,
    required this.metrics,
    required this.cards,
    required this.printings,
    required this.width,
    required this.onTap,
    required this.onInspect,
  });

  final Metrics metrics;
  final List<CardInstance> cards;
  final Map<String, CatalogCard> printings;
  final double width;
  final void Function(CardInstance) onTap;
  final void Function(CardInstance) onInspect;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Command',
          style: TextStyle(fontSize: m.scaled(10), color: Palette.inkFaint),
        ),
        SizedBox(height: m.scaled(4)),
        if (cards.isEmpty)
          Container(
            width: width,
            height: width * 88 / 63,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(width * 0.05),
              border: Border.all(color: Palette.tileEdge),
            ),
          )
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final card in cards)
                Padding(
                  padding: EdgeInsets.only(left: m.scaled(6)),
                  child: TableCard(
                    metrics: m,
                    instance: card,
                    printing: printings[card.oracleId],
                    width: width,
                    onTap: () => onTap(card),
                    onLongPress: () => onInspect(card),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
```

- [ ] **Step 6: Run it and watch it pass**

Run: `flutter test test/features/command_slot_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 7: Put it on the screen**

In `lib/features/play/play_screen.dart`, read `yours` first. The command zone
is `table.zone('command-${seat.id}')`, and it is **null in a format without
commanders**: `magicZonesFor` only creates it when `format.needsCommander`.
So:

```dart
    final command = table.zone('command-${seat.id}');
```

and inside `yours`, above the board, right aligned:

```dart
        if (command != null)
          Align(
            alignment: Alignment.centerRight,
            child: CommandSlot(
              metrics: m,
              cards: command.cards,
              printings: _printings,
              width: m.scaled(52),
              onTap: (c) => play.run(
                MoveCard(cardId: c.id, toZoneId: battlefield.id),
              ),
              onInspect: _inspect,
            ),
          ),
```

Tapping it casts: the commander moves to the battlefield. Sending it back is
the viewer's job and not this task's.

- [ ] **Step 8: Run everything**

Run: `flutter test && flutter analyze`
Expected: PASS and `No issues found!`. The two `your-board` geometry cases
measure the board's own rect, and adding a row above it inside `yours` moves
that rect down without putting anything below the hand, so both must still
pass. If either fails, say which and what the rects were.

- [ ] **Step 9: Probe**

`(false ? command : library)` is the obvious mutation and it is the wrong
one: it empties the command zone, so `expect(command.cards, hasLength(1))`
throws first and the library assertion never runs. That proves the case is
alive and leaves the assertion you care about unprobed.

Leak instead, keeping the command zone intact: add
`if (slot.commander) library.add(card);` after the existing line. The library
assertion then fires with its own reason string. Edit it back by hand and
rerun.

- [ ] **Step 10: Commit**

```bash
git add lib/features/play/widgets/command_slot.dart lib/features/play/play_screen.dart \
        test/features/command_slot_test.dart test/table/setup_test.dart
git commit -m "Sit the commander out where everybody can see it"
```

---

## Task 3: Cards the size you want them

**Files:**
- Create: `lib/features/play/card_size.dart`
- Test: `test/features/card_size_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/card_size_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/card_size.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a table starts at the size the layout chose', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(cardScaleProvider), 1.0);
  });

  test('the player can make them bigger and smaller', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(cardScaleProvider.notifier).nudge(1);
    expect(container.read(cardScaleProvider), greaterThan(1.0));

    await container.read(cardScaleProvider.notifier).nudge(-1);
    expect(container.read(cardScaleProvider), 1.0);
  });

  test('it stops before a card is a dot or fills the screen', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final size = container.read(cardScaleProvider.notifier);

    for (var i = 0; i < 40; i++) {
      await size.nudge(1);
    }
    expect(container.read(cardScaleProvider), cardScaleMax);

    for (var i = 0; i < 80; i++) {
      await size.nudge(-1);
    }
    expect(container.read(cardScaleProvider), cardScaleMin);
  });

  test('it is remembered', () async {
    final first = ProviderContainer();
    await first.read(cardScaleProvider.notifier).nudge(1);
    final chosen = first.read(cardScaleProvider);
    first.dispose();

    final second = ProviderContainer();
    addTearDown(second.dispose);
    // Riverpod builds lazily and the read is async, so the provider has to be
    // touched and then given a turn before it can have restored anything.
    second.read(cardScaleProvider);
    await Future<void>.delayed(Duration.zero);

    expect(second.read(cardScaleProvider), chosen);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/card_size_test.dart`
Expected: FAIL, `Error when reading 'lib/features/play/card_size.dart'`.

- [ ] **Step 3: Write it**

Create `lib/features/play/card_size.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How much bigger or smaller than the layout's own choice.
///
/// A multiplier and not a size, because the two renderers draw at different
/// sizes already and the player is adjusting both at once. One is what the
/// layout picked.
const cardScaleMin = 0.6;
const cardScaleMax = 2.0;
const _step = 0.1;
const _key = 'cardScale';

class CardScale extends Notifier<double> {
  @override
  double build() {
    _restore();
    return 1;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_key);
    if (saved != null) state = saved.clamp(cardScaleMin, cardScaleMax);
  }

  /// One notch bigger or smaller. Notches rather than a slider because this is
  /// reachable from a D-pad, where there is nothing to drag.
  Future<void> nudge(int by) async {
    final next = (state + by * _step).clamp(cardScaleMin, cardScaleMax);
    // Floating point: ten notches of 0.1 do not land on 2.0 exactly, and the
    // test asserts the bound.
    state = double.parse(next.toStringAsFixed(2));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, state);
  }
}

final cardScaleProvider = NotifierProvider<CardScale, double>(CardScale.new);
```

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/features/card_size_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Probe**

Delete the `.clamp(cardScaleMin, cardScaleMax)` in `nudge`. The bounds case
must fail. Edit it back by hand and rerun.

- [ ] **Step 6: Wire it**

In `play_screen.dart`, `final scale = ref.watch(cardScaleProvider);` and
multiply the widths handed to `CursorBoard` and `FreeCanvas`. Both take a
card width through `_cardOnMat`, which is a private constant in each file:
give each widget a `cardScale` parameter defaulting to 1 and multiply there,
rather than exporting the constant.

Add two pills to `_TopBar` beside the renderer switch, keyed `cards-bigger`
and `cards-smaller`, calling `ref.read(cardScaleProvider.notifier).nudge(1)`
and `nudge(-1)`.

- [ ] **Step 7: Run everything and commit**

```bash
flutter test && flutter analyze
git add lib/features/play test/features/card_size_test.dart
git commit -m "Let the player set how big a card is"
```

---

## Task 4: The card under the pointer

A mouse has a hover and a touchscreen does not, so this is a desktop and web
affordance and must not change anything on a phone.

**Files:**
- Create: `lib/features/play/widgets/hover_card.dart`
- Modify: `lib/features/play/widgets/table_card.dart`
- Test: `test/features/hover_card_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/hover_card_test.dart`:

```dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/widgets/hover_card.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';
import 'package:kitchentable/table/model/card_instance.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

const _printing = CatalogCard(
  oracleId: 'o',
  name: 'Sol Ring',
  typeLine: 'Artifact',
  cmc: 1,
  imageSmall: 'small.jpg',
);

Widget _host() => MaterialApp(
      home: Scaffold(
        body: Center(
          child: HoverCard(
            metrics: Metrics.of(DeviceClass.handheld),
            instance: const CardInstance(id: 'a', oracleId: 'o'),
            printing: _printing,
            width: 60,
          ),
        ),
      ),
    );

void main() {
  testWidgets('nothing is shown until a pointer is over it', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    expect(find.byKey(const Key('hover-preview')), findsNothing);
  });

  testWidgets('a pointer over the card brings up a bigger one',
      (tester) async {
    await tester.pumpWidget(_host());

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await tester.pump();

    await mouse.moveTo(tester.getCenter(find.byType(HoverCard)));
    await tester.pump();

    expect(find.byKey(const Key('hover-preview')), findsOneWidget);
  });

  testWidgets('moving away puts it back', (tester) async {
    await tester.pumpWidget(_host());

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await tester.pump();

    await mouse.moveTo(tester.getCenter(find.byType(HoverCard)));
    await tester.pump();
    await mouse.moveTo(const Offset(5, 5));
    await tester.pump();

    expect(find.byKey(const Key('hover-preview')), findsNothing);
  });

  testWidgets('a touch does not raise it', (tester) async {
    await tester.pumpWidget(_host());

    // A finger has no hover. On a phone this widget must be inert, or every
    // tap would flash a preview.
    await tester.tap(find.byType(HoverCard));
    await tester.pump();

    expect(find.byKey(const Key('hover-preview')), findsNothing);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/hover_card_test.dart`
Expected: FAIL, `Error when reading
'lib/features/play/widgets/hover_card.dart'`.

- [ ] **Step 3: Write it**

Create `lib/features/play/widgets/hover_card.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../sources/model/catalog_card.dart';
import '../../../table/model/card_instance.dart';
import '../../../ui/atoms/card_art.dart';
import '../../../ui/tokens/metrics.dart';

/// How much bigger the card under the pointer gets.
const _hoverGrowth = 3.2;

/// A card that grows under a mouse.
///
/// A finger has no hover, so this is inert on a phone: `MouseRegion` only
/// fires for a pointer that can be somewhere without pressing, which a touch
/// never is. The preview is in an `Overlay` so it is not clipped by whatever
/// the card is sitting inside, which on the board is a mat with its own
/// bounds.
class HoverCard extends StatefulWidget {
  const HoverCard({
    super.key,
    required this.metrics,
    required this.instance,
    required this.printing,
    required this.width,
    this.child,
  });

  final Metrics metrics;
  final CardInstance instance;
  final CatalogCard? printing;
  final double width;

  /// What to draw normally. The card itself, when there is one to wrap.
  final Widget? child;

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  OverlayEntry? _entry;

  @override
  void dispose() {
    _remove();
    super.dispose();
  }

  void _remove() {
    _entry?.remove();
    _entry = null;
  }

  void _show() {
    final printing = widget.printing;
    if (printing == null || _entry != null) return;

    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final at = box.localToGlobal(Offset.zero);
    final big = widget.width * _hoverGrowth;

    _entry = OverlayEntry(
      builder: (context) {
        final screen = MediaQuery.sizeOf(context);
        // Beside the card if there is room on the right, otherwise on its
        // left, and never off the bottom.
        final left = at.dx + widget.width + big > screen.width
            ? at.dx - big - 12
            : at.dx + widget.width + 12;
        final top = (at.dy - big * 0.3)
            .clamp(12.0, (screen.height - big * 88 / 63 - 12).clamp(12.0, 1e5));

        return Positioned(
          key: const Key('hover-preview'),
          left: left.clamp(12.0, screen.width - big - 12),
          top: top,
          child: IgnorePointer(
            child: Material(
              color: Colors.transparent,
              child: CardArt(
                metrics: widget.metrics,
                card: printing,
                width: big,
              ),
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(_entry!);
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => _show(),
        onExit: (_) => _remove(),
        child: widget.child ?? const SizedBox.shrink(),
      );
}
```

The test builds `HoverCard` with no `child`, so `find.byType(HoverCard)` has
zero size and cannot be hovered. Give the test's `_host` a child: wrap a
`SizedBox(width: 60, height: 84)`. Fix that in Step 1 before running rather
than after, and say in your report that you did.

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/features/hover_card_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Probe**

Change `onExit: (_) => _remove()` to `onExit: (_) {}`. The third case must
fail. Edit it back by hand and rerun.

- [ ] **Step 6: Wrap the table card**

In `lib/features/play/widgets/table_card.dart`, wrap what `build` returns in a
`HoverCard` carrying the same instance, printing and width. Every card on a
board, in a hand and in the command slot then hovers, in one place.

Watch the existing cases: `find.byType(TableCard)` and
`tester.getCenter(find.byType(TableCard))` are used across
`cursor_board_test.dart`, `free_canvas_test.dart` and `play_screen_test.dart`.
Wrapping inside `TableCard` keeps that finder working. Wrapping `TableCard`
from outside would not, so do it inside.

- [ ] **Step 7: Run everything and commit**

```bash
flutter test && flutter analyze
git add lib/features/play test/features/hover_card_test.dart
git commit -m "Grow the card under the pointer"
```

---

## What Magic actually does to a library

Read before designing the sheet in Task 6. Checked on 2026 09 22 rather than
recalled, because the player asked for the real dynamics.

| | looks at | may go to | order |
|---|---|---|---|
| **scry N** | top N | bottom, or top | you choose, both piles |
| **surveil N** | top N | graveyard, or top | you choose the top pile |
| **fateseal N** | top N of an **opponent's** library | bottom, or top | you choose |
| impulse effects | top N | hand, rest to the bottom | **random** |
| **explore** | top 1 | hand if a land, else top or graveyard | one choice |

They are not four screens. They are one gesture with different destinations:
**look at the top N, give each card a destination, and choose the order of the
pile that goes back on top.** Random is an option for the bottom pile, not a
separate mode. Connive is not here: it draws and discards, which the table
already does with two verbs.

Fateseal points at somebody else's library, which needs the network, so Task 6
builds the sheet for your own and leaves the whose question to plan 4.

---

## Task 5: The deck, as a pile you can see

**Files:**
- Create: `lib/features/play/widgets/library_stack.dart`
- Test: `test/features/library_stack_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/library_stack_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/widgets/library_stack.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

Widget _host({
  int count = 60,
  double width = 70,
  VoidCallback? onDraw,
  VoidCallback? onWork,
}) =>
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: LibraryStack(
            metrics: Metrics.of(DeviceClass.handheld),
            count: count,
            width: width,
            onDraw: onDraw ?? () {},
            onWork: onWork ?? () {},
          ),
        ),
      ),
    );

void main() {
  testWidgets('it says how many are left', (tester) async {
    await tester.pumpWidget(_host(count: 53));

    expect(find.text('53'), findsOneWidget);
  });

  testWidgets('tapping it draws', (tester) async {
    var drew = 0;
    await tester.pumpWidget(_host(onDraw: () => drew++));

    await tester.tap(find.byKey(const Key('library-draw')));
    await tester.pump();

    expect(drew, 1);
  });

  testWidgets('a fat deck is taller than a thin one', (tester) async {
    await tester.pumpWidget(_host(count: 99));
    final fat = tester.getSize(find.byKey(const Key('library-stack'))).height;

    await tester.pumpWidget(_host(count: 4));
    await tester.pump();
    final thin = tester.getSize(find.byKey(const Key('library-stack'))).height;

    // The whole point the player asked for: the pile shrinks as it is drawn,
    // so the table looks like a table.
    expect(fat, greaterThan(thin));
  });

  testWidgets('an empty library is drawn as nothing, not as one card',
      (tester) async {
    await tester.pumpWidget(_host(count: 0));

    expect(find.text('0'), findsOneWidget);
    expect(find.byKey(const Key('library-draw')), findsNothing,
        reason: 'there is nothing to draw, so nothing offers to');
  });

  testWidgets('the stack stops growing long before a hundred', (tester) async {
    await tester.pumpWidget(_host(count: 100));
    final hundred =
        tester.getSize(find.byKey(const Key('library-stack'))).height;

    await tester.pumpWidget(_host(count: 250));
    await tester.pump();
    final many = tester.getSize(find.byKey(const Key('library-stack'))).height;

    // A Commander deck is a hundred and a real pile is about two centimetres.
    // Letting the height track the count linearly would put a two hundred and
    // fifty card pile off the screen.
    expect(many, hundred);
  });

  testWidgets('there is a way into the deck that is not drawing',
      (tester) async {
    var worked = 0;
    await tester.pumpWidget(_host(onWork: () => worked++));

    await tester.tap(find.byKey(const Key('library-work')));
    await tester.pump();

    expect(worked, 1);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/library_stack_test.dart`
Expected: FAIL, `Error when reading
'lib/features/play/widgets/library_stack.dart'`.

- [ ] **Step 3: Write it**

Create `lib/features/play/widgets/library_stack.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../ui/atoms/card_art.dart';
import '../../../ui/tokens/metrics.dart';
import '../../../ui/tokens/palette.dart';

/// How many cards of thickness the pile ever draws.
///
/// A real Commander deck is about two centimetres and the difference between
/// ninety and a hundred cards is not something anybody sees. Tracking the
/// count linearly would put a Yorion pile off the top of the screen, so the
/// drawn thickness saturates and the number underneath carries the precision.
const _mostLeaves = 12;

/// How far each leaf below the top one is offset, in points before scaling.
const _leafStep = 1.6;

/// Your deck, as a pile that gets thinner as you draw it.
///
/// Tapping draws. The second button is everything else you can do to a
/// library, which is behind its own control because shuffling by accident is
/// the one thing at a table that cannot be undone by looking.
class LibraryStack extends StatelessWidget {
  const LibraryStack({
    super.key,
    required this.metrics,
    required this.count,
    required this.width,
    required this.onDraw,
    required this.onWork,
  });

  final Metrics metrics;
  final int count;
  final double width;
  final VoidCallback onDraw;

  /// Shuffle, look at the top, and whatever else arrives later.
  final VoidCallback onWork;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final height = width * 88 / 63;
    final leaves = count > _mostLeaves ? _mostLeaves : count;
    final lift = leaves * _leafStep;

    final pile = SizedBox(
      key: const Key('library-stack'),
      width: width + lift,
      height: height + lift,
      child: Stack(
        children: [
          for (var i = leaves; i > 0; i--)
            Positioned(
              left: (leaves - i) * _leafStep,
              top: (leaves - i) * _leafStep,
              child: Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: Palette.tile,
                  borderRadius: BorderRadius.circular(width * 0.05),
                  border: Border.all(color: Palette.tileEdge),
                ),
              ),
            ),
          if (count > 0)
            Positioned(
              left: lift,
              top: lift,
              child: CardBack(metrics: m, width: width),
            ),
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (count == 0)
          pile
        else
          GestureDetector(
            key: const Key('library-draw'),
            onTap: onDraw,
            behavior: HitTestBehavior.opaque,
            child: pile,
          ),
        SizedBox(height: m.scaled(6)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: m.scaled(14),
                fontWeight: FontWeight.w700,
                color: Palette.ink,
              ),
            ),
            SizedBox(width: m.scaled(8)),
            GestureDetector(
              key: const Key('library-work'),
              onTap: onWork,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: EdgeInsets.all(m.scaled(6)),
                decoration: BoxDecoration(
                  color: Palette.tile,
                  borderRadius: BorderRadius.circular(m.scaled(8)),
                  border: Border.all(color: Palette.tileEdge),
                ),
                child: Icon(
                  Icons.more_horiz_rounded,
                  size: m.scaled(15),
                  color: Palette.inkMuted,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
```

`CardBack` does not exist. `card_art.dart` has `CardArt` and a private
`_Fallback`; the only back in the repo is an inline `Container` inside
`TableCard.build`, drawn for a face down card or one with no printing. Lift it
into `card_art.dart` as a public `CardBack` and point `TableCard` at it.
`table_card.dart` already imports `card_art.dart`, so no new imports anywhere.

It takes **only a width**: the box uses no metrics, its radius is
`width * 0.05` and its border is the default hairline. A required parameter
the widget never reads is dead weight.

Use it for the leaves of the pile too. The block above draws them as an inline
`Container` whose decoration is a character for character copy of the same
box, and leaving a second copy in the file you just deduplicated is the wrong
half of the instruction.

Lifting it changes `TableCard`, so run the whole suite before committing, not
just this file: four test files assert `find.byType(TableCard)` or
`getCenter(find.byType(TableCard))`.

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/features/library_stack_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 5: Probe**

Change `count > _mostLeaves ? _mostLeaves : count` to `count`. The saturation
case must fail. Then change it to `1`. The thickness case must fail. Each time,
check **which assertion** failed and say so, not just that the case went red.
Edit it back by hand after each, never with `git checkout`, and rerun.

- [ ] **Step 6: Commit**

`CardBack` has to come from somewhere, so this is four files, not two.

```bash
git add lib/features/play/widgets/library_stack.dart lib/ui/atoms/card_art.dart \
        lib/features/play/widgets/table_card.dart \
        test/features/library_stack_test.dart
git commit -m "Draw the deck as a pile that gets thinner"
```

---

## Task 6: Looking at the top of your deck

One sheet for scry, surveil and an impulse effect, because they are the same
gesture with different destinations. No new verb: each card leaves on a
`MoveCard`, and `at` decides top from bottom.

**Files:**
- Create: `lib/features/play/look_at_top.dart`
- Test: `test/features/look_at_top_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/look_at_top_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/look_at_top.dart';
import 'package:kitchentable/table/actions/apply.dart';
import 'package:kitchentable/table/actions/table_action.dart';
import 'package:kitchentable/table/model/card_instance.dart';
import 'package:kitchentable/table/model/seat.dart';
import 'package:kitchentable/table/model/table_state.dart';
import 'package:kitchentable/table/model/zone.dart';

TableState _table() => TableState(
      seats: [
        Seat(
          id: 's1',
          name: 'you',
          life: 40,
          zones: [
            Zone(
              id: 'library-s1',
              seatId: 's1',
              label: 'Library',
              visibility: ZoneVisibility.hidden,
              ordered: true,
              cards: const [
                CardInstance(id: 'a', oracleId: 'A'),
                CardInstance(id: 'b', oracleId: 'B'),
                CardInstance(id: 'c', oracleId: 'C'),
                CardInstance(id: 'd', oracleId: 'D'),
              ],
            ),
            const Zone(
              id: 'graveyard-s1',
              seatId: 's1',
              label: 'Graveyard',
              visibility: ZoneVisibility.public,
              ordered: true,
            ),
            const Zone(
              id: 'hand-s1',
              seatId: 's1',
              label: 'Hand',
              visibility: ZoneVisibility.owner,
              ordered: false,
            ),
          ],
        ),
      ],
    );

List<String> _library(TableState t) =>
    t.zone('library-s1')!.cards.map((c) => c.id).toList();

TableState _run(TableState table, List<TableAction> actions) =>
    actions.fold(table, apply);

void main() {
  test('putting everything back on top in the order you chose', () {
    // Scry 2, keeping both, swapped.
    final next = _run(
      _table(),
      arrange(
        libraryId: 'library-s1',
        placements: const [
          (cardId: 'b', to: Landing.top),
          (cardId: 'a', to: Landing.top),
        ],
        librarySize: 4,
      ),
    );

    expect(_library(next), ['b', 'a', 'c', 'd']);
  });

  test('sending one to the bottom', () {
    // Scry 1, bottoming it.
    final next = _run(
      _table(),
      arrange(
        libraryId: 'library-s1',
        placements: const [(cardId: 'a', to: Landing.bottom)],
        librarySize: 4,
      ),
    );

    expect(_library(next), ['b', 'c', 'd', 'a']);
  });

  test('top and bottom at once, which is what scry two really is', () {
    final next = _run(
      _table(),
      arrange(
        libraryId: 'library-s1',
        placements: const [
          (cardId: 'b', to: Landing.top),
          (cardId: 'a', to: Landing.bottom),
        ],
        librarySize: 4,
      ),
    );

    expect(_library(next), ['b', 'c', 'd', 'a']);
  });

  test('surveil sends them to the graveyard instead', () {
    final next = _run(
      _table(),
      arrange(
        libraryId: 'library-s1',
        graveyardId: 'graveyard-s1',
        placements: const [
          (cardId: 'a', to: Landing.graveyard),
          (cardId: 'b', to: Landing.top),
        ],
        librarySize: 4,
      ),
    );

    expect(_library(next), ['b', 'c', 'd']);
    expect(next.zone('graveyard-s1')!.cards.map((c) => c.id), ['a']);
  });

  test('an impulse effect takes one and bottoms the rest', () {
    final next = _run(
      _table(),
      arrange(
        libraryId: 'library-s1',
        handId: 'hand-s1',
        placements: const [
          (cardId: 'a', to: Landing.hand),
          (cardId: 'b', to: Landing.bottom),
          (cardId: 'c', to: Landing.bottom),
        ],
        librarySize: 4,
      ),
    );

    expect(_library(next), ['d', 'b', 'c']);
    expect(next.zone('hand-s1')!.cards.map((c) => c.id), ['a']);
  });

  test('nothing chosen changes nothing', () {
    final next = _run(
      _table(),
      arrange(
        libraryId: 'library-s1',
        placements: const [],
        librarySize: 4,
      ),
    );

    expect(_library(next), ['a', 'b', 'c', 'd']);
  });

  test('a destination with no zone for it is skipped, not crashed', () {
    // No graveyardId was given, so a card sent there has nowhere to go. At a
    // real table you do not get an exception for reaching for a pile that is
    // not there, which is the rule apply already follows.
    final next = _run(
      _table(),
      arrange(
        libraryId: 'library-s1',
        placements: const [(cardId: 'a', to: Landing.graveyard)],
        librarySize: 4,
      ),
    );

    expect(_library(next), ['a', 'b', 'c', 'd']);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/look_at_top_test.dart`
Expected: FAIL, `Error when reading 'lib/features/play/look_at_top.dart'`.

- [ ] **Step 3: Write the arrangement**

Create `lib/features/play/look_at_top.dart`:

```dart
import '../../table/actions/table_action.dart';

/// Where a card you have just looked at is going.
///
/// These four cover scry, surveil, fateseal and the impulse effects that take
/// one card and bottom the rest. They are one gesture with different
/// destinations, which is why this is one sheet and not four.
enum Landing { top, bottom, graveyard, hand }

/// One card and where its owner is sending it.
typedef Placement = ({String cardId, Landing to});

/// Turns a set of choices into moves.
///
/// No new verb. `MoveCard` carries an `at`, and `Zone.add` inserts there, so
/// the top is index zero and the bottom is however long the pile is when the
/// card actually goes back, which is not the size it started at. The moves come back as a
/// list rather than being applied here, because the caller is a controller
/// with a session and an undo stack and this is arithmetic.
///
/// The top pile is emitted last to first, so that the order the player put
/// them in is the order they come off. Pushing them in reading order would
/// reverse the pile, which is the bug this comment exists to stop somebody
/// tidying back in.
List<TableAction> arrange({
  required String libraryId,
  required List<Placement> placements,
  required int librarySize,
  String? graveyardId,
  String? handId,
}) {
  final moves = <TableAction>[];

  // How many of these have left the library for good by now. A card sent to
  // the bottom goes straight back in, so it costs nothing; one sent to a hand
  // or a graveyard does not, and every bottom after it lands in a pile that is
  // one shorter than the size we were handed.
  var gone = 0;

  for (final placement in placements) {
    switch (placement.to) {
      case Landing.bottom:
        // Minus one on top of that because `_move` takes the card out of the
        // library before putting it back, so the list it inserts into is
        // shorter again than the one that was counted.
        moves.add(MoveCard(
          cardId: placement.cardId,
          toZoneId: libraryId,
          at: librarySize - gone - 1,
        ));
      case Landing.graveyard:
        if (graveyardId != null) {
          moves.add(
            MoveCard(cardId: placement.cardId, toZoneId: graveyardId),
          );
          gone++;
        }
      case Landing.hand:
        if (handId != null) {
          moves.add(MoveCard(cardId: placement.cardId, toZoneId: handId));
          gone++;
        }
      case Landing.top:
        break;
    }
  }

  for (final placement in placements.reversed) {
    if (placement.to != Landing.top) continue;
    moves.add(
      MoveCard(cardId: placement.cardId, toZoneId: libraryId, at: 0),
    );
  }

  return moves;
}
```

**The bottom index is the part to get right and the part the tests pin, and it
is not a constant.** Two separate subtractions:

- `_move` in `apply.dart` takes the card out of the pile before putting it
  back, so the list it inserts into is one shorter than the one that was
  counted. That is the `- 1`.
- A single arrangement can also send cards to a hand or a graveyard, and those
  do not come back. Every bottom after one of them lands in a pile shorter
  again. That is `gone`.

An earlier draft of this block used a flat `at: librarySize - 1` on the belief
that the bottom index was fixed. It is not, and it does not misplace the card,
it **throws**: `List.insert` raises above `length`, so the impulse case dies
with `RangeError: Invalid value: Not in inclusive range 0..2: 3`. If a later
task copies a flat index from anywhere, it will crash the same way.

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/features/look_at_top_test.dart`
Expected: PASS, 7 tests.

- [ ] **Step 5: Probe**

Change `placements.reversed` to `placements`. The first case must fail on the
order coming back as `a, b` instead of `b, a`.

Then the arithmetic, and **one probe is not enough here**. Dropping either
subtraction makes `List.insert` throw, so three cases go red by exception
inside `apply` and their `expect` never runs: that proves the code does not
crash and says nothing about where the card lands. Run a third variant that
lands the card in the wrong place without throwing, `at: librarySize - gone - 2`,
and confirm three real assertion failures naming the position. Say which
assertion failed each time, not just that the case went red. Edit each back by
hand and rerun.

- [ ] **Step 6: Commit**

```bash
git add lib/features/play/look_at_top.dart test/features/look_at_top_test.dart
git commit -m "Work out where cards go after you have looked at them"
```

---

## Task 7: Working the deck

`LibraryStack` and `arrange` both have no caller. That is the sixth time in
this project that something has been built for a reader that never arrived,
after `rename`, `makeCommander`, the refusal path, `seenBy` and the two
renderers. This task is where they get one.

**Files:**
- Create: `lib/features/play/widgets/deck_sheet.dart`
- Modify: `lib/features/play/play_screen.dart`
- Test: `test/features/deck_sheet_test.dart`, `test/features/play_screen_test.dart`

- [ ] **Step 1: Write the failing test for the sheet**

Create `test/features/deck_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/look_at_top.dart';
import 'package:kitchentable/features/play/widgets/deck_sheet.dart';
import 'package:kitchentable/table/model/card_instance.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

List<CardInstance> _top(int n) => [
      for (var i = 0; i < n; i++)
        CardInstance(id: 'c$i', oracleId: 'card$i'),
    ];

Widget _host({
  int count = 53,
  VoidCallback? onShuffle,
  void Function(List<Placement>)? onArrange,
  Future<List<CardInstance>> Function(int)? peek,
}) =>
    MaterialApp(
      home: Scaffold(
        body: DeckSheet(
          metrics: Metrics.of(DeviceClass.handheld),
          count: count,
          printings: const {},
          peek: peek ?? (n) async => _top(n),
          onShuffle: onShuffle ?? () {},
          onArrange: onArrange ?? (_) {},
        ),
      ),
    );

void main() {
  testWidgets('it opens on the choices, not on the cards', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    // A library is hidden from everybody, its owner included. Opening this
    // sheet must not itself reveal anything: looking is a deliberate second
    // act.
    expect(find.byKey(const Key('deck-shuffle')), findsOneWidget);
    expect(find.byKey(const Key('deck-look')), findsOneWidget);
    expect(find.byKey(const Key('peeked-c0')), findsNothing);
  });

  testWidgets('shuffling asks first', (tester) async {
    var shuffled = 0;
    await tester.pumpWidget(_host(onShuffle: () => shuffled++));
    await tester.pump();

    await tester.tap(find.byKey(const Key('deck-shuffle')));
    await tester.pumpAndSettle();

    // Nothing has happened yet. Shuffling is the one act at a table that
    // cannot be undone by looking, so it gets a question.
    expect(shuffled, 0);
    expect(find.byKey(const Key('confirm-shuffle')), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm-shuffle')));
    await tester.pumpAndSettle();

    expect(shuffled, 1);
  });

  testWidgets('backing out of a shuffle shuffles nothing', (tester) async {
    var shuffled = 0;
    await tester.pumpWidget(_host(onShuffle: () => shuffled++));
    await tester.pump();

    await tester.tap(find.byKey(const Key('deck-shuffle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cancel-shuffle')));
    await tester.pumpAndSettle();

    expect(shuffled, 0);
  });

  testWidgets('looking shows the top cards', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    await tester.tap(find.byKey(const Key('deck-look')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peeked-c0')), findsOneWidget);
    expect(find.byKey(const Key('peeked-c1')), findsOneWidget);
  });

  testWidgets('each card gets a destination and the choices come back',
      (tester) async {
    List<Placement>? arranged;
    await tester.pumpWidget(_host(onArrange: (p) => arranged = p));
    await tester.pump();

    await tester.tap(find.byKey(const Key('deck-look')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('bottom-c0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('deck-done')));
    await tester.pumpAndSettle();

    // Everything looked at comes back, not only the ones that were touched:
    // a card left alone is a card going back on top, and `arrange` needs it
    // in the list to know its order.
    expect(arranged, hasLength(2));
    expect(arranged!.first, (cardId: 'c0', to: Landing.bottom));
    expect(arranged!.last, (cardId: 'c1', to: Landing.top));
  });

  testWidgets('looking at a deck with fewer cards than asked for',
      (tester) async {
    await tester.pumpWidget(_host(count: 1, peek: (n) async => _top(1)));
    await tester.pump();

    await tester.tap(find.byKey(const Key('deck-look')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peeked-c0')), findsOneWidget);
    expect(find.byKey(const Key('peeked-c1')), findsNothing);
  });

  testWidgets('an empty deck offers nothing to look at', (tester) async {
    await tester.pumpWidget(_host(count: 0, peek: (n) async => const []));
    await tester.pump();

    expect(find.byKey(const Key('deck-look')), findsNothing);
    expect(find.byKey(const Key('deck-shuffle')), findsNothing);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/deck_sheet_test.dart`
Expected: FAIL, `Error when reading
'lib/features/play/widgets/deck_sheet.dart'`.

- [ ] **Step 3: Write the sheet**

Create `lib/features/play/widgets/deck_sheet.dart`. The shape, which the
implementer fills in following the idiom of `card_menu`-less sheets already in
this repo (`CardViewer.show` is the nearest thing, read it):

- A `StatefulWidget` with three states: the choices, the confirmation, and the
  looked at cards. One widget rather than three routes, because backing out of
  a shuffle has to land back on the choices and not on the table.
- `peek` is `Future<List<CardInstance>> Function(int)`. The sheet does not
  reach into the table itself: the screen passes a function, which keeps the
  library's contents out of this widget until somebody asks.
- How many to look at: two buttons, `look-2` and `look-5`, plus whatever the
  implementer finds reads well. **Do not** build a number picker; scry 1 and
  scry 2 are most of Magic and a stepper is three taps for a number nobody
  changes.
- Each looked at card is a row keyed `peeked-<id>` with destination buttons
  keyed `top-<id>`, `bottom-<id>`, `graveyard-<id>` and `hand-<id>`. The
  default is top, so a card nobody touches goes back where it was.
- `deck-done` calls `onArrange` with **every** card in the order they are
  shown, not only the ones that were touched, because `arrange` derives the
  top pile's order from that list.
- Reordering the rows is not in this task. The order shown is the order they
  came off the deck, and the destinations are the lever. Dragging rows to
  reorder the top pile is a real want and it is written down in what this plan
  leaves out.

**Do not change the library zone's visibility.** It is `hidden`, and it stays
hidden: looking is a screen state, and the cards handed over by `peek` never
enter a `SeatView`.

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/features/deck_sheet_test.dart`
Expected: PASS, 7 tests.

- [ ] **Step 5: Probe**

Two, and check **which assertion** fails each time.

- Make `deck-shuffle` call `onShuffle` directly with no confirmation. The
  second case must fail on `expect(shuffled, 0)` and the third on its own
  assertion.
- Make `deck-done` send only the cards whose destination was touched. The
  fifth case must fail on `hasLength(2)`.

Edit each back by hand, never with `git checkout`, and rerun.

- [ ] **Step 6: Put it on the screen**

In `lib/features/play/play_screen.dart`, replace `_Piles` inside `yours` with
`LibraryStack`, and delete `_Piles` once nothing calls it:

```dart
        LibraryStack(
          metrics: m,
          count: library.size,
          width: m.scaled(46) * cardScale,
          onDraw: () => play.run(DrawCards(
            fromZoneId: library.id,
            toZoneId: hand.id,
            count: 1,
          )),
          onWork: _workTheDeck,
        ),
```

and the method:

```dart
  /// Shuffling, and looking at the top.
  ///
  /// `peek` reads the library straight off the table rather than through a
  /// `SeatView`, and that is deliberate: a `SeatView` correctly hides a
  /// library from everybody, its owner included, and this is the one act that
  /// is allowed to look. It is also why it is a callback and not a field, so
  /// the cards exist only while the sheet is open.
  Future<void> _workTheDeck() async {
    final table = ref.read(playProvider);
    final seatId = ref.read(viewerSeatProvider);
    if (table == null || seatId == null) return;

    final library = table.zone('library-$seatId');
    if (library == null) return;

    final media = MediaQuery.of(context);
    final m = Metrics.of(classifyDevice(
      size: media.size,
      hasTouch: media.navigationMode == NavigationMode.traditional,
    ));

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Palette.surface,
      isScrollControlled: true,
      builder: (sheet) => DeckSheet(
        metrics: m,
        count: library.size,
        printings: _printings,
        peek: (n) async => library.cards.take(n).toList(),
        onShuffle: () {
          Navigator.of(sheet).pop();
          ref.read(playProvider.notifier).run(
                ShuffleZone(zoneId: library.id, seed: freshSeed()),
              );
        },
        onArrange: (placements) {
          Navigator.of(sheet).pop();
          final play = ref.read(playProvider.notifier);
          for (final move in arrange(
            libraryId: library.id,
            placements: placements,
            librarySize: library.size,
            graveyardId: table.zone('graveyard-$seatId')?.id,
            handId: table.zone('hand-$seatId')?.id,
          )) {
            play.run(move);
          }
        },
      ),
    );
  }
```

- [ ] **Step 7: Bite the wiring**

The seam between the sheet and the table is the part that ships untested
otherwise, which has happened twice on this project already. Append to
`test/features/play_screen_test.dart`:

```dart
  testWidgets('the deck can be shuffled from the table', (tester) async {
    final container = await _seatedPod(tester, ['you']);
    final before =
        container.read(playProvider)!.zone('library-s1')!.cards.first.id;

    await tester.tap(find.byKey(const Key('library-work')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('deck-shuffle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-shuffle')));
    await tester.pumpAndSettle();

    final after =
        container.read(playProvider)!.zone('library-s1')!.cards.first.id;

    // 53 cards, so the same card staying on top is a one in fifty three
    // coincidence rather than a flake worth tolerating. If this is ever seen
    // failing, check the seed before loosening it.
    expect(after, isNot(before));
    expect(container.read(playProvider)!.zone('library-s1')!.cards,
        hasLength(53));
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
```

- [ ] **Step 8: Run everything**

Run: `flutter test && flutter analyze`
Expected: PASS and `No issues found!`, with `flutter test 2>&1 | grep -c
"WARNING"` still 0.

The two `your-board` geometry cases measure the board's rect against the hand.
`LibraryStack` is taller than the `_Piles` row it replaces, both sit between
the board and the hand, and neither goes below the hand, so both must still
pass. If either fails, report the rects rather than adjusting the assertion.

- [ ] **Step 9: Commit**

```bash
git add lib/features/play test/features/deck_sheet_test.dart \
        test/features/play_screen_test.dart
git commit -m "Shuffle on purpose, and look at the top of your own deck"
```

---

## Task 8: The hand, centred and yours to arrange

**Files:**
- Modify: `lib/features/play/widgets/hand_sheet.dart`
- Test: `test/features/hand_sheet_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/hand_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/widgets/hand_sheet.dart';
import 'package:kitchentable/features/play/widgets/table_card.dart';
import 'package:kitchentable/table/model/card_instance.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

List<CardInstance> _hand(int n) => [
      for (var i = 0; i < n; i++)
        CardInstance(id: 'h$i', oracleId: 'card$i'),
    ];

Widget _host({
  int cards = 3,
  void Function(String cardId, int to)? onReorder,
}) =>
    MaterialApp(
      home: Scaffold(
        body: HandSheet(
          metrics: Metrics.of(DeviceClass.handheld),
          cards: _hand(cards),
          printings: const {},
          onPlay: (_) {},
          onInspect: (_) {},
          onReorder: onReorder ?? (_, _) {},
        ),
      ),
    );

void main() {
  testWidgets('a few cards sit in the middle, not against the left edge',
      (tester) async {
    await tester.pumpWidget(_host(cards: 3));
    await tester.pump();

    final sheet = tester.getRect(find.byType(HandSheet));
    final first = tester.getRect(find.byType(TableCard).first);
    final last = tester.getRect(find.byType(TableCard).last);

    final leftGap = first.left - sheet.left;
    final rightGap = sheet.right - last.right;

    expect(leftGap, greaterThan(1), reason: 'it was pinned to the left edge');
    expect(leftGap, closeTo(rightGap, 1));
  });

  testWidgets('a full hand still fills the width and scrolls', (tester) async {
    await tester.pumpWidget(_host(cards: 30));
    await tester.pump();

    final sheet = tester.getRect(find.byType(HandSheet));
    final first = tester.getRect(find.byType(TableCard).first);

    // Centring a hand that does not fit would push its left edge off screen.
    expect(first.left, closeTo(sheet.left, 12));
  });

  testWidgets('an empty hand says so', (tester) async {
    await tester.pumpWidget(_host(cards: 0));

    expect(find.textContaining('No cards'), findsOneWidget);
  });

  testWidgets('a card dragged sideways reports where it was put',
      (tester) async {
    ({String id, int to})? moved;
    await tester.pumpWidget(_host(
      cards: 4,
      onReorder: (id, to) => moved = (id: id, to: to),
    ));
    await tester.pump();

    final third = tester.getCenter(find.byType(TableCard).at(2));
    final gesture = await tester.startGesture(third);
    await tester.pump(const Duration(milliseconds: 40));
    await gesture.moveTo(tester.getCenter(find.byType(TableCard).first));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(moved?.id, 'h2');
    expect(moved?.to, 0);
  });

  testWidgets('a tap still plays the card', (tester) async {
    CardInstance? played;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HandSheet(
          metrics: Metrics.of(DeviceClass.handheld),
          cards: _hand(3),
          printings: const {},
          onPlay: (c) => played = c,
          onInspect: (_) {},
          onReorder: (_, _) {},
        ),
      ),
    ));
    await tester.pump();

    // Adding a drag to a widget that already had a tap is how a tap stops
    // working. It did, once, on the board.
    await tester.tap(find.byType(TableCard).first);
    await tester.pump();

    expect(played?.id, 'h0');
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/hand_sheet_test.dart`
Expected: FAIL to compile, `No named parameter with the name 'onReorder'`.

- [ ] **Step 3: Rebuild the hand**

In `lib/features/play/widgets/hand_sheet.dart`:

- Add `required this.onReorder` with the type
  `void Function(String cardId, int to)`.
- Centre when the cards fit. Wrap the scroll view in a `LayoutBuilder` and
  compare `cards.length * (cardWidth + gap)` against `constraints.maxWidth`;
  when it fits, a `Center` with a `Row`, when it does not, the scrolling list
  it already has. **Do not** reach for `ListView`'s `shrinkWrap` to fake it:
  the case above measures both edges and a shrink wrapped list still starts at
  the left.
- Reorder by dragging. `ReorderableListView` is the obvious answer and it is
  the wrong one here: it wants its own scroll view, it fights the centring,
  and its drag handle behaviour on a horizontal list is poor. Use the same
  `Listener` plus `GestureDetector` pair `cursor_board.dart` already uses,
  work out the index from the drop position and the card pitch, and call
  `onReorder`. Read that file first; the touch slop problem it solves is the
  same one here.

The screen wires `onReorder` to
`MoveCard(cardId: id, toZoneId: hand.id, at: to)`.

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/features/hand_sheet_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Probe**

Remove the centring, going back to a plain left aligned list. The first case
must fail on `leftGap` and not on the closeTo. Then make the drop index always
0: the fourth case must fail on `moved?.to`. Say which assertion each time.
Edit back by hand and rerun.

- [ ] **Step 6: Commit**

```bash
git add lib/features/play test/features/hand_sheet_test.dart
git commit -m "Centre the hand, and let it be rearranged"
```

---

## Task 9: Your own seat, nearest you

Two things the player asked for that are one change: in the all players view
your mat should be the one closest to your hand, and you should be able to
move your own cards there.

**Files:**
- Modify: `lib/features/play/renderers/free_canvas.dart`
- Modify: `lib/features/play/renderers/mat_layout.dart`
- Test: `test/features/mat_layout_test.dart`, `test/features/free_canvas_test.dart`

- [ ] **Step 1: Write the failing test for the order**

Append to `test/features/mat_layout_test.dart`:

```dart
  test('your own seat is the one nearest your hand', () {
    // Four seats, you are second in table order. The hand sits under the
    // canvas, so nearest means bottom, and bottom means last.
    final order = seatOrder(count: 4, viewerAt: 1);

    expect(order.last, 1);
    expect(order.toSet(), {0, 1, 2, 3});
  });

  test('the others keep going round the table in order', () {
    final order = seatOrder(count: 4, viewerAt: 1);

    // Turn order still reads round the table from the seat after yours, which
    // is the order you will be passing priority in.
    expect(order, [2, 3, 0, 1]);
  });

  test('a spectator changes nothing', () {
    expect(seatOrder(count: 3, viewerAt: null), [0, 1, 2]);
    expect(seatOrder(count: 3, viewerAt: 9), [0, 1, 2]);
  });

  test('a table of one is a table of one', () {
    expect(seatOrder(count: 1, viewerAt: 0), [0]);
  });
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/mat_layout_test.dart`
Expected: FAIL, `Method not found: 'seatOrder'`.

- [ ] **Step 3: Write it**

In `lib/features/play/renderers/mat_layout.dart`:

```dart
/// Which seat goes in which mat, so yours is the one nearest your hand.
///
/// The hand sits under the canvas, so nearest is last. The rest keep going
/// round the table from the seat after yours, which is the order priority
/// passes in, so the arrangement on screen matches the one people say out
/// loud.
///
/// Returns positions into the seat list, not seat ids.
List<int> seatOrder({required int count, required int? viewerAt}) {
  if (viewerAt == null || viewerAt < 0 || viewerAt >= count) {
    return [for (var i = 0; i < count; i++) i];
  }
  return [
    for (var i = 1; i <= count; i++) (viewerAt + i) % count,
  ];
}
```

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/features/mat_layout_test.dart`
Expected: PASS, 13 tests.

- [ ] **Step 5: Use it, and let the canvas be dragged**

In `free_canvas.dart`, walk `seatOrder` instead of the raw index:

```dart
            for (final (slot, seatAt)
                in seatOrder(
                  count: seats.length,
                  viewerAt: seats.indexWhere((s) => s.seatId == viewerSeatId),
                ).indexed)
              Positioned.fromRect(
                rect: matFor(slot, seats.length),
                child: _Mat(seat: seats[seatAt], ...),
              ),
```

`indexWhere` returns -1 for a spectator, which `seatOrder` already treats as
no viewer.

Then give `_Mat` the same drag `CursorBoard` has, **only on your own mat**: a
card on somebody else's mat is theirs to move. Add `onPlace` to `FreeCanvas`
and pass it through to `_Mat`, which wires it only when `isViewer`. Lift the
`Listener` plus `onPanStart` catch up from `cursor_board.dart` rather than
writing a second one: **the touch slop bug is the same bug and it will be back
if this is retyped.** If that means extracting it into a small widget both use,
do that and say so.

- [ ] **Step 6: Write the failing tests for the canvas drag**

Append to `test/features/free_canvas_test.dart`:

```dart
  testWidgets('you can move your own cards here too', (tester) async {
    ({String id, double x, double y})? dropped;
    await tester.pumpWidget(_host(
      [_seat('s1', board: 1)],
      onPlace: (id, x, y) => dropped = (id: id, x: x, y: y),
    ));
    await tester.pump();

    await tester.drag(find.byKey(const Key('card-s1-b0')),
        const Offset(120, 60));
    await tester.pump();

    expect(dropped?.id, 's1-b0');
    expect(dropped!.x, inExclusiveRange(0, 1));
  });

  testWidgets('somebody else s cards are not yours to move', (tester) async {
    ({String id, double x, double y})? dropped;
    await tester.pumpWidget(_host(
      [_seat('s1', board: 1), _seat('s2', board: 1)],
      onPlace: (id, x, y) => dropped = (id: id, x: x, y: y),
    ));
    await tester.pump();

    await tester.drag(find.byKey(const Key('card-s2-b0')),
        const Offset(120, 60));
    await tester.pump();

    expect(dropped, isNull);
  });

  testWidgets('your mat is the last one, nearest your hand', (tester) async {
    await tester.pumpWidget(_host(
      [_seat('s1'), _seat('s2'), _seat('s3')],
      viewer: 's2',
    ));
    await tester.pump();

    final mine = tester.getRect(find.byKey(const Key('mat-s2')));
    for (final id in ['s1', 's3']) {
      expect(mine.top, greaterThanOrEqualTo(
        tester.getRect(find.byKey(Key('mat-$id'))).top,
      ), reason: 'mat $id should not be below yours');
    }
  });
```

`_host` needs the `onPlace` argument adding, defaulting to a no-op so the
existing cases keep working.

- [ ] **Step 7: Run everything**

Run: `flutter test && flutter analyze`
Expected: PASS and `No issues found!`, WARNING count 0.

`free_canvas_test.dart` has a case asserting a positioned card sits right of a
flowed one, and another asserting every seat gets a mat. Reordering the mats
changes which rect `mat-s1` is, so if either moves, say which and what the
rects were before adjusting anything.

- [ ] **Step 8: Probe**

Change `seatOrder` to return the plain range always. The two ordering cases in
`mat_layout_test.dart` and the canvas one must fail. Then make `_Mat` wire
`onPlace` regardless of `isViewer`: the case about somebody else's cards must
fail on `expect(dropped, isNull)`. Say which assertion each time. Edit back by
hand and rerun.

- [ ] **Step 9: Commit**

```bash
git add lib/features/play/renderers test/features/mat_layout_test.dart \
        test/features/free_canvas_test.dart
git commit -m "Put your own mat nearest you, and let you move your own cards on it"
```

---

## What this plan deliberately leaves out

- **Reordering the looked at cards.** The sheet's rows come off the deck in
  order and the destinations are the lever. Dragging a row to choose the top
  pile's order is a real want and it is the next thing here.
- **Fateseal.** Looking at somebody else's library needs somebody else, which
  is plan 4.
- **Dragging between piles.** A drop lands on the mat it started on, on the
  board and on the canvas alike.
- **A number picker for how many to look at.** Two buttons, because scry 1 and
  scry 2 are most of Magic and a stepper is three taps for a number nobody
  changes.
