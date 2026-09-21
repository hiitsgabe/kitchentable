# Menu and card import, implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An app that boots to a menu which draws itself from real state, lets
the player switch on the Scryfall catalog, streams and indexes 36000 cards, and
then lights up the menu entries that the catalog unlocked.

**Architecture:** Three layers, kept apart. `ui/` holds a design system where
every atom is born focusable, with a scale that responds to device class.
`sources/` owns the source registry, the local catalog database and the
importer, and knows about no widget. `features/` holds screens and Riverpod
notifiers. Nothing in the app makes a network request until a human switches a
source on.

**Tech Stack:** Flutter 3.47.5, Dart 3.13.4, flutter_riverpod 3.4.3, drift
2.35.0 with drift_flutter 0.3.1, http 1.6.0.

---

## Why these shapes

Two measurements made on 2026 09 21 drive the whole design and you should know
them before reading the tasks.

**The catalog is 23.6 MB, not 636 MB.** MTGJSON AllPrintings is 636 MB and is
the wrong file. Scryfall's `oracle_cards` carries name, mana cost, type line,
oracle text, power, toughness, colors, rarity, legalities and image URIs for
every unique card, compressed to 24710557 bytes.

**Scryfall no longer serves JSON.** The bulk object has no `download_uri` and no
`size`. It has `jsonl_download_uri` and `compressed_size`, and the file is
gzipped JSONL, one card object per line. This matters more than it looks: a
`jsonDecode` over an array of 36000 objects would peak at hundreds of megabytes
on a phone. Streaming gunzip into a line splitter into batched inserts never
holds more than one batch in memory. Build the importer as a stream and it is
fine. Build it as a parse and it will die on real devices.

A real record, first line of the file on 2026 09 21, has 69 fields. The ones we
store:

```
id             a471b306-4941-4e46-a0cb-d92895c16f8a
oracle_id      00037840-6089-42ec-8c5c-281f9f474504
name           Nissa, Worldsoul Speaker
mana_cost      {3}{G}
cmc            4.0
type_line      Legendary Creature - Elf Druid
oracle_text    Landfall - Whenever a land you control enters, you get {E}{E}...
power          3
toughness      3
colors         ["G"]
color_identity ["G"]
rarity         rare
set            drc
legalities     {"standard":"not_legal","commander":"legal",...}
image_uris     {"small":"https://cards.scryfall.io/small/front/a/4/...jpg",...}
layout         normal
card_faces     null
```

## File structure

```
lib/
  ui/
    tokens/
      palette.dart          exists
      theme.dart            exists
      metrics.dart          NEW  device class and scale
    atoms/
      menu_row.dart         NEW  focusable row, the workhorse of every list
      hint_bar.dart         NEW  button legend along the bottom
      progress_track.dart   NEW  one labelled bar
  sources/
    model/
      source_def.dart       NEW  what a source is
      catalog_card.dart     NEW  the card we keep
    source_registry.dart    NEW  the known sources, all off
    catalog/
      catalog_db.dart       NEW  drift database
      catalog_db.g.dart     GENERATED
    import/
      jsonl_stream.dart     NEW  pure: decompressed bytes to card maps
      gunzip.dart           NEW  conditional import shim
      gunzip_io.dart        NEW  dart:io implementation
      gunzip_web.dart       NEW  throws, web has no importer yet
      scryfall_importer.dart NEW  bulk endpoint, download, index, progress
  features/
    menu/
      menu_controller.dart  NEW
      menu_screen.dart      NEW
    sources/
      sources_screen.dart   NEW
      import_controller.dart NEW
      import_screen.dart    NEW
test/
  ui/metrics_test.dart
  ui/menu_row_test.dart
  sources/source_registry_test.dart
  sources/jsonl_stream_test.dart
  sources/catalog_db_test.dart
  sources/scryfall_importer_test.dart
  features/menu_controller_test.dart
  features/menu_screen_test.dart
```

A note on web. The importer uses `dart:io` gzip, which does not compile for
web. `gunzip.dart` is a conditional import so the web build keeps working and
the web importer throws a clear `UnsupportedError`. Web exists so we can look
at the UI on a machine with no display and no emulator, not so we can import on
it.

---

## Task 1: Dependencies

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add the dependencies**

Edit `pubspec.yaml` so the `dependencies` and `dev_dependencies` blocks read:

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  flutter_riverpod: ^3.4.3
  drift: ^2.35.0
  drift_flutter: ^0.3.1
  http: ^1.6.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  build_runner: ^2.16.1
  drift_dev: ^2.35.0
```

- [ ] **Step 2: Fetch**

Run: `flutter pub get`
Expected: `Got dependencies!` with no version solving errors.

- [ ] **Step 3: Confirm the app still builds**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "Add riverpod, drift and http"
```

---

## Task 2: Device class and metrics

The app runs on handhelds with a D-pad and on TV. TV sits across a room and
needs larger type, fatter focus rings and overscan margin. One scale factor
resolved once, applied through tokens, so no widget hardcodes a size.

**Files:**
- Create: `lib/ui/tokens/metrics.dart`
- Test: `test/ui/metrics_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/ui/metrics_test.dart`:

```dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

void main() {
  test('a wide screen with no touch is a television', () {
    expect(
      classifyDevice(size: const Size(1920, 1080), hasTouch: false),
      DeviceClass.tv,
    );
  });

  test('a wide screen you can touch is still a handheld', () {
    expect(
      classifyDevice(size: const Size(1920, 1080), hasTouch: true),
      DeviceClass.handheld,
    );
  });

  test('a small screen is a handheld whatever it claims about touch', () {
    expect(
      classifyDevice(size: const Size(640, 480), hasTouch: false),
      DeviceClass.handheld,
    );
  });

  test('the threshold itself counts as a television', () {
    expect(
      classifyDevice(size: const Size(960, 540), hasTouch: false),
      DeviceClass.tv,
    );
  });

  test('one pixel under the threshold is still a handheld', () {
    expect(
      classifyDevice(size: const Size(959, 540), hasTouch: false),
      DeviceClass.handheld,
    );
  });

  test('television metrics are bigger than handheld metrics', () {
    expect(Metrics.of(DeviceClass.tv).scale,
        greaterThan(Metrics.of(DeviceClass.handheld).scale));
    expect(Metrics.of(DeviceClass.tv).safeInset,
        greaterThan(Metrics.of(DeviceClass.handheld).safeInset));
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/ui/metrics_test.dart`
Expected: FAIL, `Target of URI doesn't exist: 'package:kitchentable/ui/tokens/metrics.dart'`

- [ ] **Step 3: Write the implementation**

Create `lib/ui/tokens/metrics.dart`:

```dart
import 'dart:ui';

enum DeviceClass { handheld, tv }

/// A television is the only thing we expect to be large and untouchable at the
/// same time. Anything you can touch is being held, however big it is.
///
/// Width rather than shortestSide on purpose: touch already wins for anything
/// held, so width is only ever consulted for a D-pad session, where somebody
/// rotating the screen is not a case worth carrying.
DeviceClass classifyDevice({required Size size, required bool hasTouch}) {
  if (hasTouch) return DeviceClass.handheld;
  return size.width >= 960 ? DeviceClass.tv : DeviceClass.handheld;
}

class Metrics {
  const Metrics({
    required this.scale,
    required this.safeInset,
    required this.focusRing,
  });

  /// Multiplies every font size and every gap. Nothing hardcodes a size.
  ///
  /// This is not Android's sp and has nothing to do with the reader's font size
  /// preference. It is one constant per device class. If accessibility text
  /// scaling is ever honoured it has to come from MediaQuery on top of this,
  /// not instead of it.
  final double scale;

  /// Overscan. Televisions eat their own edges.
  final double safeInset;

  /// Thickness of the focus outline. Across a room a hairline is invisible.
  final double focusRing;

  static const _handheld = Metrics(scale: 1, safeInset: 16, focusRing: 2);
  static const _tv = Metrics(scale: 1.6, safeInset: 48, focusRing: 3);

  static Metrics of(DeviceClass deviceClass) =>
      switch (deviceClass) {
        DeviceClass.handheld => _handheld,
        DeviceClass.tv => _tv,
      };

  double scaled(double base) => base * scale;
}
```

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/ui/metrics_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/tokens/metrics.dart test/ui/metrics_test.dart
git commit -m "Tell a television apart from a handheld"
```

---

## Task 3: The focusable row

Every list in this app is made of these, so its contract is the app's contract.

Two things about it are not obvious and both were got wrong the first time.

**A tap is not a button press.** `MaterialApp` maps the select button and
gameButtonA to `ActivateIntent` in `WidgetsApp.defaultShortcuts`
(`app.dart:1268` and `1269`), but `WidgetsApp.defaultActions` contains no
handler for `ActivateIntent` at all. The intent is dispatched and nothing
catches it. A row built from `Focus` plus `GestureDetector` therefore takes
focus, draws its border, and does absolutely nothing when you press the button.
It looks correct and is inert. The row must handle `ActivateIntent` itself.

**A dead row still takes focus on a D-pad, and that is right.** Flutter decides
this for us in `FocusableActionDetector`:

```dart
bool get _canRequestFocus => switch (MediaQuery.maybeNavigationModeOf(context)) {
  NavigationMode.traditional || null => widget.enabled,
  NavigationMode.directional => true,
};
```

Under directional navigation a disabled control stays reachable. That is the
correct behaviour here and not merely something to tolerate: on the main menu
the disabled `Play` row carries the subtitle `needs a source`, which is the
sentence that teaches a new player what to do. Skipping it would hide the
instruction from exactly the people who cannot tap.

So the contract is: **a disabled row may be focused, and never activates.**
Not by tap, and not by button.

**Files:**
- Modify: `lib/ui/tokens/palette.dart`
- Create: `lib/ui/atoms/menu_row.dart`
- Test: `test/ui/menu_row_test.dart`

- [ ] **Step 1: Give the focus wash a name**

In `lib/ui/tokens/palette.dart`, add this below `accent`:

```dart
  /// Fills a focused row. Dark enough to sit under the accent border without
  /// competing with it.
  static const focusWash = Color(0xFF101A2A);
