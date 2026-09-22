# Cards you can move, implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A tap turns a card and turns it back, a long press opens everything
else, a card can be dragged anywhere on its own mat, and the Play menu can open
a table with more than one seat.

**Architecture:** No new verb. `MoveCard` already carries a `position` and
`apply` already honours it, including a move into the pile the card came from,
so dragging is a move to the same zone at the same index. `RotateCard` gains an
optional angle instead of always advancing ninety degrees.

**Tech Stack:** Flutter 3.47.5, Dart 3.13.4, flutter_riverpod 3.4.3.

---

## Where this came from

The player used the web build on 2026 09 22 and said three things.

**Tapping is wrong.** A card turns ninety degrees per tap, so four taps walk it
through upside down and back. At a table a card is either straight or turned,
and the other orientations are deliberate acts, not stops on the way.

**The mat is rigid.** Cards flow into slots and cannot be put where the player
wants them. `CardInstance.position` has existed since plan 2 and nothing has
ever written to it. Plan 3 said the field stays unwritten "until the canvas can
show what it means". The canvas exists now.

**The two views look the same.** They do, and it is not a rendering fault: the
Play menu only ever calls `start(deck)`, which seats one player, and with one
seat `StackedSeats` draws no bands and `FreeCanvas` draws one mat. Everything
plan 3 built for several seats is unreachable from the app. That is the last
task here.

## What stays the way it is

**Eleven verbs.** `MoveCard(cardId, toZoneId, at, position)` covers dragging
exactly, and `_move` in `apply.dart` already lifts the card out before putting
it back, with a comment saying that is for the same pile case. A twelfth verb
has to be argued for, and this one cannot be.

**A press and hold still opens the 3D viewer.** It is the thing the player
asked for twice and liked, and asked for again by name while this plan was
being written. The first draft moved it behind a menu sheet and that was
wrong. The controls go onto the big card instead, so the gesture the player
already has in their thumb keeps doing what it did and gains the rest.

**Positions are normalized against the seat's mat, 0 to 1.** That is what lets
both renderers show the same arrangement, and it is why a drag divides by the
mat and not by the screen.

## File structure

```
lib/
  table/
    model/card_instance.dart   MODIFY  turned() replaces rotated()
    actions/table_action.dart  MODIFY  RotateCard gains an angle
    actions/apply.dart         MODIFY  passes the angle through
  ui/organisms/card_viewer.dart MODIFY the big card carries the controls
  features/play/
    play_screen.dart           MODIFY  wires the viewer and the drag
    widgets/cursor_board.dart  MODIFY  a positioned mat, not a Wrap
  features/decks/
    play_decks_screen.dart     MODIFY  open a table with several seats
```

---

## Task 1: A tap turns a card, and turns it back

**Files:**
- Modify: `lib/table/model/card_instance.dart`
- Modify: `lib/table/actions/table_action.dart`
- Modify: `lib/table/actions/apply.dart`
- Test: `test/table/card_instance_test.dart`, `test/table/apply_test.dart`

- [ ] **Step 1: Write the failing tests**

Append to `test/table/card_instance_test.dart`, inside `main()`:

```dart
  test('a tap turns a card, and a second tap turns it back', () {
    const card = CardInstance(id: 'c', oracleId: 'o');

    // At a table a card is straight or it is turned. Ninety per tap walked it
    // through upside down on the way back, which is what the player hit.
    expect(card.turned().rotation, 90);
    expect(card.turned().turned().rotation, 0);
  });

  test('a card turned any other way comes back straight on a tap', () {
    const card = CardInstance(id: 'c', oracleId: 'o', rotation: 180);

    expect(card.turned().rotation, 0);
  });

  test('an angle can be set outright', () {
    const card = CardInstance(id: 'c', oracleId: 'o');

    expect(card.turnedTo(180).rotation, 180);
    expect(card.turnedTo(180).turnedTo(180).rotation, 180,
        reason: 'setting an angle is not a toggle');
  });
```

Append to `test/table/apply_test.dart`, inside `main()`:

```dart
  test('rotating twice leaves a card where it started', () {
    final table = _tableWith([const CardInstance(id: 'a', oracleId: 'o')]);
    final once = apply(table, const RotateCard('a'));
    final twice = apply(once, const RotateCard('a'));

    expect(once.locate('a')!.card.rotation, 90);
    expect(twice.locate('a')!.card.rotation, 0);
  });

  test('rotating to an angle sets it', () {
    final table = _tableWith([const CardInstance(id: 'a', oracleId: 'o')]);
    final next = apply(table, const RotateCard('a', to: 180));

    expect(next.locate('a')!.card.rotation, 180);
  });
```

If `apply_test.dart` has no `_tableWith` helper, read the file and build the
table the way its neighbouring cases do rather than adding a second helper.

- [ ] **Step 2: Run them and watch them fail**

Run: `flutter test test/table/card_instance_test.dart test/table/apply_test.dart`
Expected: FAIL to compile, `The method 'turned' isn't defined` and
`No named parameter with the name 'to'`.

