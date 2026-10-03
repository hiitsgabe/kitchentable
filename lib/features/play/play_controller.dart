import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../decks/model/deck.dart';
import '../../decks/model/game.dart';
import '../../sources/model/catalog_card.dart';
import '../../net/mesh.dart';
import '../../table/actions/table_action.dart';
import '../../table/model/seat.dart';
import '../../table/model/seat_owner.dart';
import '../../table/model/table_state.dart';
import '../../table/referee/referee.dart';
import '../../table/setup.dart';
import '../../table/shuffle.dart';
import '../../table/table_session.dart';
import '../lobby/lobby.dart';
import 'table_news.dart';

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

final playRefusalProvider = NotifierProvider<PlayRefusal, Refusal?>(
  PlayRefusal.new,
);

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
    if (seat == null || !seat.owner.actableHere(me: _meOf(ref))) return false;
    state = seatId;
    return true;
  }

  /// Seats the viewer without asking. Only for opening and closing a table,
  /// where there is nothing to refuse yet.
  void sit(String? seatId) => state = seatId;
}

/// This phone's key on the transport, or null with no room around the table,
/// which is the solo and pod-on-one-device paths: there every seat is held
/// [SeatOwner.here] and the key is never compared.
String? _meOf(Ref ref) => ref.read(transportProvider)?.me;

final viewerSeatProvider = NotifierProvider<ViewerSeat, String?>(
  ViewerSeat.new,
);

class PlayController extends Notifier<TableState?> {
  /// The table when it is on this device alone: solo, or the pod on one
  /// tablet. Null while a mesh has it, so there is exactly one place a verb
  /// goes and undo cannot quietly rewind a table the other phones still hold.
  TableSession? _session;

  /// The table when it is on every phone. Verbs go through it and come back
  /// through [Mesh.tables], this phone's own included, so the state here is
  /// whatever the mesh holds and never a step ahead of it.
  Mesh? _mesh;
  StreamSubscription<TableState>? _following;
  StreamSubscription<Played>? _listening;
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

  /// Which cards each seat started in its command zone.
  ///
  /// Here for the third time for the third reason of the same shape: a
  /// [CardInstance] does not know it is a commander. The deck marks the slot,
  /// `sitDown` puts those cards in the command zone before it shuffles, and
  /// from the moment one is cast it is an ordinary instance on a battlefield.
  /// The deck is in reach exactly once, so what it said is kept here.
  ///
  /// Not on the table, because the table moves cards between zones and could
  /// not tell a Commander deck from a Pokemon one, and not on the referee,
  /// which reviews an action and refuses it. Sending a card somewhere else is
  /// a different verb, and the chair is still empty.
  Map<String, Set<String>> _commanders = const {};

  /// The printing of every card the decks at this table were dealt from.
  ///
  /// The fourth of the same shape, for the same reason: the decklist is in
  /// reach exactly once. The screen looks a card up in the catalog, which is
  /// the right answer for a token and the wrong one for a table dealt from a
  /// deck the catalog no longer carries, or from no catalog at all. A guest
  /// gets this from the lobby, which carries every printing over the wire;
  /// a table dealt here had nowhere to get it and drew its own cards as
  /// blanks.
  Map<String, CatalogCard> _dealtFrom = const {};

  Map<String, CatalogCard> get printingsDealt => _dealtFrom;

  bool isCommander(String cardId) =>
      _commanders.values.any((ids) => ids.contains(cardId));

  @override
  TableState? build() {
    ref.onDispose(() {
      _following?.cancel();
      _listening?.cancel();
    });
    return null;
  }

  /// Whatever holds the table right now, whichever of the two it is.
  TableState? get _table => _mesh?.table ?? _session?.state;

  void start(Deck deck, {String? seed, int? life}) => startPod(
    players: [(deck: deck, name: 'you', owner: const SeatOwner.here())],
    seed: seed,
    life: life,
  );