```

- [ ] **Step 2: Write the failing test**

Create `test/ui/menu_row_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/ui/atoms/menu_row.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

Widget _host(Widget child, {NavigationMode? navigationMode}) {
  final app = MaterialApp(home: Scaffold(body: Column(children: [child])));
  if (navigationMode == null) return app;
  return MediaQuery(
    data: MediaQueryData(navigationMode: navigationMode),
    child: app,
  );
}

MenuRow _row({
  String title = 'Sources',
  bool enabled = true,
  FocusNode? focusNode,
  required VoidCallback onActivate,
}) =>
    MenuRow(
      title: title,
      subtitle: 'start here',
      enabled: enabled,
      focusNode: focusNode,
      metrics: Metrics.of(DeviceClass.handheld),
      onActivate: onActivate,
    );

void main() {
  testWidgets('an enabled row takes focus', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);

    await tester.pumpWidget(_host(_row(focusNode: node, onActivate: () {})));
    node.requestFocus();
    await tester.pump();

    expect(node.hasFocus, isTrue);
  });

  testWidgets('an enabled row fires when tapped', (tester) async {
    var fired = 0;
    await tester.pumpWidget(_host(_row(onActivate: () => fired++)));

    await tester.tap(find.text('Sources'));
    await tester.pump();

    expect(fired, 1);
  });

  testWidgets('an enabled row fires when the select button is pressed',
      (tester) async {
    var fired = 0;
    final node = FocusNode();
    addTearDown(node.dispose);

    await tester.pumpWidget(
      _host(_row(focusNode: node, onActivate: () => fired++)),
    );
    node.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();

    expect(fired, 1);
  });

  testWidgets('an enabled row fires when the gamepad A button is pressed',
      (tester) async {
    var fired = 0;
    final node = FocusNode();
    addTearDown(node.dispose);

    await tester.pumpWidget(
      _host(_row(focusNode: node, onActivate: () => fired++)),
    );
    node.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonA);
    await tester.pump();

    expect(fired, 1);
  });

  testWidgets('a disabled row does not fire when tapped', (tester) async {
    var fired = 0;
    await tester.pumpWidget(
      _host(_row(title: 'Play', enabled: false, onActivate: () => fired++)),
    );

    await tester.tap(find.text('Play'));
    await tester.pump();

    expect(fired, 0);
  });

  testWidgets('a D-pad can reach a disabled row so its reason can be read',
      (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);

    await tester.pumpWidget(_host(
      _row(title: 'Play', enabled: false, focusNode: node, onActivate: () {}),
      navigationMode: NavigationMode.directional,
    ));
    node.requestFocus();
    await tester.pump();

    expect(node.hasFocus, isTrue,
        reason: 'the subtitle on a dead row is how a player learns what to do');
  });

  testWidgets('a disabled row does not fire when the select button is pressed',
      (tester) async {
    var fired = 0;
    final node = FocusNode();
    addTearDown(node.dispose);

    await tester.pumpWidget(_host(
      _row(
        title: 'Play',
        enabled: false,
        focusNode: node,
        onActivate: () => fired++,
      ),
      navigationMode: NavigationMode.directional,
    ));
    node.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();

    expect(fired, 0);
  });
}
```

- [ ] **Step 3: Run it and watch it fail**

Run: `flutter test test/ui/menu_row_test.dart`
Expected: FAIL, `Target of URI doesn't exist: 'package:kitchentable/ui/atoms/menu_row.dart'`

- [ ] **Step 4: Write the implementation**

Create `lib/ui/atoms/menu_row.dart`:

```dart
import 'package:flutter/material.dart';

import '../tokens/palette.dart';
import '../tokens/metrics.dart';

/// One line in a list. Focus has to be loud, because the same widget is read
/// from thirty centimetres on a handheld and from three metres on a television.
///
/// It answers ActivateIntent as well as a tap, and that is not decoration.
/// MaterialApp maps the select button and gameButtonA to ActivateIntent, but
/// WidgetsApp.defaultActions has no handler for it, so without the action below
/// the intent is dispatched and nothing catches it: the row would take focus,
/// draw its border and do nothing when pressed.
///
/// A disabled row can still be focused under directional navigation, which is
/// Flutter's choice and the right one. Its subtitle usually says why it is
/// disabled, and that sentence is worth reaching. It just never activates.
class MenuRow extends StatefulWidget {
  const MenuRow({
    super.key,
    required this.title,
    required this.metrics,
    required this.onActivate,
    this.subtitle,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
  });

  final String title;
  final String? subtitle;
  final Metrics metrics;
  final VoidCallback onActivate;
  final bool enabled;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<MenuRow> {
  bool _focused = false;

  void _activate() {
    if (widget.enabled) widget.onActivate();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.metrics;

    return FocusableActionDetector(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus && widget.enabled,
      enabled: widget.enabled,
      descendantsAreFocusable: widget.enabled,
      onFocusChange: (v) => setState(() => _focused = v),
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _activate();
            return null;
          },
        ),
      },
      child: Semantics(
        button: true,
        enabled: widget.enabled,
        label: widget.subtitle == null
            ? widget.title
            : '${widget.title}. ${widget.subtitle}',
        child: GestureDetector(
          onTap: widget.enabled ? _activate : null,
          behavior: HitTestBehavior.opaque,
          child: Opacity(
            opacity: widget.enabled ? 1 : 0.42,
            child: Container(
              margin: EdgeInsets.only(bottom: m.scaled(5)),
              padding: EdgeInsets.symmetric(
                horizontal: m.scaled(12),
                vertical: m.scaled(11),
              ),
              decoration: BoxDecoration(
                color: _focused ? Palette.focusWash : Colors.transparent,
                borderRadius: BorderRadius.circular(m.scaled(10)),
                border: Border.all(
                  color: _focused ? Palette.accent : Colors.transparent,
                  width: m.focusRing,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: m.scaled(15),
                            color: _focused ? Colors.white : Palette.ink,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (widget.subtitle != null) ...[
                          SizedBox(height: m.scaled(2)),
                          Text(
                            widget.subtitle!,
                            style: TextStyle(
                              fontSize: m.scaled(11),
                              color: Palette.inkFaint,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    '›',
                    style: TextStyle(
                      fontSize: m.scaled(16),
                      color: _focused ? Palette.accent : Palette.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run it and watch it pass**

Run: `flutter test test/ui/menu_row_test.dart`
Expected: PASS, 7 tests.

- [ ] **Step 6: Prove the button tests bite**

A green suite is not evidence on its own. Delete the whole `actions:` block from
`FocusableActionDetector`, run the test file again, and confirm that exactly the
two button tests fail:

- `an enabled row fires when the select button is pressed`
- `an enabled row fires when the gamepad A button is pressed`

and that the tap tests stay green. Then restore the block and confirm 7 pass
again and `git status --short` shows only intended changes.

If the button tests stay green without the action, the test is not reaching the
shortcut layer and the bug is still live. Report that rather than committing.

- [ ] **Step 7: Commit**

```bash
git add lib/ui/tokens/palette.dart lib/ui/atoms/menu_row.dart test/ui/menu_row_test.dart
git commit -m "A row you can reach with a thumb or a D-pad"
```
---

## Task 4: The hint bar

Handheld interfaces tell you which button does what. Copy that, it costs one
widget and removes a whole class of confusion.

**Files:**
- Create: `lib/ui/atoms/hint_bar.dart`
- Test: `test/ui/hint_bar_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/ui/hint_bar_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/ui/atoms/hint_bar.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

