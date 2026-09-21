/// The web build exists so the interface can be looked at on a machine with no
/// display and no emulator. Importing 24 MB into browser storage is a separate
/// piece of work and nobody needs it yet.
Stream<List<int>> gunzipStream(Stream<List<int>> compressed) {
  throw UnsupportedError('Importing is not available on the web build');
}
