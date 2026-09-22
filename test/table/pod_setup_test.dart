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