void main() {
  testWidgets('it prints every hint it is given', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HintBar(
          metrics: Metrics.of(DeviceClass.handheld),
          hints: const [
            Hint(button: 'A', label: 'open'),
            Hint(button: 'B', label: 'back'),
          ],
        ),
      ),
    ));

    expect(find.text('A'), findsOneWidget);
    expect(find.text('open'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('back'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/ui/hint_bar_test.dart`
Expected: FAIL, `Target of URI doesn't exist: 'package:kitchentable/ui/atoms/hint_bar.dart'`

- [ ] **Step 3: Write the implementation**

Create `lib/ui/atoms/hint_bar.dart`:

```dart
import 'package:flutter/material.dart';

import '../tokens/palette.dart';
import '../tokens/metrics.dart';

class Hint {
  const Hint({required this.button, required this.label});
  final String button;
  final String label;
}

class HintBar extends StatelessWidget {
  const HintBar({super.key, required this.metrics, required this.hints});

  final Metrics metrics;
  final List<Hint> hints;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return Container(
      padding: EdgeInsets.only(top: m.scaled(8)),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Palette.surfaceEdge)),
      ),
      child: Row(
        children: [
          for (final hint in hints) ...[
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: m.scaled(6),
                vertical: m.scaled(2),
              ),
              decoration: BoxDecoration(
                color: Palette.surface,
                borderRadius: BorderRadius.circular(m.scaled(4)),
                border: Border.all(color: Palette.surfaceEdge),
              ),
              child: Text(
                hint.button,
                style: TextStyle(fontSize: m.scaled(10), color: Palette.inkMuted),
              ),
            ),
            SizedBox(width: m.scaled(5)),
            Text(
              hint.label,
              style: TextStyle(fontSize: m.scaled(10), color: Palette.inkFaint),
            ),
            SizedBox(width: m.scaled(14)),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/ui/hint_bar_test.dart`
Expected: PASS, 1 test.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/atoms/hint_bar.dart test/ui/hint_bar_test.dart
git commit -m "Say which button does what"
```

---

## Task 5: What a source is

**Files:**
- Create: `lib/sources/model/source_def.dart`
- Create: `lib/sources/source_registry.dart`
- Test: `test/sources/source_registry_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/sources/source_registry_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/sources/model/source_def.dart';
import 'package:kitchentable/sources/source_registry.dart';

void main() {
  test('nothing is enabled out of the box', () {
    for (final source in knownSources) {
      expect(source.enabledByDefault, isFalse,
          reason: '${source.id} must not be on before a human says so');
    }
  });

  test('every source that downloads declares its size', () {
    for (final source in knownSources.where((s) => s.endpoint != null)) {
      expect(source.approximateBytes, isNotNull,
          reason: '${source.id} downloads, so it must say how much');
    }
  });

  test('the scryfall catalog is there and points at the bulk endpoint', () {
    final scryfall = knownSources.firstWhere((s) => s.id == 'scryfall_oracle');
    expect(scryfall.kind, SourceKind.catalog);
    expect(scryfall.endpoint.toString(),
        'https://api.scryfall.com/bulk-data/oracle-cards');
  });

  test('ids are unique', () {
    final ids = knownSources.map((s) => s.id).toList();
    expect(ids.toSet().length, ids.length);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/sources/source_registry_test.dart`
Expected: FAIL, `Target of URI doesn't exist: 'package:kitchentable/sources/model/source_def.dart'`

- [ ] **Step 3: Write the model**

Create `lib/sources/model/source_def.dart`:

```dart
enum SourceKind { catalog, draftSets, localFile, url }

/// A place cards can come from. The app knows the address. It does not go
/// there until somebody switches it on.
class SourceDef {
  const SourceDef({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.kind,
    this.endpoint,
    this.approximateBytes,
    this.available = true,
  });

  final String id;
  final String name;
  final String subtitle;
  final SourceKind kind;
  final Uri? endpoint;

  /// Shown to the player before they touch the row. Nobody should be surprised
  /// by a download.
  final int? approximateBytes;

  /// False for sources we have not built yet, so the row can say so instead of
  /// failing when tapped.
  final bool available;

  /// Always false. There is no source this app turns on by itself.
  bool get enabledByDefault => false;
}
```

- [ ] **Step 4: Write the registry**

Create `lib/sources/source_registry.dart`:

```dart
import 'model/source_def.dart';

/// Sizes checked against the live endpoints on 2026 09 21.
///
/// This is `final` rather than `const` because `Uri` has no const constructor,
/// so a SourceDef carrying an endpoint can never be a compile time constant.
final knownSources = <SourceDef>[
  SourceDef(
    id: 'scryfall_oracle',
    name: 'Scryfall',
    subtitle: 'card catalog',
    kind: SourceKind.catalog,
    endpoint: null,
    approximateBytes: 24710557,
  ),
  SourceDef(
    id: 'mtgjson_sets',
    name: 'MTGJSON',
    subtitle: 'sets for draft',
    kind: SourceKind.draftSets,
    approximateBytes: 1100000,
    available: false,
  ),
  SourceDef(
    id: 'pokemon_tcg_data',
    name: 'Pokemon',
    subtitle: 'card catalog',
    kind: SourceKind.catalog,
    available: false,
  ),
  SourceDef(
    id: 'local_file',
    name: 'Local file',
    subtitle: 'a dump already on this device',
    kind: SourceKind.localFile,
    available: false,
  ),
];
```

Note the first entry has `endpoint: null` and the test demands a real URI.
That is deliberate, the next step fixes it, so you see the test catch a real
mistake rather than trusting it blindly.

- [ ] **Step 5: Run it and watch exactly one test fail**

Run: `flutter test test/sources/source_registry_test.dart`
Expected: FAIL, one test, `the scryfall catalog is there and points at the bulk endpoint`.

- [ ] **Step 6: Give Scryfall its endpoint**

In `lib/sources/source_registry.dart`, replace the `scryfall_oracle` entry's
`endpoint: null,` line with:

```dart
    endpoint: Uri(
      scheme: 'https',
      host: 'api.scryfall.com',
      path: '/bulk-data/oracle-cards',
    ),
```

- [ ] **Step 7: Run it and watch it pass**

Run: `flutter test test/sources/source_registry_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 8: Commit**

```bash
git add lib/sources test/sources
git commit -m "Name the sources and leave every one of them off"
```

---

## Task 6: The catalog database

**Files:**
- Create: `lib/sources/model/catalog_card.dart`
- Create: `lib/sources/catalog/catalog_db.dart`
- Test: `test/sources/catalog_db_test.dart`

- [ ] **Step 1: Write the card model**

Create `lib/sources/model/catalog_card.dart`:

```dart
/// What we keep out of a Scryfall record. The live record has 69 fields and we
/// want fourteen of them.
class CatalogCard {
  const CatalogCard({
    required this.oracleId,
    required this.name,
    required this.typeLine,
    required this.cmc,
    this.manaCost,
    this.oracleText,
    this.power,
    this.toughness,
    this.colorIdentity = const [],
    this.rarity,
    this.setCode,
    this.legalities = const {},
    this.imageSmall,
    this.imageNormal,
  });

  final String oracleId;
  final String name;
  final String typeLine;
  final double cmc;
  final String? manaCost;
  final String? oracleText;
  final String? power;
  final String? toughness;
  final List<String> colorIdentity;
  final String? rarity;
  final String? setCode;
  final Map<String, String> legalities;
  final String? imageSmall;
  final String? imageNormal;

  bool isLegalIn(String format) => legalities[format] == 'legal';

  /// Double faced cards carry their images under `card_faces` rather than at
  /// the top level, so the front face stands in for the card.
  static CatalogCard fromScryfall(Map<String, dynamic> json) {
    final images = (json['image_uris'] as Map<String, dynamic>?) ??
        ((json['card_faces'] as List<dynamic>?)?.isNotEmpty == true
            ? (json['card_faces'] as List<dynamic>).first['image_uris']
                as Map<String, dynamic>?
            : null);

    return CatalogCard(
      oracleId: json['oracle_id'] as String,
      name: json['name'] as String,
      typeLine: (json['type_line'] as String?) ?? '',
      cmc: ((json['cmc'] as num?) ?? 0).toDouble(),
      manaCost: json['mana_cost'] as String?,
      oracleText: json['oracle_text'] as String?,
      power: json['power'] as String?,
      toughness: json['toughness'] as String?,
      colorIdentity: ((json['color_identity'] as List<dynamic>?) ?? const [])
          .cast<String>(),
      rarity: json['rarity'] as String?,
      setCode: json['set'] as String?,
      legalities: ((json['legalities'] as Map<String, dynamic>?) ?? const {})
          .map((k, v) => MapEntry(k, v as String)),
      imageSmall: images?['small'] as String?,
      imageNormal: images?['normal'] as String?,
    );
  }
}
```

- [ ] **Step 2: Write the failing database test**

Create `test/sources/catalog_db_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/sources/catalog/catalog_db.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';

CatalogCard _card(String id, String name) => CatalogCard(
      oracleId: id,
      name: name,
      typeLine: 'Creature - Elf',
      cmc: 2,
      legalities: const {'commander': 'legal', 'standard': 'not_legal'},
    );

void main() {
  late CatalogDb db;

  setUp(() => db = CatalogDb.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('an empty catalog counts zero', () async {
    expect(await db.cardCount(), 0);
  });

  test('inserted cards are counted', () async {
    await db.insertAll([_card('a', 'Llanowar Elves'), _card('b', 'Birds')]);
    expect(await db.cardCount(), 2);
  });

  test('inserting the same oracle id twice replaces rather than duplicates',
      () async {
    await db.insertAll([_card('a', 'Llanowar Elves')]);
    await db.insertAll([_card('a', 'Llanowar Elves')]);
    expect(await db.cardCount(), 1);
  });

  test('search finds by part of the name, ignoring case', () async {
    await db.insertAll([_card('a', 'Llanowar Elves'), _card('b', 'Sol Ring')]);
    final hits = await db.searchByName('elv');
    expect(hits.map((c) => c.name), ['Llanowar Elves']);
  });

  test('legalities survive the round trip', () async {
    await db.insertAll([_card('a', 'Llanowar Elves')]);
    final hits = await db.searchByName('Llanowar');
    expect(hits.single.isLegalIn('commander'), isTrue);
    expect(hits.single.isLegalIn('standard'), isFalse);
  });

  test('clearing empties the catalog', () async {
    await db.insertAll([_card('a', 'Llanowar Elves')]);
    await db.clear();
    expect(await db.cardCount(), 0);
  });
}
```

- [ ] **Step 3: Run it and watch it fail**

Run: `flutter test test/sources/catalog_db_test.dart`
Expected: FAIL, `Target of URI doesn't exist: 'package:kitchentable/sources/catalog/catalog_db.dart'`

- [ ] **Step 4: Write the database**

Create `lib/sources/catalog/catalog_db.dart`:

```dart
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../model/catalog_card.dart';

part 'catalog_db.g.dart';

class Cards extends Table {
  TextColumn get oracleId => text()();
  TextColumn get name => text()();
  TextColumn get nameFolded => text()();
  TextColumn get typeLine => text()();
  RealColumn get cmc => real()();
  TextColumn get manaCost => text().nullable()();
  TextColumn get oracleText => text().nullable()();
  TextColumn get power => text().nullable()();
  TextColumn get toughness => text().nullable()();
  TextColumn get colorIdentity => text()();
  TextColumn get rarity => text().nullable()();
  TextColumn get setCode => text().nullable()();
  TextColumn get legalities => text()();
  TextColumn get imageSmall => text().nullable()();
  TextColumn get imageNormal => text().nullable()();

  @override
  Set<Column> get primaryKey => {oracleId};
}

@DriftDatabase(tables: [Cards])
class CatalogDb extends _$CatalogDb {
  CatalogDb() : super(driftDatabase(name: 'catalog'));

  CatalogDb.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  Future<int> cardCount() async {
    final count = countAll();
    final query = selectOnly(cards)..addColumns([count]);
    return await query.map((row) => row.read(count)!).getSingle();
  }

  /// One transaction for the whole batch. Inserting 36000 rows one statement at
  /// a time takes minutes, batched it takes seconds.
  Future<void> insertAll(List<CatalogCard> incoming) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(
        cards,
        incoming.map(_toRow).toList(),
      );
    });
  }

  Future<List<CatalogCard>> searchByName(String term) async {
    final needle = '%${term.toLowerCase()}%';
    final rows = await (select(cards)
          ..where((c) => c.nameFolded.like(needle))
          ..orderBy([(c) => OrderingTerm(expression: c.name)])
          ..limit(100))
        .get();
    return rows.map(_fromRow).toList();
  }

  Future<void> clear() => delete(cards).go();

  CardsCompanion _toRow(CatalogCard c) => CardsCompanion.insert(
        oracleId: c.oracleId,
        name: c.name,
        nameFolded: c.name.toLowerCase(),
        typeLine: c.typeLine,
        cmc: c.cmc,
        manaCost: Value(c.manaCost),
        oracleText: Value(c.oracleText),
        power: Value(c.power),
        toughness: Value(c.toughness),
        colorIdentity: c.colorIdentity.join(''),
        rarity: Value(c.rarity),
        setCode: Value(c.setCode),
        legalities: jsonEncode(c.legalities),
        imageSmall: Value(c.imageSmall),
        imageNormal: Value(c.imageNormal),
      );

  CatalogCard _fromRow(Card row) => CatalogCard(
        oracleId: row.oracleId,
        name: row.name,
        typeLine: row.typeLine,
        cmc: row.cmc,
        manaCost: row.manaCost,
        oracleText: row.oracleText,
        power: row.power,
        toughness: row.toughness,
        colorIdentity: row.colorIdentity.split('').where((s) => s.isNotEmpty).toList(),
        rarity: row.rarity,
        setCode: row.setCode,
        legalities: (jsonDecode(row.legalities) as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v as String)),
        imageSmall: row.imageSmall,
        imageNormal: row.imageNormal,
      );
}
```

- [ ] **Step 5: Generate the drift code**

Run: `dart run build_runner build`
Expected: a line like `Built with build_runner/aot in 52s; wrote 31 outputs.`
and `lib/sources/catalog/catalog_db.g.dart` now exists, about 1290 lines.

Do not pass `--delete-conflicting-outputs`. build_runner 2.16.1 removed it
and prints `These options have been removed and were ignored` if you do.

The generated file is committed. This is an application, not a published
package, so a fresh checkout should build without anyone having to run
codegen first. The cost is a large generated diff whenever the schema moves.

- [ ] **Step 6: Run it and watch it pass**

Run: `flutter test test/sources/catalog_db_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 7: Commit**

```bash
git add lib/sources test/sources
git commit -m "Keep the catalog in sqlite"
```

---

## Task 7: Streaming JSONL

The pure half of the importer, with no network and no platform in it, so it is
the easy thing to test and the thing most likely to be wrong.

**Files:**
- Create: `lib/sources/import/jsonl_stream.dart`
- Test: `test/sources/jsonl_stream_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/sources/jsonl_stream_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/sources/import/jsonl_stream.dart';

Stream<List<int>> _chunks(List<String> pieces) async* {
  for (final piece in pieces) {
    yield utf8.encode(piece);
  }
}

void main() {
  test('it yields one map per line', () async {
    final out = await decodeJsonl(
      _chunks(['{"name":"Sol Ring"}\n{"name":"Llanowar Elves"}\n']),
    ).toList();

    expect(out.map((m) => m['name']), ['Sol Ring', 'Llanowar Elves']);
  });

  test('a record split across two chunks still arrives whole', () async {
    final out = await decodeJsonl(
      _chunks(['{"name":"Sol ', 'Ring"}\n']),
    ).toList();

    expect(out.single['name'], 'Sol Ring');
  });

  test('a last line with no trailing newline is not dropped', () async {
    final out = await decodeJsonl(
      _chunks(['{"a":1}\n{"b":2}']),
    ).toList();

    expect(out.length, 2);
  });

  test('blank lines are skipped rather than throwing', () async {
    final out = await decodeJsonl(
      _chunks(['{"a":1}\n\n\n{"b":2}\n']),
    ).toList();

    expect(out.length, 2);
  });

  test('a card with an accent survives the utf8 boundary', () async {
    final bytes = utf8.encode('{"name":"Ætherize"}\n');
    final out = await decodeJsonl(
      Stream.fromIterable([bytes.sublist(0, 10), bytes.sublist(10)]),
    ).toList();

    expect(out.single['name'], 'Ætherize');
  });
}
```

The last test matters. Splitting a byte stream in the middle of a multi byte
character is exactly what happens with real network chunks, and a naive
`utf8.decode` per chunk corrupts it.

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/sources/jsonl_stream_test.dart`
Expected: FAIL, `Target of URI doesn't exist: 'package:kitchentable/sources/import/jsonl_stream.dart'`

- [ ] **Step 3: Write the implementation**

Create `lib/sources/import/jsonl_stream.dart`:

```dart
import 'dart:convert';

/// Turns a stream of decompressed bytes into one map per line.
///
/// Everything here is incremental on purpose. The catalog is 36000 records and
/// decoding it as one document would peak at hundreds of megabytes on a phone.
/// `utf8.decoder` as a stream transformer also carries partial characters
/// across chunk boundaries, which a per chunk `utf8.decode` would mangle.
Stream<Map<String, dynamic>> decodeJsonl(Stream<List<int>> bytes) {
  return bytes
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .where((line) => line.trim().isNotEmpty)
      .map((line) => jsonDecode(line) as Map<String, dynamic>);
}
```

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/sources/jsonl_stream_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/sources/import test/sources/jsonl_stream_test.dart
git commit -m "Read JSONL a line at a time"
```

---

## Task 8: Gunzip, with web kept out of it

**Files:**
- Create: `lib/sources/import/gunzip.dart`
- Create: `lib/sources/import/gunzip_io.dart`
- Create: `lib/sources/import/gunzip_web.dart`

- [ ] **Step 1: Write the shim**

Create `lib/sources/import/gunzip.dart`:

```dart
export 'gunzip_web.dart' if (dart.library.io) 'gunzip_io.dart';
```

- [ ] **Step 2: Write the io implementation**

Create `lib/sources/import/gunzip_io.dart`:

```dart
import 'dart:io';

Stream<List<int>> gunzipStream(Stream<List<int>> compressed) =>
    compressed.transform(gzip.decoder);
```

- [ ] **Step 3: Write the web stub**

Create `lib/sources/import/gunzip_web.dart`:

```dart
/// The web build exists so the interface can be looked at on a machine with no
/// display and no emulator. Importing 24 MB into browser storage is a separate
/// piece of work and nobody needs it yet.
Stream<List<int>> gunzipStream(Stream<List<int>> compressed) {
  throw UnsupportedError('Importing is not available on the web build');
}
```

This task cannot prove itself. Nothing imports `gunzip.dart` yet, and the web
compiler only compiles what is reachable from `main.dart`, so the web build
succeeds whether or not the conditional export is correct. Verified on
2026 09 21: an unconditional `export 'gunzip_io.dart';` still built web fine,
and the bundle contained zero occurrences of gunzip.

So the real proof is deferred to Task 9, which is the first thing to import it.
Task 9 Step 6 carries it. Do not skip it there.

- [ ] **Step 4: Prove both builds still compile**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter build web --release`
Expected: `Built build/web`

- [ ] **Step 5: Commit**

```bash
git add lib/sources/import
git commit -m "Gunzip on device, refuse politely on the web"
```

---

## Task 9: The importer

Two progress signals, not one. Bytes depend on the network, records depend on
the device, and a single bar covering both is the one that sits at 99 percent.

**Files:**
- Create: `lib/sources/import/scryfall_importer.dart`
- Test: `test/sources/scryfall_importer_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/sources/scryfall_importer_test.dart`:

```dart
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/sources/catalog/catalog_db.dart';
import 'package:kitchentable/sources/import/scryfall_importer.dart';

String _record(String id, String name) => jsonEncode({
      'oracle_id': id,
      'name': name,
      'type_line': 'Creature - Elf',
      'cmc': 2,
      'color_identity': ['G'],
      'legalities': {'commander': 'legal'},
      'image_uris': {'small': 'https://example.invalid/$id.jpg'},
    });

void main() {
  late CatalogDb db;

  setUp(() => db = CatalogDb.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('it indexes every record it is handed', () async {
    final importer = ScryfallImporter(db: db, batchSize: 2);

    await importer.indexFrom(Stream.fromIterable([
      utf8.encode('${_record('a', 'Llanowar Elves')}\n'
          '${_record('b', 'Sol Ring')}\n'
          '${_record('c', 'Birds of Paradise')}\n'),
    ]));

    expect(await db.cardCount(), 3);
  });

  test('it reports progress once per batch, not once at the end', () async {
    final importer = ScryfallImporter(db: db, batchSize: 2);
    final seen = <int>[];

    await importer.indexFrom(
      Stream.fromIterable([
        utf8.encode('${_record('a', 'A')}\n${_record('b', 'B')}\n'
            '${_record('c', 'C')}\n'),
      ]),
      onIndexed: seen.add,
    );

    // Three records at a batch size of two is one full flush then the
    // remainder. Asserting the whole sequence rather than just the total is
    // deliberate: `expect(seen.last, 3)` passes even when batching is removed
    // entirely, so it would not protect the thing the batch exists for.
    // Inserting 36000 rows one statement at a time takes minutes on a phone.
    expect(seen, [2, 3]);
  });

  test('a record missing oracle_id is skipped rather than killing the import',
      () async {
    final importer = ScryfallImporter(db: db, batchSize: 10);

    await importer.indexFrom(Stream.fromIterable([
      utf8.encode('${_record('a', 'A')}\n'
          '${jsonEncode({'name': 'no id here'})}\n'
          '${_record('b', 'B')}\n'),
    ]));

    expect(await db.cardCount(), 2);
    expect(importer.skipped, 1);
  });

  test('it finds the jsonl url in a bulk object', () {
    final url = ScryfallImporter.jsonlUrlFrom({
      'object': 'bulk_data',
      'type': 'oracle_cards',
      'jsonl_download_uri': 'https://data.scryfall.io/oracle-cards/x.jsonl.gz',
      'compressed_size': 24710557,
    });

    expect(url.toString(), 'https://data.scryfall.io/oracle-cards/x.jsonl.gz');
  });

  test('a bulk object without the jsonl field fails loudly', () {
    expect(
      () => ScryfallImporter.jsonlUrlFrom({'object': 'bulk_data'}),
      throwsA(isA<FormatException>()),
    );
  });
}
```

That last pair exists because Scryfall removed `download_uri` and `size` from
the bulk object during 2026. If they move the field again we want a clear
error, not a null dereference three layers down.

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/sources/scryfall_importer_test.dart`
Expected: FAIL, `Target of URI doesn't exist: 'package:kitchentable/sources/import/scryfall_importer.dart'`

- [ ] **Step 3: Write the implementation**

Create `lib/sources/import/scryfall_importer.dart`:

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../catalog/catalog_db.dart';
import '../model/catalog_card.dart';
import 'gunzip.dart';
import 'jsonl_stream.dart';

/// Scryfall asks every client to identify itself and to stay under ten
/// requests a second. We make two requests per import, so the rate is somebody
/// else's problem, but the header is ours.
const scryfallHeaders = {
  'User-Agent': 'kitchentable/0.1',
  'Accept': 'application/json',
};

class ScryfallImporter {
  ScryfallImporter({
    required this.db,
    this.batchSize = 500,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final CatalogDb db;
  final int batchSize;
  final http.Client _client;

  /// Records we could not read. Kept rather than thrown so one bad line does
  /// not cost the player a 24 MB download.
  int skipped = 0;

  /// As of 2026 the bulk object carries `jsonl_download_uri` and
  /// `compressed_size`. The older `download_uri` and `size` are gone.
  static Uri jsonlUrlFrom(Map<String, dynamic> bulk) {
    final raw = bulk['jsonl_download_uri'];
    if (raw is! String) {
      throw const FormatException(
        'Scryfall bulk object has no jsonl_download_uri',
      );
    }
    return Uri.parse(raw);
  }

  static int? compressedSizeFrom(Map<String, dynamic> bulk) =>
      (bulk['compressed_size'] as num?)?.toInt();

  Future<Map<String, dynamic>> fetchBulkObject(Uri endpoint) async {
    final response = await _client.get(endpoint, headers: scryfallHeaders);
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Scryfall answered ${response.statusCode}',
        endpoint,
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Streams the gzipped file, reporting bytes as they land.
  Future<void> downloadAndIndex(
    Uri jsonlUrl, {
    void Function(int received, int? total)? onBytes,
    void Function(int indexed)? onIndexed,
  }) async {
    final request = http.Request('GET', jsonlUrl)
      ..headers.addAll({'User-Agent': scryfallHeaders['User-Agent']!});
    final response = await _client.send(request);

    if (response.statusCode != 200) {
      throw http.ClientException(
        'Scryfall answered ${response.statusCode}',
        jsonlUrl,
      );
    }

    final total = response.contentLength;
    var received = 0;

    final counted = response.stream.map((chunk) {
      received += chunk.length;
      onBytes?.call(received, total);
      return chunk;
    });

    await indexFrom(gunzipStream(counted), onIndexed: onIndexed);
  }

  /// Takes decompressed bytes so the tests never need gzip or a socket.
  Future<void> indexFrom(
    Stream<List<int>> decompressed, {
    void Function(int indexed)? onIndexed,
  }) async {
    var buffer = <CatalogCard>[];
    var indexed = 0;

    Future<void> flush() async {
      if (buffer.isEmpty) return;
      await db.insertAll(buffer);
      indexed += buffer.length;
      onIndexed?.call(indexed);
      buffer = <CatalogCard>[];
    }

    await for (final record in decodeJsonl(decompressed)) {
      try {
        buffer.add(CatalogCard.fromScryfall(record));
      } catch (_) {
        skipped++;
        continue;
      }
      if (buffer.length >= batchSize) await flush();
    }

    await flush();
  }

  void dispose() => _client.close();
}
```

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/sources/scryfall_importer_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Do not try to prove the gunzip export here**

An earlier version of this plan put Task 8's deferred web probe in this task, on
the grounds that this file is the first to import `gunzip.dart`. That was wrong
and it was tried: on 2026 09 21 an unconditional `export 'gunzip_io.dart';`
still built web cleanly, and `build/web/main.dart.js` contained zero occurrences
of gunzip or ScryfallImporter.

Importing is not the condition. **Reachability from `main.dart` is.** Nothing in
`lib/` reaches `ScryfallImporter`: `main.dart` goes to `app.dart`, which at this
point still only pulls in `ui/tokens`. The only file importing the importer is
its own test, and tests are not part of the web compilation. So the whole thing
is tree shaken away and the build says nothing either way.

The debt moves to Task 13, which is the first task that wires the importer to a
screen the app can actually open.

- [ ] **Step 6: Commit**

```bash
git add lib/sources/import test/sources/scryfall_importer_test.dart
git commit -m "Stream the catalog in and count both waits separately"
```

---

## Task 10: The menu state

**Files:**
- Create: `lib/features/menu/menu_controller.dart`
- Test: `test/features/menu_controller_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/menu_controller_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/menu/menu_controller.dart';

void main() {
  test('with no catalog, play and decks are shut and focus starts on sources',
      () {
    const state = MenuState(cardCount: 0, enabledSources: 0);
    final entries = state.entries;

    expect(entries.firstWhere((e) => e.id == MenuEntryId.play).enabled, isFalse);
    expect(entries.firstWhere((e) => e.id == MenuEntryId.decks).enabled, isFalse);
    expect(state.initialFocus, MenuEntryId.sources);
  });

  test('sources and settings are always reachable', () {
    const state = MenuState(cardCount: 0, enabledSources: 0);
    final entries = state.entries;

    expect(
        entries.firstWhere((e) => e.id == MenuEntryId.sources).enabled, isTrue);
    expect(
        entries.firstWhere((e) => e.id == MenuEntryId.settings).enabled, isTrue);
  });

  test('with a catalog, play opens and focus moves to it', () {
    const state = MenuState(cardCount: 36079, enabledSources: 1);

    expect(state.entries.firstWhere((e) => e.id == MenuEntryId.play).enabled,
        isTrue);
    expect(state.initialFocus, MenuEntryId.play);
  });

  test('the header counts the real catalog', () {
    expect(const MenuState(cardCount: 0, enabledSources: 0).headline,
        'NO SOURCES CONFIGURED');
    expect(const MenuState(cardCount: 36079, enabledSources: 1).headline,
        '36079 CARDS');
  });

  test('a shut entry says why it is shut', () {
    const state = MenuState(cardCount: 0, enabledSources: 0);
    expect(state.entries.firstWhere((e) => e.id == MenuEntryId.play).subtitle,
        'needs a source');
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/menu_controller_test.dart`
Expected: FAIL, `Target of URI doesn't exist: 'package:kitchentable/features/menu/menu_controller.dart'`

- [ ] **Step 3: Write the implementation**

Create `lib/features/menu/menu_controller.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sources/catalog/catalog_db.dart';

enum MenuEntryId { play, decks, sources, settings }

class MenuEntry {
  const MenuEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.enabled,
  });

  final MenuEntryId id;
  final String title;
  final String subtitle;
  final bool enabled;
}

/// The menu is not a fixed list with a tutorial bolted on. It reads the real
/// state and shows what is actually possible, which is why there is no welcome
/// screen anywhere in this app.
class MenuState {
  const MenuState({required this.cardCount, required this.enabledSources});

  final int cardCount;
  final int enabledSources;

  bool get hasCatalog => cardCount > 0;

  String get headline =>
      hasCatalog ? '$cardCount CARDS' : 'NO SOURCES CONFIGURED';

  MenuEntryId get initialFocus =>
      hasCatalog ? MenuEntryId.play : MenuEntryId.sources;

  List<MenuEntry> get entries => [
        MenuEntry(
          id: MenuEntryId.play,
          title: 'Play',
          subtitle: hasCatalog ? 'host a table or join by code' : 'needs a source',
          enabled: hasCatalog,
        ),
        MenuEntry(
          id: MenuEntryId.decks,
          title: 'Decks',
          subtitle: hasCatalog ? 'no decks yet' : 'needs a source',
          enabled: hasCatalog,
        ),
        MenuEntry(
          id: MenuEntryId.sources,
          title: 'Sources',
          subtitle: enabledSources == 0
              ? 'start here'
              : '$enabledSources on',
          enabled: true,
        ),
        const MenuEntry(
          id: MenuEntryId.settings,
          title: 'Settings',
          subtitle: 'appearance, network, D-pad',
          enabled: true,
        ),
      ];
}

final catalogDbProvider = Provider<CatalogDb>((ref) {
  final db = CatalogDb();
  ref.onDispose(db.close);
  return db;
});

final menuStateProvider = FutureProvider<MenuState>((ref) async {
  final db = ref.watch(catalogDbProvider);
  final count = await db.cardCount();
  return MenuState(cardCount: count, enabledSources: count > 0 ? 1 : 0);
});
```

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/features/menu_controller_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/features/menu test/features/menu_controller_test.dart
git commit -m "Let the menu read the real state instead of guessing"
```

---

## Task 11: The menu screen

**Files:**
- Create: `lib/features/menu/menu_screen.dart`
- Modify: `lib/app.dart`
- Modify: `lib/main.dart`
- Test: `test/features/menu_screen_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/menu_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/menu/menu_controller.dart';
import 'package:kitchentable/features/menu/menu_screen.dart';

Widget _host(MenuState state) => ProviderScope(
      overrides: [
        menuStateProvider.overrideWith((ref) async => state),
      ],
      child: const MaterialApp(home: MenuScreen()),
    );

void main() {
  testWidgets('an empty app points at Sources', (tester) async {
    await tester.pumpWidget(_host(
      const MenuState(cardCount: 0, enabledSources: 0),
    ));
    await tester.pumpAndSettle();

    expect(find.text('NO SOURCES CONFIGURED'), findsOneWidget);
    expect(find.text('start here'), findsOneWidget);
    expect(find.text('needs a source'), findsNWidgets(2));
  });

  testWidgets('a loaded catalog shows the real count', (tester) async {
    await tester.pumpWidget(_host(
      const MenuState(cardCount: 36079, enabledSources: 1),
    ));
    await tester.pumpAndSettle();

    expect(find.text('36079 CARDS'), findsOneWidget);
    expect(find.text('host a table or join by code'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/menu_screen_test.dart`
Expected: FAIL, `Target of URI doesn't exist: 'package:kitchentable/features/menu/menu_screen.dart'`

- [ ] **Step 3: Write the screen**

Create `lib/features/menu/menu_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/atoms/hint_bar.dart';
import '../../ui/atoms/menu_row.dart';
import '../../ui/tokens/metrics.dart';
import '../../ui/tokens/palette.dart';
import '../sources/sources_screen.dart';
import 'menu_controller.dart';

class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = MediaQuery.of(context);
    final deviceClass = classifyDevice(
      size: media.size,
      hasTouch: media.navigationMode == NavigationMode.traditional,
    );
    final m = Metrics.of(deviceClass);
    final async = ref.watch(menuStateProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(m.safeInset),
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text('$e', style: const TextStyle(color: Palette.ink)),
            ),
            data: (state) => _Menu(state: state, metrics: m),
          ),
        ),
      ),
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu({required this.state, required this.metrics});

  final MenuState state;
  final Metrics metrics;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'kitchen'),
            TextSpan(
              text: 'table',
              style: const TextStyle(color: Palette.accent),
            ),
          ]),
          style: TextStyle(
            fontSize: m.scaled(24),
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            color: Palette.ink,
          ),
        ),
        SizedBox(height: m.scaled(4)),
        Text(
          state.headline,
          style: TextStyle(
            fontSize: m.scaled(10),
            letterSpacing: 0.8,
            color: Palette.inkFaint,
          ),
        ),
        SizedBox(height: m.scaled(20)),
        for (final entry in state.entries)
          MenuRow(
            title: entry.title,
            subtitle: entry.subtitle,
            enabled: entry.enabled,
            metrics: m,
            autofocus: entry.id == state.initialFocus,
            onActivate: () => _open(context, entry.id),
          ),
        const Spacer(),
        HintBar(
          metrics: m,
          hints: const [
            Hint(button: '▲▼', label: 'move'),
            Hint(button: 'A', label: 'open'),
          ],
        ),
      ],
    );
  }

  void _open(BuildContext context, MenuEntryId id) {
    if (id != MenuEntryId.sources) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SourcesScreen()),
    );
  }
}
```

- [ ] **Step 4: Point the app at the menu**

Replace the whole of `lib/app.dart` with:

```dart
import 'package:flutter/material.dart';

import 'features/menu/menu_screen.dart';
import 'ui/tokens/theme.dart';

class KitchentableApp extends StatelessWidget {
  const KitchentableApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'kitchentable',
      theme: kitchentableTheme(),
      debugShowCheckedModeBanner: false,
      home: const MenuScreen(),
    );
  }
}
```

Replace the whole of `lib/main.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  runApp(const ProviderScope(child: KitchentableApp()));
}
```

- [ ] **Step 5: Run it and watch it pass**

Run: `flutter test test/features/menu_screen_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 6: Run everything**

Run: `flutter test`
Expected: PASS, all tests.

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib test
git commit -m "The menu is the first thing you see and the only tutorial"
```

---

## Task 12: The sources screen

**Files:**
- Create: `lib/features/sources/sources_screen.dart`
- Test: `test/features/sources_screen_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/sources_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/sources/sources_screen.dart';

void main() {
  testWidgets('it lists the known sources and says none has run', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: SourcesScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Scryfall'), findsOneWidget);
    expect(find.text('MTGJSON'), findsOneWidget);
    expect(find.textContaining('NOTHING HAS LEFT THIS DEVICE'), findsOneWidget);
  });

  testWidgets('a source that downloads states its size up front',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: SourcesScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('23.6 MB'), findsOneWidget);
  });

  testWidgets('a source we have not built says so instead of pretending',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: SourcesScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('not ready yet'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/sources_screen_test.dart`
Expected: FAIL, `Target of URI doesn't exist: 'package:kitchentable/features/sources/sources_screen.dart'`

- [ ] **Step 3: Write the screen**

Create `lib/features/sources/sources_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sources/model/source_def.dart';
import '../../sources/source_registry.dart';
import '../../ui/atoms/hint_bar.dart';
import '../../ui/atoms/menu_row.dart';
import '../../ui/tokens/metrics.dart';
import '../../ui/tokens/palette.dart';

String formatMegabytes(int bytes) =>
    '${(bytes / 1048576).toStringAsFixed(1)} MB';

class SourcesScreen extends ConsumerWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = MediaQuery.of(context);
    final m = Metrics.of(classifyDevice(
      size: media.size,
      hasTouch: media.navigationMode == NavigationMode.traditional,
    ));

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(m.safeInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sources',
                style: TextStyle(
                  fontSize: m.scaled(20),
                  fontWeight: FontWeight.w600,
                  color: Palette.ink,
                ),
              ),
              SizedBox(height: m.scaled(4)),
              Text(
                'NOTHING HAS LEFT THIS DEVICE YET',
                style: TextStyle(
                  fontSize: m.scaled(10),
                  letterSpacing: 0.8,
                  color: Palette.inkFaint,
                ),
              ),
              SizedBox(height: m.scaled(18)),
              for (final source in knownSources)
                MenuRow(
                  title: source.name,
                  subtitle: _subtitleFor(source),
                  enabled: source.available,
                  metrics: m,
                  autofocus: source.id == knownSources.first.id,
                  onActivate: () {},
                ),
              const Spacer(),
              HintBar(
                metrics: m,
                hints: const [
                  Hint(button: '▲▼', label: 'move'),
                  Hint(button: 'A', label: 'switch on'),
                  Hint(button: 'B', label: 'back'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Nobody should be surprised by a download, so the size is on the row before
  /// it is touched.
  String _subtitleFor(SourceDef source) {
    if (!source.available) return '${source.subtitle} · not ready yet';
    final bytes = source.approximateBytes;
    if (bytes == null) return source.subtitle;
    return '${source.subtitle} · ${formatMegabytes(bytes)} · downloads';
  }
}
```

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/features/sources_screen_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/features/sources test/features/sources_screen_test.dart
git commit -m "List the sources with their sizes, all of them off"
```

---

## Task 13: The import screen with two bars

**Files:**
- Create: `lib/ui/atoms/progress_track.dart`
- Create: `lib/features/sources/import_controller.dart`
- Create: `lib/features/sources/import_screen.dart`
- Modify: `lib/features/sources/sources_screen.dart`
- Test: `test/features/import_controller_test.dart`

- [ ] **Step 1: Write the failing controller test**

Create `test/features/import_controller_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/sources/import_controller.dart';

void main() {
  test('it starts idle with both bars empty', () {
    const s = ImportState();
    expect(s.phase, ImportPhase.idle);
    expect(s.downloadFraction, 0);
    expect(s.indexFraction, 0);
  });

  test('download progress is bytes over total', () {
    const s = ImportState(
      phase: ImportPhase.downloading,
      received: 12355278,
      total: 24710557,
    );
    expect(s.downloadFraction, closeTo(0.5, 0.01));
  });

  test('an unknown total leaves the bar indeterminate rather than lying', () {
    const s = ImportState(phase: ImportPhase.downloading, received: 500);
    expect(s.downloadFraction, isNull);
  });

  test('indexing counts against the estimate', () {
    const s = ImportState(
      phase: ImportPhase.indexing,
      indexed: 18000,
      estimatedRecords: 36000,
    );
    expect(s.indexFraction, closeTo(0.5, 0.01));
  });

  test('indexing never reports more than finished', () {
    const s = ImportState(
      phase: ImportPhase.indexing,
      indexed: 40000,
      estimatedRecords: 36000,
    );
    expect(s.indexFraction, 1.0);
  });

  test('a failure carries its reason', () {
    const s = ImportState(phase: ImportPhase.failed, error: 'no network');
    expect(s.error, 'no network');
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/import_controller_test.dart`
Expected: FAIL, `Target of URI doesn't exist: 'package:kitchentable/features/sources/import_controller.dart'`

- [ ] **Step 3: Write the controller**

Create `lib/features/sources/import_controller.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sources/import/scryfall_importer.dart';
import '../../sources/model/source_def.dart';
import '../menu/menu_controller.dart';

enum ImportPhase { idle, downloading, indexing, done, failed }

/// Two numbers, not one. Bytes are the network's business and records are the
/// device's, and a single bar over both is the one that parks at 99 percent.
class ImportState {
  const ImportState({
    this.phase = ImportPhase.idle,
    this.received = 0,
    this.total,
    this.indexed = 0,
    this.estimatedRecords = 36000,
    this.error,
  });

  final ImportPhase phase;
  final int received;
  final int? total;
  final int indexed;
  final int estimatedRecords;
  final String? error;

  /// Null means indeterminate. A server that sends no content length gets an
  /// honest spinner rather than a fake percentage.
  double? get downloadFraction {
    if (phase == ImportPhase.idle) return 0;
    final t = total;
    if (t == null || t <= 0) return null;
    return (received / t).clamp(0.0, 1.0);
  }

  double get indexFraction {
    if (estimatedRecords <= 0) return 0;
    return (indexed / estimatedRecords).clamp(0.0, 1.0);
  }

  ImportState copyWith({
    ImportPhase? phase,
    int? received,
    int? total,
    int? indexed,
    int? estimatedRecords,
    String? error,
  }) =>
      ImportState(
        phase: phase ?? this.phase,
        received: received ?? this.received,
        total: total ?? this.total,
        indexed: indexed ?? this.indexed,
        estimatedRecords: estimatedRecords ?? this.estimatedRecords,
        error: error ?? this.error,
      );
}

class ImportNotifier extends Notifier<ImportState> {
  @override
  ImportState build() => const ImportState();

  Future<void> run(SourceDef source) async {
    final endpoint = source.endpoint;
    if (endpoint == null) return;

    final importer = ScryfallImporter(db: ref.read(catalogDbProvider));
    state = const ImportState(phase: ImportPhase.downloading);

    try {
      final bulk = await importer.fetchBulkObject(endpoint);
      final url = ScryfallImporter.jsonlUrlFrom(bulk);
      final size = ScryfallImporter.compressedSizeFrom(bulk);

      state = state.copyWith(total: size);

      await importer.downloadAndIndex(
        url,
        onBytes: (received, total) {
          state = state.copyWith(received: received, total: total ?? size);
        },
        onIndexed: (indexed) {
          state = state.copyWith(phase: ImportPhase.indexing, indexed: indexed);
        },
      );

      state = state.copyWith(phase: ImportPhase.done);
      ref.invalidate(menuStateProvider);
    } catch (e) {
      state = state.copyWith(phase: ImportPhase.failed, error: '$e');
    } finally {
      importer.dispose();
    }
  }
}

final importProvider =
    NotifierProvider<ImportNotifier, ImportState>(ImportNotifier.new);
```

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/features/import_controller_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 5: Write the progress atom**

Create `lib/ui/atoms/progress_track.dart`:

```dart
import 'package:flutter/material.dart';

import '../tokens/metrics.dart';
import '../tokens/palette.dart';

class ProgressTrack extends StatelessWidget {
  const ProgressTrack({
    super.key,
    required this.metrics,
    required this.label,
    required this.fraction,
    required this.trailing,
    this.dimmed = false,
  });

  final Metrics metrics;
  final String label;

  /// Null draws an indeterminate bar. Do not invent a number.
  final double? fraction;
  final String trailing;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: Container(
        margin: EdgeInsets.only(bottom: m.scaled(8)),
        padding: EdgeInsets.all(m.scaled(12)),
        decoration: BoxDecoration(
          color: Palette.surface,
          borderRadius: BorderRadius.circular(m.scaled(10)),
          border: Border.all(color: Palette.surfaceEdge),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: m.scaled(12), color: Palette.ink),
            ),
            SizedBox(height: m.scaled(7)),
            ClipRRect(
              borderRadius: BorderRadius.circular(m.scaled(4)),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: m.scaled(5),
                backgroundColor: Palette.feltEdge,
                valueColor: const AlwaysStoppedAnimation(Palette.accent),
              ),
            ),
            SizedBox(height: m.scaled(5)),
            Text(
              trailing,
              style: TextStyle(fontSize: m.scaled(10), color: Palette.inkFaint),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Write the import screen**

Create `lib/features/sources/import_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sources/model/source_def.dart';
import '../../ui/atoms/hint_bar.dart';
import '../../ui/atoms/progress_track.dart';
import '../../ui/tokens/metrics.dart';
import '../../ui/tokens/palette.dart';
import 'import_controller.dart';
import 'sources_screen.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key, required this.source});

  final SourceDef source;

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(importProvider.notifier).run(widget.source);
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final m = Metrics.of(classifyDevice(
      size: media.size,
      hasTouch: media.navigationMode == NavigationMode.traditional,
    ));
    final s = ref.watch(importProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(m.safeInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.source.name,
                style: TextStyle(
                  fontSize: m.scaled(20),
                  fontWeight: FontWeight.w600,
                  color: Palette.ink,
                ),
              ),
              SizedBox(height: m.scaled(18)),
              ProgressTrack(
                metrics: m,
                label: 'Downloading',
                fraction: s.downloadFraction,
                trailing: s.total == null
                    ? '${formatMegabytes(s.received)} so far'
                    : '${formatMegabytes(s.received)} of '
                        '${formatMegabytes(s.total!)}',
              ),
              ProgressTrack(
                metrics: m,
                label: 'Indexing',
                fraction: s.phase == ImportPhase.downloading ? 0 : s.indexFraction,
                trailing: s.phase == ImportPhase.downloading
                    ? 'waiting'
                    : '${s.indexed} cards',
                dimmed: s.phase == ImportPhase.downloading,
              ),
              if (s.phase == ImportPhase.failed)
                Padding(
                  padding: EdgeInsets.only(top: m.scaled(6)),
                  child: Text(
                    s.error ?? 'It did not work',
                    style: TextStyle(
                      fontSize: m.scaled(11),
                      color: Palette.attention,
                    ),
                  ),
                ),
              if (s.phase == ImportPhase.done)
                Padding(
                  padding: EdgeInsets.only(top: m.scaled(6)),
                  child: Text(
                    'Done. ${s.indexed} cards.',
                    style: TextStyle(fontSize: m.scaled(12), color: Palette.ink),
                  ),
                ),
              const Spacer(),
              HintBar(
                metrics: m,
                hints: const [Hint(button: 'B', label: 'back')],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 7: Make the sources screen open it**

In `lib/features/sources/sources_screen.dart`, add this import next to the
others:

```dart
import 'import_screen.dart';
```

and replace `onActivate: () {},` with:

```dart
                  onActivate: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ImportScreen(source: source),
                    ),
                  ),
```

- [ ] **Step 8: Run everything**

Run: `flutter test`
Expected: PASS, all tests.

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 9: Collect the gunzip debt, at last**

Task 8 created the conditional gunzip export and could not prove it. Task 9
tried and could not either. This is the first task where `ScryfallImporter` is
reachable from `main.dart`: import_screen pulls import_controller, which pulls
the importer, and sources_screen opens import_screen, and the menu opens
sources_screen, and app.dart opens the menu.

First confirm the chain is real rather than assuming it:

```bash
grep -c "gunzip\|ScryfallImporter" build/web/main.dart.js
```

after a successful `flutter build web --release`. If that is still 0, the
importer is STILL not reachable and the probe below cannot bite. Say so and stop.

If it is greater than 0, run the probe. Change `lib/sources/import/gunzip.dart`
to an unconditional `export 'gunzip_io.dart';` and run
`flutter build web --release` again. It must now FAIL on `dart:io` not being
available. Restore the conditional export and confirm the build succeeds.

A passing web build is not evidence here unless the grep above proved the code
was actually compiled in.

- [ ] **Step 10: Commit**

```bash
git add lib test
git commit -m "Import the catalog, with a bar for each kind of waiting"
```

---

## Task 14: Prove it on a real device

The tests never touch the network. This is the step that finds out whether the
import survives 24 MB and 36000 rows on hardware, which is the only question
that matters.

- [ ] **Step 1: Build the APK**

Run: `flutter build apk --release`
Expected: `Built build/app/outputs/flutter-apk/app-release.apk`

- [ ] **Step 2: Install it on an Android device and import**

Open the app, confirm the menu says `NO SOURCES CONFIGURED` and that Play and
Decks are dimmed. Open Sources, confirm the Scryfall row reads
`card catalog · 23.6 MB · downloads`. Switch it on.

Write down three things:
- how long the download takes
- how long the indexing takes after the download finishes
- whether the app is killed by the system during indexing

- [ ] **Step 3: Confirm the menu changed**

Go back. The header should read the real count, Play and Decks should be lit,
and focus should have moved to Play.

- [ ] **Step 4: Record what you measured**

Append a short note to `docs/specs/2026-09-21-kitchentable-design.md` under
"Importing card data" with the three numbers from Step 2. If indexing takes
more than about thirty seconds, or the system kills the app, that is a real
finding and the batch size in `ScryfallImporter` is the first thing to change.

- [ ] **Step 5: Commit**

```bash
git add docs
git commit -m "Write down what the import actually costs on hardware"
```

---

## What this plan deliberately leaves out

- Switching a source back off, and deleting a catalog. Needs a confirmation
  flow and nobody can get into trouble yet.
- Remembering which sources are on across restarts. Right now a non empty
  catalog is the evidence that Scryfall was imported, which is true until there
  is a second catalog source.
- MTGJSON set import for draft, the Pokemon catalog, local file and custom URL.
  All four are in the registry marked unavailable so the screen tells the truth
  about them.
- Card images. Nothing displays a card yet.
- Everything about playing.
