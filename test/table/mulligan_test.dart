import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/decks/model/deck.dart';
import 'package:kitchentable/decks/model/deck_format.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';
import 'package:kitchentable/table/actions/apply.dart';
import 'package:kitchentable/table/actions/table_action.dart';
import 'package:kitchentable/table/model/table_state.dart';
import 'package:kitchentable/table/opening.dart';
import 'package:kitchentable/table/setup.dart';

CatalogCard _card(String name) =>
    CatalogCard(oracleId: name, name: name, typeLine: 'Land', cmc: 0);

/// Sixty different cards, so a shuffle that moved nothing is visible.
Deck _deck() => Deck(
  id: 'd',
  name: 'sixty',
  format: DeckFormat.commander,
  slots: [
    for (var i = 0; i < 60; i++) DeckSlot(card: _card('Card $i'), quantity: 1),
  ],
);

TableState _table({String seed = 'one'}) =>
    sitDown(deck: _deck(), seatName: 'you', seed: seed);

List<String> _hand(TableState table) => [
  for (final c in table.zone('hand-s1')!.cards) c.oracleId,
];

void main() {
  test('a mulligan puts the hand back and deals the same number again', () {
    final before = _table();
    expect(_hand(before), hasLength(openingHandSize));

    final after = apply(
      before,
      const TakeMulligan(seatId: 's1', seed: 'again'),
    );

    expect(_hand(after), hasLength(openingHandSize));
    expect(
      _hand(after),
      isNot(_hand(before)),
      reason: 'the same seven back is not a mulligan',
    );

    // Nothing left the table. Sixty cards before and sixty after, wherever
    // they are: a hand that went back into the library and a library that
    // was shuffled are the same cards.
    expect(
      after.zone('library-s1')!.cards.length + _hand(after).length,
      before.zone('library-s1')!.cards.length + _hand(before).length,
    );
  });

  test('the London rule is counted, not applied', () {
    // Seven every time, and one more card owed to the bottom each time. The
    // app never picks which: that is the decision the rule exists for.
    var table = _table();
    expect(cardsToPutBack(table, 's1'), 0);

    table = apply(table, const TakeMulligan(seatId: 's1', seed: 'a'));
    expect(cardsToPutBack(table, 's1'), 1);
    expect(_hand(table), hasLength(openingHandSize));

    table = apply(table, const TakeMulligan(seatId: 's1', seed: 'b'));
    expect(cardsToPutBack(table, 's1'), 2);
    expect(_hand(table), hasLength(openingHandSize));
  });

  test('a mulligan on a seat that is not there changes nothing', () {
    final table = _table();
    expect(
      apply(table, const TakeMulligan(seatId: 'nobody', seed: 'x')).seats,
      table.seats,
    );
  });

  group('when the hand stops being the opening hand', () {
    const size = 60;

    test('a fresh deal is still being chosen', () {
      expect(stillChoosingAHand(_table(), 's1', deckSize: size), isTrue);
    });

    test('and so is one after two mulligans', () {
      var table = _table();
      table = apply(table, const TakeMulligan(seatId: 's1', seed: 'a'));
      table = apply(table, const TakeMulligan(seatId: 's1', seed: 'b'));

      expect(stillChoosingAHand(table, 's1', deckSize: size), isTrue);
    });

    test('putting a card on the bottom keeps the offer open', () {
      // The London rule says to do exactly this, so doing it cannot be what
      // takes the offer away.
      var table = _table();
      table = apply(table, const TakeMulligan(seatId: 's1', seed: 'a'));
      final card = table.zone('hand-s1')!.cards.first;
      table = apply(table, MoveCard(cardId: card.id, toZoneId: 'library-s1'));

      expect(stillChoosingAHand(table, 's1', deckSize: size), isTrue);
    });

    test('a card on the battlefield means the game is on', () {
      var table = _table();
      final card = table.zone('hand-s1')!.cards.first;
      table = apply(
        table,
        MoveCard(cardId: card.id, toZoneId: 'battlefield-s1'),
      );

      expect(stillChoosingAHand(table, 's1', deckSize: size), isFalse);
    });

    test('so does drawing a card you were not dealt', () {
      final table = apply(
        _table(),
        const DrawCards(
          fromZoneId: 'library-s1',
          toZoneId: 'hand-s1',
          count: 1,
        ),
      );

      expect(stillChoosingAHand(table, 's1', deckSize: size), isFalse);
    });

    test('and so does discarding one', () {
      var table = _table();
      final card = table.zone('hand-s1')!.cards.first;
      table = apply(table, MoveCard(cardId: card.id, toZoneId: 'graveyard-s1'));

      expect(stillChoosingAHand(table, 's1', deckSize: size), isFalse);
    });

    test('a table whose deck size nobody remembers offers nothing', () {
      // Without it a draw and a deal are the same move: both take a card off
      // the library and put it in the hand. Guessing here would offer a
      // mulligan in the middle of a game.
      expect(stillChoosingAHand(_table(), 's1', deckSize: null), isFalse);
    });
  });
}
