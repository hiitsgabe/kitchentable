/// What a pod does once the draft is built.
///
/// The host picks one when every deck is in. [oneTable] seats the whole pod
/// together, the casual pod. [pairs] splits it into parallel 1v1 games, the
/// divider. [tournament] is [pairs] in rounds, with the winners re-paired.
enum PostDraftMode {
  oneTable,
  pairs,
  tournament;

  String get label => switch (this) {
    PostDraftMode.oneTable => 'One table',
    PostDraftMode.pairs => '1v1 games',
    PostDraftMode.tournament => 'Tournament',
  };

  String get blurb => switch (this) {
    PostDraftMode.oneTable => 'the whole pod at one table',
    PostDraftMode.pairs => 'split into parallel one-on-ones',
    PostDraftMode.tournament => 'one-on-ones in rounds, winners move on',
  };
}

/// One table a mode makes: the game's [scope] on the shared transport and the
/// seats at it. An empty scope is the single pod table; a named one is a game
/// that shares the transport with the others and ignores their messages.
typedef DraftTablePlan = ({String scope, List<String> seats});

/// The tables a mode makes from the seats, which arrive host first.
///
/// [oneTable] is one table with everybody on the empty scope. [pairs] and the
/// first round of [tournament] cut the seats into consecutive twos, each on its
/// own scope; an odd seat left over sits the round out, which [byeOf] names.
/// A [round] shifts the scopes so a later tournament round does not reuse an
/// earlier one's.
List<DraftTablePlan> draftTables(
  PostDraftMode mode,
  List<String> seats, {
  int round = 0,
}) {
  if (mode == PostDraftMode.oneTable) {
    return [(scope: '', seats: List.of(seats))];
  }
  return [
    for (var i = 0; i + 1 < seats.length; i += 2)
      (scope: 'r${round}g${i ~/ 2}', seats: [seats[i], seats[i + 1]]),
  ];
}

/// The seat with no opponent this round, or null when everyone is paired.
String? byeOf(List<String> seats) =>
    seats.length.isOdd ? seats.last : null;
