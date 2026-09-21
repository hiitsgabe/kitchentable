/// What we keep out of a Scryfall record. The live record has 69 fields and we
/// want fourteen of them.
class CatalogCard {
  const CatalogCard({
    required this.oracleId,
    required this.name,
    required this.typeLine,
    required this.cmc,
    this.manaCost,
    this.oracleText,
    this.power,
    this.toughness,
    this.colorIdentity = const [],
    this.rarity,
    this.setCode,
    this.legalities = const {},
    this.imageSmall,
    this.imageNormal,
    this.imageBack,
  });

  final String oracleId;
  final String name;
  final String typeLine;
  final double cmc;
  final String? manaCost;
  final String? oracleText;
  final String? power;
  final String? toughness;
  final List<String> colorIdentity;
  final String? rarity;
  final String? setCode;
  final Map<String, String> legalities;
  final String? imageSmall;
  final String? imageNormal;

  /// The second face, for a card that has one. Null on an ordinary card, which
  /// then turns over onto the generic Magic back instead.
  final String? imageBack;

  bool isLegalIn(String format) => legalities[format] == 'legal';

  /// Double faced cards carry their images under `card_faces` rather than at
  /// the top level, so the front face stands in for the card.
  static CatalogCard fromScryfall(Map<String, dynamic> json) {
    final images = (json['image_uris'] as Map<String, dynamic>?) ??
        ((json['card_faces'] as List<dynamic>?)?.isNotEmpty == true
            ? (json['card_faces'] as List<dynamic>).first['image_uris']
                as Map<String, dynamic>?
            : null);

    final faces = json['card_faces'] as List<dynamic>?;
    // Parenthesised because `as String?` followed by a colon reads as the
    // start of a ternary to the parser, not as a nullable cast.
    final back = (faces != null && faces.length > 1)
        ? ((faces[1]['image_uris'] as Map<String, dynamic>?)?['normal']
            as String?)
        : null;

    return CatalogCard(
      oracleId: json['oracle_id'] as String,
      name: json['name'] as String,
      typeLine: (json['type_line'] as String?) ?? '',
      cmc: ((json['cmc'] as num?) ?? 0).toDouble(),
      manaCost: json['mana_cost'] as String?,
      oracleText: json['oracle_text'] as String?,
      power: json['power'] as String?,
      toughness: json['toughness'] as String?,
      colorIdentity: ((json['color_identity'] as List<dynamic>?) ?? const [])
          .cast<String>(),
      rarity: json['rarity'] as String?,
      setCode: json['set'] as String?,
      legalities: ((json['legalities'] as Map<String, dynamic>?) ?? const {})
          .map((k, v) => MapEntry(k, v as String)),
      imageSmall: images?['small'] as String?,
      imageNormal: images?['normal'] as String?,
      imageBack: back,
    );
  }
}
