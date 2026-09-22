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
