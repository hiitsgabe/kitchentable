import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../decks/model/deck.dart';
import '../../decks/model/game.dart';
import '../../table/actions/table_action.dart';
import '../../table/model/seat_owner.dart';
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

/// Which seat this device is looking out of.
///
/// A provider of its own rather than a field on [TableState], for the same
/// reason the refusal is one: looking through a different seat does not change
/// the table, so a field there would notify nobody. It is also the one thing
/// here that is about this device and not about the game, which is why plan 3
/// replicates the table and never this.
class ViewerSeat extends Notifier<String?> {
  @override
  String? build() => null;

  /// Refuses a chair this device is not in. Looking out of somebody else's
  /// seat is the exact thing [SeatView] exists to prevent, so the guard lives
  /// with the state and not in the screen, which is not the only caller it
  /// will ever have.
  bool look(String seatId) {
    final seat = ref.read(playProvider)?.seat(seatId);
    if (seat == null || !seat.owner.actableHere) return false;
    state = seatId;
    return true;
  }

  /// Seats the viewer without asking. Only for opening and closing a table,
  /// where there is nothing to refuse yet.
  void sit(String? seatId) => state = seatId;
}

final viewerSeatProvider =
    NotifierProvider<ViewerSeat, String?>(ViewerSeat.new);

class PlayController extends Notifier<TableState?> {
  TableSession? _session;
  Referee _referee = const PermissiveReferee();

  /// Which game each seat's deck came from.
  ///
  /// Here and not on [TableState] because the table is game agnostic on
  /// purpose: it moves cards between zones and could not tell a Commander
  /// deck from a Pokemon one. The deck knows, and the deck is only in reach
  /// while the table is being opened, so what it said is kept here for
  /// whoever has to draw a card back afterwards.
  Map<String, Game> _games = const {};

  Game? gameAt(String seatId) => _games[seatId];

  /// How many cards each seat's library started with.
  ///
  /// Here for the same reason the game is: the table cannot tell how much of a
  /// deck has been drawn, only how much is left, and the decklist is in reach
  /// exactly once. The pile is drawn as the fraction of itself that remains,
  /// so without this a deck of sixty and a deck of a hundred would both look
  /// like whatever twelve cards look like.
  Map<String, int> _deckSizes = const {};

  int? deckSizeAt(String seatId) => _deckSizes[seatId];


  @override
  TableState? build() => null;

  void start(Deck deck, {String? seed}) => startPod(
        players: [(deck: deck, name: 'you', owner: const SeatOwner.here())],
        seed: seed,
      );

  /// Everybody at this device. Solo comes through here too: one player is a
  /// pod of one, and a separate path for it is how the one seat case drifts
  /// away from the four seat one without anybody noticing.
  void startPod({required List<Player> players, String? seed}) {
    if (players.isEmpty) return;

    final table = sitDownTogether(players: players, seed: seed ?? freshSeed());
    // sitDownTogether seats the players in the order they arrived, so the
    // two lists line up. Matching on the id it minted would tie this to that
    // id's spelling instead.
    _games = {
      for (var i = 0; i < table.seats.length; i++)
        table.seats[i].id: players[i].deck.game,
    };
    // The main deck and not `mainCount`, which folds the commander in for the
    // hundred card rule: `sitDown` sends a commander to the command zone, so
    // the library never held it and a deck counted with it in would never
    // look quite full. Taken before the opening hand is dealt, which is the
    // point: a table that has just been opened is already seven cards down.
    _deckSizes = {
      for (var i = 0; i < table.seats.length; i++)
        table.seats[i].id:
            players[i].deck.main.fold(0, (n, s) => n + s.quantity),
    };
    _session = TableSession(table);
    _clearRefusal();
    state = table;

    final here = table.seats.where((s) => s.owner.actableHere).firstOrNull;
    ref.read(viewerSeatProvider.notifier).sit(here?.id);
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
    _games = const {};
    _clearRefusal();
    ref.read(viewerSeatProvider.notifier).sit(null);
    state = null;
  }

  void _clearRefusal() => ref.read(playRefusalProvider.notifier).say(null);

  /// Kept so a caller can ask without watching. The screen watches instead.
  Refusal? get lastRefusal => ref.read(playRefusalProvider);
}

final playProvider =
    NotifierProvider<PlayController, TableState?>(PlayController.new);
