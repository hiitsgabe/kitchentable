import 'post_draft.dart';

/// Where a player stands in the tournament: how many games they have won and
/// whether they are out.
typedef Standing = ({String seat, String name, int wins, bool out, bool champion});

/// A single-elimination bracket over the drafted pod.
///
/// Immutable: each result or new round makes a new tournament, the way the
/// table makes a new table from a verb. The host holds the one that counts and
/// tells the guests; nobody mints a result for anybody else.
///
/// Rounds pair the players still in, as [draftTables] does with the pairs mode,
/// so a round's games sit on scopes that no earlier round reused. A loser drops
/// out; the winners meet in the next round; one left is the champion. An odd
/// number in a round leaves one with no opponent, who sits the round out and
/// goes through, the usual bye.
class Tournament {
  const Tournament._(
    this.seats,
    this.names,
    this._wins,
    this._out,
    this.round,
    this.games,
    this._results,
  );

  factory Tournament.start(List<String> seats, Map<String, String> names) =>
      Tournament._(
        List.of(seats),
        Map.of(names),
        {for (final s in seats) s: 0},
        const {},
        0,
        draftTables(PostDraftMode.tournament, seats, round: 0),
        const {},
      );

  final List<String> seats;
  final Map<String, String> names;
  final Map<String, int> _wins;
  final Set<String> _out;

  /// Which round this is, from zero.
  final int round;

  /// The games being played this round, by scope and the two seats at each.
  final List<DraftTablePlan> games;

  /// The winner reported for each game this round, by scope.
  final Map<String, String> _results;

  /// The players still in, in pod order.
  List<String> get alive => [
    for (final s in seats)
      if (!_out.contains(s)) s,
  ];

  /// The player with no opponent this round, who goes through untouched.
  String? get bye => byeOf(alive);

  /// Whether every game this round has a winner in.
  bool get roundComplete => games.every((g) => _results.containsKey(g.scope));

  /// The champion, once one player is left standing. Null until then.
  String? get champion => alive.length == 1 ? alive.single : null;

  bool get over => champion != null;

  /// Which game a seat is playing this round, or null for the bye or once out.
  String? scopeOf(String seat) {
    for (final g in games) {
      if (g.seats.contains(seat)) return g.scope;
    }
    return null;
  }

  /// Records a game's winner, which drops its loser out. Ignores a result for a
  /// game that is not this round's, or a winner who is not in it.
  Tournament withResult(String scope, String winner) {
    final game = games.where((g) => g.scope == scope).firstOrNull;
    if (game == null || !game.seats.contains(winner)) return this;
    final loser = game.seats.firstWhere((s) => s != winner);
    return Tournament._(
      seats,
      names,
      {..._wins, winner: (_wins[winner] ?? 0) + 1},
      {..._out, loser},
      round,
      games,
      {..._results, scope: winner},
    );
  }

  /// Pairs the survivors for the next round. Call when [roundComplete]; a no-op
  /// once there is a champion.
  Tournament nextRound() {
    if (over) return this;
    return Tournament._(
      seats,
      names,
      _wins,
      _out,
      round + 1,
      draftTables(PostDraftMode.tournament, alive, round: round + 1),
      const {},
    );
  }

  List<Standing> get standings {
    final rows = [
      for (final s in seats)
        (
          seat: s,
          name: names[s] ?? s,
          wins: _wins[s] ?? 0,
          out: _out.contains(s),
          champion: champion == s,
        ),
    ];
    rows.sort((a, b) {
      if (a.champion != b.champion) return a.champion ? -1 : 1;
      if (a.out != b.out) return a.out ? 1 : -1;
      return b.wins.compareTo(a.wins);
    });
    return rows;
  }
}