  /// Everybody at this device. Solo comes through here too: one player is a
  /// pod of one, and a separate path for it is how the one seat case drifts
  /// away from the four seat one without anybody noticing.
  ///
  /// [life] is what the room plays to, when a room said so. Null leaves every
  /// seat on whatever its format starts at, which is every table opened without
  /// a room around it.
  void startPod({required List<Player> players, String? seed, int? life}) {
    if (players.isEmpty) return;

    var table = sitDownTogether(players: players, seed: seed ?? freshSeed());
    if (life != null) {
      // Set rather than nudged by a difference. Two decks in different formats
      // at one table start on two different numbers, and a room that says
      // thirty means thirty for everybody in it.
      table = table.copyWith(
        seats: [for (final seat in table.seats) seat.copyWith(life: life)],
      );
    }
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
        table.seats[i].id: players[i].deck.main.fold(
          0,
          (n, s) => n + s.quantity,
        ),
    };
    _commanders = _commandersOf(table);
    _dealtFrom = {
      for (final player in players)
        for (final slot in player.deck.slots) slot.card.oracleId: slot.card,
    };
    _session = TableSession(table);
    _clearRefusal();
    state = table;
    _sitAt(table);
  }

  /// Sits down at a table another phone dealt.
  ///
  /// The guest's way in. The mesh was handed the table by whoever is hosting,
  /// and this seeds the controller from that rather than from a deal: nothing
  /// here mints a card, because a table dealt on two phones is two tables.
  ///
  /// [decks] is what this phone holds, by the key of whoever brought it. On a
  /// guest that is the one it brought, so the game and the deck size are
  /// known for its own seat and nobody else's; the screen draws the rest
  /// with what the table itself says.
  void join(Mesh mesh, {Map<String, Deck> decks = const {}}) {
    final table = mesh.table;
    if (table == null) {
      throw StateError(
        'the mesh has not been handed the table yet, so there is nothing to '
        'sit down at. Wait for it to arrive: a controller seeded from a guess '
        'would be playing a different game from everybody else.',
      );
    }

    Deck? deckOf(Seat seat) => decks[seat.owner.peerId];
    _games = {
      for (final seat in table.seats)
        if (deckOf(seat) case final deck?) seat.id: deck.game,
    };
    _deckSizes = {
      for (final seat in table.seats)
        if (deckOf(seat) case final deck?)
          seat.id: deck.main.fold(0, (n, s) => n + s.quantity),
    };
    _commanders = _commandersOf(table);
    _clearRefusal();
    state = table;
    _sitAt(table);
    follow(mesh);
  }

  /// Hands the table to a mesh. From here every verb goes through it and every
  /// verb it hears lands here, until [leave].
  ///
  /// The host's way in, after it dealt: the lobby built the mesh around the
  /// table this controller already holds. The session is let go rather than
  /// kept beside the mesh, because a second copy of the table that no verb
  /// reaches is one that undo would rewind to.
  void follow(Mesh mesh) {
    _following?.cancel();
    _listening?.cancel();
    _mesh = mesh;
    _session = null;
    _following = mesh.tables.listen((table) => state = table);
    // The second half of the mesh: the table says what is true and this says
    // what somebody did. A screen cannot tell a die that was thrown from a
    // die that happens to read differently, and it cannot name the thrower
    // from a state at all.
    _listening = mesh.verbs.listen(
      (played) => ref
          .read(tableNewsProvider.notifier)
          .say(by: played.by, action: played.action, table: _table),
    );
  }

  /// Read off the zone rather than off the decklist, so a card that reached
  /// the command zone by any other road is counted the same way. Empty in a
  /// format without commanders: magicZonesFor makes no such zone.
  static Map<String, Set<String>> _commandersOf(TableState table) => {
    for (final seat in table.seats)
      seat.id: (table.zone('command-${seat.id}')?.cards ?? [])
          .map((c) => c.id)
          .toSet(),
  };

  /// Looks out of the first seat this device may act for, or none.
  void _sitAt(TableState table) {
    final here = table.seats
        .where((s) => s.owner.actableHere(me: _meOf(ref)))
        .firstOrNull;
    ref.read(viewerSeatProvider.notifier).sit(here?.id);
  }

  /// Swaps the referee. There is one, and the seat is built so a real engine
  /// can take it without the screen noticing.
  void useReferee(Referee referee) => _referee = referee;

  void run(TableAction action) {
    final table = _table;
    if (table == null) return;

    final refusal = _referee.review(table, action);
    if (refusal != null) {
      // Not thrown and not swallowed. The screen listens to the refusal
      // provider and says this out loud, which is the behaviour a real engine
      // will need on the day it arrives.
      ref.read(playRefusalProvider.notifier).say(refusal);
      return;
    }

    _clearRefusal();
    final mesh = _mesh;
    if (mesh != null) {
      // The mesh applies it here first and puts it on every wire, and what it
      // holds is read back at once rather than waited for on the stream: a
      // caller that runs two verbs in a row reads the table between them.
      mesh.run(action);
      state = mesh.table;
      return;
    }
    final session = _session!;
    session.run(action);
    state = session.state;
  }

  void undo() {
    if (_mesh != null) {
      // Refused and said so, not thrown and not quietly dropped. Undo rewinds
      // this phone's history and the table is on every phone: whose undo
      // travels, and how far, is a decision nobody has made yet, and until
      // somebody does the honest thing is to say no out loud.
      ref
          .read(playRefusalProvider.notifier)
          .say(
            const Refusal(
              'Undo stays on this phone and the table is on every phone, so it '
              'is off while other people are at it.',
            ),
          );
      return;
    }
    final session = _session;
    if (session == null) return;
    session.undo();
    _clearRefusal();
    state = session.state;
  }

  bool get canUndo => _session?.canUndo ?? false;

  List<String>? legalTargetsFor(String cardId) {
    final table = _table;
    if (table == null) return null;
    return _referee.legalTargets(table, cardId);
  }

  void leave() {
    _following?.cancel();
    _following = null;
    // Not closed. The mesh is the lobby's and the transport under it belongs
    // to whoever made it; leaving the table stops listening to it, no more.
    _mesh = null;
    _session = null;
    _games = const {};
    _deckSizes = const {};
    _commanders = const {};
    _clearRefusal();
    ref.read(viewerSeatProvider.notifier).sit(null);
    state = null;
  }

  void _clearRefusal() => ref.read(playRefusalProvider.notifier).say(null);

  /// Kept so a caller can ask without watching. The screen watches instead.
  Refusal? get lastRefusal => ref.read(playRefusalProvider);
}

final playProvider = NotifierProvider<PlayController, TableState?>(
  PlayController.new,
);
