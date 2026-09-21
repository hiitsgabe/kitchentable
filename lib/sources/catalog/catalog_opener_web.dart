import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

bool get catalogIsAvailable => true;

/// drift runs in a browser, but only with two files served next to the app:
/// `sqlite3.wasm` and `drift_worker.js`. They live in `web/` and are taken from
/// the drift release matching the version in pubspec, currently 2.35.0. If drift
/// is upgraded they have to be re downloaded from the matching release, and
/// nothing in the build will remind you.
///
/// Without them `driftDatabase` throws ArgumentError before a single pixel is
/// drawn, which is how the browser build first died: fifty three tests green
/// behind a screen that never appeared.
QueryExecutor openCatalog() => driftDatabase(
      name: 'catalog',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
