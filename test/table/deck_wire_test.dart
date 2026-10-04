import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/decks/model/deck.dart';
import 'package:kitchentable/decks/model/deck_format.dart';
import 'package:kitchentable/decks/model/game.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';
import 'package:kitchentable/table/wire/deck_wire.dart';

void main() {
  test('a card keeps its game across the wire, so a guest draws the right '
      'back', () {
    final deck = Deck(
      id: 'p1',
      name: 'Fire',
      format: DeckFormat.pokemonStandard,
      game: Game.pokemon,
      slots: const [
        DeckSlot(
          card: CatalogCard(
            oracleId: 'base1-4',
            name: 'Charizard',
            typeLine: 'Pokémon · Stage 2 · Fire',
            cmc: 0,
            game: Game.pokemon,
          ),
          quantity: 4,
        ),
      ],
    );
    final back = deckFromWire(deckToWire(deck));
    expect(back.game, Game.pokemon);
    expect(
      back.slots.single.card.game,
      Game.pokemon,
      reason: 'the card, not only the deck: the back is drawn per card',
    );
  });

  test('a card written before cards had a game is Magic', () {
    final deck = Deck(
      id: 'm1',
      name: 'Burn',
      format: DeckFormat.standard,
      slots: const [
        DeckSlot(
          card: CatalogCard(
            oracleId: 'o1',
            name: 'Lightning Bolt',
            typeLine: 'Instant',
            cmc: 1,
          ),
          quantity: 4,
        ),
      ],
    );
    final json = jsonDecode(deckToWire(deck)) as Map<String, Object?>;
    final slots = json['slots'] as List<Object?>;
    final card =
        (slots.single as Map<String, Object?>)['card'] as Map<String, Object?>;
    card.remove('game');
    expect(deckFromWire(jsonEncode(json)).slots.single.card.game, Game.magic);
  });
}
