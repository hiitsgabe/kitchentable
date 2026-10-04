import '../../decks/model/game.dart';

/// What we keep out of a card record, whichever game it came from.
///
/// Shaped by Scryfall first, which has 69 fields of which we want fourteen.
/// A Pokemon card is put into the same shape rather than given a table of
/// its own, because everything above this, the search, the deck, the table,
/// the picture, reads a card by these fields and none of it cares which
/// game printed it. Where a field has no Pokemon meaning it is empty, and
/// [typeLine] carries what Pokemon says instead.
class CatalogCard {
  const CatalogCard({
    required this.oracleId,
    required this.name,
    required this.typeLine,
    required this.cmc,
    this.game = Game.magic,
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
    this.imageLarge,
    this.imageBack,
  });

  /// Scryfall's oracle id for a Magic card, which is a UUID, and the card id
  /// for a Pokemon one, `base1-4`. Neither shape can collide with the other.
  final String oracleId;
  final String name;
  final Game game;
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

  /// Scryfall's `large`, 672 pixels wide. The biggest the app ever needs: the
  /// `png` above it is 745 wide and several times the bytes for a card that
  /// is already sharper than any screen here draws it.
  final String? imageLarge;

  /// The second face, for a card that has one. Null on an ordinary card, which
  /// then turns over onto the generic Magic back instead.
  final String? imageBack;

  bool isLegalIn(String format) => legalities[format] == 'legal';

  /// A record out of pokemon-tcg-data, the repository behind the Pokemon
  /// TCG API, one file per set and one object per card.
  ///
  /// The set is not in the record. It is the file the record came from,
  /// and it is also the front half of the id, which is what is read here
  /// so a record means the same thing wherever it was found.
  static CatalogCard fromPokemon(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final images = json['images'] as Map<String, dynamic>?;
    final types = ((json['types'] as List<dynamic>?) ?? const [])
        .cast<String>();
    final subtypes = ((json['subtypes'] as List<dynamic>?) ?? const [])
        .cast<String>();

    // What the card does, in the order it is printed: abilities, then
    // attacks, then the rules on a trainer or an energy.
    final lines = <String>[];
    for (final a in (json['abilities'] as List<dynamic>?) ?? const []) {
      final ability = a as Map<String, dynamic>;
      lines.add('${ability['name']}: ${ability['text'] ?? ''}'.trim());
    }
    for (final a in (json['attacks'] as List<dynamic>?) ?? const []) {
      final attack = a as Map<String, dynamic>;
      final damage = (attack['damage'] as String?) ?? '';
      final text = (attack['text'] as String?) ?? '';
      lines.add(
        '${attack['name']}${damage.isEmpty ? '' : ' $damage'}'
        '${text.isEmpty ? '' : ': $text'}',
      );
    }
    for (final rule in (json['rules'] as List<dynamic>?) ?? const []) {
      lines.add(rule as String);
    }

    return CatalogCard(
      oracleId: id,
      name: json['name'] as String,
      game: Game.pokemon,
      typeLine: [
        json['supertype'] as String? ?? '',
        ...subtypes,
        ...types,
      ].where((s) => s.isNotEmpty).join(' · '),
      cmc: 0,
      oracleText: lines.isEmpty ? null : lines.join('\n'),
      power: json['hp'] as String?,
      rarity: json['rarity'] as String?,
      setCode: id.contains('-') ? id.substring(0, id.indexOf('-')) : null,
      legalities: ((json['legalities'] as Map<String, dynamic>?) ?? const {})
          .map((k, v) => MapEntry(k, (v as String).toLowerCase())),
      imageSmall: images?['small'] as String?,
      // The small file is 245 pixels wide, which is a blur at the size a
      // tablet draws a card. The hires file is what Scryfall's normal is.
      imageNormal: (images?['large'] ?? images?['small']) as String?,
      imageLarge: images?['large'] as String?,
    );
  }

  /// Double faced cards carry their images under `card_faces` rather than at
  /// the top level, so the front face stands in for the card.
  static CatalogCard fromScryfall(Map<String, dynamic> json) {
    final images =
        (json['image_uris'] as Map<String, dynamic>?) ??
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
      imageLarge: images?['large'] as String?,
      imageBack: back,
    );
  }
}
