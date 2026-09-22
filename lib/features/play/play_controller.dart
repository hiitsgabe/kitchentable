import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../decks/model/deck.dart';
import '../../table/actions/table_action.dart';
import '../../table/model/table_state.dart';
import '../../table/referee/referee.dart';
import '../../table/setup.dart';
import '../../table/shuffle.dart';
import '../../table/table_session.dart';

/// The table currently being played, or null when nobody is at one.
/// Why the last action was turned down.
///
/// A provider of its own rather than a field, and that is not decoration. A
/// refused action leaves the table exactly as it was, by design, so
/// `ref.watch(playProvider)` gets no notification and the screen never
/// rebuilds. A field here would be written, never read, and silently useless:
/// it was, for exactly one commit.
class PlayRefusal extends Notifier<Refusal?> {
  @override
  Refusal? build() => null;

  void say(Refusal? refusal) => state = refusal;
}

final playRefusalProvider =
    NotifierProvider<PlayRefusal, Refusal?>(PlayRefusal.new);

class PlayController extends Notifier<TableState?> {
  TableSession? _session;
  Referee _referee = const PermissiveReferee();


  @override
  TableState? build() => null;

  void start(Deck deck, {String? seed}) {
    final table = sitDown(
      deck: deck,
      seatName: 'you',
      seed: seed ?? freshSeed(),
    );
    _session = TableSession(table);
    _clearRefusal();
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
      // Not thrown and not swallowed. The screen listens to the refusal
      // provider and says this out loud, which is the behaviour a real engine
      // will need on the day it arrives.
      ref.read(playRefusalProvider.notifier).say(refusal);
      return;
    }

    _clearRefusal();
    session.run(action);
    state = session.state;
  }

  void undo() {
    final session = _session;
    if (session == null) return;
    session.undo();
    _clearRefusal();
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
    _clearRefusal();
    state = null;
  }

  void _clearRefusal() => ref.read(playRefusalProvider.notifier).say(null);

  /// Kept so a caller can ask without watching. The screen watches instead.
  Refusal? get lastRefusal => ref.read(playRefusalProvider);
}

final playProvider =
    NotifierProvider<PlayController, TableState?>(PlayController.new);