- [ ] **Step 3: Replace rotated with turned**

In `lib/table/model/card_instance.dart`, replace:

```dart
  CardInstance rotated() => copyWith(rotation: (rotation + 90) % 360);
```

with:

```dart
  /// Straight becomes turned, and anything else becomes straight.
  ///
  /// Not `(rotation + 90) % 360`, which was the first answer and is wrong for
  /// the gesture it is bound to: four taps walked a card through upside down
  /// on the way back to where it started. Upside down is a thing somebody
  /// means, so it belongs on the menu and not on the way past.
  CardInstance turned() => copyWith(rotation: rotation == 0 ? 90 : 0);

  /// An exact angle, for the menu. Quarter turns, and it does not toggle.
  CardInstance turnedTo(int degrees) =>
      copyWith(rotation: degrees % 360);
```

In `lib/table/actions/table_action.dart`, replace the `RotateCard` class:

```dart
/// Turns a card. With no angle it is a toggle, straight to turned and back,
/// which is the tap. With one it sets that angle, which is the menu.
class RotateCard extends TableAction {
  const RotateCard(this.cardId, {this.to});
  final String cardId;
  final int? to;
}
```

In `lib/table/actions/apply.dart`, replace the `RotateCard()` arm:

```dart
      RotateCard() => _onCard(
          table,
          action.cardId,
          (c) => action.to == null ? c.turned() : c.turnedTo(action.to!),
        ),
```

- [ ] **Step 4: Run the whole suite**

Run: `flutter test`
Expected: PASS. Anything still calling `rotated()` is a compile error and there
should be none outside these three files: `grep -rn "rotated()" lib/ test/`
must come back empty.

- [ ] **Step 5: Probe**

Change `turned()` back to `copyWith(rotation: (rotation + 90) % 360)` and run
`flutter test test/table/card_instance_test.dart test/table/apply_test.dart`.
Two cases must fail. Edit it back by hand, never with `git checkout`, and rerun.

- [ ] **Step 6: Commit**

```bash
git add lib/table/model/card_instance.dart lib/table/actions/table_action.dart \
        lib/table/actions/apply.dart test/table/card_instance_test.dart \
        test/table/apply_test.dart
git commit -m "A tap turns a card and turns it back"
```

---

## Task 2: A drag is a move to the same place

Dragging does not need a verb. `MoveCard` carries a position, `_move` lifts the
card out before putting it back so the same zone works, and `at` keeps it at the
index it already had so nothing reshuffles under the player's finger.

**Files:**
- Test: `test/table/drag_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/table/drag_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
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
              id: 'battlefield-s1',
              seatId: 's1',
              label: 'Battlefield',
              visibility: ZoneVisibility.public,
              ordered: false,
              cards: const [
                CardInstance(id: 'a', oracleId: 'o'),
                CardInstance(id: 'b', oracleId: 'o'),
                CardInstance(id: 'c', oracleId: 'o'),
              ],
            ),
          ],
        ),
      ],
    );

void main() {
  test('a drag puts a card where it was dropped', () {
    final next = apply(
      _table(),
      const MoveCard(
        cardId: 'b',
        toZoneId: 'battlefield-s1',
        at: 1,
        position: (x: 0.25, y: 0.75),
      ),
    );

    expect(next.locate('b')!.card.position, (x: 0.25, y: 0.75));
  });

  test('a drag does not reorder the pile', () {
    final next = apply(
      _table(),
      const MoveCard(
        cardId: 'c',
        toZoneId: 'battlefield-s1',
        at: 2,
        position: (x: 0.5, y: 0.5),
      ),
    );

    // Zone.add inserts at the front by default, so a drag that forgot `at`
    // would send the card to index 0 and make every other card jump. The
    // D-pad cursor walks this list by index, so it would jump too.
    expect(next.zone('battlefield-s1')!.cards.map((c) => c.id),
        ['a', 'b', 'c']);
  });

  test('a drag leaves the other cards alone', () {
    final next = apply(
      _table(),
      const MoveCard(
        cardId: 'a',
        toZoneId: 'battlefield-s1',
        at: 0,
        position: (x: 0.1, y: 0.1),
      ),
    );

    expect(next.locate('b')!.card.position, isNull);
    expect(next.locate('c')!.card.position, isNull);
  });

  test('a move to another pile still clears the position', () {
    final table = _table().copyWith(
      seats: [
        _table().seats.single.copyWith(zones: [
          ..._table().seats.single.zones,
          const Zone(
            id: 'graveyard-s1',
            seatId: 's1',
            label: 'Graveyard',
            visibility: ZoneVisibility.public,
            ordered: true,
          ),
        ]),
      ],
    );

    final placed = apply(
      table,
      const MoveCard(
        cardId: 'a',
        toZoneId: 'battlefield-s1',
        at: 0,
        position: (x: 0.1, y: 0.1),
      ),
    );
    final binned = apply(
      placed,
      const MoveCard(cardId: 'a', toZoneId: 'graveyard-s1'),
    );

    // Where a card sat on the battlefield means nothing in a graveyard, and
    // carrying it would put the card back in the same spot if it ever came
    // out again.
    expect(binned.locate('a')!.card.position, isNull);
  });
}
```

