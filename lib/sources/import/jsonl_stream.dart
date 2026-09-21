import 'dart:convert';

/// Turns a stream of decompressed bytes into one map per line.
///
/// Everything here is incremental on purpose. The catalog is 36000 records and
/// decoding it as one document would peak at hundreds of megabytes on a phone.
/// `utf8.decoder` as a stream transformer also carries partial characters
/// across chunk boundaries, which a per chunk `utf8.decode` would mangle.
Stream<Map<String, dynamic>> decodeJsonl(Stream<List<int>> bytes) {
  return bytes
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .where((line) => line.trim().isNotEmpty)
      .map((line) => jsonDecode(line) as Map<String, dynamic>);
}
