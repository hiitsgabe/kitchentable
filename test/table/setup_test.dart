import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/decks/model/deck.dart';
import 'package:kitchentable/decks/model/deck_format.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';
import 'package:kitchentable/table/setup.dart';

CatalogCard _card(String name) => CatalogCard(
      oracleId: name,
      name: name,
      typeLine: 'Instant',
      cmc: 1,
    );

Deck _deck({
  DeckFormat format = DeckFormat.commander,
  List<DeckSlot> slots = const [],
}) =>
    Deck(id: 'd1', name: 'a deck', format: format, slots: slots);

void main() {
  test('every copy of a card becomes its own card on the table', () {
    final table = sitDown(
      deck: _deck(slots: [DeckSlot(card: _card('Mountain'), quantity: 37)]),
      seatName: 'you',
      seed: 'abc',
    );

    final library = table.seats.single.zones
        .firstWhere((z) => z.id.startsWith('library'));

    expect(library.size, 30, reason: '37 dealt, 7 drawn');
    expect(
      library.cards.map((c) => c.id).toSet().length,
      30,
      reason: 'thirty seven Mountains are thirty seven things',
    );
  });

  test('a hand of seven comes off the top', () {
    final table = sitDown(
      deck: _deck(slots: [DeckSlot(card: _card('Mountain'), quantity: 60)]),
      seatName: 'you',
      seed: 'abc',
    );

    final hand =
        table.seats.single.zones.firstWhere((z) => z.id.startsWith('hand'));

    expect(hand.size, 7);
  });

  test('a commander starts in the command zone, not the library', () {
    final table = sitDown(
      deck: _deck(slots: [
        DeckSlot(card: _card('Atraxa'), quantity: 1, commander: true),
        DeckSlot(card: _card('Mountain'), quantity: 99),
      ]),
      seatName: 'you',
      seed: 'abc',
    );

    final zones = table.seats.single.zones;
    final command = zones.firstWhere((z) => z.id.startsWith('command'));
    final library = zones.firstWhere((z) => z.id.startsWith('library'));

    expect(command.size, 1);
    expect(command.cards.single.oracleId, 'Atraxa');
    expect(library.cards.any((c) => c.oracleId == 'Atraxa'), isFalse);
  });

  test('the sideboard does not come to the table', () {
    final table = sitDown(
      deck: _deck(format: DeckFormat.standard, slots: [
        DeckSlot(card: _card('Bolt'), quantity: 60),
        DeckSlot(card: _card('Pyroblast'), quantity: 15, sideboard: true),
      ]),
      seatName: 'you',
      seed: 'abc',
    );

    final all = table.seats.single.zones.expand((z) => z.cards);
    expect(all.any((c) => c.oracleId == 'Pyroblast'), isFalse);
    expect(all.length, 60);
  });

  test('life comes from the format', () {
    final commander = sitDown(
      deck: _deck(slots: [DeckSlot(card: _card('x'), quantity: 10)]),
      seatName: 'you',
      seed: 'abc',
    );
    final duel = sitDown(
      deck: _deck(
        format: DeckFormat.standard,
        slots: [DeckSlot(card: _card('x'), quantity: 10)],
      ),
      seatName: 'you',
      seed: 'abc',
    );

    expect(commander.seats.single.life, 40);
    expect(duel.seats.single.life, 20);
  });

  test('the same seed seats you with the same opening hand', () {
    List<String> handFor(String seed) {
      final table = sitDown(
        deck: _deck(slots: [
          for (var i = 0; i < 60; i++)
            DeckSlot(card: _card('card$i'), quantity: 1),
        ]),
        seatName: 'you',
        seed: seed,
      );
      return table.seats.single.zones
          .firstWhere((z) => z.id.startsWith('hand'))
          .cards
          .map((c) => c.oracleId)
          .toList();
    }

    expect(handFor('abc'), handFor('abc'));
    expect(handFor('abc'), isNot(handFor('xyz')));
  });

  test('an empty deck seats you without throwing', () {
    final table = sitDown(deck: _deck(), seatName: 'you', seed: 'abc');
    expect(table.seats.single.zones.every((z) => z.isEmpty), isTrue);
  });

  test('a commander is out of the deck before a shuffle can touch it', () {
    final table = sitDown(
      deck: _deck(slots: [
        DeckSlot(card: _card('General'), quantity: 1, commander: true),
        DeckSlot(card: _card('Mountain'), quantity: 99),
      ]),
      seatName: 'you',
      seed: 'abc',
    );

    final command = table.zone('command-s1')!;
    final library = table.zone('library-s1')!;

    expect(command.cards, hasLength(1));
    expect(library.cards.any((c) => c.oracleId == 'General'), isFalse,
        reason: 'the commander must never be in the deck');
    expect(table.zone('hand-s1')!.cards.any((c) => c.oracleId == 'General'),
        isFalse);
  });
}