- [ ] **Step 2: Run it**

Run: `flutter test test/table/drag_test.dart`
Expected: PASS, 4 tests, with no production change at all. **This is the point
of the task.** If any case fails, `apply` does not already support dragging and
the rest of this plan is built on a wrong premise: stop and report which case
failed rather than changing `apply` to suit the test.

- [ ] **Step 3: Probe that the test can fail**

In `apply.dart`, drop the position through: change

```dart
  card = action.position == null
      ? card.copyWith(clearPosition: true)
      : card.copyWith(position: action.position);
```

to `card = card.copyWith(clearPosition: true);` and run the file. The first
case must fail. Edit it back by hand and rerun.

- [ ] **Step 4: Commit**

```bash
git add test/table/drag_test.dart
git commit -m "Pin that a drag is a move to the same place"
```

---

## Task 3: The viewer is where a card is worked on

The player asked for the 3D card on a press and hold, which is what a press and
hold already did. So the other things a card can be asked to do move into the
viewer rather than displacing it: hold the card, the big card comes up, and the
controls are on it. One gesture, everything reachable, and the thing the player
liked stays exactly where their thumb already expects it.

**Files:**
- Modify: `lib/ui/organisms/card_viewer.dart`
- Test: `test/ui/card_viewer_actions_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/ui/card_viewer_actions_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';
import 'package:kitchentable/table/model/card_instance.dart';
import 'package:kitchentable/ui/organisms/card_viewer.dart';

const _printing = CatalogCard(
  oracleId: 'o',
  name: 'Goblin Chieftain',
  typeLine: 'Creature',
  cmc: 3,
);

Widget _host({
  CardInstance? instance,
  void Function(CardAction)? onAct,
}) =>
    MaterialApp(
      home: Scaffold(
        body: CardViewer(
          card: _printing,
          instance: instance,
          onAct: onAct,
        ),
      ),
    );

void main() {
  testWidgets('with no card behind it, it is just a viewer', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    // The deck builder opens this on a printing that is not on any table.
    // There is nothing to turn over, so nothing offers to.
    expect(find.byKey(const Key('act-flip')), findsNothing);
    expect(find.byKey(const Key('act-upside-down')), findsNothing);
  });

  testWidgets('a card on the table gets its controls', (tester) async {
    await tester.pumpWidget(
      _host(instance: const CardInstance(id: 'a', oracleId: 'o')),
    );
    await tester.pump();

    expect(find.byKey(const Key('act-upside-down')), findsOneWidget);
    expect(find.byKey(const Key('act-flip')), findsOneWidget);
    expect(find.byKey(const Key('act-counter-up')), findsOneWidget);
    expect(find.byKey(const Key('act-counter-down')), findsOneWidget);
  });

  testWidgets('turning it upside down is reported', (tester) async {
    CardAction? acted;
    await tester.pumpWidget(_host(
      instance: const CardInstance(id: 'a', oracleId: 'o'),
      onAct: (a) => acted = a,
    ));
    await tester.pump();

    await tester.tap(find.byKey(const Key('act-upside-down')));
    await tester.pump();

    expect(acted, CardAction.upsideDown);
  });

  testWidgets('a card already upside down offers to be straightened',
      (tester) async {
    await tester.pumpWidget(_host(
      instance: const CardInstance(id: 'a', oracleId: 'o', rotation: 180),
    ));
    await tester.pump();

    expect(find.byKey(const Key('act-straighten')), findsOneWidget);
    expect(find.byKey(const Key('act-upside-down')), findsNothing);
  });

  testWidgets('counters read back off the card', (tester) async {
    await tester.pumpWidget(_host(
      instance: const CardInstance(
        id: 'a',
        oracleId: 'o',
        counters: {'+1/+1': 3},
      ),
    ));
    await tester.pump();

    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('both counter directions report', (tester) async {
    final acted = <CardAction>[];
    await tester.pumpWidget(_host(
      instance: const CardInstance(id: 'a', oracleId: 'o'),
      onAct: acted.add,
    ));
    await tester.pump();

    await tester.tap(find.byKey(const Key('act-counter-up')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('act-counter-down')));
    await tester.pump();

    expect(acted, [CardAction.counterUp, CardAction.counterDown]);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/ui/card_viewer_actions_test.dart`
Expected: FAIL to compile, `Undefined name 'CardAction'` and
`No named parameter with the name 'instance'`.

- [ ] **Step 3: Give the viewer the controls**

In `lib/ui/organisms/card_viewer.dart`, above the `CardViewer` class:

```dart
/// What the viewer can ask for, beyond looking.
///
/// Turning a card ninety degrees is not here: that is the tap, on the table,
/// where the player can see the board around it. These are the deliberate
/// ones, which is why they are behind a press and hold.
enum CardAction { upsideDown, straighten, flip, counterUp, counterDown }
```

Change the widget's fields and `show`:

