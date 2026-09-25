import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/table/actions/table_action.dart';
import 'package:kitchentable/table/model/card_instance.dart';
import 'package:kitchentable/table/model/seat.dart';
import 'package:kitchentable/table/model/seat_owner.dart';
import 'package:kitchentable/table/model/table_state.dart';
import 'package:kitchentable/table/model/zone.dart';
import 'package:kitchentable/table/wire/wire.dart';

/// One of every verb, with the optional fields filled rather than left at their
/// defaults. A field that is null on both sides round trips whether or not
/// anybody encoded it, so a case built out of defaults proves very little.
const _oneOfEach = <TableAction>[
  MoveCard(
    cardId: 'c1',
    toZoneId: 'battlefield-s1',
    at: 3,
    faceDown: true,
    position: (x: 0.25, y: 0.75),
  ),
  RotateCard('c2', to: 180),
  FlipCard('c3'),
  ChangeCounter(cardId: 'c4', kind: '+1/+1', by: -2),
  AttachCard(cardId: 'c5', toCardId: 'c6'),
  ShuffleZone(zoneId: 'library-s1', seed: 'seed/s1'),
  DrawCards(fromZoneId: 'library-s1', toZoneId: 'hand-s1', count: 7),
  CreateToken(zoneId: 'battlefield-s1', oracleId: 'goblin', cardId: 'c7'),
  ChangeLife(seatId: 's1', by: -3),
  RollDice([6, 1, 20]),
  PassTurn(),
];

/// The shapes where an optional field is absent and the absence is the verb: a
/// tap that toggles, a detach, a move that leaves the card as it was. Encoding
/// a default in place of one of these turns a tap into a set angle.
const _theNullShapes = <TableAction>[
  MoveCard(cardId: 'c1', toZoneId: 'hand-s1'),
  RotateCard('c2'),
  AttachCard(cardId: 'c5', toCardId: null),
  RollDice([]),
];

/// Every verb the sealed set declares, read off the source rather than typed
/// out here.
///
/// The list above is hand written and a hand written list cannot prove absence:
/// a twelfth verb nobody put on the wire leaves it eleven long and green. This
/// derives the population from the file that declares it, so the verb has to be
/// missing from somewhere that is not also the thing doing the checking.
Set<String> _declaredVerbs() {
  final source = File('lib/table/actions/table_action.dart');
  expect(
    source.existsSync(),
    isTrue,
    reason: 'this reads the source, so it has to run from the package root. '
        'cwd is ${Directory.current.path}',
  );

  return RegExp(r'class (\w+) (?:extends|implements) TableAction')
      .allMatches(source.readAsStringSync())
      .map((m) => m.group(1)!)
      .toSet();
}

/// A table with a card in every kind of zone, one seat held here and one held
/// by a peer, so the parts of the state that are not cards travel too.
TableState _aTableInProgress() {
  const inTheLibrary = CardInstance(id: 'l1', oracleId: 'sol ring');
  const inHand = CardInstance(
    id: 'h1',
    oracleId: 'brainstorm',
    rotation: 270,
    counters: {'damage': 3, 'loyalty': -1},
  );
  const onTheField = CardInstance(
    id: 'b1',
    oracleId: 'llanowar elves',
    rotation: 90,
    faceDown: true,
    attachedTo: 'b2',
    position: (x: 0.125, y: 0.875),
  );
  const alsoOnTheField = CardInstance(id: 'b2', oracleId: 'bear cub');
  const inTheYard = CardInstance(id: 'g1', oracleId: 'shock');
  const inCommand = CardInstance(id: 'cm1', oracleId: 'atraxa');

  return TableState(
    seats: [
      Seat(
        id: 's1',
        name: 'you',
        life: 37,
        owner: const SeatOwner.here(),
        zones: const [
          Zone(
            id: 'library-s1',
            seatId: 's1',
            label: 'Library',
            visibility: ZoneVisibility.hidden,
            ordered: true,
            cards: [inTheLibrary],
          ),
          Zone(
            id: 'hand-s1',
            seatId: 's1',
            label: 'Hand',
            visibility: ZoneVisibility.owner,
            ordered: false,
            cards: [inHand],
          ),
          Zone(
            id: 'battlefield-s1',
            seatId: 's1',
            label: 'Battlefield',
            visibility: ZoneVisibility.public,
            ordered: false,
            cards: [onTheField, alsoOnTheField],
          ),
          Zone(
            id: 'graveyard-s1',
            seatId: 's1',
            label: 'Graveyard',
            visibility: ZoneVisibility.public,
            ordered: true,
            cards: [inTheYard],
          ),
          Zone(
            id: 'command-s1',
            seatId: 's1',
            label: 'Command',
            visibility: ZoneVisibility.public,
            ordered: false,
            cards: [inCommand],
          ),
        ],
      ),
      Seat(
        id: 's2',
        name: 'kit',
        life: 40,
        owner: const SeatOwner.peer('peer-9'),
        zones: const [
          Zone(
            id: 'hand-s2',
            seatId: 's2',
            label: 'Hand',
            visibility: ZoneVisibility.owner,
            ordered: false,
          ),
        ],
      ),
    ],
    turnSeatId: 's2',
    dice: const [4, 4, 20],
  );
}

