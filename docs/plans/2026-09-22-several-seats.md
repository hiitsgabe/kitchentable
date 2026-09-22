# Several seats and the two views, implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Commander pod on one screen. Four seats, each with its own hand that
only its owner can see, drawn two ways: stacked bands on a phone and a pan and
pinch canvas on anything wider.

**Architecture:** A seat gains an owner, which is either this device or, later,
somebody on the other end of a connection. Nothing here knows what a connection
is. The two renderers read the same `TableState` and differ only in where they
put a seat.

**Tech Stack:** Flutter 3.47.5, Dart 3.13.4, flutter_riverpod 3.4.3.

---

## Where this sits

```
1  done       the table offline: state, eleven verbs, undo, one seat
2  this plan  several seats, the two views, and seeing only your own hand
3  next       the network: mesh, Nostr rendezvous, host migration
```

**Playing on one device is not the point of this plan.** The point is that
`StackedSeats` and `FreeCanvas` do not exist, they are needed whatever the
transport turns out to be, and building a four seat renderer at the same time
as WebRTC means debugging both at once. A second local seat is the cheapest way
to exercise them. That it also gives a pod around one tablet something to play
on is a bonus, not the justification.

## What the spec already settled

Read these rather than re-deciding them. They are in
`docs/specs/2026-09-21-kitchentable-design.md`.

**The hand never covers the board.** Arena opens the hand into a fan across the
battlefield, so you cannot look at both at once. Plan 1 pinned this by geometry
in `play_screen_test.dart` and both renderers here inherit the rule.

**StackedSeats is the phone default, FreeCanvas the wide one.** The app picks by
width, the player can switch, the choice is remembered per device. Neither is a
mode anybody has to understand before playing.

**Card positions are optional and normalized.** A card may carry an `x,y` from 0
to 1 against its own seat's mat, or nothing, in which case the layout places it.
Normalizing against the seat's mat rather than the screen is what lets both
renderers show the same arrangement. `CardInstance.position` exists and nothing
writes to it yet. This plan is where that changes.

**A hand is its owner's.** `ZoneVisibility` already has the three states and
`seenBy` already answers the question. Nothing has ever called it, which is the
fourth time in this project that a method has existed only on paper, after
`rename`, `makeCommander` and the refusal path. This plan is its first caller.

## File structure

```
lib/
  table/
    model/
      seat.dart           MODIFY: a seat gains an owner
      table_state.dart    MODIFY: whose turn, and who is looking
    view/
      seat_view.dart      NEW  what one seat looks like to one viewer
  games/
    magic_pack.dart       MODIFY: seats for a pod, not just one
  table/setup.dart        MODIFY: sitDown seats several decks
  features/play/
    play_controller.dart  MODIFY: which local seat is looking
    play_screen.dart      MODIFY: chooses a renderer
    renderers/
      stacked_seats.dart  NEW  bands, phone default
      free_canvas.dart    NEW  pan and pinch, wide default
      renderer_choice.dart NEW which one, and remembering it
    widgets/
      seat_band.dart      NEW  one opponent, compressed
      radar_strip.dart    NEW  every life total, always visible
```

---

## Task 1: A seat has an owner

**Files:**
- Create: `lib/table/model/seat_owner.dart`
- Modify: `lib/table/model/seat.dart`
- Test: `test/table/seat_owner_test.dart`

Built now, with only one of its two cases reachable, because plan 3 adds the
other and a seat that cannot say who holds it would have to be rewritten rather
than extended.

- [ ] **Step 1: Write the failing test**

Create `test/table/seat_owner_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/table/model/seat.dart';
import 'package:kitchentable/table/model/seat_owner.dart';

void main() {
  test('a seat on this device is held by this device', () {
    const seat = Seat(
      id: 's1',
      name: 'you',
      life: 40,
      zones: [],
      owner: SeatOwner.here(),
    );

    expect(seat.owner.isHere, isTrue);
    expect(seat.owner.peerId, isNull);
  });

  test('a seat held by somebody else names them', () {
    const seat = Seat(
      id: 's2',
      name: 'Carla',
      life: 40,
      zones: [],
      owner: SeatOwner.peer('abc123'),
    );

    expect(seat.owner.isHere, isFalse);
    expect(seat.owner.peerId, 'abc123');
  });

  test('an empty chair is held by nobody', () {
    const seat = Seat(id: 's3', name: 'empty', life: 40, zones: []);

    expect(seat.owner.isHere, isFalse);
    expect(seat.owner.isEmpty, isTrue);
  });

  test('only a seat on this device may be acted for', () {
    const here = SeatOwner.here();
    const there = SeatOwner.peer('abc');
    const nobody = SeatOwner.empty();

    // The screen reads this before offering a control. A seat somebody else
    // holds is watched, not played, and plan 3 is where the difference starts
    // to matter.
    expect(here.actableHere, isTrue);
    expect(there.actableHere, isFalse);
    expect(nobody.actableHere, isFalse);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/table/seat_owner_test.dart`
