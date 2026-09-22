import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/decks/deck_repository.dart';
import 'package:kitchentable/decks/model/deck.dart';
import 'package:kitchentable/decks/model/deck_format.dart';
import 'package:kitchentable/decks/model/game.dart';
import 'package:kitchentable/sources/catalog/catalog_db.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';

CatalogCard _card(String name) => CatalogCard(
      oracleId: name.toLowerCase(),
      name: name,
      typeLine: 'Instant',
      cmc: 1,
    );

void main() {
  late CatalogDb db;
  late DeckRepository repo;

  setUp(() async {
    db = CatalogDb.forTesting(NativeDatabase.memory());
    repo = DeckRepository(db);
    await db.insertAll([_card('Sol Ring'), _card('Atraxa'), _card('Mountain')]);
  });
  tearDown(() => db.close());

  Deck deck({List<DeckSlot> slots = const []}) => Deck(
        id: 'd1',
        name: 'my pod deck',
        format: DeckFormat.commander,
        slots: slots,
      );

  test('a saved deck comes back with its name and format', () async {
    await repo.save(deck());
    final loaded = await repo.load('d1');

    expect(loaded!.name, 'my pod deck');
    expect(loaded.format, DeckFormat.commander);
  });

  test('cards survive the round trip with their quantities', () async {
    await repo.save(deck(slots: [
      DeckSlot(card: _card('Sol Ring'), quantity: 1),
      DeckSlot(card: _card('Mountain'), quantity: 37),
    ]));

    final loaded = await repo.load('d1');
    expect(loaded!.mainCount, 38);
    expect(loaded.quantityOf('mountain'), 37);
  });

  test('the commander flag survives, and counts inside the deck', () async {
    await repo.save(deck(slots: [
      DeckSlot(card: _card('Atraxa'), quantity: 1, commander: true),
      DeckSlot(card: _card('Sol Ring'), quantity: 1),
    ]));

    final loaded = await repo.load('d1');
    expect(loaded!.commanders.single.card.name, 'Atraxa');
    expect(loaded.main.single.card.name, 'Sol Ring');
    expect(loaded.mainCount, 2);
  });

  test('the same card can sit in the deck and the sideboard at once', () async {
    await repo.save(Deck(
      id: 'd2',
      name: 'duel deck',
      format: DeckFormat.standard,
      slots: [
        DeckSlot(card: _card('Sol Ring'), quantity: 2),
        DeckSlot(card: _card('Sol Ring'), quantity: 1, sideboard: true),
      ],
    ));

    final loaded = await repo.load('d2');
    expect(loaded!.mainCount, 2);
    expect(loaded.sideCount, 1);
    expect(loaded.totalCopiesOf('sol ring'), 3);
  });

  test('saving again replaces the cards instead of piling them up', () async {
    await repo.save(deck(slots: [DeckSlot(card: _card('Sol Ring'), quantity: 1)]));
    await repo.save(deck(slots: [DeckSlot(card: _card('Mountain'), quantity: 5)]));

    final loaded = await repo.load('d1');
    expect(loaded!.mainCount, 5);
    expect(loaded.quantityOf('sol ring'), 0);
  });

  test('the list is newest first and carries no cards', () async {
    await repo.save(deck());
    await repo.save(Deck(
      id: 'd2',
      name: 'pauper thing',
      format: DeckFormat.pauper,
      slots: [DeckSlot(card: _card('Sol Ring'), quantity: 1)],
    ));

    final all = await repo.list();
    expect(all.first.name, 'pauper thing');
    expect(all.first.slots, isEmpty, reason: 'the list screen shows no cards');
    expect(all.length, 2);
  });

  test('a deck remembers which game it is', () async {
    await repo.save(const Deck(
      id: 'p1',
      name: 'pikachu pile',
      format: DeckFormat.pokemonStandard,
      game: Game.pokemon,
    ));

    final loaded = await repo.load('p1');
    expect(loaded!.game, Game.pokemon);
    expect(loaded.format, DeckFormat.pokemonStandard);
  });

  test('a deck saved before games existed reads back as Magic', () async {
    // The column arrived in schema 3 with a default, so every row that
    // predates it is a Magic deck, which is what those rows actually were.
    await db.customStatement(
      "INSERT INTO decks (id, name, format, updated_at) "
      "VALUES ('old', 'from before', 'commander', 0)",
    );

    final loaded = await repo.load('old');
    expect(loaded!.game, Game.magic);
  });

  test('the two games do not see each other in the list', () async {
    await repo.save(deck());
    await repo.save(const Deck(
      id: 'p1',
      name: 'pikachu pile',
      format: DeckFormat.pokemonStandard,
      game: Game.pokemon,
    ));

    final all = await repo.list();
    expect(all.where((d) => d.game == Game.magic).length, 1);
    expect(all.where((d) => d.game == Game.pokemon).length, 1);
  });

  test('the list knows how many cards each deck has, without loading them',
      () async {
    await repo.save(deck(slots: [
      DeckSlot(card: _card('Sol Ring'), quantity: 1),
      DeckSlot(card: _card('Mountain'), quantity: 37),
    ]));
    await repo.save(const Deck(
      id: 'd2',
      name: 'empty one',
      format: DeckFormat.commander,
    ));

    final all = await repo.list();
    final full = all.firstWhere((d) => d.id == 'd1');
    final empty = all.firstWhere((d) => d.id == 'd2');

    expect(full.slots, isEmpty, reason: 'the list still does not load cards');
    expect(full.cardCount, 38);
    expect(empty.cardCount, 0,
        reason: 'an empty deck deals nothing, and its row dims itself on this');
  });

  test('the count leaves the sideboard out', () async {
    await repo.save(Deck(
      id: 'd3',
      name: 'duel',
      format: DeckFormat.standard,
      slots: [
        DeckSlot(card: _card('Sol Ring'), quantity: 4),
        DeckSlot(card: _card('Mountain'), quantity: 2, sideboard: true),
      ],
    ));

    final listed = (await repo.list()).firstWhere((d) => d.id == 'd3');
    expect(listed.cardCount, 4);
  });

  test('a loaded deck counts its own cards, not the stored number', () async {
    await repo.save(deck(slots: [DeckSlot(card: _card('Sol Ring'), quantity: 1)]));

    final loaded = await repo.load('d1');
    expect(loaded!.cardCount, 1);
    expect(loaded.slots, isNotEmpty);
  });

  test('deleting a deck takes its cards with it', () async {
    await repo.save(deck(slots: [DeckSlot(card: _card('Sol Ring'), quantity: 1)]));
    await repo.delete('d1');

    expect(await repo.load('d1'), isNull);
    expect(await repo.list(), isEmpty);

    // Reading the card table directly, because the two assertions above pass
    // perfectly well while the rows sit there orphaned. The first version of
    // this test stopped one line early and a probe walked straight through it.
    final orphans = await db.select(db.deckCards).get();
    expect(orphans, isEmpty);
  });

  test('a card missing from the catalog does not break the load', () async {
    await repo.save(deck(slots: [
      DeckSlot(card: _card('Sol Ring'), quantity: 1),
      DeckSlot(card: _card('A Card From Another Catalog'), quantity: 3),
    ]));

    final loaded = await repo.load('d1');
    expect(loaded!.mainCount, 1);
  });
}