void main() {
  test('every verb survives the round trip', () {
    for (final action in _oneOfEach) {
      // The wire and not `'\$action'`: none of the verbs has a `toString`, so
      // both sides of a failure print as `Instance of 'MoveCard'` and name
      // neither the verb's fields nor which one of them did not make it.
      expect(fromWire(toWire(action)), action, reason: toWire(action));
    }
  });

  test('a verb whose optional field is absent comes back absent', () {
    for (final action in _theNullShapes) {
      expect(fromWire(toWire(action)), action, reason: toWire(action));
    }

    // And the absence is not the same wire as the filled shape, which is what
    // notices an encoder writing a default where the verb meant nothing.
    expect(
      toWire(const RotateCard('c2')),
      isNot(toWire(const RotateCard('c2', to: 180))),
    );
  });

  test('every verb the sealed set declares is in the list above', () {
    // The list is hand written and a hand written list cannot prove absence.
    // This is what notices a twelfth verb: the population comes off
    // `table_action.dart` itself, so a verb declared there and not put on the
    // wire is named here rather than counted as eleven of eleven.
    expect(
      _oneOfEach.map((a) => a.runtimeType.toString()).toSet(),
      _declaredVerbs(),
    );

    // Eleven, and the file says why the number is closed. A twelfth has to be
    // argued for, and arguing for it includes coming back here.
    expect(_declaredVerbs(), hasLength(11));
  });

  test('an unknown verb is an error that names it', () {
    // Never a no op. A peer on an older build that silently drops a verb it has
    // not heard of desynchronises the table, and every screen goes on looking
    // correct while the two tables disagree about where the cards are.
    expect(
      () => fromWire(jsonEncode({'v': wireVersion, 'type': 'Teleport'})),
      throwsA(
        isA<WireError>().having(
          (e) => e.message,
          'message',
          contains('Teleport'),
        ),
      ),
    );
  });

  test('a newer wire is refused with a message about the version', () {
    expect(
      () => fromWire(jsonEncode({'v': wireVersion + 1, 'type': 'PassTurn'})),
      throwsA(
        isA<WireError>().having(
          (e) => e.message,
          'message',
          allOf(contains('version'), contains('${wireVersion + 1}')),
        ),
      ),
    );
  });

  test('a table with a card in every kind of zone survives the round trip', () {
    final wire = stateToWire(_aTableInProgress());
    final back = stateFromWire(wire);

    // Field by field, because `CardInstance` equality is its id and `Seat`,
    // `Zone` and `TableState` have no equality at all: `expect(back, state)`
    // would pass on a wire that lost every rotation and counter on the table.
    expect(back.turnSeatId, 's2');
    expect(back.dice, [4, 4, 20]);
    expect(back.seats.map((s) => s.id), ['s1', 's2']);
    expect(back.seat('s1')!.name, 'you');
    expect(back.seat('s1')!.life, 37);
    expect(back.seat('s1')!.owner, const SeatOwner.here());
    expect(back.seat('s2')!.owner, const SeatOwner.peer('peer-9'));
    expect(back.seat('s2')!.owner.peerId, 'peer-9');

    final library = back.zone('library-s1')!;
    expect(library.label, 'Library');
    expect(library.visibility, ZoneVisibility.hidden);
    expect(library.ordered, isTrue);
    expect(library.seatId, 's1');

    final hand = back.zone('hand-s1')!;
    expect(hand.ordered, isFalse);
    expect(hand.visibility, ZoneVisibility.owner);
    expect(hand.cards.single.rotation, 270);
    expect(hand.cards.single.counters, {'damage': 3, 'loyalty': -1});

    final field = back.zone('battlefield-s1')!;
    expect(field.cards.map((c) => c.id), ['b1', 'b2']);
    expect(field.cards.first.oracleId, 'llanowar elves');
    expect(field.cards.first.faceDown, isTrue);
    expect(field.cards.first.attachedTo, 'b2');
    expect(field.cards.first.position, (x: 0.125, y: 0.875));
    expect(field.cards.last.attachedTo, isNull);
    expect(field.cards.last.position, isNull);
    expect(field.cards.last.faceDown, isFalse);
    expect(field.cards.last.counters, isEmpty);

    expect(back.zone('graveyard-s1')!.cards.single.id, 'g1');
    expect(back.zone('command-s1')!.cards.single.oracleId, 'atraxa');
    expect(back.zone('hand-s2')!.cards, isEmpty);

    // And the whole thing, so a field nobody thought to assert above still has
    // to make the trip. Deep, because this is decoded JSON and not the objects.
    expect(jsonDecode(stateToWire(back)), jsonDecode(wire));
  });

  test('a state wire is refused by version too', () {
    // A real state with the version bumped, and not a hand made object with a
    // `v` in it: that one is missing every other field as well, so it throws
    // about the first field it reaches and passes this case while saying
    // nothing about the version at all.
    final newer = jsonDecode(stateToWire(_aTableInProgress()))
        as Map<String, Object?>;
    newer['v'] = wireVersion + 1;

    expect(
      () => stateFromWire(jsonEncode(newer)),
      throwsA(
        isA<WireError>().having(
          (e) => e.message,
          'message',
          allOf(contains('version'), contains('${wireVersion + 1}')),
        ),
      ),
    );
  });
}