Expected: FAIL, `Target of URI doesn't exist`.

- [ ] **Step 3: Write the owner**

Create `lib/table/model/seat_owner.dart`:

```dart
import 'package:flutter/foundation.dart';

/// Who is holding a seat.
///
/// One of the three cases is unreachable until plan 3 puts somebody on the
/// other end of a connection. It is here anyway, because a seat that cannot
/// say who holds it would have to be rewritten rather than extended, and the
/// screen has to ask the question from the day it draws a second seat.
@immutable
class SeatOwner {
  const SeatOwner._(this._peerId, this._here);

  /// Somebody at this device. Several seats can be held here at once, which is
  /// a pod around one tablet.
  const SeatOwner.here() : this._(null, true);

  /// Somebody on the other end of a connection.
  const SeatOwner.peer(String peerId) : this._(peerId, false);

  /// A chair nobody has sat in.
  const SeatOwner.empty() : this._(null, false);

  final String? _peerId;
  final bool _here;

  bool get isHere => _here;
  bool get isEmpty => !_here && _peerId == null;
  String? get peerId => _peerId;

  /// Whether this device may act for this seat. The screen reads it before
  /// offering a control: a seat somebody else holds is watched, not played.
  bool get actableHere => _here;

  @override
  bool operator ==(Object other) =>
      other is SeatOwner && other._peerId == _peerId && other._here == _here;

  @override
  int get hashCode => Object.hash(_peerId, _here);
}
```

- [ ] **Step 4: Give the seat an owner**

In `lib/table/model/seat.dart`, add the import:

```dart
import 'seat_owner.dart';
```

add the parameter with a default, so every existing caller keeps compiling:

```dart
    required this.zones,
    this.owner = const SeatOwner.empty(),
  });
```

the field:

```dart
  /// Who is holding this chair. Empty until somebody sits.
  final SeatOwner owner;
```

and carry it through `copyWith`:

```dart
  Seat copyWith({String? name, int? life, List<Zone>? zones, SeatOwner? owner}) =>
      Seat(
        id: id,
        name: name ?? this.name,
        life: life ?? this.life,
        zones: zones ?? this.zones,
        owner: owner ?? this.owner,
      );
```

- [ ] **Step 5: Run it and watch it pass**

Run: `flutter test test/table/seat_owner_test.dart`
Expected: PASS, 4 tests.

Run: `flutter test`
Expected: PASS, everything, because the default keeps old callers working.

- [ ] **Step 6: Prove the tests bite**

Make `actableHere` return `true` always and confirm
`only a seat on this device may be acted for` FAILS. Restore **by editing the
code back**, never with `git checkout`: that has destroyed uncommitted work in
this project four times.

- [ ] **Step 7: Commit**

```bash
git add lib/table/model test/table/seat_owner_test.dart
git commit -m "A chair knows who is sitting in it"
```

---

## Task 2: What one seat looks like to one viewer

**Files:**
- Create: `lib/table/view/seat_view.dart`
- Test: `test/table/seat_view_test.dart`

`ZoneVisibility.seenBy` has existed since plan 1 and nothing has ever called
it. This is its first caller, and the fourth time in this project a method has
existed only on paper.

- [ ] **Step 1: Write the failing test**