```dart
  const CardViewer({
    super.key,
    required this.card,
    this.instance,
    this.onAct,
  });

  final CatalogCard card;

  /// The card on a table, when there is one. Null from the deck builder,
  /// where a printing is being looked at rather than a card being played, and
  /// then the viewer offers nothing to do because there is nothing to do it
  /// to.
  final CardInstance? instance;

  final void Function(CardAction)? onAct;

  static Future<CardAction?> show(
    BuildContext context,
    CatalogCard card, {
    CardInstance? instance,
  }) =>
      Navigator.of(context).push(
        // Not `PageRouteBuilder<CardAction?>`. `push<T>` already hands back
        // a `Future<T?>`, so declaring the return as `Future<CardAction?>`
        // infers `T = CardAction` and the parameter is `Route<CardAction>`.
        // Doubling the nullability does not compile.
        PageRouteBuilder<CardAction>(
          opaque: false,
          barrierColor: Colors.black.withValues(alpha: 0.78),
          pageBuilder: (context, _, _) => CardViewer(
            card: card,
            instance: instance,
            onAct: (action) => Navigator.of(context).pop(action),
          ),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
```

Add `import '../../table/model/card_instance.dart';` to the file.

In `_CardViewerState.build`, add the bar as a sibling of the card.

**There is no `Stack` in that build method to put it in.** The structure is
`Scaffold > GestureDetector(onTap: maybePop) > Center > Column[...]`, and the
only `Stack` in the file is inside `_Card`, which is the wrong one twice over:
its second child is the `Matrix4` transform, and it is sized to the card. So
introduce one. Wrap the existing `Center` unchanged and make `_actions(m)` the
second child, inside the dismiss `GestureDetector` so tapping the background
still closes the overlay:

```dart
        // The bar is a sibling of the card, never a child of it. Everything
        // under _Card lives inside a Matrix4 that is being turned in three
        // dimensions, and a control mounted in there turns with it.
        child: Stack(
          children: [
            Center(
              child: Column(
                // the existing column, reindented and otherwise untouched
              ),
            ),
            _actions(m),
          ],
        ),
```

The reindent is most of the diff. Two `.clamp` expressions stop fitting in 80
columns at the new depth and need rewrapping; no logic in them changes. Do not
run `dart format` on the file: this repo is not format clean, 99 of 131 files
under `lib` and `test` would change, and the file keeps its hand maintained
wrapping.

The bar's buttons sit inside the `GestureDetector` whose `onTap` is
`maybePop`. The inner detector wins the gesture arena, so the buttons work and
the background still dismisses. Cases 3 and 6 measure that rather than assume
it: if the barrier won, `onAct` would never fire and both would fail.

```dart
  Widget _actions(Metrics m) {
    final instance = widget.instance;
    if (instance == null) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.all(m.safeInset),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (instance.rotation == 180)
              _act(m, const Key('act-straighten'), Icons.straighten_rounded,
                  'Straighten', CardAction.straighten)
            else
              _act(m, const Key('act-upside-down'),
                  Icons.flip_camera_android_rounded, 'Upside down',
                  CardAction.upsideDown),
            SizedBox(width: m.scaled(10)),
            _act(
              m,
              const Key('act-flip'),
              Icons.layers_rounded,
              instance.faceDown ? 'Face up' : 'Face down',
              CardAction.flip,
            ),
            SizedBox(width: m.scaled(18)),
            _act(m, const Key('act-counter-down'), Icons.remove_rounded, null,
                CardAction.counterDown),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: m.scaled(10)),
              child: Text(
                '${instance.counters.values.fold(0, (a, b) => a + b)}',
                style: TextStyle(
                  fontSize: m.scaled(18),
                  fontWeight: FontWeight.w700,
                  color: Palette.ink,
                ),
              ),
            ),
            _act(m, const Key('act-counter-up'), Icons.add_rounded, null,
                CardAction.counterUp),
          ],
        ),
      ),
    );
  }

  Widget _act(
    Metrics m,
    Key key,
    IconData icon,
    String? label,
    CardAction action,
  ) =>
      GestureDetector(
        key: key,
        onTap: () => widget.onAct?.call(action),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: m.scaled(label == null ? 10 : 14),
            vertical: m.scaled(10),
          ),
          decoration: BoxDecoration(
            color: Palette.tile,
            borderRadius: BorderRadius.circular(m.scaled(10)),
            border: Border.all(color: Palette.tileEdge),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: m.scaled(17), color: Palette.inkMuted),
              if (label != null) ...[
                SizedBox(width: m.scaled(8)),
                Text(
                  label,
                  style:
                      TextStyle(fontSize: m.scaled(12), color: Palette.ink),
                ),
              ],
            ],
          ),
        ),
      );
```

