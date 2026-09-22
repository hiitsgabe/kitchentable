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
    // Sixty DISTINCT cards, and the comparison is on oracleId rather than on
    // the instance id. The first version of this test compared instance ids,
    // which are minted with the seat as a prefix, so one list was always
    // s1-anything and the other always s2-anything and they could never be
    // equal. It passed with the per seat seed removed, which is how a probe
    // found it: a test that cannot fail is worse than one that merely does not.
    final sixty = Deck(
      id: 'shared',
      name: 'shared',
      format: DeckFormat.commander,
      slots: [
        for (var i = 0; i < 60; i++)
          DeckSlot(card: _card('card$i'), quantity: 1),
      ],
    );

    final table = sitDownTogether(
      players: [
        (deck: sixty, name: 'you', owner: const SeatOwner.here()),
        (deck: sixty, name: 'Carla', owner: const SeatOwner.here()),
      ],
      seed: 'abc',
    );

    // Library plus hand, because seven came off the top of each and the two
    // seats drew different sevens. Comparing libraries alone compares fifty
    // three cards that are not the same fifty three, which is a mismatch about
    // the draw rather than about the shuffle.
    List<String> wholeDeck(String seatId) => [
          ...table.zone('library-$seatId')!.cards,
          ...table.zone('hand-$seatId')!.cards,
        ].map((c) => c.oracleId).toList();

    final mine = wholeDeck('s1');
    final theirs = wholeDeck('s2');

    expect(mine, hasLength(60));
    expect(mine.toSet(), theirs.toSet(),
        reason: 'the same decklist, so the same sixty cards are in there');
    expect(mine, isNot(theirs),
        reason: 'two people with the same list drawing the same seven cards '
            'would be absurd, and that is what one seed for the table gives');
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
