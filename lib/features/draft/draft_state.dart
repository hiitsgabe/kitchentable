/// One card as it moves through a draft: enough to pick it and, later, to
/// look it up in the catalog for its name and picture.
class DraftCard {
  const DraftCard({
    required this.uuid,
    required this.oracleId,
    required this.rarity,
  });

  /// The printing's MTGJSON uuid, which is what a booster sheet names and
  /// what a pick is sent as, so a stale pack cannot be picked from twice.
  final String uuid;

  /// Scryfall's oracle id, the catalog's key. Empty for a printing the
  /// catalog has never heard of, which then draws as a nameless back.
  final String oracleId;
  final String rarity;

  Map<String, Object?> toJson() => {
    'uuid': uuid,
    'oracleId': oracleId,
    'rarity': rarity,
  };

  static DraftCard fromJson(Map<String, Object?> json) => DraftCard(
    uuid: json['uuid']! as String,
    oracleId: (json['oracleId'] as String?) ?? '',
    rarity: (json['rarity'] as String?) ?? '',
  );
}

/// What a player is doing in the draft right now.
enum DraftPhase {
  /// A pack is in front of them to pick from.
  picking,

  /// Their queue is empty: a neighbour has not passed one along yet.
  waiting,

  /// The packs are spent; it is time to build a deck from the pool.
  building,
}

/// Everything one player can see of the draft: their own pack and pool, and
/// nothing of anybody else's. The host sends one of these to each seat; a
/// seat never learns what another is holding.
class DraftView {
  const DraftView({
    required this.phase,
    required this.pool,
    required this.pack,
    required this.packNumber,
    required this.pickNumber,
    required this.queueDepth,
    required this.fresh,
  });

  final DraftPhase phase;

  /// Everything this seat has picked, in pick order.
  final List<DraftCard> pool;

  /// The pack in front of them, or null while waiting or building.
  final List<DraftCard>? pack;

  /// Which round this pack belongs to (1-based), for the "Pack 2" label.
  final int packNumber;

  /// How many picks this seat has made this round, plus one, for "Pick 5".
  final int pickNumber;

  /// How many more packs are stacked behind the current one.
  final int queueDepth;

  /// Whether the current pack is one this seat just cracked open, so the
  /// opening animation plays. False for a pack passed along by a neighbour.
  final bool fresh;

  Map<String, Object?> toJson() => {
    'phase': phase.name,
    'pool': [for (final c in pool) c.toJson()],
    'pack': pack == null ? null : [for (final c in pack!) c.toJson()],
    'packNumber': packNumber,
    'pickNumber': pickNumber,
    'queueDepth': queueDepth,
    'fresh': fresh,
  };

  static DraftView fromJson(Map<String, Object?> json) => DraftView(
    phase: DraftPhase.values.byName(json['phase']! as String),
    pool: [
      for (final c in (json['pool'] as List? ?? const []))
        DraftCard.fromJson((c as Map).cast<String, Object?>()),
    ],
    pack: json['pack'] == null
        ? null
        : [
            for (final c in (json['pack'] as List))
              DraftCard.fromJson((c as Map).cast<String, Object?>()),
          ],
    packNumber: (json['packNumber'] as num).toInt(),
    pickNumber: (json['pickNumber'] as num).toInt(),
    queueDepth: (json['queueDepth'] as num).toInt(),
    fresh: json['fresh'] == true,
  );
}
