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
