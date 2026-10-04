import 'dart:convert';

import '../../decks/model/deck.dart';
import '../../decks/model/deck_format.dart';
import '../../decks/model/game.dart';
import '../../sources/model/catalog_card.dart';
import 'wire.dart';

/// A deck, with its cards, for the host that has to deal it.
///
/// Every slot carries its printing and not only its oracle id. The host deals
/// whatever the guests bring, and it has no reason to have imported a card it
/// has never owned: a wire that carried ids would leave the host looking up a
/// name it does not have, and drawing a blank where somebody's commander is.
///
/// The same version as the table's wire and not a second number. A deck
/// arrives from somebody else's build over the same channel a verb does, and
/// one build speaks one protocol.
String deckToWire(Deck deck) => jsonEncode({
  'v': wireVersion,
  'id': deck.id,
  'name': deck.name,
  'format': deck.format.name,
  'game': deck.game.name,
  'slots': [for (final slot in deck.slots) _slotToJson(slot)],
});

Deck deckFromWire(String wire) {
  final json = _objectFrom(wire);
  _checkVersion(json);

  return Deck(
    id: _string(json, 'id'),
    name: _string(json, 'name'),
    format: _formatFrom(_string(json, 'format')),
    game: _gameFrom(_string(json, 'game')),
    slots: [
      for (final slot in _list(json, 'slots')) _slotFrom(_object(slot, 'slot')),
    ],
  );
}

Map<String, Object?> _slotToJson(DeckSlot slot) => {
  'card': _cardToJson(slot.card),
  'quantity': slot.quantity,
  'sideboard': slot.sideboard,
  'commander': slot.commander,
};

DeckSlot _slotFrom(Map<String, Object?> json) => DeckSlot(
  card: _cardFrom(_object(json['card'], 'card')),
  quantity: _int(json, 'quantity'),
  sideboard: _bool(json, 'sideboard'),
  commander: _bool(json, 'commander'),
);

/// Every field a [CatalogCard] has. The screen draws from the images and the
/// sheet reads the rest, and a field left off here is a card that draws on
/// the phone it came from and not on the phone that deals it.
Map<String, Object?> _cardToJson(CatalogCard card) => {
  'oracleId': card.oracleId,
  'name': card.name,
  'typeLine': card.typeLine,
  'cmc': card.cmc,
  'manaCost': card.manaCost,
  'oracleText': card.oracleText,
  'power': card.power,
  'toughness': card.toughness,
  'colorIdentity': card.colorIdentity,
  'rarity': card.rarity,
  'setCode': card.setCode,
  'legalities': card.legalities,
  'imageSmall': card.imageSmall,
  'imageNormal': card.imageNormal,
  'imageLarge': card.imageLarge,
  'imageBack': card.imageBack,
  'game': card.game.name,
};

CatalogCard _cardFrom(Map<String, Object?> json) => CatalogCard(
  oracleId: _string(json, 'oracleId'),
  name: _string(json, 'name'),
  typeLine: _string(json, 'typeLine'),
  cmc: _double(json, 'cmc'),
  manaCost: _stringOrNull(json, 'manaCost'),
  oracleText: _stringOrNull(json, 'oracleText'),
  power: _stringOrNull(json, 'power'),
  toughness: _stringOrNull(json, 'toughness'),
  colorIdentity: _strings(json, 'colorIdentity'),
  rarity: _stringOrNull(json, 'rarity'),
  setCode: _stringOrNull(json, 'setCode'),
  legalities: _stringMap(json, 'legalities'),
  imageSmall: _stringOrNull(json, 'imageSmall'),
  imageNormal: _stringOrNull(json, 'imageNormal'),
  imageLarge: _stringOrNull(json, 'imageLarge'),
  imageBack: _stringOrNull(json, 'imageBack'),
  // Absent on a card written before cards had a game, which was Magic.
  game: _gameOrMagic(json),
);

DeckFormat _formatFrom(String name) {
  for (final format in DeckFormat.values) {
    if (format.name == name) return format;
  }
  throw WireError(
    'a deck is in the format "$name", which is not one this build knows: '
    '${DeckFormat.values.map((f) => f.name).join(', ')}',
  );
}

/// A card's own game, for the back it turns over onto. Magic when absent.
Game _gameOrMagic(Map<String, Object?> json) {
  final name = _stringOrNull(json, 'game');
  return name == null ? Game.magic : _gameFrom(name);
}

Game _gameFrom(String name) {
  for (final game in Game.values) {
    if (game.name == name) return game;
  }
  throw WireError(
    'a deck is for the game "$name", which is not one this build knows: '
    '${Game.values.map((g) => g.name).join(', ')}',
  );
}

// The readers, the same shape as the table wire's and kept private there, so
// they are here again. Each one says which field was wrong and what it held.

Map<String, Object?> _objectFrom(String wire) {
  final Object? json;
  try {
    json = jsonDecode(wire);
  } on FormatException catch (e) {
    throw WireError('this is not JSON: ${e.message}');
  }
  return _object(json, 'deck');
}

Map<String, Object?> _object(Object? json, String what) {
  if (json is Map<String, Object?>) return json;
  throw WireError(
    'a $what should be an object and this is ${json.runtimeType}',
  );
}

void _checkVersion(Map<String, Object?> json) {
  final version = json['v'];
  if (version == wireVersion) return;
  throw WireError(
    'deck version $version, and this build speaks $wireVersion. Somebody at '
    'this table is running a different one.',
  );
}

Never _wrong(String key, Object? value, String wanted) => throw WireError(
  '"$key" should be $wanted and it is ${value.runtimeType} ($value)',
);

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  return value is String ? value : _wrong(key, value, 'a string');
}

String? _stringOrNull(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  return value is String ? value : _wrong(key, value, 'a string or absent');
}

int _int(Map<String, Object?> json, String key) {
  final value = json[key];
  return value is int ? value : _wrong(key, value, 'a whole number');
}

double _double(Map<String, Object?> json, String key) {
  final value = json[key];
  return value is num ? value.toDouble() : _wrong(key, value, 'a number');
}

bool _bool(Map<String, Object?> json, String key) {
  final value = json[key];
  return value is bool ? value : _wrong(key, value, 'true or false');
}

List<Object?> _list(Map<String, Object?> json, String key) {
  final value = json[key];
  return value is List ? value : _wrong(key, value, 'a list');
}

List<String> _strings(Map<String, Object?> json, String key) => [
  for (final value in _list(json, key))
    value is String ? value : _wrong(key, value, 'a list of strings'),
];

Map<String, String> _stringMap(Map<String, Object?> json, String key) => {
  for (final entry in _object(json[key], key).entries)
    entry.key: entry.value is String
        ? entry.value as String
        : _wrong(key, entry.value, 'a map of strings'),
};
