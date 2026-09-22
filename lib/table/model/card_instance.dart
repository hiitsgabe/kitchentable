import 'package:flutter/foundation.dart';

/// One card, on a table, right now.
///
/// Distinct from a CatalogCard, which is the printing. Thirty seven Mountains
/// share one catalog entry and are thirty seven of these, because each is in a
/// different place with a different amount of state on it.
@immutable
class CardInstance {
  const CardInstance({
    required this.id,
    required this.oracleId,
    this.rotation = 0,
    this.faceDown = false,
    this.counters = const {},
    this.attachedTo,
    this.position,
  });

  /// Unique on this table, not across tables. Generated when the card is dealt.
  final String id;

  /// Which printing it is. Points into the catalog.
  final String oracleId;

  /// Quarter turns clockwise. Ninety is tapped in Magic, and the table does not
  /// know that word.
  final int rotation;

  final bool faceDown;

  /// Named rather than typed, because the names belong to the game and not to
  /// the table: `+1/+1`, `loyalty`, `damage`, `energy`.
  final Map<String, int> counters;

  /// The id of the card this one is attached to. One verb for aura, equipment,
  /// energy and evolution.
  final String? attachedTo;

  /// Where on the owner's mat it sits, from 0 to 1 on each axis. Null means the
  /// layout decides, which is the default and what most players will ever see.
  final ({double x, double y})? position;

  /// Straight becomes turned, and anything else becomes straight.
  ///
  /// Not `(rotation + 90) % 360`, which was the first answer and is wrong for
  /// the gesture it is bound to: four taps walked a card through upside down
  /// on the way back to where it started. Upside down is a thing somebody
  /// means, so it belongs on the menu and not on the way past.
  CardInstance turned() => copyWith(rotation: rotation == 0 ? 90 : 0);

  /// An exact angle, for the menu. Quarter turns, and it does not toggle.
  CardInstance turnedTo(int degrees) =>
      copyWith(rotation: degrees % 360);

  CardInstance flipped() => copyWith(faceDown: !faceDown);

  CardInstance withCounter(String kind, int by) {
    final next = Map<String, int>.from(counters);
    final total = (next[kind] ?? 0) + by;
    if (total == 0) {
      next.remove(kind);
    } else {
      next[kind] = total;
    }
    return copyWith(counters: next);
  }

  CardInstance copyWith({
    int? rotation,
    bool? faceDown,
    Map<String, int>? counters,
    String? attachedTo,
    bool clearAttachment = false,
    ({double x, double y})? position,
    bool clearPosition = false,
  }) =>
      CardInstance(
        id: id,
        oracleId: oracleId,
        rotation: rotation ?? this.rotation,
        faceDown: faceDown ?? this.faceDown,
        counters: counters ?? this.counters,
        attachedTo: clearAttachment ? null : (attachedTo ?? this.attachedTo),
        position: clearPosition ? null : (position ?? this.position),
      );

  @override
  bool operator ==(Object other) =>
      other is CardInstance && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
