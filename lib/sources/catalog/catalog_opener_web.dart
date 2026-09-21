import 'package:drift/drift.dart';

/// There is no catalog in the browser. drift can run on the web, but only with
/// `sqlite3.wasm` and `drift_worker.js` shipped in `web/`, and this project does
/// not carry them: the web build exists so the interface can be looked at on a
/// machine with no display and no emulator, and importing is not available
/// there anyway because the gunzip shim refuses first.
///
/// So the catalog reports itself absent rather than half working, and the menu
/// renders honestly with zero cards.
bool get catalogIsAvailable => false;

QueryExecutor openCatalog() {
  throw UnsupportedError('There is no local catalog on the web build');
}
