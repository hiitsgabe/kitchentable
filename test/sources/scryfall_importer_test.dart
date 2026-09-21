import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/sources/catalog/catalog_db.dart';
import 'package:kitchentable/sources/import/scryfall_importer.dart';

String _record(String id, String name) => jsonEncode({
      'oracle_id': id,
      'name': name,
      'type_line': 'Creature - Elf',
      'cmc': 2,
      'color_identity': ['G'],
      'legalities': {'commander': 'legal'},
      'image_uris': {'small': 'https://example.invalid/$id.jpg'},
    });

void main() {
  late CatalogDb db;

  setUp(() => db = CatalogDb.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('it indexes every record it is handed', () async {
    final importer = ScryfallImporter(db: db, batchSize: 2);

    await importer.indexFrom(Stream.fromIterable([
      utf8.encode('${_record('a', 'Llanowar Elves')}\n'
          '${_record('b', 'Sol Ring')}\n'
          '${_record('c', 'Birds of Paradise')}\n'),
    ]));

    expect(await db.cardCount(), 3);
  });

  test('it reports how many records it has written', () async {
    final importer = ScryfallImporter(db: db, batchSize: 2);
    final seen = <int>[];

    await importer.indexFrom(
      Stream.fromIterable([
        utf8.encode('${_record('a', 'A')}\n${_record('b', 'B')}\n'
            '${_record('c', 'C')}\n'),
      ]),
      onIndexed: seen.add,
    );

    expect(seen.last, 3);
    expect(seen, isNotEmpty);
  });

  test('a record missing oracle_id is skipped rather than killing the import',
      () async {
    final importer = ScryfallImporter(db: db, batchSize: 10);

    await importer.indexFrom(Stream.fromIterable([
      utf8.encode('${_record('a', 'A')}\n'
          '${jsonEncode({'name': 'no id here'})}\n'
          '${_record('b', 'B')}\n'),
    ]));

    expect(await db.cardCount(), 2);
    expect(importer.skipped, 1);
  });

  test('it finds the jsonl url in a bulk object', () {
    final url = ScryfallImporter.jsonlUrlFrom({
      'object': 'bulk_data',
      'type': 'oracle_cards',
      'jsonl_download_uri': 'https://data.scryfall.io/oracle-cards/x.jsonl.gz',
      'compressed_size': 24710557,
    });

    expect(url.toString(), 'https://data.scryfall.io/oracle-cards/x.jsonl.gz');
  });

  test('a bulk object without the jsonl field fails loudly', () {
    expect(
      () => ScryfallImporter.jsonlUrlFrom({'object': 'bulk_data'}),
      throwsA(isA<FormatException>()),
    );
  });
}
