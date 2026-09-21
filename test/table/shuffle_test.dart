import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/table/model/card_instance.dart';
import 'package:kitchentable/table/shuffle.dart';

List<CardInstance> _deck(int n) => [
      for (var i = 0; i < n; i++)
        CardInstance(id: 'c$i', oracleId: 'card$i'),
    ];

void main() {
  test('the same seed gives the same order, every time', () {
    final a = shuffleWithSeed(_deck(60), 'abc');
    final b = shuffleWithSeed(_deck(60), 'abc');

    expect(a.map((c) => c.id), b.map((c) => c.id));
  });

  test('a different seed gives a different order', () {
    final a = shuffleWithSeed(_deck(60), 'abc');
    final b = shuffleWithSeed(_deck(60), 'abd');

    expect(a.map((c) => c.id), isNot(b.map((c) => c.id)));
  });

  test('it keeps every card and invents none', () {
    final before = _deck(60);
    final after = shuffleWithSeed(before, 'abc');

    expect(after.length, 60);
    expect(after.map((c) => c.id).toSet(), before.map((c) => c.id).toSet());
  });

  test('it actually moves things', () {
    final before = _deck(60);
    final after = shuffleWithSeed(before, 'abc');

    final samePlace = [
      for (var i = 0; i < before.length; i++)
        if (before[i].id == after[i].id) i,
    ];

    // Sixty cards left entirely alone would be a shuffle that does nothing,
    // which is exactly what a subtly broken one looks like.
    expect(samePlace.length, lessThan(10));
  });

  test('a commitment matches its own seed and nothing else', () {
    final commitment = commitToSeed('abc');

    expect(seedMatches(commitment, 'abc'), isTrue);
    expect(seedMatches(commitment, 'abd'), isFalse);
  });

  test('a commitment gives nothing away about the seed', () {
    expect(commitToSeed('abc'), isNot(contains('abc')));
    expect(commitToSeed('abc').length, 64,
        reason: 'a sha256 in hex, whatever the seed was');
  });

  test('shuffling an empty pile is not an event', () {
    expect(shuffleWithSeed(const [], 'abc'), isEmpty);
  });
}
