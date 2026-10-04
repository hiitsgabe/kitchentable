import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/decks/model/game.dart';
import 'package:kitchentable/sources/catalog/catalog_db.dart';
import 'package:kitchentable/sources/import/local_file_importer.dart';

Map<String, dynamic> _scryfall(String id, String name) => {
  'oracle_id': id,
  'name': name,
  'type_line': 'Instant',
  'cmc': 1,
  'image_uris': {'small': 'https://example.invalid/$id.jpg'},
};

Map<String, dynamic> _pokemon(String id, String name) => {
  'id': id,
  'name': name,
  'supertype': 'Pokémon',
  'hp': '60',
  'images': {'small': 'https://example.invalid/$id.png'},
};

Stream<List<int>> _bytes(String text, {int every = 5}) async* {
  final b = utf8.encode(text);
  for (var i = 0; i < b.length; i += every) {
    yield b.sublist(i, i + every > b.length ? b.length : i + every);
  }
}

void main() {
  late CatalogDb db;
  setUp(() => db = CatalogDb.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('a Scryfall file of lines, the way the API hands it out', () async {
    final importer = LocalFileImporter(db: db);
    await importer.indexFrom(
      _bytes(
        '${jsonEncode(_scryfall('a', 'Lightning Bolt'))}\n'
        '${jsonEncode(_scryfall('b', 'Counterspell'))}\n',
      ),
    );
    expect(await db.cardCount(game: Game.magic), 2);
    expect(importer.skipped, 0);
  });

  test('a Scryfall file as one array, the way the website hands it out', () async {
    final importer = LocalFileImporter(db: db);
    await importer.indexFrom(
      _bytes(
        '\n ${jsonEncode([_scryfall('a', 'Lightning Bolt'), _scryfall('b', 'Counterspell')])}',
      ),
    );
    expect(await db.cardCount(game: Game.magic), 2);
  });

  test('a Pokemon set file goes in as Pokemon', () async {
    final importer = LocalFileImporter(db: db);
    await importer.indexFrom(
      _bytes(jsonEncode([_pokemon('base1-58', 'Pikachu')])),
    );
    expect(await db.cardCount(game: Game.pokemon), 1);
    expect(await db.cardCount(game: Game.magic), 0);
  });

  test('a gzipped file is read through the gzip, whatever is inside', () async {
    final importer = LocalFileImporter(db: db);
    final plain = utf8.encode('${jsonEncode(_scryfall('a', 'Bolt'))}\n');
    final zipped = gzip.encode(plain);
    await importer.indexFrom(
      Stream.fromIterable([
        zipped.sublist(0, 1),
        zipped.sublist(1, 3),
        zipped.sublist(3),
      ]),
    );
    expect(await db.cardCount(), 1);
  });

  test('records of neither game are counted and left out, and progress is '
      'reported per batch', () async {
    final importer = LocalFileImporter(db: db, batchSize: 2);
    final seen = <int>[];
    await importer.indexFrom(
      _bytes(
        jsonEncode([
          _scryfall('a', 'A'),
          {'id': 'x', 'name': 'a deck list entry, not a card'},
          _pokemon('base1-1', 'Alakazam'),
          _scryfall('c', 'C'),
        ]),
      ),
      onIndexed: seen.add,
    );
    expect(await db.cardCount(), 3);
    expect(importer.skipped, 1);
    expect(seen, [2, 3]);
  });

  test('an empty file indexes nothing and throws nothing', () async {
    final importer = LocalFileImporter(db: db);
    await importer.indexFrom(const Stream.empty());
    await importer.indexFrom(_bytes('   \n'));
    expect(await db.cardCount(), 0);
  });
}
