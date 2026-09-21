import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sources/import/scryfall_importer.dart';
import '../../sources/model/source_def.dart';
import '../menu/menu_controller.dart';

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
  }) =>
      ImportState(
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
    final endpoint = source.endpoint;
    if (endpoint == null) return;

    final db = ref.read(catalogDbProvider);
    if (db == null) {
      state = const ImportState(
        phase: ImportPhase.failed,
        error: 'There is no local catalog on this build, so nothing can be '
            'imported here. Use the Android build.',
      );
      return;
    }

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

      state = state.copyWith(phase: ImportPhase.done);
      ref.invalidate(menuStateProvider);
    } catch (e) {
      state = state.copyWith(phase: ImportPhase.failed, error: '$e');
    } finally {
      importer.dispose();
    }
  }
}

final importProvider =
    NotifierProvider<ImportNotifier, ImportState>(ImportNotifier.new);
