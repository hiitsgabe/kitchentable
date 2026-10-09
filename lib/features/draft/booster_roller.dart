import 'dart:convert';
import 'dart:math';

import '../../sources/model/draft_set.dart';

/// Rolls a booster pack from a set's MTGJSON recipe.
///
/// A set file carries a `booster` object: one entry per product kind
/// ("play", "draft", "collector"...). Each kind lists weighted pack layouts
/// in `boosters` and the `sheets` the layouts draw from, each sheet a bag of
/// printing uuids with weights. Rolling a pack is: pick a layout by weight,
/// then for each sheet the layout names, draw that many printings by weight.
///
/// Deterministic for a given [Random], so the host's rolls can be replayed
/// and a test can assert exactly what comes out.
class BoosterRoller {
  BoosterRoller({
    required this.booster,
    required this.printings,
    Random? random,
  }) : _random = random ?? Random();

  /// The set's `booster` object, decoded.
  final Map<String, dynamic> booster;

  /// The set's printings by uuid, so a rolled uuid becomes a card the catalog
  /// knows through its oracle id.
  final Map<String, DraftPrinting> printings;

  final Random _random;

  factory BoosterRoller.forSet(
    DraftSet set,
    List<DraftPrinting> printings, {
    Random? random,
  }) {
    final raw = set.booster;
    final booster = raw == null
        ? const <String, dynamic>{}
        : jsonDecode(raw) as Map<String, dynamic>;
    return BoosterRoller(
      booster: booster,
      printings: {for (final p in printings) p.uuid: p},
      random: random,
    );
  }

  /// Which product to draft, most preferred first. "draft" is the old Draft
  /// Booster, "play" the Play Booster that replaced it in 2024; a set has one
  /// or the other. Collector, sample and arena products are never drafted.
  static const _prefer = ['draft', 'play', 'set', 'default'];

  /// The product kind this rolls, or null if the set has no draftable one.
  String? get kind {
    for (final name in _prefer) {
      if (booster.containsKey(name)) return name;
    }
    for (final name in booster.keys) {
      final n = name.toLowerCase();
      if (!n.contains('collector') &&
          !n.contains('sample') &&
          !n.contains('arena')) {
        return name;
      }
    }
    return null;
  }

  bool get canRoll => kind != null;

  /// One pack: the printings it holds, in the order the layout names its
  /// sheets. Empty when the set cannot be drafted.
  List<DraftPrinting> rollPack() {
    final k = kind;
    if (k == null) return const [];
    final product = booster[k] as Map<String, dynamic>;
    final layouts = (product['boosters'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    if (layouts.isEmpty) return const [];
    final sheets = (product['sheets'] as Map<String, dynamic>?) ?? const {};

    final layoutTotal =
        ((product['boostersTotalWeight'] as num?) ??
                layouts.fold<num>(
                  0,
                  (a, b) => a + ((b['weight'] as num?) ?? 1),
                ))
            .toInt();
    final layout = _pick(
      layouts,
      (b) => ((b['weight'] as num?) ?? 1).toInt(),
      layoutTotal,
    );

    final contents = (layout['contents'] as Map<String, dynamic>);
    final pack = <DraftPrinting>[];
    for (final entry in contents.entries) {
      final sheet = sheets[entry.key] as Map<String, dynamic>?;
      if (sheet == null) continue;
      pack.addAll(_drawFromSheet(sheet, (entry.value as num).toInt()));
    }
    return pack;
  }

  /// Draws [count] printings from a sheet by weight, without repeating a
  /// printing within the draw while the sheet still has others: a real pack
  /// never hands you two of the same common.
  List<DraftPrinting> _drawFromSheet(Map<String, dynamic> sheet, int count) {
    final pool = (sheet['cards'] as Map<String, dynamic>).map(
      (uuid, weight) => MapEntry(uuid, (weight as num).toInt()),
    );
    final drawn = <DraftPrinting>[];
    for (var i = 0; i < count; i++) {
      if (pool.isEmpty) break;
      final total = pool.values.fold<int>(0, (a, b) => a + b);
      final uuid = _pickKey(pool, total);
      pool.remove(uuid);
      final printing = printings[uuid];
      if (printing != null) drawn.add(printing);
    }
    return drawn;
  }

  T _pick<T>(List<T> items, int Function(T) weight, int total) {
    var roll = _roll(total <= 0 ? items.length : total);
    for (final item in items) {
      roll -= total <= 0 ? 1 : weight(item);
      if (roll < 0) return item;
    }
    return items.last;
  }

  String _pickKey(Map<String, int> weights, int total) {
    var roll = _roll(total <= 0 ? weights.length : total);
    for (final entry in weights.entries) {
      roll -= total <= 0 ? 1 : entry.value;
      if (roll < 0) return entry.key;
    }
    return weights.keys.last;
  }

  /// A roll in [0, total), as a double. MTGJSON's weights are fractions
  /// brought to a common denominator, and a foil or wildcard sheet's total
  /// runs into the trillions, past the 2^32 that [Random.nextInt] takes.
  /// A double carries a weight that size exactly, and a draw that is one
  /// part in 2^53 off uniform is a pack nobody can tell from a fair one.
  double _roll(int total) => _random.nextDouble() * total;
}
