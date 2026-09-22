import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../decks/model/deck.dart';
import '../../table/actions/table_action.dart';
import '../../table/model/table_state.dart';
import '../../table/referee/referee.dart';
import '../../table/setup.dart';
import '../../table/shuffle.dart';
import '../../table/table_session.dart';

/// The table currently being played, or null when nobody is at one.
class PlayController extends Notifier<TableState?> {
  TableSession? _session;
  Referee _referee = const PermissiveReferee();

  /// Why the last action was turned down, for the screen to say out loud.
  /// Always null while the permissive referee is the only one there is.
  Refusal? lastRefusal;

  @override
  TableState? build() => null;

  void start(Deck deck, {String? seed}) {
    final table = sitDown(
      deck: deck,
      seatName: 'you',
      seed: seed ?? freshSeed(),
    );
    _session = TableSession(table);
    lastRefusal = null;
    state = table;
  }

  /// Swaps the referee. There is one, and the seat is built so a real engine
  /// can take it without the screen noticing.
  void useReferee(Referee referee) => _referee = referee;

  void run(TableAction action) {
    final session = _session;
    if (session == null) return;

    final refusal = _referee.review(session.state, action);
    if (refusal != null) {
      lastRefusal = refusal;
      // Deliberately not rethrowing or swallowing. The screen reads this and
      // says it, which is the behaviour a real engine will need on day one.
      return;
    }

    lastRefusal = null;
    session.run(action);
    state = session.state;
  }

  void undo() {
    final session = _session;
    if (session == null) return;
    session.undo();
    lastRefusal = null;
    state = session.state;
  }

  bool get canUndo => _session?.canUndo ?? false;

  List<String>? legalTargetsFor(String cardId) {
    final session = _session;
    if (session == null) return null;
    return _referee.legalTargets(session.state, cardId);
  }

  void leave() {
    _session = null;
    lastRefusal = null;
    state = null;
  }
}

final playProvider =
    NotifierProvider<PlayController, TableState?>(PlayController.new);
