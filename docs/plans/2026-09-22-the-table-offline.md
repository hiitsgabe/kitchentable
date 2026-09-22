# The table, offline, implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Open a deck and play with it alone. Shuffle, draw a hand, put cards on
the battlefield, tap to tap them, add counters, and undo any of it.

**Architecture:** An immutable `TableState` and a set of pure actions that each
turn one state into the next. The eleven verbs from the spec and nothing else.
Zones and starting totals are declared by a game pack, so the table itself never
learns what Magic is.

**Tech Stack:** Flutter 3.47.5, Dart 3.13.4, flutter_riverpod 3.4.3.

---

## This is the first of three plans

Play is three subsystems and they are written apart.

```
1  this plan          the table offline: state, the eleven verbs, undo,
                      shuffle, and one seat on screen
2  the full table     several seats, the two renderers, the D-pad on a board
3  the network        WebRTC in a star, host authority, pairing by code
```

This one is worth having on its own. A single seat with a shuffled library and
a hand is goldfishing, which is what people actually do alone with a new deck,
and both later plans are built entirely on top of it.

## What the spec already settled

Do not relitigate these while implementing. They were decided with the repo
owner and they are in `docs/specs/2026-09-21-kitchentable-design.md`.

**Eleven verbs, no rules.** `move, rotate, flip, counter, attach, shuffle,
draw, token, life, die, undo`. The table does not know what a card does. A
referee can be plugged in later to validate, and the slot for it is built here
even though the only referee is the one that permits everything.

**Positions are optional and normalized.** A card on the battlefield may carry
an `x,y` from 0 to 1 against its own seat's mat, or nothing at all, in which
case the layout places it and groups by type. Normalized rather than pixels is
what lets the two renderers in plan 2 show the same arrangement.

**The shuffle is auditable.** Seeded, deterministic, with the seat committing
to a hash of the seed before shuffling and revealing it after. Nobody can check
it in this plan, because there is nobody else at the table. It is built now
because it cannot be retrofitted once plan 3 exists.

## File structure

```
lib/
  table/
    model/
      card_instance.dart    a card on a table, with its state
      zone.dart             a pile, with an owner and a visibility
      seat.dart             a player: zones, life, name
      table_state.dart      seats, turn, dice, and the history for undo
    actions/
      table_action.dart     the eleven verbs as a sealed type
      apply.dart            the reducer: one state in, one state out
    shuffle.dart            seeded shuffle, and the commitment
    referee/
      referee.dart          the interface, and the one that permits everything
    setup.dart              a Deck becomes a TableState
  games/
    magic_pack.dart         which zones Magic has, and what they are called
  features/play/
    play_controller.dart
    play_screen.dart
    widgets/
      battlefield.dart
      hand_sheet.dart
      zone_button.dart
test/table/...
```

---

## Task 1: A card on a table

**Files:**
- Create: `lib/table/model/card_instance.dart`
- Test: `test/table/card_instance_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/table/card_instance_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/table/model/card_instance.dart';

void main() {
  test('a card starts upright, face up and uncounted', () {
    const card = CardInstance(id: 'i1', oracleId: 'sol ring');

    expect(card.rotation, 0);
    expect(card.faceDown, isFalse);
    expect(card.counters, isEmpty);
    expect(card.attachedTo, isNull);
    expect(card.position, isNull);
  });

  test('rotating goes a quarter turn and wraps at a full one', () {
    const card = CardInstance(id: 'i1', oracleId: 'x');

    expect(card.rotated().rotation, 90);
    expect(card.rotated().rotated().rotation, 180);
    expect(card.rotated().rotated().rotated().rotated().rotation, 0);
  });

  test('two cards of the same printing are still two cards', () {
    const a = CardInstance(id: 'i1', oracleId: 'mountain');
    const b = CardInstance(id: 'i2', oracleId: 'mountain');

    expect(a == b, isFalse,
        reason: 'thirty seven Mountains are thirty seven things on a table');
  });

  test('counters add up and clear away', () {
    const card = CardInstance(id: 'i1', oracleId: 'x');

    final loaded = card.withCounter('+1/+1', 2).withCounter('+1/+1', 1);
    expect(loaded.counters['+1/+1'], 3);

    final cleared = loaded.withCounter('+1/+1', -3);
    expect(cleared.counters.containsKey('+1/+1'), isFalse,
        reason: 'a counter at zero is not a counter');
  });

  test('a counter can go negative, because some of them do', () {
    const card = CardInstance(id: 'i1', oracleId: 'x');
    final drained = card.withCounter('-1/-1', 2);

    expect(drained.counters['-1/-1'], 2);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/table/card_instance_test.dart`
Expected: FAIL, `Target of URI doesn't exist`.

- [ ] **Step 3: Write the implementation**

Create `lib/table/model/card_instance.dart`:

```dart
import 'package:flutter/foundation.dart';

/// One card, on a table, right now.
///
/// Distinct from a CatalogCard, which is the printing. Thirty seven Mountains
/// share one catalog entry and are thirty seven of these, because each is in a
/// different place with a different amount of state on it.
@immutable
class CardInstance {
  const CardInstance({
    required this.id,
    required this.oracleId,
    this.rotation = 0,
    this.faceDown = false,
    this.counters = const {},
    this.attachedTo,
    this.position,
  });

  /// Unique on this table, not across tables. Generated when the card is dealt.
  final String id;

  /// Which printing it is. Points into the catalog.
  final String oracleId;

  /// Quarter turns clockwise. Ninety is tapped in Magic, and the table does not
  /// know that word.
  final int rotation;

  final bool faceDown;

  /// Named rather than typed, because the names belong to the game and not to
  /// the table: `+1/+1`, `loyalty`, `damage`, `energy`.
  final Map<String, int> counters;

  /// The id of the card this one is attached to. One verb for aura, equipment,
  /// energy and evolution.
  final String? attachedTo;

  /// Where on the owner's mat it sits, from 0 to 1 on each axis. Null means the
  /// layout decides, which is the default and what most players will ever see.
  final ({double x, double y})? position;

  CardInstance rotated() => copyWith(rotation: (rotation + 90) % 360);

  CardInstance flipped() => copyWith(faceDown: !faceDown);

  CardInstance withCounter(String kind, int by) {
    final next = Map<String, int>.from(counters);
    final total = (next[kind] ?? 0) + by;
    if (total == 0) {
      next.remove(kind);
    } else {
      next[kind] = total;
    }
    return copyWith(counters: next);
  }

  CardInstance copyWith({
    int? rotation,
    bool? faceDown,
    Map<String, int>? counters,
    String? attachedTo,
    bool clearAttachment = false,
    ({double x, double y})? position,
    bool clearPosition = false,
  }) =>
      CardInstance(
        id: id,
        oracleId: oracleId,
        rotation: rotation ?? this.rotation,
        faceDown: faceDown ?? this.faceDown,
        counters: counters ?? this.counters,
        attachedTo: clearAttachment ? null : (attachedTo ?? this.attachedTo),
        position: clearPosition ? null : (position ?? this.position),
      );

  @override
  bool operator ==(Object other) =>
      other is CardInstance && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
```

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/table/card_instance_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Prove the tests bite**

Change `(rotation + 90) % 360` to `rotation + 90` and confirm
`rotating goes a quarter turn and wraps at a full one` FAILS. Then change
`if (total == 0)` to `if (false)` and confirm `counters add up and clear away`
FAILS. Restore after each by editing back, not with `git checkout`, because the
file is not committed yet and a checkout would take the implementation with it.

- [ ] **Step 6: Commit**

```bash
git add lib/table/model/card_instance.dart test/table/card_instance_test.dart
git commit -m "A card on a table, as opposed to a card in a catalog"
```

---

## Task 2: Zones

**Files:**
- Create: `lib/table/model/zone.dart`
- Test: `test/table/zone_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/table/zone_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/table/model/card_instance.dart';
import 'package:kitchentable/table/model/zone.dart';

CardInstance _card(String id) => CardInstance(id: id, oracleId: 'x');

void main() {
  test('an ordered zone keeps the order it was given', () {
    final library = Zone(
      id: 'library',
      seatId: 's1',
      label: 'Library',
      visibility: ZoneVisibility.hidden,
      ordered: true,
      cards: [_card('a'), _card('b'), _card('c')],
    );

    expect(library.cards.map((c) => c.id), ['a', 'b', 'c']);
    expect(library.top?.id, 'a', reason: 'the top of a library is the front');
  });

  test('taking from the top leaves the rest in order', () {
    final library = Zone(
      id: 'library',
      seatId: 's1',
      label: 'Library',
      visibility: ZoneVisibility.hidden,
      ordered: true,
      cards: [_card('a'), _card('b'), _card('c')],
    );

    final (taken, rest) = library.takeFromTop(2);

    expect(taken.map((c) => c.id), ['a', 'b']);
    expect(rest.cards.map((c) => c.id), ['c']);
  });

  test('taking more than there is takes what there is', () {
    final library = Zone(
      id: 'library',
      seatId: 's1',
      label: 'Library',
      visibility: ZoneVisibility.hidden,
      ordered: true,
      cards: [_card('a')],
    );

    final (taken, rest) = library.takeFromTop(7);

    expect(taken.length, 1);
    expect(rest.cards, isEmpty,
        reason: 'drawing from an empty library is a rule, not a crash');
  });

  test('an unordered zone still holds what it is given', () {
    final battlefield = Zone(
      id: 'battlefield',
      seatId: 's1',
      label: 'Battlefield',
      visibility: ZoneVisibility.public,
      ordered: false,
      cards: [_card('a')],
    );

    expect(battlefield.cards.single.id, 'a');
    expect(battlefield.top, isNull,
        reason: 'an unordered pile has no top to speak of');
  });

  test('adding puts a card where the zone says it goes', () {
    final graveyard = Zone(
      id: 'graveyard',
      seatId: 's1',
      label: 'Graveyard',
      visibility: ZoneVisibility.public,
      ordered: true,
      cards: [_card('a')],
    );

    expect(graveyard.add(_card('b')).cards.map((c) => c.id), ['b', 'a'],
        reason: 'the last card into a graveyard is the one on top');
  });

  test('a zone knows who may look at it', () {
    expect(ZoneVisibility.public.seenBy('s1', owner: 's2'), isTrue);
    expect(ZoneVisibility.owner.seenBy('s1', owner: 's2'), isFalse);
    expect(ZoneVisibility.owner.seenBy('s2', owner: 's2'), isTrue);
    expect(ZoneVisibility.hidden.seenBy('s2', owner: 's2'), isFalse,
        reason: 'not even its owner reads their own library');
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/table/zone_test.dart`
Expected: FAIL, `Target of URI doesn't exist`.