`Metrics` and `Palette` are already imported by this file. If the build method
has no `Metrics` in scope, derive it there the way the rest of the app does,
from `MediaQuery` and `classifyDevice`.

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/ui/card_viewer_actions_test.dart`
Expected: PASS, 6 tests.

Then run the whole suite: existing callers of `CardViewer.show` pass no
`instance`, so they keep getting a plain viewer, and the return type changing
from `Future<void>` to `Future<CardAction?>` is source compatible for a caller
that ignores it. If any caller breaks, say which.

- [ ] **Step 5: Probe**

Do not delete the `if (instance == null) return const SizedBox.shrink();`
guard. That guard is what promotes `instance` from `CardInstance?`, so
removing it fails to compile, which kills the file at load and takes all six
cases down together. A red run where every case dies is not a probe: it cannot
tell case 1 apart from the other five.

Substitute a stand in instead, which keeps the behavioural change and still
compiles:

```dart
    final instance =
        widget.instance ?? const CardInstance(id: '', oracleId: '');
```

Exactly one case must fail, the first, on `act-flip` being found where the
deck builder expects nothing. Edit it back by hand, never with `git checkout`,
and rerun.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/organisms/card_viewer.dart test/ui/card_viewer_actions_test.dart
git commit -m "Work a card from the big view, since that is where holding takes you"
```

---

## Task 4: Your own board is a mat, not a grid

`CursorBoard` lays its cards out with a `Wrap`, so a position it was given has
nowhere to be honoured. Both renderers have to place a card the same way or the
same table looks different depending on the window, which is the thing
normalized positions exist to prevent.

**Files:**
- Modify: `lib/features/play/widgets/cursor_board.dart`
- Modify: `test/features/cursor_board_test.dart`

- [ ] **Step 1: Write the failing tests**

Append to `test/features/cursor_board_test.dart`, inside `main()`:

```dart
  testWidgets('a card with a position sits where it says', (tester) async {
    await tester.pumpWidget(_host(placed: {
      'b1': (x: 0.8, y: 0.2),
    }));
    await tester.pump();

    final placed = tester.getRect(find.byType(TableCard).at(1));
    final flowed = tester.getRect(find.byType(TableCard).at(0));

    expect(placed.left, greaterThan(flowed.left));
  });

  testWidgets('dragging a card reports where it was dropped', (tester) async {
    ({String id, double x, double y})? dropped;
    await tester.pumpWidget(_host(onPlace: (id, x, y) {
      dropped = (id: id, x: x, y: y);
    }));
    await tester.pump();

    await tester.drag(find.byType(TableCard).first, const Offset(120, 90));
    await tester.pump();

    expect(dropped?.id, 'b0');
    expect(dropped!.x, greaterThan(0));
    expect(dropped!.y, greaterThan(0));
  });

  testWidgets('a drop is reported normalized, never in pixels',
      (tester) async {
    ({String id, double x, double y})? dropped;
    await tester.pumpWidget(_host(onPlace: (id, x, y) {
      dropped = (id: id, x: x, y: y);
    }));
    await tester.pump();

    await tester.drag(find.byType(TableCard).first, const Offset(60, 40));
    await tester.pump();

    // 0 to 1 against this seat's mat, which is what lets a phone and a
    // television show the same arrangement.
    //
    // Strictly inside, not merely within. Production clamps its own output to
    // 0 and 1, so asserting the range asserts the clamp's postcondition and
    // cannot fail whatever the arithmetic does.
    expect(dropped!.x, lessThan(1));
    expect(dropped!.y, lessThan(1));
    expect(dropped!.x, greaterThan(0));
  });

  testWidgets('a longer drag lands further along than a shorter one',
      (tester) async {
    Future<double> dropAfter(double dx) async {
      double? x;
      await tester.pumpWidget(_host(onPlace: (_, at, _) => x = at));
      await tester.pump();
      await tester.drag(find.byType(TableCard).first, Offset(dx, 0));
      await tester.pump();
      return x!;
    }

    final short = await dropAfter(40);
    final long = await dropAfter(120);

    // Two drags of different lengths have to land in different places. In
    // pixels both are past the mat's width and both clamp to 1.0, so this is
    // the assertion the range check could not make.
    expect(long, greaterThan(short));
  });

  testWidgets('a card lands where the finger let go, not short of it',
      (tester) async {
    double? x;
    await tester.pumpWidget(_host(onPlace: (_, at, _) => x = at));
    await tester.pump();

    final from = tester.getCenter(find.byType(TableCard).first);
    final gesture = await tester.startGesture(from);
    await gesture.moveBy(const Offset(200, 0));
    await tester.pump();
    final under = tester.getCenter(find.byType(TableCard).first);
    await gesture.up();
    await tester.pump();

    expect((under.dx - (from.dx + 200)).abs(), lessThan(1),
        reason: 'the card must sit under the finger, not behind it');
    expect(x, isNotNull);
  });

  testWidgets('a drag does not also activate the card', (tester) async {
    CardInstance? acted;
    await tester.pumpWidget(_host(
      onActivate: (c) => acted = c,
      onPlace: (_, __, ___) {},
    ));
    await tester.pump();

    await tester.drag(find.byType(TableCard).first, const Offset(100, 60));
    await tester.pump();

    expect(acted, isNull, reason: 'dragging a card must not turn it');
  });
```

Extend the file's `_host` to take the two new arguments, keeping every existing
call working:

```dart
Widget _host({
  int board = 3,
  int graveyard = 0,
  void Function(CardInstance)? onActivate,
  void Function(CardInstance)? onInspect,
  Map<String, ({double x, double y})> placed = const {},
  void Function(String id, double x, double y)? onPlace,
}) =>
```

and inside it build the battlefield cards through `placed`:

```dart
            (
              id: 'battlefield-s1',
              label: 'Battlefield',
              cards: [
                for (var i = 0; i < board; i++)
                  CardInstance(
                    id: 'b$i',
                    oracleId: 'card$i',
                    position: placed['b$i'],
                  ),
              ],
            ),
```

passing `onPlace: onPlace ?? (_, __, ___) {}` to `CursorBoard`. Add
`import 'package:kitchentable/features/play/widgets/table_card.dart';` if it is
not already there from the touch cases.

- [ ] **Step 2: Run them and watch them fail**

Run: `flutter test test/features/cursor_board_test.dart`
Expected: FAIL to compile, `No named parameter with the name 'onPlace'`.

- [ ] **Step 3: Rebuild the layout**

In `lib/features/play/widgets/cursor_board.dart`, add to the imports:

```dart
import '../renderers/mat_layout.dart';
```

Add the parameter to the widget, beside `onInspect`:

```dart
  /// Where a card was dropped, normalized 0 to 1 against this mat.
  final void Function(String cardId, double x, double y) onPlace;
```

and to the constructor: `required this.onPlace,`.

Replace `_pile` and `_card` with a positioned mat. The cards keep their zone
order, which is what the D-pad cursor walks, and a card with no position falls
into the same flow slot `FreeCanvas` would give it:

```dart
  Widget _pile(BoardZone zone, BoardCursor cursor) {
    final m = widget.metrics;

    return Padding(
      padding: EdgeInsets.only(bottom: m.scaled(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            zone.label,
            style: TextStyle(fontSize: m.scaled(11), color: Palette.inkFaint),
          ),
          SizedBox(height: m.scaled(6)),
          LayoutBuilder(
            builder: (context, constraints) {
              // The mat keeps its shape whatever the window does, so a drag
              // on a phone and the same drag on a television land on the same
              // normalized spot.
              final scale = constraints.maxWidth / matSize.width;
              return SizedBox(
                width: constraints.maxWidth,
                height: matSize.height * scale,
                child: Stack(
                  children: [
                    for (var i = 0; i < zone.cards.length; i++)
                      _card(zone, i, cursor, scale),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _card(BoardZone zone, int index, BoardCursor cursor, double scale) {
    final m = widget.metrics;
    final card = zone.cards[index];
    final ringed = zone.id == cursor.zoneId && index == cursor.index;
    final spot = spotFor(
      position: card.position,
      index: index,
      card: _cardOnMat,
    );

    return Positioned(
      left: spot.dx * scale,
      top: spot.dy * scale,
      child: GestureDetector(
        onPanEnd: (details) => _drop(zone, card, spot, scale),
        onPanUpdate: (details) => _drag(card.id, details.delta / scale),
        child: Container(
          key: ringed ? Key('ring-${card.id}') : null,
          padding: EdgeInsets.all(m.focusRing),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(m.scaled(8)),
            border: Border.all(
              color: ringed ? Palette.accent : Colors.transparent,
              width: m.focusRing,
            ),
          ),
          child: TableCard(
            metrics: m,
            instance: card,
            printing: widget.printings[card.oracleId],
            width: _cardOnMat.width * scale,
            onTap: () => widget.onActivate(card),
            onLongPress: () => widget.onInspect(card),
          ),
        ),
      ),
    );
  }
```

Add the drag bookkeeping and the card size to the state class:

```dart
  /// Where a card has been dragged to but not yet dropped, in mat units.
  final _dragging = <String, Offset>{};

  void _drag(String cardId, Offset delta) {
    setState(() {
      _dragging[cardId] = (_dragging[cardId] ?? Offset.zero) + delta;
    });
  }

  void _drop(BoardZone zone, CardInstance card, Offset from, double scale) {
    final moved = _dragging.remove(card.id);
    if (moved == null) return;

    // The centre of where the card ended up, normalized against the mat. The
    // centre and not the corner, because spotFor centres a positioned card
    // and the two have to be inverses or a card walks on every drag.
    final at = from + moved + Offset(_cardOnMat.width / 2, _cardOnMat.height / 2);
    setState(() {});
    widget.onPlace(
      card.id,
      clampDouble(at.dx / matSize.width, 0, 1),
      clampDouble(at.dy / matSize.height, 0, 1),
    );
  }
```

and, above the class:

```dart
/// The same card size the canvas uses, so both renderers place alike.
const _cardOnMat = Size(90, 90 * 88 / 63);
```

`clampDouble` comes from `dart:ui`; add `import 'dart:ui' show clampDouble;`
if analyze says it is missing. While a card is being dragged its `spot` must
include the pending offset, so change the `Positioned` to:

```dart
    final pending = _dragging[card.id] ?? Offset.zero;

    return Positioned(
      left: (spot.dx + pending.dx) * scale,
      top: (spot.dy + pending.dy) * scale,
```

- [ ] **Step 4: Run the file**

Run: `flutter test test/features/cursor_board_test.dart`
Expected: PASS, 13 tests. The file had seven cases before this task, not five:
the four key event ones, two touch ones, and the empty board.

The key-event cases and the touch cases must all still pass. If the tap case
now fails because the pan gesture swallows it, that is real: a `GestureDetector`
with both `onTap` and `onPanUpdate` resolves in the arena and a tap should still
win. If it does not, move `onTap` to the outer detector rather than loosening
the assertion.

- [ ] **Step 5: Probe**

Change the normalization to return pixels, `at.dx` instead of
`at.dx / matSize.width`, **keeping the clamp**. The normalized case and the
longer drag case must both fail.

The first draft of this task asserted `inInclusiveRange(0, 1)` there and this
exact mutation survived it: the real value is 93 mat units, the clamp
saturates it to 1.0, and 1.0 is in range. The case named "never in pixels"
was the one case in the file that could not detect pixels. If either of those
two cases passes under this mutation, the assertions have drifted back to
asserting the clamp's own postcondition.

- [ ] **Step 5a: The slop**

The drag recogniser swallows `kTouchSlop`, about eighteen logical pixels,
before `onPanStart` fires, and that travel is never reported. A card driven by
`details.delta` alone therefore trails the finger by that much for the whole
drag and is released short of where it was let go. Measured: a drop the
geometry puts at 109 mat units arrives at 93.

Wrap the card's `GestureDetector` in a `Listener` that records the raw touch
down, and hand the swallowed travel back when the drag starts:

```dart
      child: Listener(
        onPointerDown: (event) => _grabbedAt = event.position,
        child: GestureDetector(
          onPanStart: (details) => _catchUp(card.id, details, scale),
          onPanEnd: (details) => _drop(zone, card, spot, scale),
          onPanUpdate: (details) => _drag(card.id, details.delta / scale),
```

```dart
  /// Where the finger went down, before the drag was recognised.
  Offset? _grabbedAt;

  /// Gives the card back the travel the recogniser swallowed, so it sits
  /// under the finger from the first frame instead of trailing it.
  void _catchUp(String cardId, DragStartDetails details, double scale) {
    final grabbed = _grabbedAt;
    if (grabbed == null) return;
    _drag(cardId, (details.globalPosition - grabbed) / scale);
  }
```

Probe it by passing `Offset.zero` instead. The case named "a card lands where
the finger let go" must fail, and only it. Edit it back by hand and rerun.

- [ ] **Step 6: Commit**

```bash
git add lib/features/play/widgets/cursor_board.dart test/features/cursor_board_test.dart
git commit -m "Let a card be put where you want it on your own mat"
```

---

## Task 5: The screen honours a drop, and a hold works the card

**Files:**
- Modify: `lib/features/play/play_screen.dart`
- Modify: `test/features/play_screen_test.dart`

- [ ] **Step 1: Write the failing test**

Append to `test/features/play_screen_test.dart`, inside `main()`:

```dart
  testWidgets('a drop is written onto the card', (tester) async {
    final container = await _seatedPod(tester, ['you']);
    final play = container.read(playProvider.notifier);
    final table = container.read(playProvider)!;
    final card = table.zone('hand-s1')!.cards.first;

    play.run(MoveCard(cardId: card.id, toZoneId: 'battlefield-s1'));
    await tester.pump();

    play.run(MoveCard(
      cardId: card.id,
      toZoneId: 'battlefield-s1',
      at: 0,
      position: (x: 0.3, y: 0.6),
    ));
    await tester.pump();

    // CardInstance.position has existed since plan 2 with nothing writing to
    // it. This is the first thing in the app that does.
    expect(
      container.read(playProvider)!.locate(card.id)!.card.position,
      (x: 0.3, y: 0.6),
    );
  });
```

- [ ] **Step 2: Run it**

Run: `flutter test test/features/play_screen_test.dart`
Expected: PASS. It exercises the controller rather than the widget, and is here
so the screen's wiring has something to be checked against in Step 4.

- [ ] **Step 3: Wire the screen**

Pass `onPlace` to `CursorBoard`, beside `onInspect`:

```dart
            onPlace: (cardId, x, y) {
              final found = ref.read(playProvider)?.locate(cardId);
              if (found == null) return;
              play.run(MoveCard(
                cardId: cardId,
                toZoneId: found.zone.id,
                at: found.zone.cards.indexWhere((c) => c.id == cardId),
                position: (x: x, y: y),
              ));
            },
```

`_inspect` stays bound to the long press everywhere, which is what the player
asked for: holding a card brings up the big one. What changes is that it now
hands the viewer the card on the table, and acts on what comes back.