Create `test/table/seat_view_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/table/model/card_instance.dart';
import 'package:kitchentable/table/model/seat.dart';
import 'package:kitchentable/table/model/zone.dart';
import 'package:kitchentable/table/view/seat_view.dart';

Zone _zone(String id, String seatId, ZoneVisibility v, int n) => Zone(
      id: '$id-$seatId',
      seatId: seatId,
      label: id,
      visibility: v,
      ordered: true,
      cards: [
        for (var i = 0; i < n; i++)
          CardInstance(id: '$seatId-$id-$i', oracleId: 'card$i'),
      ],
    );

Seat _seat(String id) => Seat(
      id: id,
      name: id,
      life: 40,
      zones: [
        _zone('library', id, ZoneVisibility.hidden, 53),
        _zone('hand', id, ZoneVisibility.owner, 7),
        _zone('battlefield', id, ZoneVisibility.public, 3),
      ],
    );

void main() {
  test('you see the cards in your own hand', () {
    final view = SeatView.of(_seat('s1'), viewer: 's1');
    final hand = view.zone('hand-s1')!;

    expect(hand.count, 7);
    expect(hand.cards, hasLength(7));
    expect(hand.readable, isTrue);
  });

  test('you see how many cards are in somebody else s hand, and no more', () {
    final view = SeatView.of(_seat('s2'), viewer: 's1');
    final hand = view.zone('hand-s2')!;

    // The count is public at a real table: everybody can see how many cards
    // somebody is holding. What is in them is not.
    expect(hand.count, 7);
    expect(hand.cards, isEmpty);
    expect(hand.readable, isFalse);
  });

  test('nobody reads a library, not even its owner', () {
    final mine = SeatView.of(_seat('s1'), viewer: 's1');
    final theirs = SeatView.of(_seat('s2'), viewer: 's1');

    expect(mine.zone('library-s1')!.readable, isFalse);
    expect(mine.zone('library-s1')!.count, 53);
    expect(theirs.zone('library-s2')!.readable, isFalse);
  });

  test('a battlefield is everybody s', () {
    final theirs = SeatView.of(_seat('s2'), viewer: 's1');
    final board = theirs.zone('battlefield-s2')!;

    expect(board.readable, isTrue);
    expect(board.cards, hasLength(3));
  });

  test('a view never carries a card it will not show', () {
    final theirs = SeatView.of(_seat('s2'), viewer: 's1');

    // The point of building a view rather than filtering in the widget: a card
    // that reached the screen could be read off the widget tree, and plan 3
    // sends these over a wire.
    final everything = theirs.zones.expand((z) => z.cards).map((c) => c.id);
    expect(everything.any((id) => id.contains('hand')), isFalse);
    expect(everything.any((id) => id.contains('library')), isFalse);
  });

  test('it is the same seat either way round', () {
    final view = SeatView.of(_seat('s1'), viewer: 's1');
    expect(view.seatId, 's1');
    expect(view.life, 40);
    expect(view.name, 's1');
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/table/seat_view_test.dart`
Expected: FAIL, `Target of URI doesn't exist`.

- [ ] **Step 3: Write the view**

Create `lib/table/view/seat_view.dart`:

```dart
import 'package:flutter/foundation.dart';

import '../model/card_instance.dart';
import '../model/seat.dart';
import '../model/zone.dart';

/// A pile as one viewer sees it.
@immutable
class ZoneView {
  const ZoneView({
    required this.id,
    required this.label,
    required this.count,
    required this.readable,
    required this.cards,
  });

  final String id;
  final String label;

  /// How many are in there. Public even when the contents are not, because at
  /// a real table everybody can see how many cards somebody is holding.
  final int count;

  /// Whether this viewer may read the contents.
  final bool readable;

  /// The cards, when readable. Empty otherwise, and empty means empty: a card
  /// this viewer may not see never reaches here at all.
  final List<CardInstance> cards;
}

/// A seat as one viewer sees it.
///
/// Built rather than filtered at the widget, for two reasons. A card that
/// reaches the screen can be read off the widget tree whether or not it was
/// drawn, and plan 3 sends exactly this over a wire, where a card nobody may
/// see must not travel.
@immutable
class SeatView {
  const SeatView({
    required this.seatId,
    required this.name,
    required this.life,
    required this.zones,
    required this.isViewer,
  });

  final String seatId;
  final String name;
  final int life;
  final List<ZoneView> zones;

  /// True when this is the seat doing the looking.
  final bool isViewer;

  ZoneView? zone(String zoneId) =>
      zones.where((z) => z.id == zoneId).firstOrNull;

  static SeatView of(Seat seat, {required String viewer}) => SeatView(
        seatId: seat.id,
        name: seat.name,
        life: seat.life,
        isViewer: seat.id == viewer,
        zones: [
          for (final zone in seat.zones) _viewOf(zone, viewer),
        ],
      );

  static ZoneView _viewOf(Zone zone, String viewer) {
    final readable = zone.visibility.seenBy(viewer, owner: zone.seatId);
    return ZoneView(
      id: zone.id,
      label: zone.label,
      count: zone.size,
      readable: readable,
      cards: readable ? zone.cards : const [],
    );
  }
}
```

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/table/seat_view_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 5: Prove the tests bite**

