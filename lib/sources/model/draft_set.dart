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
