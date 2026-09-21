import 'dart:convert';

import 'package:http/http.dart' as http;

import '../catalog/catalog_db.dart';
import '../model/catalog_card.dart';
import 'gunzip.dart';
import 'jsonl_stream.dart';

/// Scryfall asks every client to identify itself and to stay under ten
/// requests a second. We make two requests per import, so the rate is somebody
/// else's problem, but the header is ours.
const scryfallHeaders = {
  'User-Agent': 'kitchentable/0.1',
  'Accept': 'application/json',
};

class ScryfallImporter {
  ScryfallImporter({
    required this.db,
    this.batchSize = 500,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final CatalogDb db;
  final int batchSize;
  final http.Client _client;

  /// Records we could not read. Kept rather than thrown so one bad line does
  /// not cost the player a 24 MB download.
  int skipped = 0;

  /// As of 2026 the bulk object carries `jsonl_download_uri` and
  /// `compressed_size`. The older `download_uri` and `size` are gone.
  static Uri jsonlUrlFrom(Map<String, dynamic> bulk) {
    final raw = bulk['jsonl_download_uri'];
    if (raw is! String) {
      throw const FormatException(
        'Scryfall bulk object has no jsonl_download_uri',
      );
    }
    return Uri.parse(raw);
  }

  static int? compressedSizeFrom(Map<String, dynamic> bulk) =>
      (bulk['compressed_size'] as num?)?.toInt();

  Future<Map<String, dynamic>> fetchBulkObject(Uri endpoint) async {
    final response = await _client.get(endpoint, headers: scryfallHeaders);
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Scryfall answered ${response.statusCode}',
        endpoint,
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Streams the gzipped file, reporting bytes as they land.
  Future<void> downloadAndIndex(
    Uri jsonlUrl, {
    void Function(int received, int? total)? onBytes,
    void Function(int indexed)? onIndexed,
  }) async {
    final request = http.Request('GET', jsonlUrl)
      ..headers.addAll({'User-Agent': scryfallHeaders['User-Agent']!});
    final response = await _client.send(request);

    if (response.statusCode != 200) {
      throw http.ClientException(
        'Scryfall answered ${response.statusCode}',
        jsonlUrl,
      );
    }

    final total = response.contentLength;
    var received = 0;

    final counted = response.stream.map((chunk) {
      received += chunk.length;
      onBytes?.call(received, total);
      return chunk;
    });

    await indexFrom(gunzipStream(counted), onIndexed: onIndexed);
  }

  /// Takes decompressed bytes so the tests never need gzip or a socket.
  Future<void> indexFrom(
    Stream<List<int>> decompressed, {
    void Function(int indexed)? onIndexed,
  }) async {
    var buffer = <CatalogCard>[];
    var indexed = 0;

    Future<void> flush() async {
      if (buffer.isEmpty) return;
      await db.insertAll(buffer);
      indexed += buffer.length;
      onIndexed?.call(indexed);
      buffer = <CatalogCard>[];
    }

    await for (final record in decodeJsonl(decompressed)) {
      try {
        buffer.add(CatalogCard.fromScryfall(record));
      } catch (_) {
        skipped++;
        continue;
      }
      if (buffer.length >= batchSize) await flush();
    }

    await flush();
  }

  void dispose() => _client.close();
}