Make `_viewOf` always pass `zone.cards` regardless of `readable`, and confirm
both `you see how many cards are in somebody else s hand, and no more` and
`a view never carries a card it will not show` FAIL. Restore by editing back.

Then make `count` return `cards.length` instead of `zone.size` and confirm the
same first test fails on the count. That one matters: a hidden hand would then
report zero cards, and an opponent holding seven would look empty.

- [ ] **Step 6: Commit**

```bash
git add lib/table/view test/table/seat_view_test.dart
git commit -m "Show a seat the way one person sees it"
```

---

## Task 3: A table of several seats

**Files:**
- Modify: `lib/games/magic_pack.dart`
- Modify: `lib/table/setup.dart`
- Test: `test/table/pod_setup_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/table/pod_setup_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/decks/model/deck.dart';
import 'package:kitchentable/decks/model/deck_format.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';
import 'package:kitchentable/table/model/seat_owner.dart';
import 'package:kitchentable/table/setup.dart';

CatalogCard _card(String n) =>
    CatalogCard(oracleId: n, name: n, typeLine: 'Instant', cmc: 1);

Deck _deck(String name, {int cards = 60}) => Deck(
      id: name,
      name: name,
      format: DeckFormat.commander,
      slots: [DeckSlot(card: _card('$name-card'), quantity: cards)],
    );

void main() {
  test('a pod seats everybody who brought a deck', () {
    final table = sitDownTogether(
      players: [
        (deck: _deck('a'), name: 'you', owner: const SeatOwner.here()),
        (deck: _deck('b'), name: 'Carla', owner: const SeatOwner.here()),
        (deck: _deck('c'), name: 'Diego', owner: const SeatOwner.here()),
      ],
      seed: 'abc',
    );

    expect(table.seats, hasLength(3));
    expect(table.seats.map((s) => s.name), ['you', 'Carla', 'Diego']);
  });

  test('every seat gets its own zones, and they do not collide', () {
    final table = sitDownTogether(
      players: [
        (deck: _deck('a'), name: 'you', owner: const SeatOwner.here()),
        (deck: _deck('b'), name: 'Carla', owner: const SeatOwner.here()),
      ],
      seed: 'abc',
    );

    final ids = table.allZones.map((z) => z.id).toList();
    expect(ids.toSet().length, ids.length, reason: 'no two zones share an id');
    expect(table.zone('hand-s1')!.size, 7);
    expect(table.zone('hand-s2')!.size, 7);
  });

  test('two seats with the same deck get different shuffles', () {
    final table = sitDownTogether(
      players: [
        (deck: _deck('a', cards: 60), name: 'you', owner: const SeatOwner.here()),
        (deck: _deck('a', cards: 60), name: 'Carla', owner: const SeatOwner.here()),
      ],
      seed: 'abc',
    );

    final mine = table.zone('library-s1')!.cards.map((c) => c.id).toList();
    final theirs = table.zone('library-s2')!.cards.map((c) => c.id).toList();

    // Same seed for the table, a different one per seat underneath. Two people
    // with the same decklist drawing the same seven cards would be absurd.
    expect(mine, isNot(theirs));
  });

  test('the same table seed deals the same pod twice', () {
    List<String> handsFor(String seed) => sitDownTogether(
          players: [
            (deck: _deck('a'), name: 'you', owner: const SeatOwner.here()),
            (deck: _deck('b'), name: 'Carla', owner: const SeatOwner.here()),
          ],
          seed: seed,
        ).allZones.expand((z) => z.cards).map((c) => c.id).toList();

    expect(handsFor('abc'), handsFor('abc'));
    expect(handsFor('abc'), isNot(handsFor('xyz')));
  });

  test('the turn starts with the first seat', () {
    final table = sitDownTogether(
      players: [
        (deck: _deck('a'), name: 'you', owner: const SeatOwner.here()),
        (deck: _deck('b'), name: 'Carla', owner: const SeatOwner.here()),
      ],
      seed: 'abc',
    );

    expect(table.turnSeatId, 's1');
  });

  test('an owner is carried onto the seat', () {
    final table = sitDownTogether(
      players: [
        (deck: _deck('a'), name: 'you', owner: const SeatOwner.here()),
        (deck: _deck('b'), name: 'Carla', owner: const SeatOwner.peer('p9')),
      ],
      seed: 'abc',
    );

    expect(table.seats[0].owner.isHere, isTrue);
    expect(table.seats[1].owner.peerId, 'p9');
  });

  test('one player is a table of one, same function', () {
    final table = sitDownTogether(
      players: [(deck: _deck('a'), name: 'you', owner: const SeatOwner.here())],
      seed: 'abc',
    );

    expect(table.seats, hasLength(1));
    expect(table.zone('hand-s1')!.size, 7);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/table/pod_setup_test.dart`
