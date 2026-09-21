import 'package:flutter/foundation.dart';

import 'card_instance.dart';
import 'seat.dart';
import 'zone.dart';

/// Where a card was found, and in which pile.
typedef CardLocation = ({CardInstance card, Zone zone});

/// Everything on the table, at one moment.
///
/// Immutable, and every verb in `actions/` turns one of these into the next.
/// That is what makes undo a list rather than a pile of inverse operations,
/// and it is what lets plan 3 broadcast a state instead of a diff.
@immutable
class TableState {
  const TableState({
    required this.seats,
    this.turnSeatId,
    this.dice = const [],
  });

  final List<Seat> seats;

  /// Null before anybody has started. The table tracks whose turn it is and
  /// enforces nothing about it.
  final String? turnSeatId;

  /// The last roll, kept so everybody sees the same number.
  final List<int> dice;

  Iterable<Zone> get allZones => seats.expand((s) => s.zones);

  Zone? zone(String zoneId) =>
      allZones.where((z) => z.id == zoneId).firstOrNull;

  Seat? seat(String seatId) =>
      seats.where((s) => s.id == seatId).firstOrNull;

  CardLocation? locate(String cardId) {
    for (final zone in allZones) {
      final card = zone.find(cardId);
      if (card != null) return (card: card, zone: zone);
    }
    return null;
  }

  TableState withZone(Zone zone) => copyWith(
        seats: [
          for (final seat in seats)
            if (seat.id != zone.seatId)
              seat
            else
              seat.copyWith(
                zones: [
                  for (final z in seat.zones) z.id == zone.id ? zone : z,
                ],
              ),
        ],
      );

  TableState withLife(String seatId, int by) => copyWith(
        seats: [
          for (final seat in seats)
            seat.id == seatId ? seat.copyWith(life: seat.life + by) : seat,
        ],
      );

  TableState passTurn() {
    if (seats.isEmpty) return this;
    final at = seats.indexWhere((s) => s.id == turnSeatId);
    final next = seats[(at + 1) % seats.length];
    return copyWith(turnSeatId: next.id);
  }

  TableState copyWith({
    List<Seat>? seats,
    String? turnSeatId,
    List<int>? dice,
  }) =>
      TableState(
        seats: seats ?? this.seats,
        turnSeatId: turnSeatId ?? this.turnSeatId,
        dice: dice ?? this.dice,
      );
}
