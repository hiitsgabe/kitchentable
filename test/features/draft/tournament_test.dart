import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/draft/tournament.dart';

void main() {
  final names = {'a': 'A', 'b': 'B', 'c': 'C', 'd': 'D'};

  test('four players run two rounds to a champion', () {
    var t = Tournament.start(['a', 'b', 'c', 'd'], names);

    // Round 0: two games, a vs b and c vs d.
    expect(t.round, 0);
    expect(t.games.length, 2);
    expect(t.games[0].seats, ['a', 'b']);
    expect(t.games[1].seats, ['c', 'd']);
    expect(t.roundComplete, isFalse);

    t = t.withResult(t.games[0].scope, 'a');
    expect(t.roundComplete, isFalse, reason: 'one game still out');
    t = t.withResult(t.games[1].scope, 'c');
    expect(t.roundComplete, isTrue);
    expect(t.alive, ['a', 'c'], reason: 'the losers are out');
    expect(t.champion, isNull);

    // Round 1: the final, a vs c on a fresh scope.
    t = t.nextRound();
    expect(t.round, 1);
    expect(t.games.length, 1);
    expect(t.games.single.seats, ['a', 'c']);
    expect(t.games.single.scope, isNot('r0g0'));

    t = t.withResult(t.games.single.scope, 'c');
    expect(t.over, isTrue);
    expect(t.champion, 'c');
    expect(t.standings.first.seat, 'c');
    expect(t.standings.first.champion, isTrue);
  });

  test('an odd round gives the leftover a bye into the next round', () {
    var t = Tournament.start(['a', 'b', 'c'], names);
    expect(t.games.length, 1, reason: 'a vs b');
    expect(t.bye, 'c', reason: 'c sits it out');

    t = t.withResult(t.games.single.scope, 'a');
    expect(t.roundComplete, isTrue);
    t = t.nextRound();
    expect(t.alive, ['a', 'c'], reason: 'the bye went through');
    expect(t.games.single.seats, ['a', 'c']);
  });

  test('a result for a seat not in the game is ignored', () {
    final t = Tournament.start(['a', 'b', 'c', 'd'], names);
    final same = t.withResult(t.games[0].scope, 'd');
    expect(same.roundComplete, isFalse);
    expect(same.alive.length, 4);
  });
}
