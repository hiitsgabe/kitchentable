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

## Tasks 5 onward

Written once these four land, for the same reason plan 3 held its renderers
back: the library stack, the look at the top, the centred hand and the mat
near your seat all draw against sizes and a hover that do not exist yet.

They cover:

- **`library_stack.dart`**, the deck as a pile on the right whose height
  tracks the count, tapping to draw.
- **`look_at_top.dart`**, the top N with a destination each. Scry, surveil and
  a tutor are the same gesture with different destinations, and the real
  dynamics need reading up before the sheet is designed.
- **Shuffling on purpose**, behind a confirmation, because it is the one act
  at a table that cannot be undone by looking.
- **The hand centred and reorderable.**
- **Your own mat nearest your hand** in the all players view, and dragging
  your own cards there.
