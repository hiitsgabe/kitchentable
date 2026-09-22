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
      seat.dart            MODIFY  a seat gains an owner
      seat_owner.dart      NEW     here, a peer, or nobody
    view/
      seat_view.dart       NEW     one seat as one viewer sees it
    setup.dart             MODIFY  sitDownTogether seats a pod
  features/play/
    play_controller.dart   MODIFY  opens a pod, and who is looking
    play_screen.dart       MODIFY  picks a renderer and wires the rest
    board_cursor.dart      NEW     where the D-pad is pointing
    renderers/
      renderer_choice.dart NEW     which view, and remembering it
      stacked_seats.dart   NEW     bands, the phone default
      mat_layout.dart      NEW     where a mat goes and a card sits on it
      free_canvas.dart     NEW     pan and pinch, the wide default
    widgets/
      radar_strip.dart     NEW     every life total, always visible
      seat_band.dart       NEW     one opponent, compressed
      cursor_board.dart    NEW     your own piles, walkable
      hand_sheet.dart      MODIFY  a key per card, so a test can look for one
```

Two files the first draft of this plan listed are not here. `table_state.dart`
does not learn who is looking, because that is about this device rather than
about the table and plan 3 replicates the table. `magic_pack.dart` did not need
touching at all: it already took a seat id, and seating a pod turned out to be
a loop in `setup.dart` around the function that seats one.

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
  freeCanvas,
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

## Task 6: A seat compressed into a band

The first widget that draws from a `SeatView` rather than from a `Seat`. An
opponent's hand arrives here already emptied, so the band shows a number and
there is no card in the widget tree to read off.

**Files:**
- Modify: `lib/table/view/seat_view.dart`
- Modify: `test/table/seat_view_test.dart`
- Create: `lib/features/play/widgets/seat_band.dart`
- Test: `test/features/seat_band_test.dart`

- [ ] **Step 1: Write the failing test for finding a pile by kind**

Append to `test/table/seat_view_test.dart`, inside `main()`:

```dart
  test('a pile is found by kind', () {
    final view = SeatView.of(_seat('s1'), viewer: 's1');

    // Zone ids are built as `<kind>-<seatId>` in magic_pack. Every widget that
    // wants a hand would otherwise paste that string together itself.
    expect(view.pile('hand')!.id, 'hand-s1');
    expect(view.pile('battlefield')!.count, 3);
    expect(view.pile('sideboard'), isNull);
  });
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/table/seat_view_test.dart`
Expected: FAIL, `The method 'pile' isn't defined for the type 'SeatView'`.

- [ ] **Step 3: Add the method**

In `lib/table/view/seat_view.dart`, directly below `zone`:

```dart
  /// The pile of that kind: `pile('hand')`, `pile('battlefield')`.
  ///
  /// Zone ids are `<kind>-<seatId>` by construction in `magic_pack.dart`. A
  /// game that names its piles differently passes its own kinds in and this
  /// still holds, which is why the kind is a string and not an enum.
  ZoneView? pile(String kind) => zone('$kind-$seatId');
```

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/table/seat_view_test.dart`
Expected: PASS, 7 tests.

- [ ] **Step 5: Write the failing test for the band**

Create `test/features/seat_band_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/widgets/seat_band.dart';
import 'package:kitchentable/features/play/widgets/table_card.dart';
import 'package:kitchentable/table/model/card_instance.dart';
import 'package:kitchentable/table/model/seat.dart';
import 'package:kitchentable/table/model/zone.dart';
import 'package:kitchentable/table/view/seat_view.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

Zone _zone(String kind, String seatId, ZoneVisibility v, int n) => Zone(
      id: '$kind-$seatId',
      seatId: seatId,
      label: kind,
      visibility: v,
      ordered: false,
      cards: [
        for (var i = 0; i < n; i++)
          CardInstance(id: '$seatId-$kind-$i', oracleId: 'card$i'),
      ],
    );

Seat _seat(String id, {int life = 40, int hand = 3, int board = 0}) => Seat(
      id: id,
      name: 'seat $id',
      life: life,
      zones: [
        _zone('hand', id, ZoneVisibility.owner, hand),
        _zone('battlefield', id, ZoneVisibility.public, board),
      ],
    );

Widget _host(SeatView seat, {void Function()? onTap}) => MaterialApp(
      home: Scaffold(
        body: SeatBand(
          metrics: Metrics.of(DeviceClass.handheld),
          seat: seat,
          printings: const {},
          onTap: onTap ?? () {},
        ),
      ),
    );

/// A view that leaks on purpose: the hand arrives full and readable.
///
/// [SeatView] would never build this, and that is the point. Handing the band
/// a correct view proves nothing about the band, because a band that read the
/// hand would find it empty and draw nothing either way. The band is what is
/// under test here, so it is given a view that would let it misbehave.
SeatView _leaking({int hand = 7, int board = 1}) => SeatView(
      seatId: 's2',
      name: 'seat s2',
      life: 40,
      isViewer: false,
      zones: [
        ZoneView(
          id: 'battlefield-s2',
          label: 'battlefield',
          count: board,
          readable: true,
          cards: [
            for (var i = 0; i < board; i++)
              CardInstance(id: 's2-b$i', oracleId: 'card$i'),
          ],
        ),
        ZoneView(
          id: 'hand-s2',
          label: 'hand',
          count: hand,
          readable: true,
          cards: [
            for (var i = 0; i < hand; i++)
              CardInstance(id: 's2-h$i', oracleId: 'card$i'),
          ],
        ),
      ],
    );

