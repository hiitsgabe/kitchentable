import 'dart:async';

import '../catalog/catalog_db.dart';
import '../model/catalog_card.dart';
import 'gunzip.dart';
import 'json_array_stream.dart';
import 'jsonl_stream.dart';

/// A dump already on the device: a Scryfall bulk file or a Pokemon set file,
/// as the sites hand them out.
///
/// Nothing is asked about the file. Gzip is read off its first two bytes,
/// an array off its first character against a line of objects, and the
/// game off each record: a Scryfall record has an `oracle_id` and a Pokemon
/// one a `supertype`. A record that is neither is counted in [skipped] and
/// left out, so a file of the wrong kind ends with nothing indexed and a
/// count that says why rather than an exception halfway through.
class LocalFileImporter {
  LocalFileImporter({required this.db, this.batchSize = 500});

  final CatalogDb db;
  final int batchSize;

  int skipped = 0;

  static const _gzipMagic = [0x1F, 0x8B];

  Future<void> indexFrom(
    Stream<List<int>> raw, {
    void Function(int indexed)? onIndexed,
  }) async {
    final it = StreamIterator(raw);
    final head = <int>[];
    while (head.length < 2 && await it.moveNext()) {
      head.addAll(it.current);
    }
    if (head.isEmpty) return;

    var bytes = _withHead(head, it);
    if (head.length >= 2 &&
        head[0] == _gzipMagic[0] &&
        head[1] == _gzipMagic[1]) {
      bytes = gunzipStream(bytes);
    }

    // The first non blank byte says array or lines. Peeked again after the
    // gunzip, because the compressed head says nothing about the shape.
    final peek = StreamIterator(bytes);
    final lead = <int>[];
    var first = -1;
    while (first < 0 && await peek.moveNext()) {
      lead.addAll(peek.current);
      first = lead.indexWhere(
        (b) => b != 0x20 && b != 0x0A && b != 0x0D && b != 0x09,
      );
    }
    if (first < 0) return;
    final body = _withHead(lead, peek);
    final records = lead[first] == 0x5B
        ? decodeJsonArray(body)
        : decodeJsonl(body);

    var buffer = <CatalogCard>[];
    var indexed = 0;
    Future<void> flush() async {
      if (buffer.isEmpty) return;
      await db.insertAll(buffer);
      indexed += buffer.length;
      onIndexed?.call(indexed);
      buffer = <CatalogCard>[];
    }

    await for (final record in records) {
      final card = _read(record);
      if (card == null) {
        skipped++;
        continue;
      }
      buffer.add(card);
      if (buffer.length >= batchSize) await flush();
    }
    await flush();
  }

  CatalogCard? _read(Map<String, dynamic> record) {
    try {
      if (record.containsKey('oracle_id')) {
        return CatalogCard.fromScryfall(record);
      }
      if (record.containsKey('supertype')) {
        return CatalogCard.fromPokemon(record);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static Stream<List<int>> _withHead(
    List<int> head,
    StreamIterator<List<int>> rest,
  ) async* {
    yield head;
    while (await rest.moveNext()) {
      yield rest.current;
    }
  }
}