```dart
  /// The long press: the big card, and the controls on it.
  Future<void> _inspect(CardInstance instance) async {
    final printing = _printings[instance.oracleId];
    if (printing == null) return;

    final action = await CardViewer.show(context, printing,
        instance: instance);
    if (action == null || !mounted) return;

    final play = ref.read(playProvider.notifier);
    switch (action) {
      case CardAction.upsideDown:
        play.run(RotateCard(instance.id, to: 180));
      case CardAction.straighten:
        play.run(RotateCard(instance.id, to: 0));
      case CardAction.flip:
        play.run(FlipCard(instance.id));
      case CardAction.counterUp:
        play.run(ChangeCounter(cardId: instance.id, kind: '+1/+1', by: 1));
      case CardAction.counterDown:
        play.run(ChangeCounter(cardId: instance.id, kind: '+1/+1', by: -1));
    }
  }
```

The old `_inspect` was synchronous and returned early when the catalog had
never heard of the card. Keep that early return: a token has no printing and
must not open an empty viewer.

- [ ] **Step 4: Run everything**

Run: `flutter test && flutter analyze`
Expected: PASS and `No issues found!`.

- [ ] **Step 5: Commit**

```bash
git add lib/features/play/play_screen.dart test/features/play_screen_test.dart
git commit -m "Act on a card from the big view, and remember where it was dropped"
```

---

## Task 6: Open a table with more than one seat

The last one, and the reason the player could not tell the two renderers apart:
`play_decks_screen.dart` calls `start(deck)`, which seats one. Everything plan 3
built for several seats has been unreachable from the app since it landed.

**Files:**
- Modify: `lib/features/decks/play_decks_screen.dart`
- Test: `test/features/play_entry_test.dart`

- [ ] **Step 1: Read the screen first**

Run `sed -n '1,140p' lib/features/decks/play_decks_screen.dart`. The deal path
is around line 122 and the code below assumes the surrounding `_deal` still
looks the way it does there. If it does not, report what changed rather than
guessing.

- [ ] **Step 2: Write the failing test**

Append to `test/features/play_entry_test.dart`, inside `main()`:

```dart
  testWidgets('dealing several decks seats several people', (tester) async {
    final container = await _listed(tester);

    await tester.tap(find.byKey(const Key('add-seat')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('deck-row-0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('deck-row-0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('deal')));
    await tester.pumpAndSettle();

    final table = container.read(playProvider);
    expect(table!.seats, hasLength(2));
    expect(table.seats.every((s) => s.owner.actableHere), isTrue,
        reason: 'a pod on one device holds every chair itself');
  });
```

Read `test/features/play_entry_test.dart` before writing this: it has its own
harness and its own names for things. Adapt the helper call and the keys to
what is already there rather than inventing `_listed` if something else exists,
and say in your report what you adapted.

- [ ] **Step 3: Add the second seat**

The shape, which the implementer adapts to the live screen: a small toggle at
the top of the deck list that turns picking into collecting. Off, tapping a
deck deals immediately, which is what the player asked for in plan 1 and must
not change. On, tapping a deck adds it to a list and a `Deal` button opens the
pod through `startPod`, with `SeatOwner.here()` for every seat, because a pod
on one device holds all its own chairs.

```dart
  Future<void> _dealPod(List<Deck> decks) async {
    final full = <Player>[];
    for (var i = 0; i < decks.length; i++) {
      final deck = await _hydrate(decks[i]);
      if (deck == null) return;
      full.add((
        deck: deck,
        name: i == 0 ? 'you' : 'seat ${i + 1}',
        owner: const SeatOwner.here(),
      ));
    }

    ref.read(playProvider.notifier).startPod(players: full, seed: freshSeed());
    if (mounted) Navigator.of(context).pushNamed('/play');
  }
```

`_hydrate` is whatever the existing `_deal` already does to turn a stored deck
into one with catalog cards in it. Do not duplicate that logic: extract it from
`_deal` and have both call it. If `_deal` surfaces failure toasts, `_dealPod`
surfaces the same ones, because a pod that silently does nothing is the exact
bug this screen already shipped once.

- [ ] **Step 4: Run everything**

Run: `flutter test && flutter analyze`
Expected: PASS and `No issues found!`.

- [ ] **Step 5: Probe**

Change `startPod` to take only `full.first`. The new case must fail on the
seat count. Edit it back by hand and rerun.

- [ ] **Step 6: Commit**

```bash
git add lib/features/decks/play_decks_screen.dart test/features/play_entry_test.dart
git commit -m "Open a pod from the Play menu, not just a solitaire"
```

---

## What this plan deliberately leaves out

- **Dragging between piles.** A drop lands on the mat it started on. Dragging a
  card from the battlefield into the graveyard is a second gesture with a
  second set of questions and it is not what was asked for.
- **Dragging on the canvas.** Task 4 puts it on your own mat, which is where a
  player arranges their own cards. The canvas is where you look at everybody,
  and a drag there has to decide what happens when you drop on somebody else's
  mat.
- **Counters other than +1/+1.** The menu steps one kind. The model has always
  taken any name and the screen picks one, which is a screen decision to revisit
  when somebody plays a deck that needs another.
- **Where a token is born.** `CreateToken` still places by flow.
