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