Expected: FAIL, `Method not found: 'sitDownTogether'`.

- [ ] **Step 3: Write it**

In `lib/table/setup.dart`, add the import for `model/seat_owner.dart` and this
below the existing `sitDown`:

```dart
/// One player arriving at a table.
typedef Player = ({Deck deck, String name, SeatOwner owner});

/// Seats everybody and deals. A table of one goes through here too, because
/// solo is not a mode, it is the case where nobody else has joined.
TableState sitDownTogether({
  required List<Player> players,
  required String seed,
}) {
  final seats = <Seat>[];

  for (var i = 0; i < players.length; i++) {
    final player = players[i];
    final seatId = 's${i + 1}';

    // A seed per seat, derived from the table's. One seed for the whole table
    // would give two people with the same decklist the same seven cards.
    final single = sitDown(
      deck: player.deck,
      seatName: player.name,
      seed: '$seed/$seatId',
      seatId: seatId,
    );

    seats.add(single.seats.single.copyWith(owner: player.owner));
  }

  return TableState(seats: seats, turnSeatId: seats.first.id);
}
```

`sitDown` stays exactly as it is and this builds on it, so plan 1's seven tests
keep passing unchanged.

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/table/pod_setup_test.dart`
Expected: PASS, 7 tests.

Run: `flutter test`
Expected: PASS, everything.

- [ ] **Step 5: Prove the tests bite**

Change `'$seed/$seatId'` to plain `seed` and confirm
`two seats with the same deck get different shuffles` FAILS. Restore by editing
back.

Then drop `owner: player.owner` and confirm `an owner is carried onto the seat`
FAILS.

- [ ] **Step 6: Commit**

```bash
git add lib/table/setup.dart test/table/pod_setup_test.dart
git commit -m "Seat a whole pod, and give each a shuffle of its own"
```

---

## Task 4: Which renderer, and remembering it

**Files:**
- Create: `lib/features/play/renderers/renderer_choice.dart`
- Test: `test/features/renderer_choice_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/renderer_choice_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/renderers/renderer_choice.dart';

