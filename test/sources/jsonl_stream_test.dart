import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/sources/import/jsonl_stream.dart';

Stream<List<int>> _chunks(List<String> pieces) async* {
  for (final piece in pieces) {
    yield utf8.encode(piece);
  }
}

void main() {
  test('it yields one map per line', () async {
    final out = await decodeJsonl(
      _chunks(['{"name":"Sol Ring"}\n{"name":"Llanowar Elves"}\n']),
    ).toList();

    expect(out.map((m) => m['name']), ['Sol Ring', 'Llanowar Elves']);
  });

  test('a record split across two chunks still arrives whole', () async {
    final out = await decodeJsonl(
      _chunks(['{"name":"Sol ', 'Ring"}\n']),
    ).toList();

    expect(out.single['name'], 'Sol Ring');
  });

  test('a last line with no trailing newline is not dropped', () async {
    final out = await decodeJsonl(
      _chunks(['{"a":1}\n{"b":2}']),
    ).toList();

    expect(out.length, 2);
  });

  test('blank lines are skipped rather than throwing', () async {
    final out = await decodeJsonl(
      _chunks(['{"a":1}\n\n\n{"b":2}\n']),
    ).toList();

    expect(out.length, 2);
  });

  test('a card with an accent survives the utf8 boundary', () async {
    final bytes = utf8.encode('{"name":"Ætherize"}\n');
    final out = await decodeJsonl(
      Stream.fromIterable([bytes.sublist(0, 10), bytes.sublist(10)]),
    ).toList();

    expect(out.single['name'], 'Ætherize');
  });
}
