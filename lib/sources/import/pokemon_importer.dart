import 'dart:convert';

import 'package:http/http.dart' as http;

import '../catalog/catalog_db.dart';
import '../model/catalog_card.dart';
import 'json_array_stream.dart';
import 'scryfall_importer.dart' show fileHeaders;

/// Pulls the Pokemon catalog out of pokemon-tcg-data, one set at a time.
///
/// The repository is the data behind the Pokemon TCG API, kept as plain
/// files: `sets/en.json` lists the sets and `cards/en/<set>.json` holds
/// each one's cards as an array. There is no bulk file to fetch, so this
/// reads the list and then every set, which is 176 requests and 27 MB, and
/// it is read straight off the repository rather than through the API,
/// because the API is scheduled to go away in 2027 and the files are not.
class PokemonImporter {
  PokemonImporter({required this.db, this.batchSize = 500, http.Client? client})
    : _client = client ?? http.Client();

  final CatalogDb db;
  final int batchSize;
  final http.Client _client;

  /// Records we could not read. Kept rather than thrown so one bad card
  /// does not cost the player the download.
  int skipped = 0;

  /// See [fileHeaders]: a custom header here is a 403 from a browser.
  static const headers = fileHeaders;

  /// The set ids in the list the endpoint points at, in its order.
  Future<List<String>> fetchSetIds(Uri setsEndpoint) async {
    final response = await _client.get(setsEndpoint, headers: headers);
    if (response.statusCode != 200) {
      throw http.ClientException(
        'pokemon-tcg-data answered ${response.statusCode}',
        setsEndpoint,
      );
    }
    final sets = jsonDecode(response.body) as List<dynamic>;
    return [for (final s in sets) (s as Map<String, dynamic>)['id'] as String];
  }

  /// Where a set's cards live, beside the list of sets.
  static Uri cardsUrlFor(Uri setsEndpoint, String setId) =>
      setsEndpoint.resolve('../cards/en/$setId.json');

  /// Fetches every set and indexes it, reporting bytes as they land.
  ///
  /// [approximateTotal] is the size the registry quotes, because the files
  /// come one at a time and no single response knows the whole.
  Future<void> downloadAndIndex(
    Uri setsEndpoint,
    List<String> setIds, {
    int? approximateTotal,
    void Function(int received, int? total)? onBytes,
    void Function(int indexed)? onIndexed,
  }) async {
    var received = 0;
    var indexed = 0;
    for (final setId in setIds) {
      final url = cardsUrlFor(setsEndpoint, setId);
      final request = http.Request('GET', url)..headers.addAll(headers);
      final response = await _client.send(request);
      if (response.statusCode != 200) {
        throw http.ClientException(
          'pokemon-tcg-data answered ${response.statusCode}',
          url,
        );
      }
      final counted = response.stream.map((chunk) {
        received += chunk.length;
        onBytes?.call(received, approximateTotal);
        return chunk;
      });
      indexed = await indexFrom(
        counted,
        already: indexed,
        onIndexed: onIndexed,
      );
    }
  }

  /// Indexes one set file's bytes. Returns the running total so the next
  /// set carries on counting from it.
  Future<int> indexFrom(
    Stream<List<int>> bytes, {
    int already = 0,
    void Function(int indexed)? onIndexed,
  }) async {
    var buffer = <CatalogCard>[];
    var indexed = already;

    Future<void> flush() async {
      if (buffer.isEmpty) return;
      await db.insertAll(buffer);
      indexed += buffer.length;
      onIndexed?.call(indexed);
      buffer = <CatalogCard>[];
    }

    await for (final record in decodeJsonArray(bytes)) {
      try {
        buffer.add(CatalogCard.fromPokemon(record));
      } catch (_) {
        skipped++;
        continue;
      }
      if (buffer.length >= batchSize) await flush();
    }
    await flush();
    return indexed;
  }

  void dispose() => _client.close();
}
