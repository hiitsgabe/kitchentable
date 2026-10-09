import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/decks/model/deck.dart';
import 'package:kitchentable/decks/model/deck_format.dart';
import 'package:kitchentable/features/draft/draft_build_screen.dart';
import 'package:kitchentable/features/draft/draft_state.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';

CatalogCard _card(String oracle) =>
    CatalogCard(oracleId: oracle, name: oracle, typeLine: 'Creature', cmc: 1);

DraftCard _draft(String uuid, String oracle) =>
    DraftCard(uuid: uuid, oracleId: oracle, rarity: 'common');

void main() {
  final cards = {
    for (final o in ['a', 'b', 'c']) o: _card(o),
  };

  test('copies of one card become one slot of that quantity', () {
    // Three of a, one of b; a and b both in the deck.
    final pool = [
      _draft('1', 'a'),
      _draft('2', 'a'),
      _draft('3', 'a'),
      _draft('4', 'b'),
    ];
    final slots = draftDeckSlots(
      pool: pool,
      inDeck: {0, 1, 2, 3},
      basics: const {},
      cards: cards,
      basicCards: const {},
    );
    final deck = Deck(
      id: 'd',
      name: 'x',
      format: DeckFormat.draft,
      slots: slots,
    );
    expect(deck.quantityOf('a'), 3);
    expect(deck.quantityOf('b'), 1);
    expect(deck.sideCount, 0);
  });

  test('the pool left out of the deck is kept as the sideboard', () {
    final pool = [_draft('1', 'a'), _draft('2', 'b'), _draft('3', 'c')];
    final slots = draftDeckSlots(
      pool: pool,
      inDeck: {0}, // only a makes the deck
      basics: const {},
      cards: cards,
      basicCards: const {},
    );
    final deck = Deck(
      id: 'd',
      name: 'x',
      format: DeckFormat.draft,
      slots: slots,
    );
    expect(deck.mainCount, 1);
    expect(deck.quantityOf('a'), 1);
    expect(deck.sideCount, 2);
    expect(deck.quantityOf('b', sideboard: true), 1);
    expect(deck.quantityOf('c', sideboard: true), 1);
  });

  test('basics are added to the deck, not the sideboard', () {
    final basics = {'Plains': _card('Plains'), 'Forest': _card('Forest')};
    final slots = draftDeckSlots(
      pool: [_draft('1', 'a')],
      inDeck: {0},
      basics: const {'Plains': 10, 'Forest': 7},
      cards: cards,
      basicCards: basics,
    );
    final deck = Deck(
      id: 'd',
      name: 'x',
      format: DeckFormat.draft,
      slots: slots,
    );
    expect(deck.mainCount, 1 + 10 + 7);
    expect(deck.sideCount, 0);
  });

  test('a pool card the catalog never resolved is dropped from both piles', () {
    final slots = draftDeckSlots(
      pool: [_draft('1', 'a'), _draft('2', '')],
      inDeck: {0, 1},
      basics: const {},
      cards: cards,
      basicCards: const {},
    );
    final deck = Deck(
      id: 'd',
      name: 'x',
      format: DeckFormat.draft,
      slots: slots,
    );
    expect(deck.mainCount, 1);
    expect(deck.sideCount, 0);
  });
}
