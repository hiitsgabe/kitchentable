import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/sources/model/source_def.dart';
import 'package:kitchentable/sources/source_registry.dart';

void main() {
  test('nothing is enabled out of the box', () {
    for (final source in knownSources) {
      expect(
        source.enabledByDefault,
        isFalse,
        reason: '${source.id} must not be on before a human says so',
      );
    }
  });

  test('every source that downloads declares its size', () {
    for (final source in knownSources.where((s) => s.endpoint != null)) {
      expect(
        source.approximateBytes,
        isNotNull,
        reason: '${source.id} downloads, so it must say how much',
      );
    }
  });

  test('the scryfall catalog is there and points at the bulk endpoint', () {
    final scryfall = knownSources.firstWhere((s) => s.id == 'scryfall_oracle');
    expect(scryfall.kind, SourceKind.catalog);
    expect(
      scryfall.endpoint.toString(),
      'https://api.scryfall.com/bulk-data/oracle-cards',
    );
  });

  test('ids are unique', () {
    final ids = knownSources.map((s) => s.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test(
    'pokemon and the local file are real, and draft sets are not listed',
    () {
      final ids = knownSources.map((s) => s.id).toList();
      expect(
        ids,
        isNot(contains('mtgjson_sets')),
        reason: 'a source nothing reads is a download that changes nothing',
      );
      final pokemon = knownSources.singleWhere(
        (s) => s.id == 'pokemon_tcg_data',
      );
      expect(pokemon.available, isTrue);
      expect(pokemon.endpoint!.host, 'raw.githubusercontent.com');
      expect(pokemon.endpoint!.path, endsWith('/sets/en.json'));
      expect(pokemon.approximateBytes, greaterThan(20000000));
      final local = knownSources.singleWhere((s) => s.id == 'local_file');
      expect(local.available, isTrue);
      expect(local.endpoint, isNull);
    },
  );
}