void main() {
  testWidgets('an opponent shows how many cards, never which', (tester) async {
    await tester.pumpWidget(_host(_leaking(hand: 7, board: 1)));

    expect(find.text('hand 7'), findsOneWidget);
    // One card drawn, and it is the one on the battlefield. The seven in the
    // hand are right there in the view and the band must still not reach for
    // them: a pile other than the battlefield is not the band's to draw.
    expect(find.byType(TableCard), findsNWidgets(1));
  });

  testWidgets('a battlefield is drawn, because everybody can see it',
      (tester) async {
    final them = SeatView.of(_seat('s2', board: 2), viewer: 's1');
    await tester.pumpWidget(_host(them));

    expect(find.byType(TableCard), findsNWidgets(2));
  });

  testWidgets('an empty battlefield says so', (tester) async {
    final them = SeatView.of(_seat('s2'), viewer: 's1');
    await tester.pumpWidget(_host(them));

    expect(find.text('nothing out'), findsOneWidget);
  });

  testWidgets('life shows, and a dead seat still shows it', (tester) async {
    final them = SeatView.of(_seat('s2', life: -2), viewer: 's1');
    await tester.pumpWidget(_host(them));

    expect(find.text('-2'), findsOneWidget);
  });

  testWidgets('tapping the band reports it', (tester) async {
    var tapped = false;
    final them = SeatView.of(_seat('s2'), viewer: 's1');
    await tester.pumpWidget(_host(them, onTap: () => tapped = true));

    await tester.tap(find.byKey(const Key('band-s2')));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
```

- [ ] **Step 6: Run it and watch it fail**

Run: `flutter test test/features/seat_band_test.dart`
Expected: FAIL, `Error when reading 'lib/features/play/widgets/seat_band.dart'`.

- [ ] **Step 7: Write the band**

Create `lib/features/play/widgets/seat_band.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../sources/model/catalog_card.dart';
import '../../../table/view/seat_view.dart';
import '../../../ui/tokens/metrics.dart';
import '../../../ui/tokens/palette.dart';
import 'table_card.dart';

/// One seat, compressed: who they are, how much life, how many cards they are
/// holding, and what they have on the battlefield.
///
/// It takes a [SeatView] and not a `Seat`, which is the whole point. A card
/// this viewer may not see never arrives, so there is nothing in the widget
/// tree to read off, screenshot, or accidentally draw.
class SeatBand extends StatelessWidget {
  const SeatBand({
    super.key,
    required this.metrics,
    required this.seat,
    required this.printings,
    required this.onTap,
    this.isTurn = false,
    this.focused = false,
  });

  final Metrics metrics;
  final SeatView seat;

  /// Printings for whatever is on their battlefield. A card the catalog has
  /// never heard of draws as a back, which [TableCard] already handles.
  final Map<String, CatalogCard> printings;

  final VoidCallback onTap;
  final bool isTurn;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final board = seat.pile('battlefield');
    final hand = seat.pile('hand');

    return GestureDetector(
      key: Key('band-${seat.seatId}'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: EdgeInsets.only(bottom: m.scaled(8)),
        padding: EdgeInsets.all(m.scaled(10)),
        decoration: BoxDecoration(
          color: focused ? Palette.tileFocused : Palette.tile,
          borderRadius: BorderRadius.circular(m.scaled(10)),
          border: Border.all(
            color: isTurn ? Palette.accent : Palette.tileEdge,
            width: isTurn ? m.focusRing : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    seat.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: m.scaled(13), color: Palette.ink),
                  ),
                ),
                // The count and not the cards. At a real table everybody can
                // see how many somebody is holding and nobody can see which.
                Text(
                  'hand ${hand?.count ?? 0}',
                  style: TextStyle(
                    fontSize: m.scaled(11),
                    color: Palette.inkFaint,
                  ),
                ),
                SizedBox(width: m.scaled(12)),
                Text(
                  '${seat.life}',
                  style: TextStyle(
                    fontSize: m.scaled(18),
                    fontWeight: FontWeight.w700,
                    color: seat.life <= 0 ? Palette.attention : Palette.ink,
                  ),
                ),
              ],
            ),
            SizedBox(height: m.scaled(8)),
            SizedBox(
              height: m.scaled(58),
              child: board == null || board.cards.isEmpty
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'nothing out',
                        style: TextStyle(
                          fontSize: m.scaled(11),
                          color: Palette.inkFaint,
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final card in board.cards)
                            Padding(
                              padding: EdgeInsets.only(right: m.scaled(6)),
                              child: TableCard(
                                metrics: m,
                                instance: card,
                                printing: printings[card.oracleId],
                                width: m.scaled(40),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 8: Run both test files and watch them pass**

Run: `flutter test test/features/seat_band_test.dart test/table/seat_view_test.dart`
Expected: PASS, 12 tests.

- [ ] **Step 9: Probe that the hiding test can fail**

Probe the band and not the view. In `seat_band.dart`, change the battlefield
row to `for (final card in [...board.cards, ...?seat.pile('hand')?.cards])`
and run `flutter test test/features/seat_band_test.dart`. The first case must
fail with eight TableCards found where one was expected, and it must be the
only case that fails. Edit it back by hand, never with `git checkout`, and
rerun.

**Do not probe `SeatView._viewOf` here and expect this file to notice.** The
first draft of this task did, and the mutation survived: `SeatBand` has no
code path that renders a hand card, so a leaking view changes nothing it
draws. Only both bugs at once made the case fail, which means it pinned
neither. `SeatView`'s own hiding is probed in Task 2 and in
`seat_view_test.dart`, where it bites.

- [ ] **Step 10: Commit**

```bash
git add lib/table/view/seat_view.dart test/table/seat_view_test.dart \
        lib/features/play/widgets/seat_band.dart test/features/seat_band_test.dart
git commit -m "Draw an opponent as a number and a battlefield"
```

---

## Task 7: A pod, and which seat is looking

The table already seats several people. Nothing opens one, and nothing decides
whose eyes the screen is behind. Both land here, and the second is the thing
that makes `SeatView` more than a unit test.

**Files:**
- Modify: `lib/features/play/play_controller.dart`
- Test: `test/features/pod_controller_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/pod_controller_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/decks/model/deck.dart';
import 'package:kitchentable/decks/model/deck_format.dart';
import 'package:kitchentable/features/play/play_controller.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';
import 'package:kitchentable/table/model/seat_owner.dart';
import 'package:kitchentable/table/setup.dart';

CatalogCard _card(String name) =>
    CatalogCard(oracleId: name, name: name, typeLine: 'Instant', cmc: 1);

Deck _deck(String name) => Deck(
      id: name,
      name: name,
      format: DeckFormat.commander,
      slots: [DeckSlot(card: _card('$name-card'), quantity: 60)],
    );

Player _here(String name) =>
    (deck: _deck(name), name: name, owner: const SeatOwner.here());

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  PlayController controller() => container.read(playProvider.notifier);
  ViewerSeat viewer() => container.read(viewerSeatProvider.notifier);

  test('nobody is looking before a table opens', () {
    expect(container.read(viewerSeatProvider), isNull);
  });

  test('a pod seats everybody and you are looking first', () {
    controller().startPod(
      players: [_here('you'), _here('Carla'), _here('Diego')],
      seed: 'abc',
    );

    expect(container.read(playProvider)!.seats, hasLength(3));
    expect(container.read(viewerSeatProvider), 's1');
  });

  test('one deck goes through the same door', () {
    controller().start(_deck('solo'), seed: 'abc');

    final table = container.read(playProvider)!;
    expect(table.seats, hasLength(1));
    expect(table.zone('hand-s1')!.size, 7);
    // Solo is not a mode. It is the case where nobody else has joined, so the
    // one seat is held here exactly like the other three would be.
    expect(table.seats.single.owner.actableHere, isTrue);
    expect(container.read(viewerSeatProvider), 's1');
  });

  test('looking through another local seat moves the viewer', () {
    controller().startPod(players: [_here('you'), _here('Carla')], seed: 'abc');

    expect(viewer().look('s2'), isTrue);
    expect(container.read(viewerSeatProvider), 's2');
  });

  test('looking through a seat this device does not hold is refused', () {
    controller().startPod(
      players: [
        _here('you'),
        (deck: _deck('far'), name: 'Bruno', owner: const SeatOwner.peer('p1')),
      ],
      seed: 'abc',
    );

    // The one rule that makes hidden information mean anything on a device
    // holding several seats: you may only look out of a chair you are in.
    expect(viewer().look('s2'), isFalse);
    expect(container.read(viewerSeatProvider), 's1');
  });

  test('looking at a seat that is not there is refused', () {
    controller().startPod(players: [_here('you')], seed: 'abc');

    expect(viewer().look('s9'), isFalse);
    expect(container.read(viewerSeatProvider), 's1');
  });

  test('leaving puts nobody in the chair', () {
    controller().startPod(players: [_here('you'), _here('Carla')], seed: 'abc');
    viewer().look('s2');
    controller().leave();

    expect(container.read(playProvider), isNull);
    // A stale viewer outlives its table and points at a seat that no longer
    // exists, which the next table then inherits.
    expect(container.read(viewerSeatProvider), isNull);
  });

  test('a new table reseats the viewer at its own first seat', () {
    controller().startPod(players: [_here('you'), _here('Carla')], seed: 'abc');
    viewer().look('s2');
    controller().startPod(players: [_here('you')], seed: 'def');

    expect(container.read(viewerSeatProvider), 's1');
  });

  test('a pod of peers only leaves nobody looking', () {
    controller().startPod(
      players: [
        (deck: _deck('a'), name: 'Carla', owner: const SeatOwner.peer('p1')),
        (deck: _deck('b'), name: 'Diego', owner: const SeatOwner.peer('p2')),
      ],
      seed: 'abc',
    );

    // A spectator: the table is open and this device holds no chair. Plan 3
    // arrives here, and it must not land on somebody else's hand by default.
    expect(container.read(viewerSeatProvider), isNull);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/pod_controller_test.dart`
Expected: FAIL to compile, `Undefined name 'viewerSeatProvider'` and
`The method 'startPod' isn't defined`.

- [ ] **Step 3: Add the viewer and the pod door**

In `lib/features/play/play_controller.dart`, add these imports:

```dart
import '../../table/model/seat_owner.dart';
```

Add below `playRefusalProvider`:

```dart
/// Which seat this device is looking out of.
///
/// A provider of its own rather than a field on [TableState], for the same
/// reason the refusal is one: looking through a different seat does not change
/// the table, so a field there would notify nobody. It is also the one thing
/// here that is about this device and not about the game, which is why plan 3
/// replicates the table and never this.
class ViewerSeat extends Notifier<String?> {
  @override
  String? build() => null;

  /// Refuses a chair this device is not in. Looking out of somebody else's
  /// seat is the exact thing [SeatView] exists to prevent, so the guard lives
  /// with the state and not in the screen, which is not the only caller it
  /// will ever have.
  bool look(String seatId) {
    final seat = ref.read(playProvider)?.seat(seatId);
    if (seat == null || !seat.owner.actableHere) return false;
    state = seatId;
    return true;
  }

  /// Seats the viewer without asking. Only for opening and closing a table,
  /// where there is nothing to refuse yet.
  void sit(String? seatId) => state = seatId;
}

final viewerSeatProvider =
    NotifierProvider<ViewerSeat, String?>(ViewerSeat.new);
```

Replace `PlayController.start` with:

```dart
  void start(Deck deck, {String? seed}) => startPod(
        players: [(deck: deck, name: 'you', owner: const SeatOwner.here())],
        seed: seed,
      );

  /// Everybody at this device. Solo comes through here too: one player is a
  /// pod of one, and a separate path for it is how the one seat case drifts
  /// away from the four seat one without anybody noticing.
  void startPod({required List<Player> players, String? seed}) {
    if (players.isEmpty) return;

    final table = sitDownTogether(players: players, seed: seed ?? freshSeed());
    _session = TableSession(table);
    _clearRefusal();
    state = table;

    final here = table.seats.where((s) => s.owner.actableHere).firstOrNull;
    ref.read(viewerSeatProvider.notifier).sit(here?.id);
  }
```

In `leave()`, below `_clearRefusal();`:

```dart
    ref.read(viewerSeatProvider.notifier).sit(null);
```

- [ ] **Step 4: Run the whole suite**

Run: `flutter test`
Expected: PASS. `play_controller_test.dart` and `play_screen_test.dart` both
call `start` and must keep passing unchanged: a pod of one deals the same seven
cards, because `sitDownTogether` derives `abc/s1` from `abc` and the one seat
case went through `sitDown` with the raw seed before. **If the seven cards
changed, they changed for everybody, and that is a real behaviour change to
report rather than a test to update.**

- [ ] **Step 5: Probe that the refusal test can fail**

Change the guard to `if (seat == null) return false;` and run
`flutter test test/features/pod_controller_test.dart`. The peer case must fail.
Edit it back by hand and rerun.

- [ ] **Step 6: Commit**

```bash
git add lib/features/play/play_controller.dart test/features/pod_controller_test.dart
git commit -m "Open a table for a pod, and decide whose eyes it is"
```

---

## Task 8: Bands, stacked

The phone renderer. Opponents above in a scrolling column, your own seat below
and taller. The renderer decides where your seat goes and has no opinion about
what is inside it, which is why it takes a widget.

**Files:**
- Create: `lib/features/play/renderers/stacked_seats.dart`
- Test: `test/features/stacked_seats_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/stacked_seats_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/renderers/stacked_seats.dart';
import 'package:kitchentable/features/play/widgets/seat_band.dart';
import 'package:kitchentable/table/model/card_instance.dart';
import 'package:kitchentable/table/model/seat.dart';
import 'package:kitchentable/table/model/zone.dart';
import 'package:kitchentable/table/view/seat_view.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

Seat _seat(String id) => Seat(
      id: id,
      name: 'seat $id',
      life: 40,
      zones: [
        Zone(
          id: 'hand-$id',
          seatId: id,
          label: 'hand',
          visibility: ZoneVisibility.owner,
          ordered: false,
          cards: [CardInstance(id: '$id-h0', oracleId: 'c0')],
        ),
        Zone(
          id: 'battlefield-$id',
          seatId: id,
          label: 'battlefield',
          visibility: ZoneVisibility.public,
          ordered: false,
        ),
      ],
    );

Widget _host(
  List<String> seatIds, {
  String viewer = 's1',
  void Function(String)? onFocusSeat,
}) =>
    MaterialApp(
      home: Scaffold(
        body: StackedSeats(
          metrics: Metrics.of(DeviceClass.handheld),
          seats: [
            for (final id in seatIds) SeatView.of(_seat(id), viewer: viewer),
          ],
          viewerSeatId: viewer,
          printings: const {},
          onFocusSeat: onFocusSeat ?? (_) {},
          yours: const ColoredBox(
            key: Key('your-seat'),
            color: Color(0xFF000000),
            child: SizedBox.expand(),
          ),
        ),
      ),
    );


/// The default 800x600 surface leaves the band column 240 logical pixels,
/// which is two of a 122 pixel band: the rest scrolls, and a band in the cache
/// region is offstage, where the default finders will not look. These cases
/// are about where a band goes, not about scrolling, so give the surface room
/// for every band to be on screen at once.
void _roomForBands(WidgetTester tester) {
  tester.view.physicalSize = const Size(2400, 3000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('everybody but you gets a band', (tester) async {
    _roomForBands(tester);
    await tester.pumpWidget(_host(['s1', 's2', 's3', 's4']));

    expect(find.byType(SeatBand), findsNWidgets(3));
    expect(find.byKey(const Key('band-s1')), findsNothing);
    expect(find.byKey(const Key('band-s4')), findsOneWidget);
  });

  testWidgets('your seat sits below every band', (tester) async {
    _roomForBands(tester);
    await tester.pumpWidget(_host(['s1', 's2', 's3']));

    final yours = tester.getRect(find.byKey(const Key('your-seat')));
    for (final id in ['s2', 's3']) {
      final band = tester.getRect(find.byKey(Key('band-$id')));
      expect(yours.top, greaterThanOrEqualTo(band.bottom - 1),
          reason: 'your seat must start at or below where $id ends');
    }
  });

  testWidgets('a table of one is your seat and nothing else', (tester) async {
    _roomForBands(tester);
    await tester.pumpWidget(_host(['s1']));

    expect(find.byType(SeatBand), findsNothing);
    expect(find.byKey(const Key('your-seat')), findsOneWidget);
  });

  testWidgets('tapping a band asks to look out of that seat', (tester) async {
    _roomForBands(tester);
    String? asked;
    await tester.pumpWidget(_host(['s1', 's2'], onFocusSeat: (id) => asked = id));

    await tester.tap(find.byKey(const Key('band-s2')));
    await tester.pump();

    expect(asked, 's2');
  });

  testWidgets('a spectator gets a band for everybody', (tester) async {
    _roomForBands(tester);
    // Nobody is looking, which is plan 3 arriving as a spectator. Every seat
    // is somebody else, so every seat is a band.
    await tester.pumpWidget(_host(['s1', 's2'], viewer: ''));

    expect(find.byType(SeatBand), findsNWidgets(2));
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/stacked_seats_test.dart`
Expected: FAIL, `Error when reading
'lib/features/play/renderers/stacked_seats.dart'`.

- [ ] **Step 3: Write the renderer**

Create `lib/features/play/renderers/stacked_seats.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../sources/model/catalog_card.dart';
import '../../../table/view/seat_view.dart';
import '../../../ui/tokens/metrics.dart';
import '../widgets/seat_band.dart';

/// The phone view. Opponents stacked above, your own seat below and taller.
///
/// Bands rather than tabs, because a threat you are not looking at is a threat
/// you forget, and Commander is the format where the rest of the table matters
/// most. Nobody has to switch to anything to know they are about to die.
class StackedSeats extends StatelessWidget {
  const StackedSeats({
    super.key,
    required this.metrics,
    required this.seats,
    required this.viewerSeatId,
    required this.printings,
    required this.onFocusSeat,
    required this.yours,
    this.turnSeatId,
    this.focusedSeatId,
  });

  final Metrics metrics;

  /// Every seat, in table order, already filtered for this viewer.
  final List<SeatView> seats;

  /// Whose eyes. Empty or unknown means a spectator, and then every seat is
  /// somebody else's.
  final String viewerSeatId;

  final Map<String, CatalogCard> printings;
  final void Function(String seatId) onFocusSeat;

  /// Your own seat, drawn by whoever owns that layout. This renderer decides
  /// where it goes and has no opinion about what is in it, which is what keeps
  /// the board, the piles and the hand out of here.
  final Widget yours;

  final String? turnSeatId;
  final String? focusedSeatId;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final others = seats.where((s) => s.seatId != viewerSeatId).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (others.isNotEmpty)
          Expanded(
            flex: 2,
            child: ListView(
              padding: EdgeInsets.only(bottom: m.scaled(4)),
              children: [
                for (final seat in others)
                  SeatBand(
                    metrics: m,
                    seat: seat,
                    printings: printings,
                    isTurn: seat.seatId == turnSeatId,
                    focused: seat.seatId == focusedSeatId,
                    onTap: () => onFocusSeat(seat.seatId),
                  ),
              ],
            ),
          ),
        // Three to two: your own seat is where the game is played from, and a
        // fair split makes a four card hand and four opponents equally cramped.
        Expanded(flex: 3, child: yours),
      ],
    );
  }
}
```

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/features/stacked_seats_test.dart`
Expected: PASS, 5 tests.

Without `_roomForBands` two of them fail, and the renderer is not at fault:
three bands are 366 logical pixels and the band column on the default surface
is 240, so the third lands in the `ListView` cache region where it is built
but offstage, and `find.byType` skips offstage by default. The first draft of
this task had no `_roomForBands` and hit exactly that.

- [ ] **Step 5: Probe the geometry test**

Swap the two children so `yours` comes first, and run the file. The geometry
case must fail. Edit it back by hand and rerun.

- [ ] **Step 6: Commit**

```bash
git add lib/features/play/renderers/stacked_seats.dart \
        test/features/stacked_seats_test.dart
git commit -m "Stack the table, with your own seat at the bottom"
```

---

## Task 9: Where a mat goes, and where a card goes on it

The canvas needs arithmetic before it needs widgets. Doing it in the widget is
how the answer becomes untestable and how the two renderers quietly stop
agreeing about what a position means.

**Files:**
- Create: `lib/features/play/renderers/mat_layout.dart`
- Test: `test/features/mat_layout_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/mat_layout_test.dart`:

```dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/renderers/mat_layout.dart';

void main() {
  test('two seats sit side by side', () {
    final a = matFor(0, 2);
    final b = matFor(1, 2);

    expect(a.top, b.top);
    expect(b.left, greaterThan(a.right));
  });

  test('four seats make a square and no two mats touch', () {
    final mats = [for (var i = 0; i < 4; i++) matFor(i, 4)];

    for (var i = 0; i < mats.length; i++) {
      for (var j = i + 1; j < mats.length; j++) {
        expect(mats[i].overlaps(mats[j]), isFalse,
            reason: 'mat $i overlaps mat $j');
      }
    }
    expect(mats[2].top, greaterThan(mats[0].bottom));
  });

  test('three seats leave the fourth place empty', () {
    // Squeezing three into a row makes a card a smudge on a tablet. The gap
    // where the fourth would be is the cheaper answer.
    expect(matFor(2, 3).top, greaterThan(matFor(0, 3).bottom));
    expect(matFor(2, 3).left, matFor(0, 3).left);
  });

  test('one seat gets the whole surface', () {
    expect(matFor(0, 1), Rect.fromLTWH(0, 0, matSize.width, matSize.height));
    expect(surfaceFor(1), matSize);
  });

  test('the surface is big enough for every mat', () {
    for (final count in [1, 2, 3, 4, 5, 6]) {
      final surface = surfaceFor(count);
      for (var i = 0; i < count; i++) {
        final mat = matFor(i, count);
        expect(mat.right, lessThanOrEqualTo(surface.width),
            reason: 'mat $i of $count runs off the right');
        expect(mat.bottom, lessThanOrEqualTo(surface.height),
            reason: 'mat $i of $count runs off the bottom');
      }
    }
  });

  const card = Size(90, 126);

  test('a card with a position is centred on it', () {
    final spot = spotFor(position: (x: 0.5, y: 0.5), index: 0, card: card);

    expect(spot.dx, closeTo(matSize.width / 2 - card.width / 2, 0.01));
    expect(spot.dy, closeTo(matSize.height / 2 - card.height / 2, 0.01));
  });

  test('a card at the very edge stays on the mat', () {
    final spot = spotFor(position: (x: 1, y: 1), index: 0, card: card);

    expect(spot.dx, closeTo(matSize.width - card.width, 0.01));
    expect(spot.dy, closeTo(matSize.height - card.height, 0.01));
    expect(spot.dx, greaterThanOrEqualTo(0));
  });

  test('a card without a position gets a slot, and keeps it', () {
    final first = spotFor(position: null, index: 0, card: card);
    final again = spotFor(position: null, index: 0, card: card);
    final second = spotFor(position: null, index: 1, card: card);

    // Cards must not jump around when one of them is turned, so the slot is a
    // function of the index and nothing else.
    expect(first, again);
    expect(second.dx, greaterThan(first.dx));
    expect(second.dy, first.dy);
  });

  test('the flow wraps rather than running off the mat', () {
    final spots = [
      for (var i = 0; i < 20; i++) spotFor(position: null, index: i, card: card),
    ];

    expect(spots.last.dy, greaterThan(spots.first.dy));
    for (final spot in spots) {
      expect(spot.dx + card.width, lessThanOrEqualTo(matSize.width));
    }
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/mat_layout_test.dart`
Expected: FAIL, `Error when reading
'lib/features/play/renderers/mat_layout.dart'`.

- [ ] **Step 3: Write the arithmetic**

Create `lib/features/play/renderers/mat_layout.dart`:

```dart
import 'dart:math' as math;
import 'dart:ui';

/// One seat's mat, in surface units. The canvas zooms, so these are not
/// pixels and do not scale with the device.
const matSize = Size(640, 380);

/// Between mats, so two battlefields never read as one.
const matGap = 40.0;

/// Space kept clear inside a mat, and between cards laid out by flow.
const matPadding = 16.0;

/// Where a seat's mat sits on the shared surface.
///
/// A grid and not a ring. A ring was the first idea and it is wrong for a
/// rectangle: seats land at angles where a card is either tiny or off the
/// edge, and a phone rotated into landscape makes it worse. Two across, then
/// down, and three seats leave the fourth place empty rather than squeezing.
Rect matFor(int index, int count) {
  final columns = count <= 1 ? 1 : 2;
  final column = index % columns;
  final row = index ~/ columns;

  return Rect.fromLTWH(
    column * (matSize.width + matGap),
    row * (matSize.height + matGap),
    matSize.width,
    matSize.height,
  );
}

/// How big the whole surface is, so the viewer knows what it is panning over.
Size surfaceFor(int count) {
  final seats = math.max(1, count);
  final columns = seats <= 1 ? 1 : 2;
  final rows = (seats / columns).ceil();

  return Size(
    columns * matSize.width + (columns - 1) * matGap,
    rows * matSize.height + (rows - 1) * matGap,
  );
}

/// Where a card sits inside its own mat.
///
/// A card carrying an `x,y` is centred on it, normalized against the mat and
/// not against the screen, which is what lets both renderers show the same
/// arrangement. A card without one falls into a slot that depends on the index
/// and on nothing else, because cards must not jump around when one of them
/// is turned.
Offset spotFor({
  required ({double x, double y})? position,
  required int index,
  required Size card,
}) {
  if (position == null) return _flowSpot(index, card);

  return Offset(
    clampDouble(
      position.x * matSize.width - card.width / 2,
      0,
      matSize.width - card.width,
    ),
    clampDouble(
      position.y * matSize.height - card.height / 2,
      0,
      matSize.height - card.height,
    ),
  );
}

Offset _flowSpot(int index, Size card) {
  final perRow = math.max(
    1,
    ((matSize.width - matPadding) / (card.width + matPadding)).floor(),
  );

  return Offset(
    matPadding + (index % perRow) * (card.width + matPadding),
    matPadding + (index ~/ perRow) * (card.height + matPadding),
  );
}
```

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/features/mat_layout_test.dart`
Expected: PASS, 9 tests.

- [ ] **Step 5: Probe the clamp**

Delete the outer `clampDouble` on the x axis, returning the raw value, and run
the file. The edge case must fail. Edit it back by hand and rerun.

- [ ] **Step 6: Commit**

```bash
git add lib/features/play/renderers/mat_layout.dart test/features/mat_layout_test.dart
git commit -m "Work out where a mat goes before drawing one"
```

---

## Task 10: The canvas

The wide view. Every mat on one surface, pan and pinch, and the positions from
`CardInstance.position` honoured. Nothing writes that field yet and this is the
first thing that would show it if something did.

**Files:**
- Create: `lib/features/play/renderers/free_canvas.dart`
- Test: `test/features/free_canvas_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/free_canvas_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/renderers/free_canvas.dart';
import 'package:kitchentable/features/play/widgets/table_card.dart';
import 'package:kitchentable/table/model/card_instance.dart';
import 'package:kitchentable/table/model/seat.dart';
import 'package:kitchentable/table/model/zone.dart';
import 'package:kitchentable/table/view/seat_view.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

Zone _zone(String kind, String seatId, ZoneVisibility v, List<CardInstance> c) =>
    Zone(
      id: '$kind-$seatId',
      seatId: seatId,
      label: kind,
      visibility: v,
      ordered: false,
      cards: c,
    );

Seat _seat(String id, {int board = 1, int hand = 2}) => Seat(
      id: id,
      name: 'seat $id',
      life: 40,
      zones: [
        _zone('battlefield', id, ZoneVisibility.public, [
          for (var i = 0; i < board; i++)
            CardInstance(id: '$id-b$i', oracleId: 'c$i'),
        ]),
        _zone('hand', id, ZoneVisibility.owner, [
          for (var i = 0; i < hand; i++)
            CardInstance(id: '$id-h$i', oracleId: 'c$i'),
        ]),
      ],
    );

Widget _host(
  List<Seat> seats, {
  String viewer = 's1',
  void Function(CardInstance)? onTapCard,
}) =>
    MaterialApp(
      home: Scaffold(
        body: FreeCanvas(
          metrics: Metrics.of(DeviceClass.handheld),
          seats: [for (final s in seats) SeatView.of(s, viewer: viewer)],
          viewerSeatId: viewer,
          printings: const {},
          onTapCard: onTapCard ?? (_) {},
          onInspectCard: (_) {},
        ),
      ),
    );

void main() {
  testWidgets('every seat gets a mat with its name on it', (tester) async {
    await tester.pumpWidget(_host([_seat('s1'), _seat('s2'), _seat('s3')]));

    expect(find.byKey(const Key('mat-s1')), findsOneWidget);
    expect(find.byKey(const Key('mat-s2')), findsOneWidget);
    expect(find.byKey(const Key('mat-s3')), findsOneWidget);
    expect(find.text('seat s2 · 40'), findsOneWidget);
  });

  testWidgets('a battlefield is drawn for everybody', (tester) async {
    await tester.pumpWidget(_host([_seat('s1', board: 2), _seat('s2', board: 3)]));

    expect(find.byType(TableCard), findsNWidgets(5));
  });

  testWidgets('no hand is on the canvas, not even your own', (tester) async {
    await tester.pumpWidget(_host([_seat('s1', board: 1, hand: 2)]));

    // The hand lives in its own sheet below the board, and a hand on the mat
    // is the Arena mistake the spec rules out by geometry.
    expect(find.byKey(const Key('card-s1-h0')), findsNothing);
    expect(find.byKey(const Key('card-s1-b0')), findsOneWidget);
  });

  testWidgets('tapping a card reports it', (tester) async {
    CardInstance? tapped;
    await tester.pumpWidget(
      _host([_seat('s1', board: 1)], onTapCard: (c) => tapped = c),
    );

    await tester.tap(find.byKey(const Key('card-s1-b0')));
    await tester.pump();

    expect(tapped?.id, 's1-b0');
  });

  testWidgets('a card that says where it is goes there', (tester) async {
    final placed = Seat(
      id: 's1',
      name: 'seat s1',
      life: 40,
      zones: [
        _zone('battlefield', 's1', ZoneVisibility.public, [
          const CardInstance(
            id: 's1-b0',
            oracleId: 'c0',
            position: (x: 0.9, y: 0.1),
          ),
          const CardInstance(id: 's1-b1', oracleId: 'c1'),
        ]),
      ],
    );
    await tester.pumpWidget(_host([placed]));

    final positioned = tester.getRect(find.byKey(const Key('card-s1-b0')));
    final flowed = tester.getRect(find.byKey(const Key('card-s1-b1')));

    // Nothing writes position yet. This is the first thing that would show it
    // if something did, which is the only reason the field is not dead code.
    expect(positioned.left, greaterThan(flowed.left));
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/free_canvas_test.dart`
Expected: FAIL, `Error when reading
'lib/features/play/renderers/free_canvas.dart'`.

- [ ] **Step 3: Write the canvas**

Create `lib/features/play/renderers/free_canvas.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../sources/model/catalog_card.dart';
import '../../../table/model/card_instance.dart';
import '../../../table/view/seat_view.dart';
import '../../../ui/tokens/metrics.dart';
import '../../../ui/tokens/palette.dart';
import '../widgets/table_card.dart';
import 'mat_layout.dart';

/// How big a card is in surface units. The canvas zooms, so this is fixed and
/// [Metrics] is deliberately not consulted for it: a card must be the same
/// size relative to the mat on a phone and on a television.
const _cardOnMat = Size(90, 90 * 88 / 63);

/// The wide view. Every mat on one surface you pan and pinch.
///
/// Only battlefields are here. A hand belongs to one person and lives in its
/// own sheet below the board, which is the Arena rule the spec pins by
/// geometry: you must be able to look at your hand and the table at once.
class FreeCanvas extends StatelessWidget {
  const FreeCanvas({
    super.key,
    required this.metrics,
    required this.seats,
    required this.viewerSeatId,
    required this.printings,
    required this.onTapCard,
    required this.onInspectCard,
    this.turnSeatId,
  });

  final Metrics metrics;
  final List<SeatView> seats;
  final String viewerSeatId;
  final Map<String, CatalogCard> printings;
  final void Function(CardInstance) onTapCard;
  final void Function(CardInstance) onInspectCard;
  final String? turnSeatId;

  @override
  Widget build(BuildContext context) {
    final surface = surfaceFor(seats.length);

    return InteractiveViewer(
      constrained: false,
      minScale: 0.2,
      maxScale: 2.5,
      boundaryMargin: const EdgeInsets.all(matGap),
      child: SizedBox(
        width: surface.width,
        height: surface.height,
        child: Stack(
          children: [
            for (var i = 0; i < seats.length; i++)
              Positioned.fromRect(
                rect: matFor(i, seats.length),
                child: _Mat(
                  metrics: metrics,
                  seat: seats[i],
                  printings: printings,
                  isViewer: seats[i].seatId == viewerSeatId,
                  isTurn: seats[i].seatId == turnSeatId,
                  onTapCard: onTapCard,
                  onInspectCard: onInspectCard,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Mat extends StatelessWidget {
  const _Mat({
    required this.metrics,
    required this.seat,
    required this.printings,
    required this.isViewer,
    required this.isTurn,
    required this.onTapCard,
    required this.onInspectCard,
  });

  final Metrics metrics;
  final SeatView seat;
  final Map<String, CatalogCard> printings;
  final bool isViewer;
  final bool isTurn;
  final void Function(CardInstance) onTapCard;
  final void Function(CardInstance) onInspectCard;

  @override
  Widget build(BuildContext context) {
    final board = seat.pile('battlefield');
    final cards = board?.cards ?? const <CardInstance>[];

    return Container(
      key: Key('mat-${seat.seatId}'),
      decoration: BoxDecoration(
        color: isViewer ? Palette.tileFocused : Palette.tile,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isTurn ? Palette.accent : Palette.tileEdge,
          width: isTurn ? 3 : 1,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: matPadding,
            top: matPadding / 2,
            child: Text(
              '${seat.name} · ${seat.life}',
              style: TextStyle(
                fontSize: 18,
                color: seat.life <= 0 ? Palette.attention : Palette.inkMuted,
              ),
            ),
          ),
          for (var i = 0; i < cards.length; i++)
            _place(cards[i], i),
        ],
      ),
    );
  }

  Widget _place(CardInstance card, int index) {
    final spot = spotFor(
      position: card.position,
      index: index,
      card: _cardOnMat,
    );

    return Positioned(
      key: Key('card-${card.id}'),
      left: spot.dx,
      // Below the seat's name, which sits in the padding at the top.
      top: spot.dy + matPadding,
      child: TableCard(
        metrics: metrics,
        instance: card,
        printing: printings[card.oracleId],
        width: _cardOnMat.width,
        onTap: () => onTapCard(card),
        onLongPress: () => onInspectCard(card),
      ),
    );
  }
}
```

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/features/free_canvas_test.dart`
Expected: PASS, 5 tests.

If the tap case fails with the card outside the hit area, it is the surface
being larger than the test window: add
`tester.view.physicalSize = const Size(1400, 1000);`, `devicePixelRatio = 1`
and `addTearDown(tester.view.resetPhysicalSize)` to that case rather than
changing the widget.

- [ ] **Step 5: Probe that the hand test can fail**

Change `seat.pile('battlefield')` to
`ZoneView(id: 'x', label: 'x', count: 0, readable: true, cards: [...seat.pile('battlefield')!.cards, ...?seat.pile('hand')?.cards])`
temporarily, run the file, and confirm the hand case fails. Edit it back by
hand and rerun.

- [ ] **Step 6: Commit**

```bash
git add lib/features/play/renderers/free_canvas.dart test/features/free_canvas_test.dart
git commit -m "Put every mat on one surface you can pan"
```

---

## Task 11: The screen picks one

Everything built so far is unreachable. `RadarStrip`, `SeatBand`,
`StackedSeats`, `FreeCanvas`, `rendererFor` and `ViewerSeat.look` have no
caller between them, which is the fifth time in this project that a thing has
existed only on paper. This task is where that stops.

**Files:**
- Modify: `lib/features/play/play_screen.dart`
- Modify: `test/features/play_screen_test.dart`

- [ ] **Step 1: Write the failing tests**

Replace the `_seated` helper in `test/features/play_screen_test.dart` with
these two, keeping every existing case working through `_seated`:

```dart
Future<ProviderContainer> _seated(WidgetTester tester) =>
    _seatedPod(tester, ['you']);

Future<ProviderContainer> _seatedPod(
  WidgetTester tester,
  List<String> names, {
  Size window = const Size(390, 844),
}) async {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(
    overrides: [catalogDbProvider.overrideWithValue(null)],
  );
  addTearDown(container.dispose);
  container.read(playProvider.notifier).startPod(
        players: [
          for (final name in names)
            (deck: _deck(), name: name, owner: const SeatOwner.here()),
        ],
        seed: 'abc',
      );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: PlayScreen()),
    ),
  );
  await tester.pump();
  return container;
}
```

Add these imports to the file:

```dart
import 'package:kitchentable/features/play/renderers/free_canvas.dart';
import 'package:kitchentable/features/play/renderers/stacked_seats.dart';
import 'package:kitchentable/features/play/widgets/radar_strip.dart';
import 'package:kitchentable/features/play/widgets/seat_band.dart';
import 'package:kitchentable/table/model/seat_owner.dart';
```

Append these cases inside `main()`:

```dart
  testWidgets('a narrow window stacks the bands', (tester) async {
    await _seatedPod(tester, ['you', 'Carla', 'Diego']);

    expect(find.byType(StackedSeats), findsOneWidget);
    expect(find.byType(FreeCanvas), findsNothing);
    expect(find.byType(SeatBand), findsNWidgets(2));
  });

  testWidgets('a wide window opens the canvas', (tester) async {
    await _seatedPod(tester, ['you', 'Carla'],
        window: const Size(1280, 800));

    expect(find.byType(FreeCanvas), findsOneWidget);
    expect(find.byType(StackedSeats), findsNothing);
  });

  testWidgets('every life total is on screen whichever view it is',
      (tester) async {
    await _seatedPod(tester, ['you', 'Carla', 'Diego']);

    expect(find.byType(RadarStrip), findsOneWidget);
  });

  testWidgets('your hand is yours and theirs is a number', (tester) async {
    final container = await _seatedPod(tester, ['you', 'Carla']);
    final theirs = container.read(playProvider)!.zone('hand-s2')!;

    for (final card in theirs.cards) {
      expect(find.byKey(Key('hand-card-${card.id}')), findsNothing,
          reason: 'a card from somebody else s hand reached the widget tree');
    }
    expect(find.text('hand 7'), findsOneWidget);
  });

  testWidgets('a spectator is shown no hand at all', (tester) async {
    final container = await _seatedPod(tester, ['you', 'Carla']);
    container.read(viewerSeatProvider.notifier).sit(null);
    await tester.pump();

    // Plan 3 arrives here: the table is open and this device holds no chair.
    // The seat the screen falls back to drawing is still somebody's, and its
    // hand is not this device's to see. Every other case in this file has a
    // local seat, which makes this the only one where the `mine` guard on
    // HandSheet is load bearing at all.
    final table = container.read(playProvider)!;
    for (final seat in table.seats) {
      for (final card in table.zone('hand-${seat.id}')!.cards) {
        expect(find.byKey(Key('hand-card-${card.id}')), findsNothing,
            reason: 'a spectator was handed ${seat.id} s cards');
      }
    }
  });

  testWidgets('looking out of another local seat swaps whose hand it is',
      (tester) async {
    final container = await _seatedPod(tester, ['you', 'Carla']);

    await tester.tap(find.byKey(const Key('band-s2')));
    await tester.pump();

    expect(container.read(viewerSeatProvider), 's2');
    // The seat you left is now the one drawn as a band.
    expect(find.byKey(const Key('band-s1')), findsOneWidget);
    expect(find.byKey(const Key('band-s2')), findsNothing);
  });

  testWidgets('the hand still sits below the board in a pod', (tester) async {
    await _seatedPod(tester, ['you', 'Carla', 'Diego']);

    final board = tester.getRect(find.byKey(const Key('your-board')));
    final hand = tester.getRect(find.byType(HandSheet));

    expect(hand.top, greaterThanOrEqualTo(board.bottom - 1),
        reason: 'the hand must start at or below where your board ends');
  });
```

- [ ] **Step 2: Run them and watch them fail**

Run: `flutter test test/features/play_screen_test.dart`
Expected: FAIL. The compile errors come first, and then the new cases fail on
`StackedSeats` not being in the tree.

- [ ] **Step 3: Wire the screen**

In `lib/features/play/play_screen.dart`, add these imports:

```dart
import '../../table/view/seat_view.dart';
import 'renderers/free_canvas.dart';
import 'renderers/renderer_choice.dart';
import 'renderers/stacked_seats.dart';
import 'widgets/radar_strip.dart';
```

Replace everything in `build` from `final seat = table.seats.first;` to the end
of the method with:

```dart
    final viewerId = ref.watch(viewerSeatProvider) ?? '';
    final views = [
      for (final s in table.seats) SeatView.of(s, viewer: viewerId),
    ];
    // A spectator has no seat. It draws the table and offers no controls, and
    // plan 3 is where somebody arrives that way for real.
    final seat = table.seat(viewerId) ?? table.seats.first;
    final mine = seat.id == viewerId;

    final hand = table.zone('hand-${seat.id}')!;
    final battlefield = table.zone('battlefield-${seat.id}')!;
    final library = table.zone('library-${seat.id}')!;
    final graveyard = table.zone('graveyard-${seat.id}')!;

    final renderer = rendererFor(
      width: media.size.width,
      chosen: ref.watch(rendererChoiceProvider),
    );

    final yours = Column(
      key: const Key('your-seat'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: KeyedSubtree(
            key: const Key('your-board'),
            child: _Battlefield(
              metrics: m,
              cards: battlefield.cards,
              printings: _printings,
              onTap: (c) => play.run(RotateCard(c.id)),
              onInspect: _inspect,
            ),
          ),
        ),
        SizedBox(height: m.scaled(10)),
        _Piles(
          metrics: m,
          librarySize: library.size,
          graveyardSize: graveyard.size,
          onDraw: () => play.run(DrawCards(
            fromZoneId: library.id,
            toZoneId: hand.id,
            count: 1,
          )),
        ),
        HandSheet(
          metrics: m,
          cards: mine ? hand.cards : const [],
          printings: _printings,
          onPlay: (c) => play.run(
            MoveCard(cardId: c.id, toZoneId: battlefield.id),
          ),
          onInspect: _inspect,
        ),
      ],
    );

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(m.safeInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopBar(
                metrics: m,
                seatName: seat.name,
                life: seat.life,
                canUndo: play.canUndo,
                renderer: renderer,
                onSwitchRenderer: () => ref
                    .read(rendererChoiceProvider.notifier)
                    .choose(renderer == TableRenderer.stackedSeats
                        ? TableRenderer.freeCanvas
                        : TableRenderer.stackedSeats),
                onLife: (by) => play.run(ChangeLife(seatId: seat.id, by: by)),
                onUndo: play.undo,
                onLeave: () {
                  play.leave();
                  Navigator.of(context).maybePop();
                },
              ),
              if (views.length > 1) ...[
                SizedBox(height: m.scaled(10)),
                RadarStrip(
                  metrics: m,
                  seats: [
                    for (final v in views)
                      (seatId: v.seatId, name: v.name, life: v.life),
                  ],
                  focusedSeatId: viewerId,
                  onJump: _look,
                ),
              ],
              SizedBox(height: m.scaled(12)),
              Expanded(
                child: switch (renderer) {
                  TableRenderer.stackedSeats => StackedSeats(
                      metrics: m,
                      seats: views,
                      viewerSeatId: viewerId,
                      printings: _printings,
                      turnSeatId: table.turnSeatId,
                      onFocusSeat: _look,
                      yours: yours,
                    ),
                  TableRenderer.freeCanvas => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: KeyedSubtree(
                            key: const Key('your-board'),
                            child: FreeCanvas(
                              metrics: m,
                              seats: views,
                              viewerSeatId: viewerId,
                              printings: _printings,
                              turnSeatId: table.turnSeatId,
                              onTapCard: (c) => play.run(RotateCard(c.id)),
                              onInspectCard: _inspect,
                            ),
                          ),
                        ),
                        // The hand stays below the surface in both renderers.
                        // A hand floating over the canvas is the one thing the
                        // spec rules out by geometry.
                        HandSheet(
                          metrics: m,
                          cards: mine ? hand.cards : const [],
                          printings: _printings,
                          onPlay: (c) => play.run(
                            MoveCard(cardId: c.id, toZoneId: battlefield.id),
                          ),
                          onInspect: _inspect,
                        ),
                      ],
                    ),
                },
              ),
              HintBar(
                metrics: m,
                hints: const [
                  Hint(button: 'A', label: 'tap to turn'),
                  Hint(button: 'B', label: 'back'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Moves the viewer, and says out loud when it will not move.
  ///
  /// A seat somebody else holds is watched and not played, and a tap that does
  /// nothing silently is the bug this project has already shipped once, on the
  /// Play row that refused without a word.
  void _look(String seatId) {
    if (ref.read(viewerSeatProvider.notifier).look(seatId)) return;
    Toast.show(
      context,
      'That seat is not yours to look out of',
      icon: Icons.visibility_off_rounded,
    );
  }
```

`Key('your-board')` names the surface above the hand in both branches, never
the hand itself. Only one branch is ever in the tree, so the key is unique.
Note that the geometry case runs at 390x844, which picks the stacked renderer,
so it does not exercise this branch: nothing here would have caught the key on
the wrong widget, which is why the code is written out rather than left to a
correction.

In `_TopBar`, add the two fields and the button. New fields:

```dart
  final TableRenderer renderer;
  final VoidCallback onSwitchRenderer;
```

and in its `Row`, directly before the undo pill:

```dart
        _Pill(
          metrics: m,
          key: const Key('switch-renderer'),
          icon: renderer == TableRenderer.stackedSeats
              ? Icons.grid_view_rounded
              : Icons.view_agenda_rounded,
          onTap: onSwitchRenderer,
        ),
        SizedBox(width: m.scaled(12)),
```

`_TopBar` needs `import 'renderers/renderer_choice.dart';`, which the file
already has from the list above.

In `HandSheet`, give each card a key so a hand card can be looked for by id.
The `itemBuilder` in `lib/features/play/widgets/hand_sheet.dart` indexes
`cards[i]` and has no `card` variable, so the key reads:

```dart
                  key: Key('hand-card-${cards[i].id}'),
```

- [ ] **Step 4: Run the whole suite**

Run: `flutter test`
Expected: PASS. Watch `play_entry_test.dart` and `play_controller_test.dart`
in particular: they go through `start`, which now goes through `startPod`.

- [ ] **Step 5: Run analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Probe that the hidden hand test can fail**

Change `cards: mine ? hand.cards : const []` to `cards: hand.cards` in both
branches and run `flutter test test/features/play_screen_test.dart`. The
spectator case must fail, and it must be the only one.

**Not the swap case, and this is worth understanding before you run it.**
`mine` is `seat.id == viewerId`, and `seat` is already
`table.seat(viewerId) ?? table.seats.first`, so after looking out of s2 the
viewer IS s2 and the hand drawn is s2's own either way. `mine` is false in
exactly one state: a viewer matching no seat, which is the spectator. Every
other case in the file seats somebody, which makes the two sides of the
ternary the same expression there.

What keeps another player's hand out of the tree in the seated case is not
`mine` at all, it is `SeatView`: `SeatBand` reads a hand whose cards are
already empty and draws only the count. Two independent guards for two
different states, and each needs its own case.

- [ ] **Step 7: Commit**

```bash
git add lib/features/play/play_screen.dart lib/features/play/widgets/hand_sheet.dart \
        test/features/play_screen_test.dart
git commit -m "Draw the whole pod, and let you sit somewhere else"
```

---

## Task 12: Walking a board with a D-pad

The half of the D-pad requirement the spec flagged as unsolved. A battlefield
is a two dimensional pile and a D-pad has four directions, so left and right
walk the cards and a separate button changes pile. Up and down meaning both at
once was the first idea, and it makes every zone change feel like an accident.

**Files:**
- Create: `lib/features/play/board_cursor.dart`
- Test: `test/features/board_cursor_test.dart`
- Create: `lib/features/play/widgets/cursor_board.dart`
- Test: `test/features/cursor_board_test.dart`

- [ ] **Step 1: Write the failing test for the cursor**

Create `test/features/board_cursor_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/board_cursor.dart';

const _board = [
  (id: 'battlefield-s1', size: 3),
  (id: 'graveyard-s1', size: 0),
  (id: 'hand-s1', size: 2),
];

void main() {
  test('it starts on the first pile with something in it', () {
    final cursor = BoardCursor.start(_board)!;

    expect(cursor.zoneId, 'battlefield-s1');
    expect(cursor.index, 0);
  });

  test('it starts nowhere when there is nothing anywhere', () {
    expect(BoardCursor.start(const [(id: 'battlefield-s1', size: 0)]), isNull);
    expect(BoardCursor.start(const []), isNull);
  });

  test('stepping walks along the pile', () {
    final cursor = BoardCursor.start(_board)!.step(1, zones: _board);

    expect(cursor.index, 1);
    expect(cursor.zoneId, 'battlefield-s1');
  });

  test('stepping past the end stays at the end', () {
    var cursor = BoardCursor.start(_board)!;
    for (var i = 0; i < 9; i++) {
      cursor = cursor.step(1, zones: _board);
    }

    // Clamped and not wrapped. A player pressing right twice on a board of one
    // card should see nothing happen rather than see the ring teleport, and a
    // wrap on a pile of one is indistinguishable from a dead button.
    expect(cursor.index, 2);
  });

  test('stepping back past the front stays at the front', () {
    final cursor = BoardCursor.start(_board)!.step(-1, zones: _board);

    expect(cursor.index, 0);
  });

  test('changing pile skips the empty ones', () {
    final cursor = BoardCursor.start(_board)!.changeZone(1, zones: _board);

    expect(cursor.zoneId, 'hand-s1');
    expect(cursor.index, 0);
  });

  test('changing pile wraps round the table', () {
    final cursor = BoardCursor.start(_board)!
        .changeZone(1, zones: _board)
        .changeZone(1, zones: _board);

    expect(cursor.zoneId, 'battlefield-s1');
  });

  test('changing pile backwards works too', () {
    final cursor = BoardCursor.start(_board)!.changeZone(-1, zones: _board);

    expect(cursor.zoneId, 'hand-s1');
  });

  test('it stays put when every other pile is empty', () {
    const only = [
      (id: 'battlefield-s1', size: 2),
      (id: 'graveyard-s1', size: 0),
    ];
    final cursor = BoardCursor.start(only)!.step(1, zones: only);

    expect(cursor.changeZone(1, zones: only).zoneId, 'battlefield-s1');
    expect(cursor.changeZone(1, zones: only).index, 1,
        reason: 'a pile change that changes nothing must not move the ring');
  });

  test('a pile that shrank under the cursor pulls it back', () {
    const before = [(id: 'battlefield-s1', size: 5)];
    const after = [(id: 'battlefield-s1', size: 2)];
    var cursor = BoardCursor.start(before)!;
    for (var i = 0; i < 4; i++) {
      cursor = cursor.step(1, zones: before);
    }

    // Playing the card the ring was on is the common case, and the index it
    // was holding no longer exists.
    expect(cursor.step(0, zones: after).index, 1);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/board_cursor_test.dart`
Expected: FAIL, `Error when reading 'lib/features/play/board_cursor.dart'`.

- [ ] **Step 3: Write the cursor**

Create `lib/features/play/board_cursor.dart`:

```dart
import 'package:flutter/foundation.dart';

/// A pile and how many are in it, which is all the cursor needs to know.
typedef CursorZone = ({String id, int size});

/// Where the D-pad is pointing.
///
/// Left and right walk the cards, a separate button changes pile. This is the
/// half of the D-pad requirement the spec flagged as a real interaction
/// problem: a board is two dimensional and a D-pad is four directions, and
/// making up and down mean both a row change and a pile change turns every
/// zone change into an accident.
@immutable
class BoardCursor {
  const BoardCursor({required this.zoneId, required this.index});

  final String zoneId;
  final int index;

  /// Null when there is nothing to point at anywhere, which is a fresh table
  /// with an empty battlefield and a screen that should show no ring at all.
  static BoardCursor? start(List<CursorZone> zones) {
    final zone = zones.where((z) => z.size > 0).firstOrNull;
    if (zone == null) return null;
    return BoardCursor(zoneId: zone.id, index: 0);
  }

  /// Walks along the pile, clamped at both ends. Pass 0 to re-clamp after the
  /// pile has changed under it, which happens every time a card is played.
  BoardCursor step(int by, {required List<CursorZone> zones}) {
    final size = _sizeOf(zoneId, zones);
    if (size == 0) return this;
    final next = (index + by).clamp(0, size - 1);
    return BoardCursor(zoneId: zoneId, index: next);
  }

  /// Moves to the next pile with something in it, wrapping. Empty piles are
  /// skipped rather than landed on: a ring around nothing is a dead end the
  /// player has to press through.
  BoardCursor changeZone(int by, {required List<CursorZone> zones}) {
    if (zones.isEmpty) return this;
    final at = zones.indexWhere((z) => z.id == zoneId);
    if (at < 0) return this;

    for (var hop = 1; hop <= zones.length; hop++) {
      final zone = zones[(at + by * hop) % zones.length];
      if (zone.size == 0 || zone.id == zoneId) continue;
      return BoardCursor(zoneId: zone.id, index: 0);
    }
    return this;
  }

  int _sizeOf(String id, List<CursorZone> zones) =>
      zones.where((z) => z.id == id).map((z) => z.size).firstOrNull ?? 0;

  @override
  bool operator ==(Object other) =>
      other is BoardCursor && other.zoneId == zoneId && other.index == index;

  @override
  int get hashCode => Object.hash(zoneId, index);
}
```

The `%` on a negative left operand in Dart returns a non negative result, which
is why `changeZone(-1)` needs no special case. That is not true in every
language and it is the reason this is a one liner here.

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/features/board_cursor_test.dart`
Expected: PASS, 10 tests.

- [ ] **Step 5: Write the failing test for the board**

Create `test/features/cursor_board_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/widgets/cursor_board.dart';
import 'package:kitchentable/table/model/card_instance.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

List<CardInstance> _cards(int n) => [
      for (var i = 0; i < n; i++)
        CardInstance(id: 'b$i', oracleId: 'card$i'),
    ];

Widget _host({
  int board = 3,
  int graveyard = 0,
  void Function(CardInstance)? onActivate,
}) =>
    MaterialApp(
      home: Scaffold(
        body: CursorBoard(
          metrics: Metrics.of(DeviceClass.tv),
          zones: [
            (id: 'battlefield-s1', label: 'Battlefield', cards: _cards(board)),
            (
              id: 'graveyard-s1',
              label: 'Graveyard',
              cards: [
                for (var i = 0; i < graveyard; i++)
                  CardInstance(id: 'g$i', oracleId: 'card$i'),
              ],
            ),
          ],
          printings: const {},
          onActivate: onActivate ?? (_) {},
          onInspect: (_) {},
        ),
      ),
    );

void main() {
  testWidgets('the ring starts on the first card', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    expect(find.byKey(const Key('ring-b0')), findsOneWidget);
    expect(find.byKey(const Key('ring-b1')), findsNothing);
  });

  testWidgets('right walks the ring along', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(find.byKey(const Key('ring-b1')), findsOneWidget);
    expect(find.byKey(const Key('ring-b0')), findsNothing);
  });

  testWidgets('the shoulder button changes pile', (tester) async {
    await tester.pumpWidget(_host(graveyard: 2));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(find.byKey(const Key('ring-g0')), findsOneWidget);
  });

  testWidgets('select acts on the card under the ring', (tester) async {
    CardInstance? acted;
    await tester.pumpWidget(_host(onActivate: (c) => acted = c));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(acted?.id, 'b1');
  });

  testWidgets('an empty board draws no ring and does not crash',
      (tester) async {
    await tester.pumpWidget(_host(board: 0));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(find.textContaining('Nothing'), findsOneWidget);
  });
}
```

- [ ] **Step 6: Run it and watch it fail**

Run: `flutter test test/features/cursor_board_test.dart`
Expected: FAIL, `Error when reading
'lib/features/play/widgets/cursor_board.dart'`.

- [ ] **Step 7: Write the board**

Create `lib/features/play/widgets/cursor_board.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../sources/model/catalog_card.dart';
import '../../../table/model/card_instance.dart';
import '../../../ui/tokens/metrics.dart';
import '../../../ui/tokens/palette.dart';
import '../board_cursor.dart';
import 'table_card.dart';

/// A pile as this widget draws it.
typedef BoardZone = ({String id, String label, List<CardInstance> cards});

/// Your own piles, walkable with a D-pad.
///
/// The keys are handled here and not through `Shortcuts` and `Actions`,
/// because `WidgetsApp.defaultActions` has no handler for `ActivateIntent` at
/// all: the intent is mapped and lands nowhere. That was already found once in
/// this project, on the menu row that would not answer a controller.
class CursorBoard extends StatefulWidget {
  const CursorBoard({
    super.key,
    required this.metrics,
    required this.zones,
    required this.printings,
    required this.onActivate,
    required this.onInspect,
  });

  final Metrics metrics;
  final List<BoardZone> zones;
  final Map<String, CatalogCard> printings;

  /// A press of select, on whatever the ring is around.
  final void Function(CardInstance) onActivate;
  final void Function(CardInstance) onInspect;

  @override
  State<CursorBoard> createState() => _CursorBoardState();
}

class _CursorBoardState extends State<CursorBoard> {
  BoardCursor? _cursor;

  List<CursorZone> get _sizes =>
      [for (final z in widget.zones) (id: z.id, size: z.cards.length)];

  @override
  void initState() {
    super.initState();
    _cursor = BoardCursor.start(_sizes);
  }

  @override
  void didUpdateWidget(CursorBoard old) {
    super.didUpdateWidget(old);
    // A card was played out of the pile the ring was on, so the index it held
    // may no longer exist. Re-clamping is what step(0) is for.
    final cursor = _cursor;
    _cursor = cursor == null
        ? BoardCursor.start(_sizes)
        : cursor.step(0, zones: _sizes);
  }

  CardInstance? get _under {
    final cursor = _cursor;
    if (cursor == null) return null;
    final zone = widget.zones.where((z) => z.id == cursor.zoneId).firstOrNull;
    if (zone == null || cursor.index >= zone.cards.length) return null;
    return zone.cards[cursor.index];
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final cursor = _cursor;
    if (cursor == null) return KeyEventResult.ignored;

    final key = event.logicalKey;
    BoardCursor? next;

    if (key == LogicalKeyboardKey.arrowRight) {
      next = cursor.step(1, zones: _sizes);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      next = cursor.step(-1, zones: _sizes);
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.gameButtonRight1) {
      next = cursor.changeZone(1, zones: _sizes);
    } else if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.gameButtonLeft1) {
      next = cursor.changeZone(-1, zones: _sizes);
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.gameButtonA) {
      final card = _under;
      if (card != null) widget.onActivate(card);
      return KeyEventResult.handled;
    } else {
      return KeyEventResult.ignored;
    }

    setState(() => _cursor = next);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.metrics;
    final cursor = _cursor;

    if (cursor == null) {
      return Center(
        child: Text(
          'Nothing on the battlefield',
          style: TextStyle(fontSize: m.scaled(12), color: Palette.inkFaint),
        ),
      );
    }

    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final zone in widget.zones)
              if (zone.cards.isNotEmpty) _pile(zone, cursor),
          ],
        ),
      ),
    );
  }

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
          Wrap(
            spacing: m.scaled(8),
            runSpacing: m.scaled(10),
            children: [
              for (var i = 0; i < zone.cards.length; i++)
                _card(zone, i, cursor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _card(BoardZone zone, int index, BoardCursor cursor) {
    final m = widget.metrics;
    final card = zone.cards[index];
    final ringed = zone.id == cursor.zoneId && index == cursor.index;

    return Container(
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
        width: m.scaled(70),
        onTap: () => widget.onActivate(card),
        onLongPress: () => widget.onInspect(card),
      ),
    );
  }
}
```

- [ ] **Step 8: Run it and watch it pass**

Run: `flutter test test/features/cursor_board_test.dart`
Expected: PASS, 5 tests.

If the key cases report ignored, the `Focus` did not take focus: add
`await tester.pumpAndSettle();` after the first `pump`, and only if that fails
give the `Focus` an explicit `FocusNode` the test can request. Do not reach for
`Shortcuts` and `Actions`, for the reason in the class comment.

- [ ] **Step 9: Use it on the screen**

In `lib/features/play/play_screen.dart`, replace the `_Battlefield` inside
`yours` with:

```dart
            child: CursorBoard(
              key: const Key('your-board'),
              metrics: m,
              zones: [
                (
                  id: battlefield.id,
                  label: battlefield.label,
                  cards: battlefield.cards
                ),
                (
                  id: graveyard.id,
                  label: graveyard.label,
                  cards: graveyard.cards
                ),
              ],
              printings: _printings,
              onActivate: (c) => play.run(RotateCard(c.id)),
              onInspect: _inspect,
            ),
```

and drop the `KeyedSubtree` that was carrying the key. Delete the now unused
`_Battlefield` class from the bottom of the file, and add
`import 'widgets/cursor_board.dart';`.

- [ ] **Step 10: Run the whole suite and analyze**

Run: `flutter test && flutter analyze`
Expected: PASS and `No issues found!`. `play_screen_test.dart` has a case that
taps a battlefield card to turn it, which now goes through `CursorBoard`'s own
`onTap`. It must still pass: if it does not, the tap is landing on the ring
padding, and the fix is `behavior: HitTestBehavior.opaque` in `TableCard`
rather than a looser assertion.

- [ ] **Step 11: Probe that the ring moves for a reason**

Change `step(1, ...)` to `step(0, ...)` on the right arrow and run
`flutter test test/features/cursor_board_test.dart`. Two cases must fail. Edit
it back by hand and rerun.

- [ ] **Step 12: Commit**

```bash
git add lib/features/play/board_cursor.dart lib/features/play/widgets/cursor_board.dart \
        lib/features/play/play_screen.dart test/features/board_cursor_test.dart \
        test/features/cursor_board_test.dart
git commit -m "Walk a board with a D-pad, and change pile on a shoulder"
```

---
## What this plan deliberately leaves out

- **The network, entirely.** `SeatOwner.peer` exists and nothing constructs it.
- **Free card placement by dragging.** The field is honoured when set and
  nothing sets it until the canvas can show what it means.
- **Encrypted hands and libraries.** `SeatView` is the seam they will arrive
  through: it already decides what a viewer may see, and plan 3 changes where
  the answer comes from rather than who asks.
- **Commander damage, the stack, phases, priority.** All rules, and the
  referee's chair is still empty on purpose.
