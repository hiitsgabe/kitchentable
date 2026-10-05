import 'dart:collection';

import 'draft_state.dart';

/// The host's bookkeeping for a whole draft: who sits where, which packs are
/// in front of whom, and what everybody has picked.
///
/// Pure and host-only. It is the single source of truth the design settled
/// on: one place moves packs, so the async queues stay consistent and a
/// seat's view can be handed out without ever leaking another seat's pack.
/// [DraftRoom] wraps this with a transport; this knows nothing of the wire.
///
/// Sealed is the degenerate case: every pack opens into its owner's pool at
/// once and there is nothing to pass, so everyone is building from the start.
class DraftTable {
  DraftTable({
    required this.seatIds,
    required this.sealed,
    required List<List<List<DraftCard>>> packsPerSeat,
  }) : assert(seatIds.length == packsPerSeat.length) {
    _packCount = packsPerSeat.isEmpty ? 0 : packsPerSeat.first.length;
    for (final id in seatIds) {
      _pool[id] = [];
      _queue[id] = Queue<_Pack>();
      _fresh[id] = [];
      _pickedThisRound[id] = 0;
    }
    if (sealed) {
      for (var i = 0; i < seatIds.length; i++) {
        for (final pack in packsPerSeat[i]) {
          _pool[seatIds[i]]!.addAll(pack);
        }
      }
      _round = _packCount + 1; // past the last round: everyone is building.
      return;
    }
    for (var i = 0; i < seatIds.length; i++) {
      final mine = packsPerSeat[i];
      for (var r = 1; r < mine.length; r++) {
        _fresh[seatIds[i]]!.add(_Pack(mine[r], round: r + 1, fresh: true));
      }
    }
    _round = 1;
    _openRound(packsPerSeat);
  }

  /// The seats in a circle, in pass order: round 1 passes to the next, round
  /// 2 to the previous, round 3 to the next, and so on.
  final List<String> seatIds;
  final bool sealed;

  late final int _packCount;
  int _round = 0;
  final _pool = <String, List<DraftCard>>{};
  final _queue = <String, Queue<_Pack>>{};
  final _fresh = <String, List<_Pack>>{};
  final _pickedThisRound = <String, int>{};
  int _picksThisRound = 0;
  int _targetThisRound = 0;

  List<List<List<DraftCard>>>? _packsForOpen;

  void _openRound(List<List<List<DraftCard>>> packsPerSeat) {
    _packsForOpen = packsPerSeat;
    _picksThisRound = 0;
    _targetThisRound = 0;
    for (var i = 0; i < seatIds.length; i++) {
      _pickedThisRound[seatIds[i]] = 0;
      final pack = packsPerSeat[i][_round - 1];
      _targetThisRound += pack.length;
      _queue[seatIds[i]]!.addLast(_Pack(pack, round: _round, fresh: true));
    }
  }

  /// Whether every pack is spent and the pod is done drafting.
  bool get done => !sealed && _round > _packCount;

  /// Whether the draft is over for everyone: done, or sealed.
  bool get building => sealed || done;

  int _next(int i) => (i + 1) % seatIds.length;
  int _prev(int i) => (i - 1 + seatIds.length) % seatIds.length;

  /// The seat a round-[round] pack passes to from seat [i]. Odd rounds go to
  /// the next seat, even rounds to the previous one.
  int _neighbour(int i, int round) => round.isOdd ? _next(i) : _prev(i);

  /// Takes a card out of the pack in front of [seatId] and passes the rest
  /// on. [uuid] must be in that pack, which guards against a double pick on a
  /// pack that has already moved. Does nothing once building.
  ///
  /// Returns true if the pick was taken.
  bool pick(String seatId, String uuid) {
    if (building) return false;
    final queue = _queue[seatId];
    if (queue == null || queue.isEmpty) return false;
    final front = queue.first;
    final card = front.cards.where((c) => c.uuid == uuid).firstOrNull;
    if (card == null) return false;

    queue.removeFirst();
    front.cards.remove(card);
    _pool[seatId]!.add(card);
    _pickedThisRound[seatId] = (_pickedThisRound[seatId] ?? 0) + 1;
    _picksThisRound++;

    if (front.cards.isNotEmpty) {
      final from = seatIds.indexOf(seatId);
      front.fresh = false; // a passed pack is somebody else's opened one.
      _queue[seatIds[_neighbour(from, front.round)]]!.addLast(front);
    }

    if (_picksThisRound >= _targetThisRound) _advance();
    return true;
  }

  void _advance() {
    _round++;
    if (_round > _packCount) return; // done; everyone builds.
    _openRound(_packsForOpen!);
  }

  /// What seat [seatId] can see right now.
  DraftView viewFor(String seatId) {
    final pool = List<DraftCard>.unmodifiable(_pool[seatId] ?? const []);
    if (building) {
      return DraftView(
        phase: DraftPhase.building,
        pool: pool,
        pack: null,
        packNumber: _packCount,
        pickNumber: 0,
        queueDepth: 0,
        fresh: false,
      );
    }
    final queue = _queue[seatId]!;
    if (queue.isEmpty) {
      return DraftView(
        phase: DraftPhase.waiting,
        pool: pool,
        pack: null,
        packNumber: _round,
        pickNumber: (_pickedThisRound[seatId] ?? 0) + 1,
        queueDepth: 0,
        fresh: false,
      );
    }
    final front = queue.first;
    return DraftView(
      phase: DraftPhase.picking,
      pool: pool,
      pack: List<DraftCard>.unmodifiable(front.cards),
      packNumber: front.round,
      pickNumber: (_pickedThisRound[seatId] ?? 0) + 1,
      queueDepth: queue.length - 1,
      fresh: front.fresh,
    );
  }
}

/// A pack in flight: its remaining cards, which round it belongs to (that
/// sets which way it passes), and whether the seat holding it cracked it.
class _Pack {
  _Pack(List<DraftCard> cards, {required this.round, required this.fresh})
    : cards = List<DraftCard>.from(cards);

  final List<DraftCard> cards;
  final int round;

  /// True only until the pack is first passed. The seat that opened it sees
  /// the crack-open animation; after it moves on, nobody does.
  bool fresh;
}
