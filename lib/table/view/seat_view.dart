import 'package:flutter/foundation.dart';

import '../model/card_instance.dart';
import '../model/seat.dart';
import '../model/zone.dart';

/// A pile as one viewer sees it.
@immutable
class ZoneView {
  const ZoneView({
    required this.id,
    required this.label,
    required this.count,
    required this.readable,
    required this.cards,
  });

  final String id;
  final String label;

  /// How many are in there. Public even when the contents are not, because at
  /// a real table everybody can see how many cards somebody is holding.
  final int count;

  /// Whether this viewer may read the contents.
  final bool readable;

  /// The cards, when readable. Empty otherwise, and empty means empty: a card
  /// this viewer may not see never reaches here at all.
  final List<CardInstance> cards;
}

/// A seat as one viewer sees it.
///
/// Built rather than filtered at the widget, for two reasons. A card that
/// reaches the screen can be read off the widget tree whether or not it was
/// drawn, and plan 3 sends exactly this over a wire, where a card nobody may
/// see must not travel.
@immutable
class SeatView {
  const SeatView({
    required this.seatId,
    required this.name,
    required this.life,
    required this.zones,
    required this.isViewer,
  });

  final String seatId;
  final String name;
  final int life;
  final List<ZoneView> zones;

  /// True when this is the seat doing the looking.
  final bool isViewer;

  ZoneView? zone(String zoneId) =>
      zones.where((z) => z.id == zoneId).firstOrNull;

  static SeatView of(Seat seat, {required String viewer}) => SeatView(
        seatId: seat.id,
        name: seat.name,
        life: seat.life,
        isViewer: seat.id == viewer,
        zones: [
          for (final zone in seat.zones) _viewOf(zone, viewer),
        ],
      );

  static ZoneView _viewOf(Zone zone, String viewer) {
    final readable = zone.visibility.seenBy(viewer, owner: zone.seatId);
    return ZoneView(
      id: zone.id,
      label: zone.label,
      count: zone.size,
      readable: readable,
      cards: readable ? zone.cards : const [],
    );
  }
}
