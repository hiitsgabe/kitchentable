import 'dart:convert';
import 'dart:typed_data';

/// Turns a stream of bytes holding one JSON array of objects into one map
/// per element, without ever holding the array.
///
/// Scryfall's bulk files on the website are arrays, not lines, and so is
/// every set file in pokemon-tcg-data. The oracle catalog is 150 MB as an
/// array, which `jsonDecode` would want in memory three times over on a
/// phone. This walks the bytes once, counting braces outside strings, and
/// decodes each top level object on its own the moment it closes.
///
/// Only the array's own structure is read here. What is inside an element
/// is handed to `jsonDecode` whole, so anything it would refuse is refused
/// the same way.
Stream<Map<String, dynamic>> decodeJsonArray(Stream<List<int>> bytes) async* {
  const openBrace = 0x7B, closeBrace = 0x7D;
  const openBracket = 0x5B, closeBracket = 0x5D;
  const quote = 0x22, backslash = 0x5C;

  var inArray = false;
  var depth = 0;
  var inString = false;
  var escaped = false;
  BytesBuilder? element;

  await for (final chunk in bytes) {
    var from = 0;
    for (var i = 0; i < chunk.length; i++) {
      final b = chunk[i];

      if (!inArray) {
        if (b == openBracket) inArray = true;
        from = i + 1;
        continue;
      }

      if (element == null) {
        if (b == openBrace) {
          element = BytesBuilder(copy: false);
          depth = 1;
          from = i;
        } else if (b == closeBracket) {
          return;
        }
        continue;
      }

      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (b == backslash) {
          escaped = true;
        } else if (b == quote) {
          inString = false;
        }
        continue;
      }

      if (b == quote) {
        inString = true;
      } else if (b == openBrace) {
        depth++;
      } else if (b == closeBrace) {
        depth--;
        if (depth == 0) {
          element.add(
            Uint8List.sublistView(
              chunk is Uint8List ? chunk : Uint8List.fromList(chunk),
              from,
              i + 1,
            ),
          );
          yield jsonDecode(utf8.decode(element.takeBytes()))
              as Map<String, dynamic>;
          element = null;
          from = i + 1;
        }
      }
    }
    if (element != null && from < chunk.length) {
      element.add(Uint8List.fromList(chunk.sublist(from)));
    }
  }
}
