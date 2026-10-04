import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:file_picker/file_picker.dart';

import '../../sources/catalog/catalog_db.dart';
import '../../sources/import/local_file_importer.dart';
import '../../sources/import/pokemon_importer.dart';
import '../../sources/import/scryfall_importer.dart';
import '../../sources/model/source_def.dart';
import '../menu/menu_controller.dart';
import 'imported.dart';

enum ImportPhase { idle, downloading, indexing, done, failed }

/// Two numbers, not one. Bytes are the network's business and records are the
/// device's, and a single bar over both is the one that parks at 99 percent.
class ImportState {
  const ImportState({
    this.phase = ImportPhase.idle,
    this.received = 0,
    this.total,
    this.indexed = 0,
    this.estimatedRecords = 36000,
    this.error,
  });

  final ImportPhase phase;
  final int received;
  final int? total;
  final int indexed;
  final int estimatedRecords;
  final String? error;

  /// Null means indeterminate. A server that sends no content length gets an
  /// honest spinner rather than a fake percentage.
  double? get downloadFraction {
    if (phase == ImportPhase.idle) return 0;
    final t = total;
    if (t == null || t <= 0) return null;
    return (received / t).clamp(0.0, 1.0);
  }

  double get indexFraction {
    if (estimatedRecords <= 0) return 0;
    return (indexed / estimatedRecords).clamp(0.0, 1.0);
  }

  ImportState copyWith({
    ImportPhase? phase,
    int? received,
    int? total,
    int? indexed,
    int? estimatedRecords,
    String? error,
  }) => ImportState(
    phase: phase ?? this.phase,
    received: received ?? this.received,
    total: total ?? this.total,
    indexed: indexed ?? this.indexed,
    estimatedRecords: estimatedRecords ?? this.estimatedRecords,
    error: error ?? this.error,
  );
}

class ImportNotifier extends Notifier<ImportState> {
  @override
  ImportState build() => const ImportState();

  Future<void> run(SourceDef source) async {
    final db = ref.read(catalogDbProvider);
    if (db == null) {
      state = const ImportState(
        phase: ImportPhase.failed,
        error:
            'There is no local catalog on this build, so nothing can be '
            'imported here. Use the Android build.',
      );
      return;
    }

    switch (source.kind) {
      case SourceKind.catalog when source.id == 'pokemon_tcg_data':
        await _pokemon(source, db);
      case SourceKind.catalog:
        await _scryfall(source, db);
      case SourceKind.localFile:
        await _localFile(source, db);
      case SourceKind.draftSets || SourceKind.url:
        return;
    }
  }

  /// What every road ends on: the count on the menu, the games that can
  /// build a deck, and the row in the list of sources, all told.
  Future<void> _finish(SourceDef source) async {
    state = state.copyWith(phase: ImportPhase.done);
    ref.invalidate(menuStateProvider);
    ref.invalidate(gamesWithCardsProvider);
    // Remembered by source, not just as a count. The count is what the
    // menu wants; which source it came from is what the list of sources
    // and the first run both want, and neither could tell before.
    await ref.read(importedSourcesProvider.notifier).mark(source.id);
  }

  Future<void> _pokemon(SourceDef source, CatalogDb db) async {
    final endpoint = source.endpoint;
    if (endpoint == null) return;
    final importer = PokemonImporter(db: db);
    state = ImportState(
      phase: ImportPhase.downloading,
      total: source.approximateBytes,
    );
    try {
      final sets = await importer.fetchSetIds(endpoint);
      await importer.downloadAndIndex(
        endpoint,
        sets,
        approximateTotal: source.approximateBytes,
        onBytes: (received, total) {
          state = state.copyWith(received: received, total: total);
        },
        onIndexed: (indexed) {
          state = state.copyWith(phase: ImportPhase.indexing, indexed: indexed);
        },
      );
      await _finish(source);
    } catch (e) {
      state = state.copyWith(phase: ImportPhase.failed, error: '$e');
    } finally {
      importer.dispose();
    }
  }

  /// A file the player points at. The picker is the whole of the download
  /// phase: there is nothing to receive, only something to read.
  Future<void> _localFile(SourceDef source, CatalogDb db) async {
    state = const ImportState(phase: ImportPhase.downloading);
    final file = await FilePicker.pickFile();
    if (file == null) {
      state = const ImportState(
        phase: ImportPhase.failed,
        error: 'No file was chosen.',
      );
      return;
    }
    final size = await file.length();
    final importer = LocalFileImporter(db: db);
    state = state.copyWith(received: size ?? 0, total: size);
    try {
      await importer.indexFrom(
        file.readAsByteStream(),
        onIndexed: (indexed) {
          state = state.copyWith(phase: ImportPhase.indexing, indexed: indexed);
        },
      );
      if (state.indexed == 0) {
        state = state.copyWith(
          phase: ImportPhase.failed,
          error: importer.skipped == 0
              ? 'Nothing in that file.'
              : 'Nothing in that file is a Scryfall or a Pokemon card.',
        );
        return;
      }
      await _finish(source);
    } catch (e) {
      state = state.copyWith(phase: ImportPhase.failed, error: '$e');
    }
  }

  Future<void> _scryfall(SourceDef source, CatalogDb db) async {
    final endpoint = source.endpoint;
    if (endpoint == null) return;

    final importer = ScryfallImporter(db: db);
    state = const ImportState(phase: ImportPhase.downloading);

    try {
      final bulk = await importer.fetchBulkObject(endpoint);
      final url = ScryfallImporter.jsonlUrlFrom(bulk);
      final size = ScryfallImporter.compressedSizeFrom(bulk);

      state = state.copyWith(total: size);

      await importer.downloadAndIndex(
        url,
        onBytes: (received, total) {
          state = state.copyWith(received: received, total: total ?? size);
        },
        onIndexed: (indexed) {
          state = state.copyWith(phase: ImportPhase.indexing, indexed: indexed);
        },
      );

      await _finish(source);
    } catch (e) {
      state = state.copyWith(phase: ImportPhase.failed, error: '$e');
    } finally {
      importer.dispose();
    }
  }
}

/// Whether the catalog predates the large image column. A re-import is the
/// only thing that fills it in, and nothing else on screen says so, so the
/// Sources screen is where it has to be said.
///
/// A missing catalog answers false, and so does a query that throws: telling
/// somebody to re-import is only worth doing when we know it would help.
final betterPicturesProvider = FutureProvider<bool>((ref) async {
  final db = ref.watch(catalogDbProvider);
  if (db == null) return false;
  return db.needsBetterPictures();
});

final importProvider = NotifierProvider<ImportNotifier, ImportState>(
  ImportNotifier.new,
);