- [ ] **Step 3: Write the implementation**

Create `lib/table/model/zone.dart`:

```dart
import 'package:flutter/foundation.dart';

import 'card_instance.dart';

/// Who may look at what is in a pile.
///
/// Three states and not two, because a library is not merely private: its owner
/// cannot read it either, and a table that let them would be a table nobody
/// would trust in plan 3.
enum ZoneVisibility {
  /// Everybody sees it. A battlefield, a graveyard.
  public,

  /// Only the owner. A hand.
  owner,

  /// Nobody, including the owner. A library, a face down pile.
  hidden;

  bool seenBy(String seatId, {required String owner}) => switch (this) {
        ZoneVisibility.public => true,
        ZoneVisibility.owner => seatId == owner,
        ZoneVisibility.hidden => false,
      };
}

/// A pile of cards belonging to a seat.
@immutable
class Zone {
  const Zone({
    required this.id,
    required this.seatId,
    required this.label,
    required this.visibility,
    required this.ordered,
    this.cards = const [],
  });

  final String id;
  final String seatId;

  /// What the game calls it. The table has no opinion: `Library` and `Deck` are
  /// the same thing wearing different words.
  final String label;

  final ZoneVisibility visibility;

  /// True where the order is part of the game, as in a library or a graveyard.
  /// False for a battlefield, where the order is only how it got laid out.
  final bool ordered;

  final List<CardInstance> cards;

  /// The front of an ordered pile. Null for an unordered one, which has no top
  /// to speak of.
  CardInstance? get top =>
      ordered && cards.isNotEmpty ? cards.first : null;

  bool get isEmpty => cards.isEmpty;

  int get size => cards.length;

  /// Takes up to [n]. Fewer if there are fewer, because drawing from an empty
  /// library is a rule about losing the game and not a reason to crash.
  (List<CardInstance>, Zone) takeFromTop(int n) {
    final count = n.clamp(0, cards.length);
    final taken = cards.take(count).toList();
    return (taken, copyWith(cards: cards.skip(count).toList()));
  }

  Zone add(CardInstance card, {int? at}) {
    final next = [...cards];
    next.insert(at ?? 0, card);
    return copyWith(cards: next);
  }

  Zone remove(String cardId) =>
      copyWith(cards: cards.where((c) => c.id != cardId).toList());

  CardInstance? find(String cardId) =>
      cards.where((c) => c.id == cardId).firstOrNull;

  Zone replace(CardInstance card) => copyWith(
        cards: [
          for (final c in cards) c.id == card.id ? card : c,
        ],
      );

  Zone copyWith({List<CardInstance>? cards}) => Zone(
        id: id,
        seatId: seatId,
        label: label,
        visibility: visibility,
        ordered: ordered,
        cards: cards ?? this.cards,
      );
}
```

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/table/zone_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 5: Prove the tests bite**

Change `ZoneVisibility.hidden => false` to `=> seatId == owner` and confirm
`a zone knows who may look at it` FAILS. Then change `next.insert(at ?? 0, card)`
to `next.add(card)` and confirm `adding puts a card where the zone says it goes`
FAILS. Restore by editing back after each.

- [ ] **Step 6: Commit**

```bash
git add lib/table/model/zone.dart test/table/zone_test.dart
git commit -m "Piles, and who is allowed to look in them"
```

---

## Task 3: Seats and the table

**Files:**
- Create: `lib/table/model/seat.dart`
- Create: `lib/table/model/table_state.dart`
- Test: `test/table/table_state_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/table/table_state_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/table/model/card_instance.dart';
import 'package:kitchentable/table/model/seat.dart';
import 'package:kitchentable/table/model/table_state.dart';
import 'package:kitchentable/table/model/zone.dart';

Zone _zone(String id, {List<CardInstance> cards = const []}) => Zone(
      id: id,
      seatId: 's1',
      label: id,
      visibility: ZoneVisibility.public,
      ordered: true,
      cards: cards,
    );

Seat _seat({List<Zone> zones = const []}) => Seat(
      id: 's1',
      name: 'you',
      life: 40,
      zones: zones,
    );

void main() {
  test('a table finds a zone wherever it is', () {
    final table = TableState(seats: [
      _seat(zones: [_zone('hand'), _zone('library')]),
    ]);

    expect(table.zone('library')?.id, 'library');
    expect(table.zone('nowhere'), isNull);
  });

  test('a table finds a card wherever it is', () {
    const card = CardInstance(id: 'c1', oracleId: 'sol ring');
    final table = TableState(seats: [
      _seat(zones: [_zone('hand'), _zone('battlefield', cards: [card])]),
    ]);

    final found = table.locate('c1');
    expect(found?.zone.id, 'battlefield');
    expect(found?.card.oracleId, 'sol ring');
    expect(table.locate('nope'), isNull);
  });

  test('replacing a zone leaves the others alone', () {
    final table = TableState(seats: [
      _seat(zones: [_zone('hand'), _zone('library')]),
    ]);

    final next = table.withZone(
      _zone('hand', cards: const [CardInstance(id: 'c1', oracleId: 'x')]),
    );

    expect(next.zone('hand')!.size, 1);
    expect(next.zone('library')!.size, 0);
    expect(next.seats.single.zones.length, 2);
  });

  test('life is per seat and moves by a delta', () {
    final table = TableState(seats: [_seat()]);

    expect(table.withLife('s1', -3).seats.single.life, 37);
    expect(table.withLife('s1', 3).seats.single.life, 43);
  });

  test('life can go below zero, because it does', () {
    final table = TableState(seats: [_seat()]);
    expect(table.withLife('s1', -45).seats.single.life, -5);
  });

  test('a table knows whose turn it is, and passes it round', () {
    final table = TableState(
      seats: [
        _seat(),
        const Seat(id: 's2', name: 'them', life: 40, zones: []),
      ],
      turnSeatId: 's1',
    );

    expect(table.passTurn().turnSeatId, 's2');
    expect(table.passTurn().passTurn().turnSeatId, 's1',
        reason: 'it goes round, it does not run out');
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/table/table_state_test.dart`
Expected: FAIL, `Target of URI doesn't exist`.

- [ ] **Step 3: Write the seat**

Create `lib/table/model/seat.dart`:

```dart
import 'package:flutter/foundation.dart';

import 'zone.dart';

/// One player's side of the table.
@immutable
class Seat {
  const Seat({
    required this.id,
    required this.name,
    required this.life,
    required this.zones,
  });

  final String id;
  final String name;

  /// Life in Magic, prize cards taken in Pokemon, points in whatever comes
  /// next. The table counts it and has no opinion about what it means.
  final int life;

  final List<Zone> zones;

  Zone? zone(String zoneId) =>
      zones.where((z) => z.id == zoneId).firstOrNull;

  Seat copyWith({String? name, int? life, List<Zone>? zones}) => Seat(
        id: id,
        name: name ?? this.name,
        life: life ?? this.life,
        zones: zones ?? this.zones,
      );
}
```

- [ ] **Step 4: Write the table**

Create `lib/table/model/table_state.dart`:

```dart
import 'package:flutter/foundation.dart';

import 'card_instance.dart';
import 'seat.dart';
import 'zone.dart';

/// Where a card was found, and in which pile.
typedef CardLocation = ({CardInstance card, Zone zone});

/// Everything on the table, at one moment.
///
/// Immutable, and every verb in `actions/` turns one of these into the next.
/// That is what makes undo a list rather than a pile of inverse operations,
/// and it is what lets plan 3 broadcast a state instead of a diff.
@immutable
class TableState {
  const TableState({
    required this.seats,
    this.turnSeatId,
    this.dice = const [],
  });

  final List<Seat> seats;

  /// Null before anybody has started. The table tracks whose turn it is and
  /// enforces nothing about it.
  final String? turnSeatId;

  /// The last roll, kept so everybody sees the same number.
  final List<int> dice;

  Iterable<Zone> get allZones => seats.expand((s) => s.zones);

  Zone? zone(String zoneId) =>
      allZones.where((z) => z.id == zoneId).firstOrNull;

  Seat? seat(String seatId) =>
      seats.where((s) => s.id == seatId).firstOrNull;

  CardLocation? locate(String cardId) {
    for (final zone in allZones) {
      final card = zone.find(cardId);
      if (card != null) return (card: card, zone: zone);
    }
    return null;
  }

  TableState withZone(Zone zone) => copyWith(
        seats: [
          for (final seat in seats)
            if (seat.id != zone.seatId)
              seat
            else
              seat.copyWith(
                zones: [
                  for (final z in seat.zones) z.id == zone.id ? zone : z,
                ],
              ),
        ],
      );

  TableState withLife(String seatId, int by) => copyWith(
        seats: [
          for (final seat in seats)
            seat.id == seatId ? seat.copyWith(life: seat.life + by) : seat,
        ],
      );

  TableState passTurn() {
    if (seats.isEmpty) return this;
    final at = seats.indexWhere((s) => s.id == turnSeatId);
    final next = seats[(at + 1) % seats.length];
    return copyWith(turnSeatId: next.id);
  }

  TableState copyWith({
    List<Seat>? seats,
    String? turnSeatId,
    List<int>? dice,
  }) =>
      TableState(
        seats: seats ?? this.seats,
        turnSeatId: turnSeatId ?? this.turnSeatId,
        dice: dice ?? this.dice,
      );
}
```

- [ ] **Step 5: Run it and watch it pass**

Run: `flutter test test/table/table_state_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 6: Prove the tests bite**

Change `(at + 1) % seats.length` to `at + 1` and confirm
`a table knows whose turn it is, and passes it round` FAILS, probably by
throwing rather than by a mismatch, which is fine as evidence. Then make
`withLife` clamp at zero and confirm `life can go below zero` FAILS. Restore by
editing back after each.

- [ ] **Step 7: Commit**

```bash
git add lib/table/model test/table/table_state_test.dart
git commit -m "Seats, and one immutable moment of a table"
```

---

## Task 4: The seeded shuffle, and its commitment

**Files:**
- Create: `lib/table/shuffle.dart`
- Test: `test/table/shuffle_test.dart`

Nobody can check a shuffle in this plan, because there is nobody else at the
table. It is built now because it cannot be retrofitted: plan 3 has a host who
owns the state, and the only thing that stops a host stacking their own library
is having said what the seed was before they used it.

- [ ] **Step 1: Write the failing test**

Create `test/table/shuffle_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/table/model/card_instance.dart';
import 'package:kitchentable/table/shuffle.dart';

