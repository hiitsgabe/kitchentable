import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kitchentable/decks/model/game.dart';
import 'package:kitchentable/sources/catalog/catalog_db.dart';
import 'package:kitchentable/sources/import/pokemon_importer.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';

/// A record the way pokemon-tcg-data writes one, trimmed to what matters.
Map<String, dynamic> _card(String id, String name, {String? hp}) => {
  'id': id,
  'name': name,
  'supertype': 'Pokémon',
  'subtypes': ['Stage 2'],
  'hp': hp ?? '120',
  'types': ['Fire'],
  'abilities': [
    {'name': 'Energy Burn', 'text': 'All Energy attached count as Fire.'},
  ],
  'attacks': [
    {'name': 'Fire Spin', 'damage': '100', 'text': 'Discard 2 Energy.'},
  ],
  'rarity': 'Rare Holo',
  'legalities': {'unlimited': 'Legal'},
  'images': {
    'small': 'https://example.invalid/$id.png',
    'large': 'https://example.invalid/${id}_hires.png',
  },
};

final _sets = Uri.parse('https://example.invalid/data/sets/en.json');

void main() {
  late CatalogDb db;
  setUp(() => db = CatalogDb.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('the record', () {
    test('reads as a Pokemon card in the catalog shape', () {
      final card = CatalogCard.fromPokemon(_card('base1-4', 'Charizard'));
      expect(card.game, Game.pokemon);
      expect(card.oracleId, 'base1-4');
      expect(card.setCode, 'base1', reason: 'the set is the front of the id');
      expect(card.typeLine, 'Pokémon · Stage 2 · Fire');
      expect(card.power, '120');
      expect(card.oracleText, contains('Fire Spin 100: Discard 2 Energy.'));
      expect(card.oracleText, contains('Energy Burn:'));
      expect(card.legalities, {
        'unlimited': 'legal',
      }, reason: 'legal is lowercase here, the way isLegalIn reads it');
      expect(
        card.imageNormal,
        endsWith('_hires.png'),
        reason: 'the small file is a blur at table size',
      );
      expect(card.imageSmall, endsWith('base1-4.png'));
    });

    test('a trainer has rules and no hp', () {
      final card = CatalogCard.fromPokemon({
        'id': 'sv1-1',
        'name': 'Rare Candy',
        'supertype': 'Trainer',
        'subtypes': ['Item'],
        'rules': ['Evolve a Pokémon in play.'],
        'images': {'small': 'https://example.invalid/sv1-1.png'},
      });
      expect(card.typeLine, 'Trainer · Item');
      expect(card.power, isNull);
      expect(card.oracleText, 'Evolve a Pokémon in play.');
      expect(
        card.imageNormal,
        endsWith('sv1-1.png'),
        reason: 'with no large file the small one stands in',
      );
    });
  });

  test('every set in the list is fetched from beside it and indexed', () async {
    final asked = <String>[];
    final client = MockClient.streaming((request, body) async {
      asked.add(request.url.path);
      final path = request.url.path;
      final text = switch (path) {
        '/data/sets/en.json' => jsonEncode([
          {'id': 'base1', 'name': 'Base'},
          {'id': 'base2', 'name': 'Jungle'},
        ]),
        '/data/cards/en/base1.json' => jsonEncode([
          _card('base1-4', 'Charizard'),
          _card('base1-58', 'Pikachu', hp: '40'),
        ]),
        '/data/cards/en/base2.json' => jsonEncode([
          _card('base2-1', 'Clefable'),
        ]),
        _ => '[]',
      };
      return http.StreamedResponse(
        Stream.value(utf8.encode(text)),
        path.contains('nowhere') ? 404 : 200,
      );
    });
    final importer = PokemonImporter(db: db, client: client, batchSize: 2);

    final sets = await importer.fetchSetIds(_sets);
    expect(sets, ['base1', 'base2']);

    final bytes = <int>[];
    final counts = <int>[];
    await importer.downloadAndIndex(
      _sets,
      sets,
      approximateTotal: 1000,
      onBytes: (received, total) => bytes.add(received),
      onIndexed: counts.add,
    );

    expect(asked, [
      '/data/sets/en.json',
      '/data/cards/en/base1.json',
      '/data/cards/en/base2.json',
    ]);
    expect(await db.cardCount(game: Game.pokemon), 3);
    expect(await db.cardCount(game: Game.magic), 0);
    expect(counts, [2, 3], reason: 'the count carries across set files');
    expect(bytes, isNotEmpty);
    expect(bytes.last, greaterThan(bytes.first));
    expect(importer.skipped, 0);
  });

  test('a set the repository will not give up is the whole import failing', () {
    final client = MockClient.streaming(
      (request, body) async =>
          http.StreamedResponse(Stream.value(utf8.encode('')), 404),
    );
    final importer = PokemonImporter(db: db, client: client);
    expect(
      importer.downloadAndIndex(_sets, ['base1']),
      throwsA(isA<http.ClientException>()),
    );
  });

  test('a record it cannot read is counted and the rest go in', () async {
    final importer = PokemonImporter(db: db);
    await importer.indexFrom(
      Stream.value(
        utf8.encode(
          jsonEncode([
            {'name': 'no id'},
            _card('base1-4', 'Charizard'),
          ]),
        ),
      ),
    );
    expect(await db.cardCount(), 1);
    expect(importer.skipped, 1);
  });
}
