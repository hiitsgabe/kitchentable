import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/decks/model/basic_lands.dart';
import 'package:kitchentable/decks/model/deck.dart';
import 'package:kitchentable/decks/model/deck_format.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';

CatalogCard _card(String name, List<String> identity) => CatalogCard(
      oracleId: name.toLowerCase(),
      name: name,
      typeLine: 'Creature',
      cmc: 1,
      colorIdentity: identity,
    );

Deck _deck(DeckFormat f, List<DeckSlot> slots) =>
    Deck(id: 'd', name: 'x', format: f, slots: slots);

void main() {
  test('an empty deck is offered all five', () {
    expect(suggestedLandsFor(_deck(DeckFormat.commander, const [])),
        basicLandNames);
  });

  test('a deck is read for the colours it actually contains', () {
    final deck = _deck(DeckFormat.commander, [
      DeckSlot(card: _card('Counterspell', ['U']), quantity: 1),
      DeckSlot(card: _card('Lightning Bolt', ['R']), quantity: 1),
    ]);

    expect(suggestedLandsFor(deck), ['Island', 'Mountain']);
  });

  test('a commander overrules what the deck happens to hold', () {
    final deck = _deck(DeckFormat.commander, [
      DeckSlot(
        card: _card('Atraxa', ['W', 'U', 'B', 'G']),
        quantity: 1,
        commander: true,
      ),
      DeckSlot(card: _card('Lightning Bolt', ['R']), quantity: 1),
    ]);

    // Red is in the deck and not in the identity, which is illegal, and the
    // lands should follow the commander rather than the mistake.
    expect(suggestedLandsFor(deck), ['Plains', 'Island', 'Swamp', 'Forest']);
  });

  test('a colourless deck still gets offered something', () {
    final deck = _deck(DeckFormat.commander, [
      DeckSlot(card: _card('Sol Ring', const []), quantity: 1),
    ]);
    expect(suggestedLandsFor(deck), basicLandNames);
  });

  test('the split fills exactly what is missing', () {
    final deck = _deck(DeckFormat.commander, [
      DeckSlot(card: _card('Counterspell', ['U']), quantity: 1),
      DeckSlot(card: _card('Lightning Bolt', ['R']), quantity: 62),
    ]);

    final split = evenLandSplit(deck);
    expect(split.values.fold(0, (a, b) => a + b), 100 - 63);
    expect(split.keys, ['Island', 'Mountain']);
  });

  test('a remainder goes to the earlier colours, the way a person does it', () {
    final deck = _deck(DeckFormat.commander, [
      DeckSlot(card: _card('a', ['W']), quantity: 1),
      DeckSlot(card: _card('b', ['U']), quantity: 1),
      DeckSlot(card: _card('c', ['B']), quantity: 60),
    ]);

    final split = evenLandSplit(deck);
    expect(split.values.fold(0, (a, b) => a + b), 38);
    expect(split['Plains'], 13);
    expect(split['Island'], 13);
    expect(split['Swamp'], 12);
  });

  test('a full deck is offered nothing', () {
    final deck = _deck(DeckFormat.commander, [
      DeckSlot(card: _card('a', ['W']), quantity: 100),
    ]);
    expect(evenLandSplit(deck), isEmpty);
  });
}