List<CardInstance> _deck(int n) => [
      for (var i = 0; i < n; i++)
        CardInstance(id: 'c$i', oracleId: 'card$i'),
    ];

void main() {
  test('the same seed gives the same order, every time', () {
    final a = shuffleWithSeed(_deck(60), 'abc');
    final b = shuffleWithSeed(_deck(60), 'abc');

    expect(a.map((c) => c.id), b.map((c) => c.id));
  });

  test('a different seed gives a different order', () {
    final a = shuffleWithSeed(_deck(60), 'abc');
    final b = shuffleWithSeed(_deck(60), 'abd');

    expect(a.map((c) => c.id), isNot(b.map((c) => c.id)));
  });

  test('it keeps every card and invents none', () {
    final before = _deck(60);
    final after = shuffleWithSeed(before, 'abc');

    expect(after.length, 60);
    expect(after.map((c) => c.id).toSet(), before.map((c) => c.id).toSet());
  });

  test('it actually moves things', () {
    final before = _deck(60);
    final after = shuffleWithSeed(before, 'abc');

    final samePlace = [
      for (var i = 0; i < before.length; i++)
        if (before[i].id == after[i].id) i,
    ];

    // Sixty cards left entirely alone would be a shuffle that does nothing,
    // which is exactly what a subtly broken one looks like.
    expect(samePlace.length, lessThan(10));
  });

  test('a commitment matches its own seed and nothing else', () {
    final commitment = commitToSeed('abc');

    expect(seedMatches(commitment, 'abc'), isTrue);
    expect(seedMatches(commitment, 'abd'), isFalse);
  });

  test('a commitment gives nothing away about the seed', () {
    expect(commitToSeed('abc'), isNot(contains('abc')));
    expect(commitToSeed('abc').length, 64,
        reason: 'a sha256 in hex, whatever the seed was');
  });

  test('shuffling an empty pile is not an event', () {
    expect(shuffleWithSeed(const [], 'abc'), isEmpty);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/table/shuffle_test.dart`
Expected: FAIL, `Target of URI doesn't exist`.

- [ ] **Step 3: Write the implementation**

Create `lib/table/shuffle.dart`:

```dart
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'model/card_instance.dart';

/// Turns a seed string into an int that every platform agrees on.
///
/// Not `seed.hashCode`. That was the first answer here and it is wrong: it is
/// stable across runs and it is a DIFFERENT FUNCTION on the VM than on
/// dart2js, and this app ships both. Measured on 2026 09 22:
///
///     'abc'  VM 756227931   JS 102006619
///     'abd'  VM 458030030   JS 340630478
///
/// A phone and a browser at the same table would derive different orders from
/// the identical committed seed, and the commitment would be worth nothing
/// while appearing to work.
///
/// SHA-256 has a specification rather than an implementation, so its bytes are
/// the same everywhere by construction. `Random(int)` is itself portable:
/// `Random(42)` gives the same sequence on both, which is how the fault was
/// pinned to the derivation and not to the generator.
int seedToInt(String seed) {
  final digest = sha256.convert(utf8.encode(seed)).bytes;
  var value = 0;
  // Four bytes, inside the 32 bits dart2js holds exactly. Random takes the low
  // bits anyway, so a wider fold buys nothing and costs precision on the web.
  for (var i = 0; i < 4; i++) {
    value = (value << 8) | digest[i];
  }
  return value;
}

/// A Fisher Yates driven by a seed, so the same seed always gives the same
/// order. Deterministic on purpose: it is what makes a shuffle checkable by
/// somebody who was not holding the cards.
List<CardInstance> shuffleWithSeed(List<CardInstance> cards, String seed) {
  final random = Random(seedToInt(seed));
  final out = [...cards];

  for (var i = out.length - 1; i > 0; i--) {
    final j = random.nextInt(i + 1);
    final swap = out[i];
    out[i] = out[j];
    out[j] = swap;
  }

  return out;
}

/// What a seat says before it shuffles, so that what it says afterwards can be
/// checked. A hash gives nothing away and cannot be changed later, which is
/// the whole trick.
String commitToSeed(String seed) =>
    sha256.convert(utf8.encode(seed)).toString();

bool seedMatches(String commitment, String seed) =>
    commitToSeed(seed) == commitment;

/// A seed nobody chose on purpose. Not cryptographic, and it does not need to
/// be: it is committed to before use, so guessing it later buys nothing.
String freshSeed() =>
    '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';
```

- [ ] **Step 4: Add the dependency**

`crypto` is not in pubspec yet.

Run: `flutter pub add crypto`
Expected: `crypto` appears under dependencies.

- [ ] **Step 5: Run it and watch it pass**

Run: `flutter test test/table/shuffle_test.dart`
Expected: PASS, 10 tests.

- [ ] **Step 6: Prove the tests bite, and the seed derivation finding**

Change the loop body so it never swaps (`final j = i;`) and confirm
`it actually moves things` FAILS. Restore.

This task originally shipped `Random(seed.hashCode)` and asked the implementer
to investigate it. They did, and it was wrong, so the code above already has
the fix. The finding is kept here because the shape of it is worth knowing:

`String.hashCode` IS stable across runs of the VM. The worry as first written
was wrong about that. What it is not is the same function on the VM and on
dart2js, and this app ships both, so two seats would have disagreed while every
test on either one passed.

The control that settled it was checking `Random(42)` on both platforms and
getting an identical sequence, which pinned the fault to the string to int
derivation rather than to the generator.

Three tests guard it now, and the frozen values in them were checked against
Python's hashlib rather than against the implementation, because a test that
only agrees with the code it tests passes happily while two platforms disagree.

- [ ] **Step 7: Commit**

```bash
git add lib/table/shuffle.dart test/table/shuffle_test.dart pubspec.yaml pubspec.lock
git commit -m "A shuffle somebody else can check"
```

---

## Task 5: The eleven verbs

**Files:**
- Create: `lib/table/actions/table_action.dart`
- Test: `test/table/table_action_test.dart`

- [ ] **Step 1: Write the implementation first, it is a type**

This one is a sealed type and nothing else, so there is nothing to test until
Task 6 applies it. Create `lib/table/actions/table_action.dart`:

```dart
import 'package:flutter/foundation.dart';

/// Everything that can happen at this table.
///
/// Eleven, from the spec, and the list is closed on purpose: a sealed type
/// means the reducer cannot quietly forget one, and a twelfth verb has to be
/// argued for rather than added.
@immutable
sealed class TableAction {
  const TableAction();
}

/// Moves a card from wherever it is into a pile.
class MoveCard extends TableAction {
  const MoveCard({
    required this.cardId,
    required this.toZoneId,
    this.at,
    this.faceDown,
    this.position,
  });

  final String cardId;
  final String toZoneId;

  /// Where in an ordered pile. Null means the top.
  final int? at;

  /// Null leaves it as it was. Moving to a hand does not turn a card over by
  /// itself, because the table does not know that hands are private: the zone
  /// does, and the screen reads the zone.
  final bool? faceDown;

  final ({double x, double y})? position;
}

class RotateCard extends TableAction {
  const RotateCard(this.cardId);
  final String cardId;
}

class FlipCard extends TableAction {
  const FlipCard(this.cardId);
  final String cardId;
}

class ChangeCounter extends TableAction {
  const ChangeCounter({
    required this.cardId,
    required this.kind,
    required this.by,
  });

  final String cardId;
  final String kind;
  final int by;
}

/// Attaches one card to another, or to nothing. Aura, equipment, energy and
/// evolution are all this.
class AttachCard extends TableAction {
  const AttachCard({required this.cardId, required this.toCardId});

  final String cardId;

  /// Null detaches.
  final String? toCardId;
}

class ShuffleZone extends TableAction {
  const ShuffleZone({required this.zoneId, required this.seed});

  final String zoneId;
  final String seed;
}

class DrawCards extends TableAction {
  const DrawCards({
    required this.fromZoneId,
    required this.toZoneId,
    required this.count,
  });

  final String fromZoneId;
  final String toZoneId;
  final int count;
}

class CreateToken extends TableAction {
  const CreateToken({
    required this.zoneId,
    required this.oracleId,
    required this.cardId,
  });

  final String zoneId;
  final String oracleId;

  /// Generated by the caller rather than inside the reducer, so applying the
  /// same action twice gives the same table. Plan 3 replays these.
  final String cardId;
}

class ChangeLife extends TableAction {
  const ChangeLife({required this.seatId, required this.by});

  final String seatId;
  final int by;
}

class RollDice extends TableAction {
  const RollDice(this.results);

  /// Rolled by the caller for the same reason a token's id is: the reducer has
  /// to be a function, or replaying a game gives a different game.
  final List<int> results;
}

class PassTurn extends TableAction {
  const PassTurn();
}
```

- [ ] **Step 2: Confirm it compiles**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/table/actions/table_action.dart
git commit -m "Name the eleven things that can happen"
```

---

## Task 6: Applying them

**Files:**
- Create: `lib/table/actions/apply.dart`
- Test: `test/table/apply_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/table/apply_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/table/actions/apply.dart';
import 'package:kitchentable/table/actions/table_action.dart';
import 'package:kitchentable/table/model/card_instance.dart';
import 'package:kitchentable/table/model/seat.dart';
import 'package:kitchentable/table/model/table_state.dart';
import 'package:kitchentable/table/model/zone.dart';

Zone _zone(String id, ZoneVisibility v, bool ordered, List<String> ids) => Zone(
      id: id,
      seatId: 's1',
      label: id,
      visibility: v,
      ordered: ordered,
      cards: [for (final i in ids) CardInstance(id: i, oracleId: 'card-$i')],
    );

TableState _table() => TableState(
      seats: [
        Seat(
          id: 's1',
          name: 'you',
          life: 40,
          zones: [
            _zone('library', ZoneVisibility.hidden, true, ['a', 'b', 'c']),
            _zone('hand', ZoneVisibility.owner, false, []),
            _zone('battlefield', ZoneVisibility.public, false, []),
            _zone('graveyard', ZoneVisibility.public, true, []),
          ],
        ),
      ],
      turnSeatId: 's1',
    );

void main() {
  test('moving takes a card out of one pile and puts it in another', () {
    final next = apply(_table(), const MoveCard(cardId: 'a', toZoneId: 'hand'));

    expect(next.zone('library')!.cards.map((c) => c.id), ['b', 'c']);
    expect(next.zone('hand')!.cards.single.id, 'a');
  });

  test('moving a card that is not there changes nothing', () {
    final before = _table();
    final after = apply(before, const MoveCard(cardId: 'zz', toZoneId: 'hand'));

    expect(after.zone('library')!.size, before.zone('library')!.size);
    expect(after.zone('hand')!.size, 0);
  });

  test('drawing moves several, in order, off the top', () {
    final next = apply(
      _table(),
      const DrawCards(fromZoneId: 'library', toZoneId: 'hand', count: 2),
    );

    expect(next.zone('library')!.cards.single.id, 'c');
    expect(next.zone('hand')!.size, 2);
  });

  test('drawing more than the library holds empties it and does not throw', () {
    final next = apply(
      _table(),
      const DrawCards(fromZoneId: 'library', toZoneId: 'hand', count: 99),
    );

    expect(next.zone('library')!.isEmpty, isTrue);
    expect(next.zone('hand')!.size, 3);
  });

  test('rotating a card turns only that card', () {
    final table = apply(_table(), const MoveCard(cardId: 'a', toZoneId: 'battlefield'));
    final next = apply(table, const RotateCard('a'));

    expect(next.locate('a')!.card.rotation, 90);
    expect(next.locate('b')!.card.rotation, 0);
  });

  test('counters land on the right card', () {
    final table = apply(_table(), const MoveCard(cardId: 'a', toZoneId: 'battlefield'));
    final next = apply(
      table,
      const ChangeCounter(cardId: 'a', kind: '+1/+1', by: 2),
    );

    expect(next.locate('a')!.card.counters['+1/+1'], 2);
  });

  test('attaching points one card at another, and detaching lets go', () {
    var table = apply(_table(), const MoveCard(cardId: 'a', toZoneId: 'battlefield'));
    table = apply(table, const MoveCard(cardId: 'b', toZoneId: 'battlefield'));

    final on = apply(table, const AttachCard(cardId: 'b', toCardId: 'a'));
    expect(on.locate('b')!.card.attachedTo, 'a');

    final off = apply(on, const AttachCard(cardId: 'b', toCardId: null));
    expect(off.locate('b')!.card.attachedTo, isNull);
  });

  test('shuffling keeps every card', () {
    final next = apply(
      _table(),
      const ShuffleZone(zoneId: 'library', seed: 'abc'),
    );

    expect(next.zone('library')!.cards.map((c) => c.id).toSet(),
        {'a', 'b', 'c'});
  });

  test('a token arrives on the battlefield with the id it was given', () {
    final next = apply(
      _table(),
      const CreateToken(
        zoneId: 'battlefield',
        oracleId: 'goblin',
        cardId: 't1',
      ),
    );

    expect(next.zone('battlefield')!.cards.single.id, 't1');
    expect(next.zone('battlefield')!.cards.single.oracleId, 'goblin');
  });

  test('life moves by the delta it is given', () {
    expect(
      apply(_table(), const ChangeLife(seatId: 's1', by: -3)).seat('s1')!.life,
      37,
    );
  });

  test('a die roll is remembered so everybody reads the same number', () {
    expect(apply(_table(), const RollDice([4, 6])).dice, [4, 6]);
  });

  test('every action leaves the one it was given alone', () {
    final before = _table();
    apply(before, const DrawCards(
      fromZoneId: 'library',
      toZoneId: 'hand',
      count: 3,
    ));

    // The point of an immutable state: plan 3 keeps old ones around for undo
    // and for replay, and a reducer that edited in place would corrupt both.
    expect(before.zone('library')!.size, 3);
    expect(before.zone('hand')!.size, 0);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/table/apply_test.dart`
Expected: FAIL, `Target of URI doesn't exist`.

- [ ] **Step 3: Write the implementation**

Create `lib/table/actions/apply.dart`:

```dart
import '../model/card_instance.dart';
import '../model/table_state.dart';
import '../shuffle.dart';
import 'table_action.dart';

/// One state in, one state out. No rules, no validation, no opinion about
/// whether any of it is legal: that is what the referee is for, and the only
/// referee so far permits everything.
///
/// An action naming something that is not there is a no op rather than an
/// error. At a real table you do not get an exception for reaching for a card
/// that somebody already moved, you just find it gone.
TableState apply(TableState table, TableAction action) => switch (action) {
      MoveCard() => _move(table, action),
      RotateCard() => _onCard(table, action.cardId, (c) => c.rotated()),
      FlipCard() => _onCard(table, action.cardId, (c) => c.flipped()),
      ChangeCounter() => _onCard(
          table,
          action.cardId,
          (c) => c.withCounter(action.kind, action.by),
        ),
      AttachCard() => _onCard(
          table,
          action.cardId,
          (c) => action.toCardId == null
              ? c.copyWith(clearAttachment: true)
              : c.copyWith(attachedTo: action.toCardId),
        ),
      ShuffleZone() => _shuffle(table, action),
      DrawCards() => _draw(table, action),
      CreateToken() => _token(table, action),
      ChangeLife() => table.withLife(action.seatId, action.by),
      RollDice() => table.copyWith(dice: action.results),
      PassTurn() => table.passTurn(),
    };

TableState _onCard(
  TableState table,
  String cardId,
  CardInstance Function(CardInstance) change,
) {
  final found = table.locate(cardId);
  if (found == null) return table;
  return table.withZone(found.zone.replace(change(found.card)));
}

TableState _move(TableState table, MoveCard action) {
  final found = table.locate(action.cardId);
  final destination = table.zone(action.toZoneId);
  if (found == null || destination == null) return table;

  var card = found.card;
  if (action.faceDown != null) {
    card = card.copyWith(faceDown: action.faceDown);
  }
  card = action.position == null
      ? card.copyWith(clearPosition: true)
      : card.copyWith(position: action.position);

  // Taken out first, in case it is going back into the pile it came from.
  final emptied = found.zone.remove(action.cardId);
  final withSource = table.withZone(emptied);

  final target = withSource.zone(action.toZoneId)!;
  return withSource.withZone(target.add(card, at: action.at));
}

TableState _draw(TableState table, DrawCards action) {
  final from = table.zone(action.fromZoneId);
  final to = table.zone(action.toZoneId);
  if (from == null || to == null) return table;

  final (taken, rest) = from.takeFromTop(action.count);
  if (taken.isEmpty) return table;

  var next = table.withZone(rest);
  var destination = next.zone(action.toZoneId)!;

  // Backwards, so the first card off the top ends up on top of the hand too.
  for (final card in taken.reversed) {
    destination = destination.add(card.copyWith(clearPosition: true));
  }

  return next.withZone(destination);
}

TableState _shuffle(TableState table, ShuffleZone action) {
  final zone = table.zone(action.zoneId);
  if (zone == null) return table;
  return table.withZone(
    zone.copyWith(cards: shuffleWithSeed(zone.cards, action.seed)),
  );
}

TableState _token(TableState table, CreateToken action) {
  final zone = table.zone(action.zoneId);
  if (zone == null) return table;
  return table.withZone(
    zone.add(CardInstance(id: action.cardId, oracleId: action.oracleId)),
  );
}
```

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/table/apply_test.dart`
Expected: PASS, 12 tests.

- [ ] **Step 5: Prove the tests bite**

Three mutations, each must fail exactly one test and leave the rest green.

a. In `_draw`, remove `.reversed` and report which test fails. If none does,
   say so: it would mean the draw order is untested, which matters because the
   top of a library becoming the bottom of a hand is the kind of thing nobody
   notices until a game goes wrong.
b. In `_move`, apply the removal after the insert instead of before, and
   confirm something fails when a card moves inside its own zone. If nothing
   does, that case is untested and worth adding.
c. Make `_onCard` throw instead of returning `table` when the card is missing,
   and confirm `moving a card that is not there changes nothing` still passes,
   since it uses `_move`. Then say which test covers the missing card case for
   the other verbs. If none does, add one.

Restore by editing back after each.

- [ ] **Step 6: Commit**

```bash
git add lib/table/actions test/table/apply_test.dart
git commit -m "One state in, one state out, and no opinions"
```

---

## Task 7: Undo

**Files:**
- Create: `lib/table/table_session.dart`
- Test: `test/table/table_session_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/table/table_session_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/table/actions/table_action.dart';
import 'package:kitchentable/table/model/card_instance.dart';
import 'package:kitchentable/table/model/seat.dart';
import 'package:kitchentable/table/model/table_state.dart';
import 'package:kitchentable/table/model/zone.dart';
import 'package:kitchentable/table/table_session.dart';

TableState _table() => TableState(
      seats: [
        Seat(
          id: 's1',
          name: 'you',
          life: 40,
          zones: [
            Zone(
              id: 'library',
              seatId: 's1',
              label: 'Library',
              visibility: ZoneVisibility.hidden,
              ordered: true,
              cards: [
                for (var i = 0; i < 5; i++)
                  CardInstance(id: 'c$i', oracleId: 'x'),
              ],
            ),
            const Zone(
              id: 'hand',
              seatId: 's1',
              label: 'Hand',
              visibility: ZoneVisibility.owner,
              ordered: false,
            ),
          ],
        ),
      ],
    );

void main() {
  test('a fresh session has nothing to undo', () {
    final session = TableSession(_table());
    expect(session.canUndo, isFalse);
  });

  test('undo puts the table back exactly as it was', () {
    final session = TableSession(_table());
    session.run(const DrawCards(
      fromZoneId: 'library',
      toZoneId: 'hand',
      count: 3,
    ));

    expect(session.state.zone('hand')!.size, 3);

    session.undo();

    expect(session.state.zone('hand')!.size, 0);
    expect(session.state.zone('library')!.size, 5);
  });

  test('undo goes back more than one step', () {
    final session = TableSession(_table());
    session.run(const ChangeLife(seatId: 's1', by: -1));
    session.run(const ChangeLife(seatId: 's1', by: -1));
    session.run(const ChangeLife(seatId: 's1', by: -1));

    expect(session.state.seat('s1')!.life, 37);

    session.undo();
    session.undo();

    expect(session.state.seat('s1')!.life, 39);
  });

  test('undoing past the beginning stops at the beginning', () {
    final session = TableSession(_table());
    session.run(const ChangeLife(seatId: 's1', by: -1));

    session.undo();
    session.undo();
    session.undo();

    expect(session.state.seat('s1')!.life, 40);
    expect(session.canUndo, isFalse);
  });

  test('history does not grow without bound', () {
    final session = TableSession(_table(), historyLimit: 10);

    for (var i = 0; i < 50; i++) {
      session.run(const ChangeLife(seatId: 's1', by: -1));
    }

    // A table left running all evening would otherwise keep every state it
    // ever had, and each one holds every card.
    expect(session.historyLength, 10);
  });

  test('undo only reaches as far back as the history kept', () {
    final session = TableSession(_table(), historyLimit: 3);

    for (var i = 0; i < 10; i++) {
      session.run(const ChangeLife(seatId: 's1', by: -1));
    }
    for (var i = 0; i < 10; i++) {
      session.undo();
    }

    expect(session.state.seat('s1')!.life, 33,
        reason: 'three steps back from thirty, and no further');
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/table/table_session_test.dart`
Expected: FAIL, `Target of URI doesn't exist`.

- [ ] **Step 3: Write the implementation**

Create `lib/table/table_session.dart`:

```dart
import 'actions/apply.dart';
import 'actions/table_action.dart';
import 'model/table_state.dart';

/// A table being played, and the last few states it was in.
///
/// Undo is a list of whole states rather than a stack of inverse actions. It
/// costs memory and it is right: an inverse has to be derived for every verb
/// and gets subtly wrong for the ones that lose information, like shuffling a
/// pile or clearing a counter to zero.
class TableSession {
  TableSession(this._state, {this.historyLimit = 40});

  TableState _state;
  final List<TableState> _history = [];

  /// How far back undo reaches. A table left running all evening would
  /// otherwise keep every state it ever had, and each one holds every card.
  final int historyLimit;

  TableState get state => _state;
  bool get canUndo => _history.isNotEmpty;
  int get historyLength => _history.length;

  void run(TableAction action) {
    final next = apply(_state, action);
    if (identical(next, _state)) return;

    _history.add(_state);
    if (_history.length > historyLimit) _history.removeAt(0);
    _state = next;
  }

  void undo() {
    if (_history.isEmpty) return;
    _state = _history.removeLast();
  }
}
```

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/table/table_session_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 5: Prove the tests bite**

Remove the `if (_history.length > historyLimit) _history.removeAt(0);` line and
confirm `history does not grow without bound` FAILS. Then change `removeLast`
to `removeAt(0)` and confirm `undo goes back more than one step` FAILS. Restore
by editing back after each.

Also note: `run` skips no op actions by comparing with `identical`, which works
because `apply` returns the same instance when nothing matched. Check that
`moving a card that is not there` really does return the identical object and
not an equal copy, and say what you found. If it does not, `canUndo` will be
true after an action that did nothing, and undo will appear to do nothing too.

- [ ] **Step 6: Commit**

```bash
git add lib/table/table_session.dart test/table/table_session_test.dart
git commit -m "Undo, by keeping the states rather than inverting the verbs"
```

---

## Task 8: What zones Magic has

**Files:**
- Create: `lib/games/magic_pack.dart`
- Test: `test/table/magic_pack_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/table/magic_pack_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/decks/model/deck_format.dart';
import 'package:kitchentable/games/magic_pack.dart';
import 'package:kitchentable/table/model/zone.dart';

void main() {
  test('a duel seat has five zones and no command zone', () {
    final zones = magicZonesFor('s1', DeckFormat.standard);

    expect(zones.map((z) => z.id), [
      'library-s1',
      'hand-s1',
      'battlefield-s1',
      'graveyard-s1',
      'exile-s1',
    ]);
  });

  test('a Commander seat gets the command zone as well', () {
    final zones = magicZonesFor('s1', DeckFormat.commander);

    expect(zones.map((z) => z.id), contains('command-s1'));
    expect(zones.length, 6);
  });

  test('zone ids carry the seat, because two seats have a library each', () {
    final mine = magicZonesFor('s1', DeckFormat.commander);
    final theirs = magicZonesFor('s2', DeckFormat.commander);

    expect(mine.map((z) => z.id).toSet().intersection(
          theirs.map((z) => z.id).toSet(),
        ),
        isEmpty);
  });

  test('a library is hidden from everybody, a hand from everybody else', () {
    final zones = magicZonesFor('s1', DeckFormat.commander);

    Zone find(String prefix) =>
        zones.firstWhere((z) => z.id.startsWith(prefix));

    expect(find('library').visibility, ZoneVisibility.hidden);
    expect(find('hand').visibility, ZoneVisibility.owner);
    expect(find('battlefield').visibility, ZoneVisibility.public);
    expect(find('graveyard').visibility, ZoneVisibility.public);
    expect(find('command').visibility, ZoneVisibility.public);
  });

  test('order matters in a library and a graveyard, not on a battlefield', () {
    final zones = magicZonesFor('s1', DeckFormat.commander);

    Zone find(String prefix) =>
        zones.firstWhere((z) => z.id.startsWith(prefix));

    expect(find('library').ordered, isTrue);
    expect(find('graveyard').ordered, isTrue);
    expect(find('battlefield').ordered, isFalse);
    expect(find('hand').ordered, isFalse);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/table/magic_pack_test.dart`
Expected: FAIL, `Target of URI doesn't exist`.

- [ ] **Step 3: Write the implementation**

Create `lib/games/magic_pack.dart`:

```dart
import '../decks/model/deck_format.dart';
import '../table/model/zone.dart';

/// Which piles a Magic player has in front of them.
///
/// A declaration, not code. The table does not import this and would work the
/// same with Pokemon's seven zones instead, which is the whole point of the
/// eleven verbs.
List<Zone> magicZonesFor(String seatId, DeckFormat format) => [
      _zone(seatId, 'library', 'Library', ZoneVisibility.hidden, true),
      _zone(seatId, 'hand', 'Hand', ZoneVisibility.owner, false),
      _zone(seatId, 'battlefield', 'Battlefield', ZoneVisibility.public, false),
      _zone(seatId, 'graveyard', 'Graveyard', ZoneVisibility.public, true),
      _zone(seatId, 'exile', 'Exile', ZoneVisibility.public, false),
      if (format.needsCommander)
        _zone(seatId, 'command', 'Command', ZoneVisibility.public, false),
    ];

Zone _zone(
  String seatId,
  String kind,
  String label,
  ZoneVisibility visibility,
  bool ordered,
) =>
    Zone(
      id: '$kind-$seatId',
      seatId: seatId,
      label: label,
      visibility: visibility,
      ordered: ordered,
    );
```

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/table/magic_pack_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Prove the tests bite**

Change the library's visibility to `owner` and confirm
`a library is hidden from everybody` FAILS. Then drop the `-$seatId` from the
zone id and confirm `zone ids carry the seat` FAILS. Restore by editing back.

- [ ] **Step 6: Commit**

```bash
git add lib/games/magic_pack.dart test/table/magic_pack_test.dart
git commit -m "Declare the piles a Magic player sits behind"
```

---

## Task 9: Sitting down with a deck

**Files:**
- Create: `lib/table/setup.dart`
- Test: `test/table/setup_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/table/setup_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/decks/model/deck.dart';
import 'package:kitchentable/decks/model/deck_format.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';
import 'package:kitchentable/table/setup.dart';

CatalogCard _card(String name) => CatalogCard(
      oracleId: name,
      name: name,
      typeLine: 'Instant',
      cmc: 1,
    );

Deck _deck({
  DeckFormat format = DeckFormat.commander,
  List<DeckSlot> slots = const [],
}) =>
    Deck(id: 'd1', name: 'a deck', format: format, slots: slots);

void main() {
  test('every copy of a card becomes its own card on the table', () {
    final table = sitDown(
      deck: _deck(slots: [DeckSlot(card: _card('Mountain'), quantity: 37)]),
      seatName: 'you',
      seed: 'abc',
    );

    final library = table.seats.single.zones
        .firstWhere((z) => z.id.startsWith('library'));

    expect(library.size, 30, reason: '37 dealt, 7 drawn');
    expect(
      library.cards.map((c) => c.id).toSet().length,
      30,
      reason: 'thirty seven Mountains are thirty seven things',
    );
  });

  test('a hand of seven comes off the top', () {
    final table = sitDown(
      deck: _deck(slots: [DeckSlot(card: _card('Mountain'), quantity: 60)]),
      seatName: 'you',
      seed: 'abc',
    );

    final hand =
        table.seats.single.zones.firstWhere((z) => z.id.startsWith('hand'));

    expect(hand.size, 7);
  });

  test('a commander starts in the command zone, not the library', () {
    final table = sitDown(
      deck: _deck(slots: [
        DeckSlot(card: _card('Atraxa'), quantity: 1, commander: true),
        DeckSlot(card: _card('Mountain'), quantity: 99),
      ]),
      seatName: 'you',
      seed: 'abc',
    );

    final zones = table.seats.single.zones;
    final command = zones.firstWhere((z) => z.id.startsWith('command'));
    final library = zones.firstWhere((z) => z.id.startsWith('library'));

    expect(command.size, 1);
    expect(command.cards.single.oracleId, 'Atraxa');
    expect(library.cards.any((c) => c.oracleId == 'Atraxa'), isFalse);
  });

  test('the sideboard does not come to the table', () {
    final table = sitDown(
      deck: _deck(format: DeckFormat.standard, slots: [
        DeckSlot(card: _card('Bolt'), quantity: 60),
        DeckSlot(card: _card('Pyroblast'), quantity: 15, sideboard: true),
      ]),
      seatName: 'you',
      seed: 'abc',
    );

    final all = table.seats.single.zones.expand((z) => z.cards);
    expect(all.any((c) => c.oracleId == 'Pyroblast'), isFalse);
    expect(all.length, 60);
  });

  test('life comes from the format', () {
    final commander = sitDown(
      deck: _deck(slots: [DeckSlot(card: _card('x'), quantity: 10)]),
      seatName: 'you',
      seed: 'abc',
    );
    final duel = sitDown(
      deck: _deck(
        format: DeckFormat.standard,
        slots: [DeckSlot(card: _card('x'), quantity: 10)],
      ),
      seatName: 'you',
      seed: 'abc',
    );

    expect(commander.seats.single.life, 40);
    expect(duel.seats.single.life, 20);
  });

  test('the same seed seats you with the same opening hand', () {
    List<String> handFor(String seed) {
      final table = sitDown(
        deck: _deck(slots: [
          for (var i = 0; i < 60; i++)
            DeckSlot(card: _card('card$i'), quantity: 1),
        ]),
        seatName: 'you',
        seed: seed,
      );
      return table.seats.single.zones
          .firstWhere((z) => z.id.startsWith('hand'))
          .cards
          .map((c) => c.oracleId)
          .toList();
    }

    expect(handFor('abc'), handFor('abc'));
    expect(handFor('abc'), isNot(handFor('xyz')));
  });

  test('an empty deck seats you without throwing', () {
    final table = sitDown(deck: _deck(), seatName: 'you', seed: 'abc');
    expect(table.seats.single.zones.every((z) => z.isEmpty), isTrue);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/table/setup_test.dart`
Expected: FAIL, `Target of URI doesn't exist`.

- [ ] **Step 3: Write the implementation**

Create `lib/table/setup.dart`:

```dart
import '../decks/model/deck.dart';
import '../games/magic_pack.dart';
import 'actions/apply.dart';
import 'actions/table_action.dart';
import 'model/card_instance.dart';
import 'model/seat.dart';
import 'model/table_state.dart';

/// How many a Magic player starts with. It belongs to the game rather than to
/// the table, and it lives here until there is a second game to disagree with
/// it.
const openingHandSize = 7;

/// Turns a deck into a table with one seat at it.
///
/// Every copy becomes its own card: thirty seven Mountains are thirty seven
/// things, because each one ends up somewhere different with its own state.
TableState sitDown({
  required Deck deck,
  required String seatName,
  required String seed,
  String seatId = 's1',
}) {
  final zones = magicZonesFor(seatId, deck.format);
  var counter = 0;

  CardInstance mint(String oracleId) =>
      CardInstance(id: '$seatId-${counter++}', oracleId: oracleId);

  final library = <CardInstance>[];
  final command = <CardInstance>[];

  for (final slot in deck.slots) {
    if (slot.sideboard) continue; // a sideboard is not at the table
    for (var i = 0; i < slot.quantity; i++) {
      final card = mint(slot.card.oracleId);
      (slot.commander ? command : library).add(card);
    }
  }

  final seat = Seat(
    id: seatId,
    name: seatName,
    life: deck.format.startingLife,
    zones: [
      for (final zone in zones)
        if (zone.id.startsWith('library'))
          zone.copyWith(cards: library)
        else if (zone.id.startsWith('command'))
          zone.copyWith(cards: command)
        else
          zone,
    ],
  );

  var table = TableState(seats: [seat], turnSeatId: seatId);

  table = apply(
    table,
    ShuffleZone(zoneId: 'library-$seatId', seed: seed),
  );

  return apply(
    table,
    DrawCards(
      fromZoneId: 'library-$seatId',
      toZoneId: 'hand-$seatId',
      count: openingHandSize,
    ),
  );
}
```

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/table/setup_test.dart`
Expected: PASS, 7 tests.

- [ ] **Step 5: Prove the tests bite**

Remove the `if (slot.sideboard) continue;` line and confirm
`the sideboard does not come to the table` FAILS. Then give every minted card
the same id and confirm `every copy of a card becomes its own card` FAILS.
Restore by editing back after each.

- [ ] **Step 6: Commit**

```bash
git add lib/table/setup.dart test/table/setup_test.dart
git commit -m "Sit down with a deck, shuffle, draw seven"
```

---

## Task 10: The referee slot

**Files:**
- Create: `lib/table/referee/referee.dart`
- Test: `test/table/referee_test.dart`

The only referee here permits everything, and it will still be the only one
when this plan finishes. It is built now because the cost of the slot is paid
in the screen, which has to handle a refusal from the day it is written, and
retrofitting that later is the rewrite the spec is trying to avoid.

- [ ] **Step 1: Write the failing test**

Create `test/table/referee_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/table/actions/table_action.dart';
import 'package:kitchentable/table/model/seat.dart';
import 'package:kitchentable/table/model/table_state.dart';
import 'package:kitchentable/table/referee/referee.dart';

final _table = const TableState(
  seats: [Seat(id: 's1', name: 'you', life: 40, zones: [])],
);

void main() {
  test('the permissive referee permits everything', () {
    const referee = PermissiveReferee();

    expect(
      referee.review(_table, const MoveCard(cardId: 'x', toZoneId: 'y')),
      isNull,
    );
    expect(referee.review(_table, const PassTurn()), isNull);
    expect(referee.review(_table, const RollDice([6])), isNull);
  });

  test('it knows no legal targets, and says so rather than guessing', () {
    const referee = PermissiveReferee();

    expect(referee.legalTargets(_table, 'c1'), isNull,
        reason: 'null is I do not know, an empty list would be there are none');
  });

  test('a refusal carries a reason a player can act on', () {
    const refusal = Refusal('It is not your turn');
    expect(refusal.reason, 'It is not your turn');
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/table/referee_test.dart`
Expected: FAIL, `Target of URI doesn't exist`.

- [ ] **Step 3: Write the implementation**

Create `lib/table/referee/referee.dart`:

```dart
import '../actions/table_action.dart';
import '../model/table_state.dart';

/// Why an action was refused, in words a player can act on.
class Refusal {
  const Refusal(this.reason);
  final String reason;
}

/// Whatever decides whether a thing may happen.
///
/// The only one that exists permits everything, and that is the product
/// decision, not a stub: a kitchen table game is played by people who settle
/// rules by talking. The interface is here so a real engine can be dropped in
/// without the screen changing, which is the whole argument in the spec.
abstract interface class Referee {
  /// Null to allow.
  Refusal? review(TableState table, TableAction action);

  /// Which cards this card may legally be pointed at.
  ///
  /// Null means the referee does not know, which is different from an empty
  /// list meaning there are none. The screen has to tell those apart: one is
  /// draw nothing special, the other is light nothing up.
  List<String>? legalTargets(TableState table, String cardId);
}

class PermissiveReferee implements Referee {
  const PermissiveReferee();

  @override
  Refusal? review(TableState table, TableAction action) => null;

  @override
  List<String>? legalTargets(TableState table, String cardId) => null;
}
```

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/table/referee_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/table/referee test/table/referee_test.dart
git commit -m "Leave the referee's chair empty, but built"
```

---

## Task 11: The play controller

**Files:**
- Create: `lib/features/play/play_controller.dart`
- Test: `test/features/play_controller_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/play_controller_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/decks/model/deck.dart';
import 'package:kitchentable/decks/model/deck_format.dart';
import 'package:kitchentable/features/play/play_controller.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';
import 'package:kitchentable/table/actions/table_action.dart';

CatalogCard _card(String name) => CatalogCard(
      oracleId: name,
      name: name,
      typeLine: 'Instant',
      cmc: 1,
    );

Deck _deck() => Deck(
      id: 'd1',
      name: 'a deck',
      format: DeckFormat.commander,
      slots: [DeckSlot(card: _card('Mountain'), quantity: 60)],
    );

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  PlayController controller() => container.read(playProvider.notifier);

  test('nothing is on the table until a deck is brought to it', () {
    expect(container.read(playProvider), isNull);
  });

  test('starting seats you with a hand', () {
    controller().start(_deck(), seed: 'abc');

    final table = container.read(playProvider)!;
    expect(table.zone('hand-s1')!.size, 7);
    expect(table.zone('library-s1')!.size, 53);
  });

  test('an action moves the table on', () {
    controller().start(_deck(), seed: 'abc');
    final card = container.read(playProvider)!.zone('hand-s1')!.cards.first;

    controller().run(MoveCard(cardId: card.id, toZoneId: 'battlefield-s1'));

    expect(container.read(playProvider)!.zone('battlefield-s1')!.size, 1);
    expect(container.read(playProvider)!.zone('hand-s1')!.size, 6);
  });

  test('undo puts it back', () {
    controller().start(_deck(), seed: 'abc');
    controller().run(const ChangeLife(seatId: 's1', by: -5));

    expect(container.read(playProvider)!.seat('s1')!.life, 35);

    controller().undo();

    expect(container.read(playProvider)!.seat('s1')!.life, 40);
  });

  test('a refused action does not move the table, and says why', () {
    controller().start(_deck(), seed: 'abc');
    controller().useReferee(const _GrumpyReferee());

    controller().run(const ChangeLife(seatId: 's1', by: -5));

    expect(container.read(playProvider)!.seat('s1')!.life, 40);
    expect(controller().lastRefusal?.reason, 'no');
  });

  test('leaving the table clears it', () {
    controller().start(_deck(), seed: 'abc');
    controller().leave();

    expect(container.read(playProvider), isNull);
  });
}
```

Add this at the bottom of the same file:

```dart
class _GrumpyReferee implements Referee {
  const _GrumpyReferee();

  @override
  Refusal? review(TableState table, TableAction action) => const Refusal('no');

  @override
  List<String>? legalTargets(TableState table, String cardId) => null;
}
```

and the imports it needs:

```dart
import 'package:kitchentable/table/model/table_state.dart';
import 'package:kitchentable/table/referee/referee.dart';
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/play_controller_test.dart`
Expected: FAIL, `Target of URI doesn't exist`.

- [ ] **Step 3: Write the implementation**

Create `lib/features/play/play_controller.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../decks/model/deck.dart';
import '../../table/actions/table_action.dart';
import '../../table/model/table_state.dart';
import '../../table/referee/referee.dart';
import '../../table/setup.dart';
import '../../table/shuffle.dart';
import '../../table/table_session.dart';

/// The table currently being played, or null when nobody is at one.
class PlayController extends Notifier<TableState?> {
  TableSession? _session;
  Referee _referee = const PermissiveReferee();

  /// Why the last action was turned down, for the screen to say out loud.
  /// Always null while the permissive referee is the only one there is.
  Refusal? lastRefusal;

  @override
  TableState? build() => null;

  void start(Deck deck, {String? seed}) {
    final table = sitDown(
      deck: deck,
      seatName: 'you',
      seed: seed ?? freshSeed(),
    );
    _session = TableSession(table);
    lastRefusal = null;
    state = table;
  }

  /// Swaps the referee. There is one, and the seat is built so a real engine
  /// can take it without the screen noticing.
  void useReferee(Referee referee) => _referee = referee;

  void run(TableAction action) {
    final session = _session;
    if (session == null) return;

    final refusal = _referee.review(session.state, action);
    if (refusal != null) {
      lastRefusal = refusal;
      // Deliberately not rethrowing or swallowing. The screen reads this and
      // says it, which is the behaviour a real engine will need on day one.
      return;
    }

    lastRefusal = null;
    session.run(action);
    state = session.state;
  }

  void undo() {
    final session = _session;
    if (session == null) return;
    session.undo();
    lastRefusal = null;
    state = session.state;
  }

  bool get canUndo => _session?.canUndo ?? false;

  List<String>? legalTargetsFor(String cardId) {
    final session = _session;
    if (session == null) return null;
    return _referee.legalTargets(session.state, cardId);
  }

  void leave() {
    _session = null;
    lastRefusal = null;
    state = null;
  }
}

final playProvider =
    NotifierProvider<PlayController, TableState?>(PlayController.new);
```

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/features/play_controller_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 5: Prove the tests bite**

Make `run` apply the action before asking the referee and confirm
`a refused action does not move the table` FAILS. Then make `undo` forget to
assign `state` and confirm `undo puts it back` FAILS. Restore by editing back.

- [ ] **Step 6: Commit**

```bash
git add lib/features/play test/features/play_controller_test.dart
git commit -m "Bring a deck to a table and act on it"
```

---

## Task 12: One seat on screen

**Files:**
- Create: `lib/features/play/widgets/table_card.dart`
- Create: `lib/features/play/widgets/hand_sheet.dart`
- Create: `lib/features/play/play_screen.dart`
- Test: `test/features/play_screen_test.dart`

This is the screen the whole plan was for. One seat, a battlefield, a hand that
pushes the board up rather than covering it, and buttons for the piles.

The rule from the spec, taken from Arena's mistake: **the hand never covers the
board.** On mobile Arena hides the hand at the bottom edge and opens it into a
fan across the battlefield, so you cannot look at your hand and the board at
once.

- [ ] **Step 1: Write the failing test**

Create `test/features/play_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/decks/model/deck.dart';
import 'package:kitchentable/decks/model/deck_format.dart';
import 'package:kitchentable/features/play/play_controller.dart';
import 'package:kitchentable/features/play/play_screen.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';

CatalogCard _card(String name) => CatalogCard(
      oracleId: name,
      name: name,
      typeLine: 'Instant',
      cmc: 1,
    );

Deck _deck() => Deck(
      id: 'd1',
      name: 'a deck',
      format: DeckFormat.commander,
      slots: [DeckSlot(card: _card('Mountain'), quantity: 60)],
    );

Future<ProviderContainer> _seated(WidgetTester tester) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container.read(playProvider.notifier).start(_deck(), seed: 'abc');

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: PlayScreen()),
    ),
  );
  await tester.pump();
  return container;
}

void main() {
  testWidgets('an empty table says so instead of drawing nothing',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: PlayScreen())),
    );
    await tester.pump();

    expect(find.textContaining('No table'), findsOneWidget);
  });

  testWidgets('a seated table shows life and the pile counts', (tester) async {
    await _seated(tester);

    expect(find.text('40'), findsOneWidget);
    expect(find.textContaining('53'), findsWidgets,
        reason: 'the library has 53 left after a hand of seven');
  });

  testWidgets('drawing takes one off the library and adds one to the hand',
      (tester) async {
    final container = await _seated(tester);

    await tester.tap(find.byKey(const Key('draw')));
    await tester.pump();

    expect(container.read(playProvider)!.zone('library-s1')!.size, 52);
    expect(container.read(playProvider)!.zone('hand-s1')!.size, 8);
  });

  testWidgets('undo is offered only once there is something to undo',
      (tester) async {
    final container = await _seated(tester);

    expect(container.read(playProvider.notifier).canUndo, isFalse);

    await tester.tap(find.byKey(const Key('draw')));
    await tester.pump();

    expect(container.read(playProvider.notifier).canUndo, isTrue);
  });

  testWidgets('life goes down and back up', (tester) async {
    final container = await _seated(tester);

    await tester.tap(find.byKey(const Key('life-down')));
    await tester.pump();

    expect(container.read(playProvider)!.seat('s1')!.life, 39);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/play_screen_test.dart`
Expected: FAIL, `Target of URI doesn't exist`.

- [ ] **Step 3: Write the card on the table**

Create `lib/features/play/widgets/table_card.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../sources/model/catalog_card.dart';
import '../../../table/model/card_instance.dart';
import '../../../ui/atoms/card_art.dart';
import '../../../ui/tokens/metrics.dart';
import '../../../ui/tokens/palette.dart';

/// One card where it is sitting, turned however it is turned.
class TableCard extends StatelessWidget {
  const TableCard({
    super.key,
    required this.metrics,
    required this.instance,
    required this.printing,
    required this.width,
    this.onTap,
    this.onLongPress,
  });

  final Metrics metrics;
  final CardInstance instance;

  /// Null when the catalog has never heard of it, which happens to a token and
  /// to a card from a source that was cleared.
  final CatalogCard? printing;

  final double width;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final card = printing;

    final face = instance.faceDown || card == null
        ? Container(
            width: width,
            height: width * 88 / 63,
            decoration: BoxDecoration(
              color: Palette.tile,
              borderRadius: BorderRadius.circular(width * 0.05),
              border: Border.all(color: Palette.tileEdge),
            ),
          )
        : CardArt(metrics: m, card: card, width: width);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: AnimatedRotation(
        turns: instance.rotation / 360,
        duration: const Duration(milliseconds: 160),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            face,
            if (instance.counters.isNotEmpty)
              Positioned(
                right: -width * 0.06,
                bottom: -width * 0.06,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: m.scaled(6),
                    vertical: m.scaled(2),
                  ),
                  decoration: BoxDecoration(
                    color: Palette.accent,
                    borderRadius: BorderRadius.circular(m.scaled(99)),
                  ),
                  child: Text(
                    instance.counters.values
                        .map((v) => v > 0 ? '+$v' : '$v')
                        .join(' '),
                    style: TextStyle(
                      fontSize: m.scaled(10),
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
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

- [ ] **Step 4: Write the hand**

Create `lib/features/play/widgets/hand_sheet.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../sources/model/catalog_card.dart';
import '../../../table/model/card_instance.dart';
import '../../../ui/tokens/metrics.dart';
import '../../../ui/tokens/palette.dart';
import 'table_card.dart';

/// The hand, along the bottom, scrolling sideways.
///
/// It sits below the board and never on top of it. On mobile Arena opens the
/// hand into a fan across the battlefield, so you cannot look at your hand and
/// the board at the same time, and that is the one thing this must not copy.
class HandSheet extends StatelessWidget {
  const HandSheet({
    super.key,
    required this.metrics,
    required this.cards,
    required this.printings,
    required this.onPlay,
    required this.onInspect,
  });

  final Metrics metrics;
  final List<CardInstance> cards;
  final Map<String, CatalogCard> printings;
  final void Function(CardInstance) onPlay;
  final void Function(CardInstance) onInspect;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return Container(
      padding: EdgeInsets.symmetric(vertical: m.scaled(10)),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Palette.rule)),
      ),
      child: SizedBox(
        height: m.scaled(96),
        child: cards.isEmpty
            ? Center(
                child: Text(
                  'No cards in hand',
                  style:
                      TextStyle(fontSize: m.scaled(12), color: Palette.inkFaint),
                ),
              )
            : ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: cards.length,
                separatorBuilder: (_, _) => SizedBox(width: m.scaled(6)),
                itemBuilder: (_, i) => TableCard(
                  metrics: m,
                  instance: cards[i],
                  printing: printings[cards[i].oracleId],
                  width: m.scaled(64),
                  onTap: () => onPlay(cards[i]),
                  onLongPress: () => onInspect(cards[i]),
                ),
              ),
      ),
    );
  }
}
```

- [ ] **Step 5: Write the screen**

Create `lib/features/play/play_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sources/model/catalog_card.dart';
import '../../table/actions/table_action.dart';
import '../../table/model/card_instance.dart';
import '../../table/model/table_state.dart';
import '../../ui/atoms/hint_bar.dart';
import '../../ui/organisms/card_viewer.dart';
import '../../ui/organisms/screen_frame.dart';
import '../../ui/tokens/metrics.dart';
import '../../ui/tokens/palette.dart';
import '../menu/menu_controller.dart';
import 'play_controller.dart';
import 'widgets/hand_sheet.dart';
import 'widgets/table_card.dart';

class PlayScreen extends ConsumerStatefulWidget {
  const PlayScreen({super.key});

  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends ConsumerState<PlayScreen> {
  Map<String, CatalogCard> _printings = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPrintings());
  }

  /// Every card on the table at once, looked up in one go. Looking each one up
  /// as it is drawn would be a query per card per frame.
  Future<void> _loadPrintings() async {
    final db = ref.read(catalogDbProvider);
    final table = ref.read(playProvider);
    if (db == null || table == null) return;

    final ids = table.allZones
        .expand((z) => z.cards)
        .map((c) => c.oracleId)
        .toSet()
        .toList();

    final cards = await db.cardsByOracleIds(ids);
    if (mounted) {
      setState(() => _printings = {for (final c in cards) c.oracleId: c});
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final m = Metrics.of(classifyDevice(
      size: media.size,
      hasTouch: media.navigationMode == NavigationMode.traditional,
    ));
    final table = ref.watch(playProvider);
    final play = ref.read(playProvider.notifier);

    if (table == null) {
      return ScreenFrame(
        metrics: m,
        title: 'Play',
        label: 'no table',
        onBack: () => Navigator.of(context).maybePop(),
        hints: const [Hint(button: 'B', label: 'back')],
        children: [
          Text(
            'No table open. Start one from a deck.',
            style: TextStyle(fontSize: m.scaled(13), color: Palette.inkFaint),
          ),
        ],
      );
    }

    final seat = table.seats.first;
    final hand = table.zone('hand-${seat.id}')!;
    final battlefield = table.zone('battlefield-${seat.id}')!;
    final library = table.zone('library-${seat.id}')!;
    final graveyard = table.zone('graveyard-${seat.id}')!;

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
                onLife: (by) =>
                    play.run(ChangeLife(seatId: seat.id, by: by)),
                onUndo: play.undo,
                onLeave: () {
                  play.leave();
                  Navigator.of(context).maybePop();
                },
              ),
              SizedBox(height: m.scaled(12)),
              Expanded(
                child: _Battlefield(
                  metrics: m,
                  cards: battlefield.cards,
                  printings: _printings,
                  onTap: (c) => play.run(RotateCard(c.id)),
                  onInspect: _inspect,
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
                cards: hand.cards,
                printings: _printings,
                onPlay: (c) => play.run(
                  MoveCard(cardId: c.id, toZoneId: battlefield.id),
                ),
                onInspect: _inspect,
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

  void _inspect(CardInstance instance) {
    final printing = _printings[instance.oracleId];
    if (printing != null) CardViewer.show(context, printing);
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.metrics,
    required this.seatName,
    required this.life,
    required this.canUndo,
    required this.onLife,
    required this.onUndo,
    required this.onLeave,
  });

  final Metrics metrics;
  final String seatName;
  final int life;
  final bool canUndo;
  final void Function(int) onLife;
  final VoidCallback onUndo;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return Row(
      children: [
        GestureDetector(
          onTap: onLeave,
          behavior: HitTestBehavior.opaque,
          child: Icon(
            Icons.arrow_back_rounded,
            size: m.scaled(20),
            color: Palette.inkMuted,
          ),
        ),
        SizedBox(width: m.scaled(12)),
        Expanded(
          child: Text(
            seatName,
            style: TextStyle(fontSize: m.scaled(14), color: Palette.inkMuted),
          ),
        ),
        _Pill(
          metrics: m,
          key: const Key('life-down'),
          icon: Icons.remove_rounded,
          onTap: () => onLife(-1),
        ),
        SizedBox(width: m.scaled(10)),
        Text(
          '$life',
          style: TextStyle(
            fontSize: m.scaled(22),
            fontWeight: FontWeight.w700,
            color: Palette.ink,
          ),
        ),
        SizedBox(width: m.scaled(10)),
        _Pill(
          metrics: m,
          key: const Key('life-up'),
          icon: Icons.add_rounded,
          onTap: () => onLife(1),
        ),
        SizedBox(width: m.scaled(12)),
        Opacity(
          opacity: canUndo ? 1 : 0.35,
          child: _Pill(
            metrics: m,
            key: const Key('undo'),
            icon: Icons.undo_rounded,
            onTap: onUndo,
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    required this.metrics,
    required this.icon,
    required this.onTap,
  });

  final Metrics metrics;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: m.scaled(34),
        height: m.scaled(34),
        decoration: BoxDecoration(
          color: Palette.tile,
          borderRadius: BorderRadius.circular(m.scaled(8)),
          border: Border.all(color: Palette.tileEdge),
        ),
        child: Icon(icon, size: m.scaled(17), color: Palette.inkMuted),
      ),
    );
  }
}

class _Battlefield extends StatelessWidget {
  const _Battlefield({
    required this.metrics,
    required this.cards,
    required this.printings,
    required this.onTap,
    required this.onInspect,
  });

  final Metrics metrics;
  final List<CardInstance> cards;
  final Map<String, CatalogCard> printings;
  final void Function(CardInstance) onTap;
  final void Function(CardInstance) onInspect;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    if (cards.isEmpty) {
      return Center(
        child: Text(
          'Nothing on the battlefield',
          style: TextStyle(fontSize: m.scaled(12), color: Palette.inkFaint),
        ),
      );
    }

    return SingleChildScrollView(
      child: Wrap(
        spacing: m.scaled(8),
        runSpacing: m.scaled(10),
        children: [
          for (final card in cards)
            TableCard(
              metrics: m,
              instance: card,
              printing: printings[card.oracleId],
              width: m.scaled(70),
              onTap: () => onTap(card),
              onLongPress: () => onInspect(card),
            ),
        ],
      ),
    );
  }
}

class _Piles extends StatelessWidget {
  const _Piles({
    required this.metrics,
    required this.librarySize,
    required this.graveyardSize,
    required this.onDraw,
  });

  final Metrics metrics;
  final int librarySize;
  final int graveyardSize;
  final VoidCallback onDraw;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return Row(
      children: [
        GestureDetector(
          key: const Key('draw'),
          onTap: onDraw,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: m.scaled(14),
              vertical: m.scaled(9),
            ),
            decoration: BoxDecoration(
              color: Palette.tile,
              borderRadius: BorderRadius.circular(m.scaled(10)),
              border: Border.all(color: Palette.tileEdge),
            ),
            child: Text(
              'Draw · $librarySize',
              style: TextStyle(fontSize: m.scaled(13), color: Palette.ink),
            ),
          ),
        ),
        SizedBox(width: m.scaled(10)),
        Text(
          'Graveyard $graveyardSize',
          style: TextStyle(fontSize: m.scaled(12), color: Palette.inkFaint),
        ),
      ],
    );
  }
}
```

- [ ] **Step 6: Run it and watch it pass**

Run: `flutter test test/features/play_screen_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 7: Run everything**

Run: `flutter test`
Expected: PASS.

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter build web --release`
Expected: `Built build/web`

- [ ] **Step 8: Commit**

```bash
git add lib/features/play test/features/play_screen_test.dart
git commit -m "One seat, a board, and a hand that never covers it"
```

---

## Task 13: A way in

**Files:**
- Modify: `lib/features/decks/deck_screen.dart`
- Modify: `lib/features/menu/menu_controller.dart`
- Test: `test/features/play_entry_test.dart`

Play is reachable from a deck, because a table without a deck is nothing. The
main menu's Play entry stays dimmed in this plan: it is where hosting and
joining will live, and neither exists yet.

- [ ] **Step 1: Write the failing test**

Create `test/features/play_entry_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/menu/menu_controller.dart';

void main() {
  test('Play still says what it is waiting for', () {
    const state = MenuState(cardCount: 36079, enabledSources: 1);
    final play = state.entries.firstWhere((e) => e.id == MenuEntryId.play);

    // The catalog is loaded and Play is still not a table: hosting and joining
    // are plan 3. Saying so beats a row that opens nothing.
    expect(play.subtitle, contains('deck'));
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/play_entry_test.dart`
Expected: FAIL, the subtitle is `host a table or join by code`.

- [ ] **Step 3: Say what Play is actually waiting for**

In `lib/features/menu/menu_controller.dart`, change the Play entry's subtitle
from `'host a table or join by code'` to
`'open a deck to play with it'`.

**This breaks a second test, and that is expected.**
`test/features/menu_screen_test.dart` line 34 asserts the old wording inside
`a loaded catalog shows the real count`. Change that line to:

```dart
    expect(find.text('open a deck to play with it'), findsOneWidget);
```

Do not weaken it to a `findsWidgets` or drop the assertion. It is checking that
the screen renders the subtitle the state gave it, which is the wiring two
earlier mutation probes were added to protect.

- [ ] **Step 4: Add the way in from a deck**

In `lib/features/decks/deck_screen.dart`, add this import:

```dart
import '../play/play_controller.dart';
import '../play/play_screen.dart';
import '../../table/shuffle.dart';
```

and add this row above `Add cards`:

```dart
        if (deck.slots.isNotEmpty)
          MenuRow(
            title: 'Play with this deck',
            subtitle: 'shuffle, draw seven, and see how it goldfishes',
            icon: Icons.play_arrow_rounded,
            metrics: m,
            onActivate: () {
              ref.read(playProvider.notifier).start(deck, seed: freshSeed());
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const PlayScreen()),
              );
            },
          ),
```

Note this makes `DeckScreen`'s build need a `WidgetRef`. It is already a
`ConsumerWidget`, so `ref` is in scope.

- [ ] **Step 5: Run everything**

Run: `flutter test`
Expected: PASS.

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib test
git commit -m "Reach a table from the deck that fills it"
```

---

## Task 14: Play a real deck on the web build

The tests never touch a real catalog. This is where it meets one.

- [ ] **Step 1: Build and serve**

```bash
flutter build web --release
cd build/web && python3 -m http.server 8088 --bind 0.0.0.0
```

- [ ] **Step 2: Play a game of one**

Import the Scryfall catalog if it is not there. Build or paste a Commander
deck. Open it, tap `Play with this deck`.

Check, and write down what you find:

- the opening hand is seven, and the library says the rest
- tapping a card in hand puts it on the battlefield
- tapping a card on the battlefield turns it ninety degrees
- holding a card opens the big turnable viewer
- life goes up and down
- undo puts back whatever just happened, several times over
- the commander sits in the command zone and not in the library

- [ ] **Step 3: Write down what is wrong**

Append what you found to this plan under a heading `## What playing it found`.
Every previous slice of this project shipped something green that was wrong on
a real screen, and it was always running it that caught it, never the suite.

- [ ] **Step 4: Commit**

```bash
git add docs
git commit -m "Write down what playing it actually did"
```

---

## What this plan deliberately leaves out

- **More than one seat.** Plan 2. The state already carries a list of seats and
  every zone id already carries its owner, so nothing here blocks it.
- **The two renderers.** Plan 2. This screen is a plain board, not StackedSeats
  or FreeCanvas, and it will be replaced rather than grown.
- **Free card positions.** The field is on `CardInstance` and nothing writes to
  it. Dragging a card to a spot belongs with the renderer that can show it.
- **The network.** Plan 3, entirely.
- **Pokemon.** Its zones are declared nowhere yet.

  The claim this plan opened with was that adding them changes no code under
  `lib/table/`. **That claim is already false and it is worth writing down
  rather than discovering later.** `lib/table/setup.dart` imports
  `games/magic_pack.dart` and hardcodes `openingHandSize = 7`, so a Magic
  shaped thing lives in the generic folder.

  Nothing under `table/model/` or `table/actions/` knows about any game, and
  that part holds: the eleven verbs and the state really are game agnostic.
  It is `sitDown` that is misfiled. It is a game's way of starting a table, not
  the table's.

  The fix is for plan 2, when there is a second game to shape it: a game pack
  grows a `sitDown` of its own and `lib/table/setup.dart` goes away. Doing it
  now would mean designing that interface against one real case and one
  imagined one, which is the mistake the spec already warned about for Pokemon
  itself.
- **Mulligans, phases, the stack, priority.** All of them are rules, and the
  referee's chair is empty on purpose.