void main() {
  test('a phone gets bands', () {
    expect(rendererFor(width: 390, chosen: null), TableRenderer.stackedSeats);
  });

  test('a wide window gets the canvas', () {
    expect(rendererFor(width: 1280, chosen: null), TableRenderer.freeCanvas);
  });

  test('a tablet counts as wide', () {
    expect(rendererFor(width: 820, chosen: null), TableRenderer.freeCanvas);
  });

  test('the boundary belongs to the canvas', () {
    expect(rendererFor(width: 720, chosen: null), TableRenderer.freeCanvas);
    expect(rendererFor(width: 719, chosen: null), TableRenderer.stackedSeats);
  });

  test('a choice beats the width, in both directions', () {
    expect(
      rendererFor(width: 390, chosen: TableRenderer.freeCanvas),
      TableRenderer.freeCanvas,
    );
    expect(
      rendererFor(width: 1280, chosen: TableRenderer.stackedSeats),
      TableRenderer.stackedSeats,
    );
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/renderer_choice_test.dart`
Expected: FAIL, `Target of URI doesn't exist`.

- [ ] **Step 3: Write it**

Create `lib/features/play/renderers/renderer_choice.dart`:

```dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TableRenderer {
  /// Bands down the screen, one seat each, yours pinned at the bottom.
  stackedSeats,

  /// Every seat on a surface you pan and pinch.
  freeCanvas;

  String get label => switch (this) {
        TableRenderer.stackedSeats => 'Bands',
        TableRenderer.freeCanvas => 'Canvas',
      };

  String get describe => switch (this) {
        TableRenderer.stackedSeats =>
          'one seat per band, yours at the bottom',
        TableRenderer.freeCanvas => 'the whole table, pan and pinch',
      };
}

/// Wide enough for four seats side by side without a card becoming a smudge.
const _wideEnough = 720.0;

/// What to draw, given the room and whatever the player picked.
///
/// The choice wins in both directions. Somebody on a phone who wants the whole
/// table zoomed out is not wrong, and neither is somebody on a desktop who
/// prefers the bands.
TableRenderer rendererFor({required double width, TableRenderer? chosen}) {
  if (chosen != null) return chosen;
  return width >= _wideEnough
      ? TableRenderer.freeCanvas
      : TableRenderer.stackedSeats;
}

const _key = 'tableRenderer';

/// Null until the player picks one, which means the width decides.
class RendererChoice extends Notifier<TableRenderer?> {
  @override
  TableRenderer? build() {
    _restore();
    return null;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    state = TableRenderer.values.where((r) => r.name == raw).firstOrNull;
  }

  Future<void> choose(TableRenderer? renderer) async {
    state = renderer;
    final prefs = await SharedPreferences.getInstance();
    if (renderer == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, renderer.name);
    }
  }
}

final rendererChoiceProvider =
    NotifierProvider<RendererChoice, TableRenderer?>(RendererChoice.new);
```

The `dart:convert` import is unused. Delete it: `flutter analyze` must be clean
and the plan for Task 12 in the previous slice shipped exactly this mistake.

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/features/renderer_choice_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Prove the tests bite**

Change `>=` to `>` and confirm `the boundary belongs to the canvas` FAILS. Then
make `chosen` only win when it is `freeCanvas` and confirm
`a choice beats the width, in both directions` FAILS. Restore by editing back
after each.

- [ ] **Step 6: Commit**

```bash
git add lib/features/play/renderers test/features/renderer_choice_test.dart
git commit -m "Pick a view by the room, and let the player overrule it"
```

---

## Task 5: The radar strip

**Files:**
- Create: `lib/features/play/widgets/radar_strip.dart`
- Test: `test/features/radar_strip_test.dart`

Every life total, always visible, whichever renderer is drawing. In a pod the
threat you are not looking at is the one that kills you, and the spec chose
bands over tabs for exactly this reason.

- [ ] **Step 1: Write the failing test**

Create `test/features/radar_strip_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/widgets/radar_strip.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

Widget _host({
  required List<({String seatId, String name, int life})> seats,
  String? focused,
  void Function(String)? onJump,
}) =>
    MaterialApp(
      home: Scaffold(
        body: RadarStrip(
          metrics: Metrics.of(DeviceClass.handheld),
          seats: seats,
          focusedSeatId: focused,
          onJump: onJump ?? (_) {},
        ),
      ),
    );

void main() {
  testWidgets('every life total is on screen at once', (tester) async {
    await tester.pumpWidget(_host(seats: const [
      (seatId: 's1', name: 'you', life: 40),
      (seatId: 's2', name: 'Carla', life: 28),
      (seatId: 's3', name: 'Diego', life: 19),
      (seatId: 's4', name: 'Bruno', life: 34),
    ]));

    // The whole argument for bands over tabs: a threat you are not looking at
    // is a threat you forget.
    expect(find.text('40'), findsOneWidget);
    expect(find.text('28'), findsOneWidget);
    expect(find.text('19'), findsOneWidget);
    expect(find.text('34'), findsOneWidget);
  });

  testWidgets('tapping one asks to jump to it', (tester) async {
    String? jumped;
    await tester.pumpWidget(_host(
      seats: const [
        (seatId: 's1', name: 'you', life: 40),
        (seatId: 's2', name: 'Carla', life: 28),
      ],
      onJump: (id) => jumped = id,
    ));

    await tester.tap(find.text('Carla'));
    await tester.pump();

    expect(jumped, 's2');
  });

  testWidgets('a dead seat is still counted, at zero or below',
      (tester) async {
    await tester.pumpWidget(_host(seats: const [
      (seatId: 's1', name: 'you', life: 40),
      (seatId: 's2', name: 'Carla', life: -3),
    ]));

    expect(find.text('-3'), findsOneWidget);
  });

  testWidgets('one seat still draws a strip', (tester) async {
    await tester.pumpWidget(_host(seats: const [
      (seatId: 's1', name: 'you', life: 40),
    ]));

    expect(find.text('40'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/radar_strip_test.dart`
Expected: FAIL, `Target of URI doesn't exist`.

- [ ] **Step 3: Write it**

Create `lib/features/play/widgets/radar_strip.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../ui/tokens/metrics.dart';
import '../../../ui/tokens/palette.dart';

/// Every life total, always visible, whichever renderer is drawing.
///
/// This is the whole argument for bands over tabs in the spec. A threat you are
/// not looking at is a threat you forget, and Commander is the format where the
/// rest of the table matters most.
class RadarStrip extends StatelessWidget {
  const RadarStrip({
    super.key,
    required this.metrics,
    required this.seats,
    required this.onJump,
    this.focusedSeatId,
  });

  final Metrics metrics;
  final List<({String seatId, String name, int life})> seats;
  final void Function(String seatId) onJump;
  final String? focusedSeatId;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return Row(
      children: [
        for (final seat in seats)
          Expanded(
            child: GestureDetector(
              onTap: () => onJump(seat.seatId),
              behavior: HitTestBehavior.opaque,
              child: Container(
                margin: EdgeInsets.only(right: m.scaled(5)),
                padding: EdgeInsets.symmetric(vertical: m.scaled(6)),
                decoration: BoxDecoration(
                  color: Palette.tile,
                  borderRadius: BorderRadius.circular(m.scaled(8)),
                  border: Border.all(
                    color: seat.seatId == focusedSeatId
                        ? Palette.accent
                        : Palette.tileEdge,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${seat.life}',
                      style: TextStyle(
                        fontSize: m.scaled(15),
                        fontWeight: FontWeight.w700,
                        color: seat.life <= 0
                            ? Palette.attention
                            : Palette.ink,
                      ),
                    ),
                    Text(
                      seat.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: m.scaled(9),
                        letterSpacing: .4,
                        color: Palette.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/features/radar_strip_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Prove the tests bite**

Wrap the seat list in `.take(2)` and confirm
`every life total is on screen at once` FAILS with four seats. Restore by
editing back.

- [ ] **Step 6: Commit**

```bash
git add lib/features/play/widgets/radar_strip.dart test/features/radar_strip_test.dart
git commit -m "Keep every life total on screen"
```

---

## Task 6 onward

The remaining tasks build the two renderers themselves and are written after
the first six land, because their shape depends on what `SeatView` turns out to
be comfortable to draw from. Writing them now would be guessing at an interface
that does not exist yet, which is the mistake this project has already made
twice: the refusal path that no screen could read, and the seat that could not
say who held it.

What they will cover:

- **`seat_band.dart`**, one seat compressed into a band: name, life, hand count,
  and a row of what is on their battlefield.
- **`stacked_seats.dart`**, the bands stacked with yours pinned at the bottom
  and taller, scrolling between them, tapping a band to expand it.
- **`free_canvas.dart`**, the same seats on a pan and pinch surface, with the
  card positions from `CardInstance.position` honoured in both.
- **Switching which local seat is looking**, which is what makes a pod on one
  device playable and what proves `SeatView` actually hides anything.
- **The D-pad on a board**, walking card to card inside a zone and jumping
  between zones on a separate button. This is the part of the D-pad requirement
  the spec flagged as a real interaction problem and it is still unsolved.

## What this plan deliberately leaves out

- **The network, entirely.** `SeatOwner.peer` exists and nothing constructs it.
- **Free card placement by dragging.** The field is honoured when set and
  nothing sets it until the canvas can show what it means.
- **Encrypted hands and libraries.** `SeatView` is the seam they will arrive
  through: it already decides what a viewer may see, and plan 3 changes where
  the answer comes from rather than who asks.
- **Commander damage, the stack, phases, priority.** All rules, and the
  referee's chair is still empty on purpose.
