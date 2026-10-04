import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/sources/catalog/catalog_db.dart';
import 'package:kitchentable/sources/import/mtgjson_importer.dart';
import 'package:kitchentable/sources/model/draft_set.dart';

Map<String, dynamic> _set(
  String code,
  String name, {
  String type = 'expansion',
}) => {
  'code': code,
  'name': name,
  'type': type,
  'releaseDate': '2024-02-09',
  'baseSetSize': 286,
  'totalSetSize': 451,
  'isOnlineOnly': false,
  // What makes the real list 12 MB, and what a reader that stopped at the
  // first closing brace would choke on.
  'sealedProduct': [
    {
      'name': '$name Play Booster Box',
      'contents': {
        'pack': [
          {'code': code, 'set': 'x'},
        ],
      },
    },
  ],
};

String _list(List<Map<String, dynamic>> sets) => jsonEncode({
  'meta': {'date': '2026-10-04', 'version': '5.3.0'},
  'data': sets,
});

String _setFile(String code) => jsonEncode({
  'meta': {'date': '2026-10-04'},
  'data': {
    'code': code,
    'name': 'Murders at Karlov Manor',
    'booster': {
      'play': {
        'boosters': [
          {
            'contents': {'common': 7, 'rare': 1},
            'weight': 1,
          },
        ],
        'boostersTotalWeight': 1,
        'sheets': {
          'common': {
            'cards': {'u1': 1, 'u2': 1},
            'foil': false,
            'totalWeight': 2,
          },
          'rare': {
            'cards': {'u3': 1},
            'foil': false,
            'totalWeight': 1,
          },
        },
      },
    },
    'cards': [
      {
        'uuid': 'u1',
        'name': 'A',
        'rarity': 'common',
        'number': '1',
        'boosterTypes': ['default'],
        'identifiers': {'scryfallOracleId': 'o1'},
      },
      {
        'uuid': 'u2',
        'name': 'B',
        'rarity': 'common',
        'number': '2',
        'boosterTypes': ['default', 'collector'],
        'identifiers': {'scryfallOracleId': 'o2'},
      },
      {
        'uuid': 'u3',
        'name': 'C',
        'rarity': 'rare',
        'number': '3',
        'identifiers': {},
      },
    ],
  },
});

void main() {
  late CatalogDb db;
  setUp(() => db = CatalogDb.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('the set list goes in, newest first, with no packs yet', () async {
    final importer = MtgjsonImporter(db: db, batchSize: 2);
    final seen = <int>[];
    final count = await importer.indexSetList(
      Stream.value(
        utf8.encode(
          _list([
            _set('MKM', 'Murders at Karlov Manor'),
            _set('LEA', 'Limited Edition Alpha', type: 'core'),
            _set('PMKM', 'Promos', type: 'promo'),
          ]),
        ),
      ),
      onIndexed: seen.add,
    );
    expect(count, 3);
    expect(seen, [2, 3]);
    expect(importer.skipped, 0);
    final sets = await db.draftSetList();
    expect(sets.map((s) => s.code), ['MKM', 'LEA', 'PMKM']);
    expect(sets.first.name, 'Murders at Karlov Manor');
    expect(sets.first.fetched, isFalse);
  });

  test('a set fetched keeps its packs through a later list import', () async {
    final importer = MtgjsonImporter(db: db);
    await importer.indexSetList(
      Stream.value(utf8.encode(_list([_set('MKM', 'MKM')]))),
    );
    await importer.storeSet('mkm', _setFile('MKM'));

    final set = await db.draftSet('MKM');
    expect(set!.fetched, isTrue);
    final booster = jsonDecode(set.booster!) as Map<String, dynamic>;
    expect((booster['play'] as Map)['sheets'], contains('common'));

    final printings = await db.draftPrintingsOf('MKM');
    expect(printings.map((p) => p.uuid), unorderedEquals(['u1', 'u2', 'u3']));
    expect(printings.singleWhere((p) => p.uuid == 'u2').boosterTypes, [
      'default',
      'collector',
    ]);
    expect(printings.singleWhere((p) => p.uuid == 'u2').oracleId, 'o2');
    expect(
      printings.singleWhere((p) => p.uuid == 'u3').oracleId,
      '',
      reason: 'a printing with no Scryfall id is kept and says so',
    );

    // The list again: the row is updated, the packs stay.
    await importer.indexSetList(
      Stream.value(utf8.encode(_list([_set('MKM', 'Renamed')]))),
    );
    final again = await db.draftSet('MKM');
    expect(again!.name, 'Renamed');
    expect(again.fetched, isTrue);
    expect(await db.draftSetCount(), 1);
  });

  test('fetching a set twice leaves one copy of its printings', () async {
    final importer = MtgjsonImporter(db: db);
    await importer.indexSetList(
      Stream.value(utf8.encode(_list([_set('MKM', 'MKM')]))),
    );
    await importer.storeSet('MKM', _setFile('MKM'));
    await importer.storeSet('MKM', _setFile('MKM'));
    expect(await db.draftPrintingsOf('MKM'), hasLength(3));
  });

  test('a set file lives beside the list, by its code in capitals', () {
    final list = Uri.parse('https://mtgjson.com/api/v5/SetList.json.gz');
    expect(
      MtgjsonImporter.setUrlFor(list, 'mkm').toString(),
      'https://mtgjson.com/api/v5/MKM.json.gz',
    );
  });

  test('a set the list cannot read is counted and the rest go in', () async {
    final importer = MtgjsonImporter(db: db);
    await importer.indexSetList(
      Stream.value(
        utf8.encode(
          _list([
            {'name': 'no code'},
            _set('MKM', 'MKM'),
          ]),
        ),
      ),
    );
    expect(await db.draftSetCount(), 1);
    expect(importer.skipped, 1);
  });

  test('a row reads back as it went in', () {
    final set = DraftSet.fromMtgjson(_set('MKM', 'Murders at Karlov Manor'));
    expect(set.type, 'expansion');
    expect(set.releaseDate, '2024-02-09');
    expect(set.baseSetSize, 286);
    expect(set.onlineOnly, isFalse);
  });
}
