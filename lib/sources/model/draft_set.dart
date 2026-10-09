/// A Magic set as MTGJSON lists it, for a draft to pick from.
///
/// The list says what exists. What a set's packs are made of, [booster],
/// is in the set's own file and arrives only when somebody asks for that
/// set, which is why it is null on a row the list put there.
class DraftSet {
  const DraftSet({
    required this.code,
    required this.name,
    required this.type,
    required this.releaseDate,
    required this.baseSetSize,
    required this.totalSetSize,
    this.onlineOnly = false,
    this.booster,
  });

  final String code;
  final String name;

  /// MTGJSON's word for it: expansion, core, masters, draft_innovation and
  /// a dozen others. The draft wants the ones with packs; the rest are
  /// promos, tokens and memorabilia.
  final String type;
  final String releaseDate;
  final int baseSetSize;
  final int totalSetSize;
  final bool onlineOnly;

  /// MTGJSON's `booster` object for the set, as JSON, once fetched: the
  /// pack kinds, each with its sheets of printings and their weights.
  final String? booster;

  bool get fetched => booster != null;

  /// Whether the file that was read had a pack recipe in it. A set that was
  /// read before MTGJSON wrote its recipe is stored with an empty one, and
  /// is worth reading again rather than being refused every time.
  bool get hasPacks => fetched && booster != '{}';

  /// The MTGJSON types that were sold in boosters. Everything else on the
  /// list (promo, token, commander, memorabilia, alchemy, box...) is a
  /// product with no packs to open.
  static const boosterTypes = {
    'core',
    'expansion',
    'masters',
    'draft_innovation',
    'funny',
    'starter',
  };

  /// The fewest cards a set needs before its packs are worth opening: six
  /// packs of fifteen, one sealed pool. The type gate lets through sets that
  /// are not out yet (0 cards on the list) and the odd tiny one; this is
  /// what keeps them off the picker.
  static const minCards = 90;

  /// Whether a draft can be run from this set: a boostered type, on paper,
  /// with enough cards printed, and not one whose file was read and had no
  /// packs in it (The List, playtest cards, a foreign reprint).
  bool get draftable =>
      boosterTypes.contains(type) &&
      !onlineOnly &&
      totalSetSize >= minCards &&
      !(fetched && !hasPacks);

  /// Whether the set is out on [day]. A set in preview is on the list with
  /// a slice of its cards and no packs yet, which is no draft.
  bool releasedBy(DateTime day) {
    if (releaseDate.isEmpty) return true;
    final d = day.toIso8601String().substring(0, 10);
    return releaseDate.compareTo(d) <= 0;
  }

  /// Scryfall's symbol for the set, as an SVG.
  String get symbolUrl => symbolUrlFor(code)!;

  /// Scryfall's symbol for a set, by its code. Null for anything that is not
  /// a set code, so a demo's made-up label draws no broken symbol.
  static String? symbolUrlFor(String? code) {
    if (code == null) return null;
    final c = code.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9]{2,6}$').hasMatch(c)) return null;
    return 'https://svgs.scryfall.io/sets/$c.svg';
  }

  /// A row out of SetList.json.
  static DraftSet fromMtgjson(Map<String, dynamic> json) => DraftSet(
    code: json['code'] as String,
    name: json['name'] as String,
    type: (json['type'] as String?) ?? '',
    releaseDate: (json['releaseDate'] as String?) ?? '',
    baseSetSize: ((json['baseSetSize'] as num?) ?? 0).toInt(),
    totalSetSize: ((json['totalSetSize'] as num?) ?? 0).toInt(),
    onlineOnly: json['isOnlineOnly'] == true,
  );
}

/// One printing in a set, which is what a booster sheet names.
///
/// The sheet says uuid; the table says oracle id. This row is the bridge,
/// so a pack can be rolled by uuid and dealt as cards the catalog knows.
class DraftPrinting {
  const DraftPrinting({
    required this.setCode,
    required this.uuid,
    required this.oracleId,
    required this.rarity,
    required this.number,
    this.boosterTypes = const [],
  });

  final String setCode;
  final String uuid;

  /// Scryfall's oracle id, which is the catalog's key. Empty for a printing
  /// MTGJSON has no Scryfall id for, which happens on digital only cards.
  final String oracleId;
  final String rarity;
  final String number;
  final List<String> boosterTypes;

  static DraftPrinting fromMtgjson(String setCode, Map<String, dynamic> json) {
    final ids = (json['identifiers'] as Map<String, dynamic>?) ?? const {};
    return DraftPrinting(
      setCode: setCode,
      uuid: json['uuid'] as String,
      oracleId: (ids['scryfallOracleId'] as String?) ?? '',
      rarity: (json['rarity'] as String?) ?? '',
      number: (json['number'] as String?) ?? '',
      boosterTypes: ((json['boosterTypes'] as List<dynamic>?) ?? const [])
          .cast<String>(),
    );
  }
}
