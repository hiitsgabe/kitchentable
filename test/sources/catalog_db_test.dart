import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/decks/model/game.dart';
import 'package:kitchentable/sources/catalog/catalog_db.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';

CatalogCard _card(String id, String name) => CatalogCard(
  oracleId: id,
  name: name,
  typeLine: 'Creature - Elf',
  cmc: 2,
  legalities: const {'commander': 'legal', 'standard': 'not_legal'},
);

void main() {
  test(
    'a search can be held to one game, and the games are what is there',
    () async {
      final db = CatalogDb.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      expect(await db.gamesWithCards(), isEmpty);

      await db.insertAll(const [
        CatalogCard(
          oracleId: 'm1',
          name: 'Charizard, Cousin',
          typeLine: 'Creature',
          cmc: 4,
        ),
        CatalogCard(
          oracleId: 'base1-4',
          name: 'Charizard',
          typeLine: 'Pokémon',
          cmc: 0,
          game: Game.pokemon,
        ),
      ]);

      expect(
        (await db.searchByName('chariz')).map((c) => c.oracleId),
        unorderedEquals(['m1', 'base1-4']),
      );
      expect(
        (await db.searchByName(
          'chariz',
          game: Game.pokemon,
        )).map((c) => c.oracleId),
        ['base1-4'],
      );
      expect(
        (await db.searchByName(
          'chariz',
          game: Game.magic,
        )).map((c) => c.oracleId),
        ['m1'],
      );
      expect(await db.cardCount(game: Game.pokemon), 1);
      expect(await db.gamesWithCards(), {Game.magic, Game.pokemon});
      // The game comes back off the row, not off a default.
      expect(
        (await db.cardsByOracleIds(['base1-4'])).single.game,
        Game.pokemon,
      );
    },
  );

  late CatalogDb db;

  setUp(() => db = CatalogDb.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('an empty catalog counts zero', () async {
    expect(await db.cardCount(), 0);
  });

  test('inserted cards are counted', () async {
    await db.insertAll([_card('a', 'Llanowar Elves'), _card('b', 'Birds')]);
    expect(await db.cardCount(), 2);
  });

  test(
    'inserting the same oracle id twice replaces rather than duplicates',
    () async {
      await db.insertAll([_card('a', 'Llanowar Elves')]);
      await db.insertAll([_card('a', 'Llanowar Elves')]);
      expect(await db.cardCount(), 1);
    },
  );

  test('search finds by part of the name, ignoring case', () async {
    await db.insertAll([_card('a', 'Llanowar Elves'), _card('b', 'Sol Ring')]);
    final hits = await db.searchByName('elv');
    expect(hits.map((c) => c.name), ['Llanowar Elves']);
  });

  test('legalities survive the round trip', () async {
    await db.insertAll([_card('a', 'Llanowar Elves')]);
    final hits = await db.searchByName('Llanowar');
    expect(hits.single.isLegalIn('commander'), isTrue);
    expect(hits.single.isLegalIn('standard'), isFalse);
  });

  test('clearing empties the catalog', () async {
    await db.insertAll([_card('a', 'Llanowar Elves')]);
    await db.clear();
    expect(await db.cardCount(), 0);
  });
}
