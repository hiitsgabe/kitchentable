import 'package:flutter/foundation.dart';

/// A pile and how many are in it, which is all the cursor needs to know.
typedef CursorZone = ({String id, int size});

/// Where the D-pad is pointing.
///
/// Left and right walk the cards, a separate button changes pile. This is the
/// half of the D-pad requirement the spec flagged as a real interaction
/// problem: a board is two dimensional and a D-pad is four directions, and
/// making up and down mean both a row change and a pile change turns every
/// zone change into an accident.
@immutable
class BoardCursor {
  const BoardCursor({required this.zoneId, required this.index});

  final String zoneId;
  final int index;

  /// Null when there is nothing to point at anywhere, which is a fresh table
  /// with an empty battlefield and a screen that should show no ring at all.
  static BoardCursor? start(List<CursorZone> zones) {
    final zone = zones.where((z) => z.size > 0).firstOrNull;
    if (zone == null) return null;
    return BoardCursor(zoneId: zone.id, index: 0);
  }

  /// Walks along the pile, clamped at both ends. Pass 0 to re-clamp after the
  /// pile has changed under it, which happens every time a card is played.
  BoardCursor step(int by, {required List<CursorZone> zones}) {
    final size = _sizeOf(zoneId, zones);
    if (size == 0) return this;
    final next = (index + by).clamp(0, size - 1);
    return BoardCursor(zoneId: zoneId, index: next);
  }

  /// Moves to the next pile with something in it, wrapping. Empty piles are
  /// skipped rather than landed on: a ring around nothing is a dead end the
  /// player has to press through.
  BoardCursor changeZone(int by, {required List<CursorZone> zones}) {
    if (zones.isEmpty) return this;
    final at = zones.indexWhere((z) => z.id == zoneId);
    if (at < 0) return this;

    for (var hop = 1; hop <= zones.length; hop++) {
      final zone = zones[(at + by * hop) % zones.length];
      if (zone.size == 0 || zone.id == zoneId) continue;
      return BoardCursor(zoneId: zone.id, index: 0);
    }
    return this;
  }

  int _sizeOf(String id, List<CursorZone> zones) =>
      zones.where((z) => z.id == id).map((z) => z.size).firstOrNull ?? 0;

  @override
  bool operator ==(Object other) =>
      other is BoardCursor && other.zoneId == zoneId && other.index == index;

  @override
  int get hashCode => Object.hash(zoneId, index);
}
