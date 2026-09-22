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

  test('moving a card into the zone it is already in does not lose it', () {
    final next = apply(_table(), const MoveCard(cardId: 'a', toZoneId: 'library'));

    // A card can be moved within its own pile, to reorder it. It must still
    // be there afterwards, not vanish because it was briefly present twice.
    expect(next.zone('library')!.cards.map((c) => c.id).toSet(),
        {'a', 'b', 'c'});
    expect(next.zone('library')!.size, 3);
  });

  test('moving a card that is not there changes nothing', () {
    final before = _table();
    final after = apply(before, const MoveCard(cardId: 'zz', toZoneId: 'hand'));

    expect(after.zone('library')!.size, before.zone('library')!.size);
    expect(after.zone('hand')!.size, 0);
  });

  test('rotating, flipping, countering or attaching a card that is not '
      'there changes nothing', () {
    final before = _table();

    expect(apply(before, const RotateCard('zz')), before);
    expect(apply(before, const FlipCard('zz')), before);
    expect(
      apply(before, const ChangeCounter(cardId: 'zz', kind: 'x', by: 1)),
      before,
    );
    expect(
      apply(before, const AttachCard(cardId: 'zz', toCardId: 'a')),
      before,
    );
  });

  test('drawing moves several, in order, off the top', () {
    final next = apply(
      _table(),
      const DrawCards(fromZoneId: 'library', toZoneId: 'hand', count: 2),
    );

    expect(next.zone('library')!.cards.single.id, 'c');
    expect(next.zone('hand')!.size, 2);
  });

  test('drawing keeps the top of the library on top of the hand', () {
    final table = TableState(
      seats: [
        Seat(
          id: 's1',
          name: 'you',
          life: 40,
          zones: [
            _zone('library', ZoneVisibility.hidden, true, ['a', 'b', 'c']),
            _zone('hand', ZoneVisibility.owner, true, []),
          ],
        ),
      ],
    );

    final next = apply(
      table,
      const DrawCards(fromZoneId: 'library', toZoneId: 'hand', count: 2),
    );

    // The top of the library is what a player sees first when they look at
    // their hand. If a draw silently reversed the order, the top of a
    // library would become the bottom of a hand and nobody would notice
    // until a game went wrong.
    expect(next.zone('hand')!.cards.map((c) => c.id), ['a', 'b']);
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
