import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/decks/model/deck.dart';
import 'package:kitchentable/decks/model/deck_format.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';

CatalogCard _card(
  String name, {
  String typeLine = 'Instant',
  Map<String, String> legalities = const {
    'commander': 'legal',
    'standard': 'legal',
    'pauper': 'legal',
  },
}) =>
    CatalogCard(
      oracleId: name,
      name: name,
      typeLine: typeLine,
      cmc: 1,
      legalities: legalities,
    );

Deck _deck(DeckFormat format, List<DeckSlot> slots) =>
    Deck(id: 'd', name: 'a deck', format: format, slots: slots);

void main() {
  test('an empty deck complains about nothing', () {
    final deck = _deck(DeckFormat.commander, const []);
    expect(complainAbout(deck, _card('Sol Ring')), isNull);
  });

  test('Commander refuses a second copy', () {
    final sol = _card('Sol Ring');
    final deck = _deck(DeckFormat.commander, [DeckSlot(card: sol, quantity: 1)]);

    final complaint = complainAbout(deck, sol);
    expect(complaint, isNotNull);
    expect(complaint!.blocking, isTrue);
    expect(complaint.message, contains('singleton'));
  });

  test('Standard allows four and refuses the fifth', () {
    final bolt = _card('Lightning Bolt');
    final four = _deck(DeckFormat.standard, [DeckSlot(card: bolt, quantity: 4)]);
    final three = _deck(DeckFormat.standard, [DeckSlot(card: bolt, quantity: 3)]);

    expect(complainAbout(three, bolt), isNull);
    expect(complainAbout(four, bolt)?.message, contains('4 copies'));
  });

  test('the limit spans the sideboard, it is not per pile', () {
    final bolt = _card('Lightning Bolt');
    final deck = _deck(DeckFormat.standard, [
      DeckSlot(card: bolt, quantity: 3),
      DeckSlot(card: bolt, quantity: 1, sideboard: true),
    ]);

    // Four already, across both piles. A fifth is a fifth wherever it goes.
    expect(complainAbout(deck, bolt, sideboard: true), isNotNull);
    expect(complainAbout(deck, bolt), isNotNull);
  });

  test('basic lands never run out, even in Commander', () {
    final mountain = _card('Mountain', typeLine: 'Basic Land - Mountain');
    final deck = _deck(
      DeckFormat.commander,
      [DeckSlot(card: mountain, quantity: 37)],
    );
    expect(complainAbout(deck, mountain), isNull);
  });

  test('an illegal card is allowed in, and said out loud', () {
    final banned = _card('Black Lotus', legalities: const {
      'commander': 'banned',
      'standard': 'not_legal',
    });
    final deck = _deck(DeckFormat.commander, const []);

    final complaint = complainAbout(deck, banned);
    expect(complaint, isNotNull);
    expect(complaint!.blocking, isFalse,
        reason: 'a kitchen table deck is allowed to be illegal');
    expect(complaint.message, contains('Commander'));
  });

  test('a draft pool answers to no legality list', () {
    final banned = _card('Black Lotus', legalities: const {});
    expect(complainAbout(_deck(DeckFormat.draft, const []), banned), isNull);
  });

  test('the commander counts inside the hundred', () {
    final deck = _deck(DeckFormat.commander, [
      DeckSlot(card: _card('Atraxa'), quantity: 1, commander: true),
      DeckSlot(card: _card('Sol Ring'), quantity: 1),
    ]);
    expect(deck.mainCount, 2);
    expect(deck.commanders.length, 1);
    expect(deck.main.length, 1);
  });

  test('the sideboard is counted apart from the deck', () {
    final deck = _deck(DeckFormat.standard, [
      DeckSlot(card: _card('Lightning Bolt'), quantity: 4),
      DeckSlot(card: _card('Pyroblast'), quantity: 2, sideboard: true),
    ]);
    expect(deck.mainCount, 4);
    expect(deck.sideCount, 2);
  });
}
