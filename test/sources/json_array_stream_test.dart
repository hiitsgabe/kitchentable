import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/sources/import/json_array_stream.dart';

/// The bytes of [text], cut every [every] bytes, so no element arrives whole.
Stream<List<int>> _chunked(String text, int every) async* {
  final bytes = utf8.encode(text);
  for (var i = 0; i < bytes.length; i += every) {
    yield bytes.sublist(i, i + every > bytes.length ? bytes.length : i + every);
  }
}

void main() {
  test('one map per element, however the bytes are cut', () async {
    const text = '[{"id": "a", "n": 1}, {"id": "b", "n": 2},{"id":"c","n":3}]';
    for (final every in [1, 3, 7, 1000]) {
      final seen = await decodeJsonArray(_chunked(text, every)).toList();
      expect(seen.map((m) => m['id']), [
        'a',
        'b',
        'c',
      ], reason: 'cut at $every');
      expect(seen.last['n'], 3);
    }
  });

  test('braces and brackets inside strings and nested objects do not end an '
      'element early', () async {
    const text =
        '[{"name": "Mr. }{ Bracket]", "faces": [{"a": {"b": 1}}], '
        '"esc": "a \\" quote and a \\\\ slash"}]';
    final seen = await decodeJsonArray(_chunked(text, 5)).toList();
    expect(seen, hasLength(1));
    expect(seen.single['name'], 'Mr. }{ Bracket]');
    expect(seen.single['faces'], [
      {
        'a': {'b': 1},
      },
    ]);
    expect(seen.single['esc'], 'a " quote and a \\ slash');
  });

  test('an empty array and whitespace around it are nothing', () async {
    expect(await decodeJsonArray(_chunked('  \n[ ]\n', 2)).toList(), isEmpty);
  });

  test('a card with a multibyte name survives the chunking', () async {
    const text = '[{"name": "Pokémon · Stage 2"}]';
    for (final every in [1, 2, 3]) {
      final seen = await decodeJsonArray(_chunked(text, every)).toList();
      expect(seen.single['name'], 'Pokémon · Stage 2', reason: 'cut at $every');
    }
  });
}
