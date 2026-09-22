import 'package:flutter/foundation.dart';

import 'seat_owner.dart';
import 'zone.dart';

/// One player's side of the table.
@immutable
class Seat {
  const Seat({
    required this.id,
    required this.name,
    required this.life,
    required this.zones,
    this.owner = const SeatOwner.empty(),
  });

  final String id;
  final String name;

  /// Life in Magic, prize cards taken in Pokemon, points in whatever comes
  /// next. The table counts it and has no opinion about what it means.
  final int life;

  final List<Zone> zones;

  /// Who is holding this chair. Empty until somebody sits.
  final SeatOwner owner;

  Zone? zone(String zoneId) =>
      zones.where((z) => z.id == zoneId).firstOrNull;

  Seat copyWith({String? name, int? life, List<Zone>? zones, SeatOwner? owner}) =>
      Seat(
        id: id,
        name: name ?? this.name,
        life: life ?? this.life,
        zones: zones ?? this.zones,
        owner: owner ?? this.owner,
      );
}
