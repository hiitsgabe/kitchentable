import 'dart:convert';

import 'package:http/http.dart' as http;

import '../catalog/catalog_db.dart';
import '../model/draft_set.dart';
import 'gunzip.dart';
import 'json_array_stream.dart';
import 'scryfall_importer.dart' show fileHeaders;

/// Pulls what a draft needs out of MTGJSON, in two sizes.
///
/// The set list first, which is what the source imports: every set that
/// exists, 2.5 MB gzipped, into [CatalogDb.insertDraftSets]. A set's packs
/// are not in the list. They are in the set's own file, a megabyte or so
/// gzipped, and [fetchSet] reads one when a draft asks for that set: the
/// booster recipes, kept as MTGJSON wrote them, and every printing with its
/// Scryfall oracle id, which is how a sheet of uuids becomes cards the
/// catalog can draw.
///
/// Both files are `{meta, data}` documents and both are read through the
/// gzip they are served in. The list streams, because its 871 entries
/// carry every sealed product ever sold and come to 12 MB; a set file is
/// read whole, because 4 MB is fine and its booster object is one value.
class MtgjsonImporter {
  MtgjsonImporter({required this.db, this.batchSize = 200, http.Client? client})
    : _client = client ?? http.Client();

  final CatalogDb db;
  final int batchSize;
  final http.Client _client;

  /// Entries we could not read. Kept rather than thrown.
  int skipped = 0;

  /// See [fileHeaders]: a custom header here is a 403 from a browser.
  static const headers = fileHeaders;

  /// Where a set's own file is, beside the list.
  static Uri setUrlFor(Uri listEndpoint, String code) =>
      listEndpoint.resolve('${code.toUpperCase()}.json.gz');

  /// Reads the set list into the catalog, reporting bytes as they land.
  Future<int> downloadSetList(
    Uri listEndpoint, {
    void Function(int received, int? total)? onBytes,
    void Function(int indexed)? onIndexed,
  }) async {
    final response = await _get(listEndpoint);
    var received = 0;
    final counted = response.stream.map((chunk) {
      received += chunk.length;
      onBytes?.call(received, response.contentLength);
      return chunk;
    });
    return indexSetList(gunzipStream(counted), onIndexed: onIndexed);
  }

  /// Takes the decompressed list, so tests never need gzip or a socket.
  Future<int> indexSetList(
    Stream<List<int>> decompressed, {
    void Function(int indexed)? onIndexed,
  }) async {
    var buffer = <DraftSet>[];
    var indexed = 0;

    Future<void> flush() async {
      if (buffer.isEmpty) return;
      await db.insertDraftSets(buffer);
      indexed += buffer.length;
      onIndexed?.call(indexed);
      buffer = <DraftSet>[];
    }

    // The document is {meta, data: [...]}, and the first bracket in it is
    // the data array: meta is two strings.
    await for (final record in decodeJsonArray(decompressed)) {
      try {
        buffer.add(DraftSet.fromMtgjson(record));
      } catch (_) {
        skipped++;
        continue;
      }
      if (buffer.length >= batchSize) await flush();
    }
    await flush();
    return indexed;
  }

  /// Fetches one set's file and stores its packs and printings.
  Future<void> fetchSet(Uri listEndpoint, String code) async {
    final response = await _get(setUrlFor(listEndpoint, code));
    final bytes = <int>[];
    await for (final chunk in gunzipStream(response.stream)) {
      bytes.addAll(chunk);
    }
    await storeSet(code, utf8.decode(bytes));
  }

  /// Takes the decompressed set file, so tests never need gzip or a socket.
  Future<void> storeSet(String code, String document) async {
    final data =
        (jsonDecode(document) as Map<String, dynamic>)['data']
            as Map<String, dynamic>;
    final setCode = (data['code'] as String?) ?? code.toUpperCase();
    final booster = data['booster'] ?? const <String, dynamic>{};
    final printings = <DraftPrinting>[];
    for (final c in (data['cards'] as List<dynamic>?) ?? const []) {
      try {
        printings.add(
          DraftPrinting.fromMtgjson(setCode, c as Map<String, dynamic>),
        );
      } catch (_) {
        skipped++;
      }
    }
    await db.storeDraftSet(setCode, jsonEncode(booster), printings);
  }

  Future<http.StreamedResponse> _get(Uri url) async {
    final request = http.Request('GET', url)..headers.addAll(headers);
    final response = await _client.send(request);
    if (response.statusCode != 200) {
      throw http.ClientException(
        'MTGJSON answered ${response.statusCode}',
        url,
      );
    }
    return response;
  }

  void dispose() => _client.close();
}
