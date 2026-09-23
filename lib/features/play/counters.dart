import 'package:flutter/painting.dart';

/// One of the plastic counters that ship in a set's box.
///
/// A name, a colour, and what it does to power and toughness. Nothing here is
/// a widget and nothing here knows about the table: this is the box, and both
/// the card and the viewer's picker read it.
class CounterPiece {
  const CounterPiece({
    required this.name,
    required this.colour,
    this.power = 0,
    this.toughness = 0,
    this.isKeyword = false,
  });

  /// What the table calls it, which is also the key it arrives under in
  /// `CardInstance.counters`.
  final String name;

  final Color colour;

  /// What one of these adds. Zero on both for a keyword, which is the whole
  /// difference between FLYING and `+1/+1`.
  final int power;
  final int toughness;

  /// A word rather than a number, printed in capitals the way the plastic is.
  final bool isKeyword;

  /// What is printed on it, twice, top and bottom.
  ///
  /// A keyword goes up in capitals because that is how the piece is moulded. A
  /// kind nobody printed keeps the case it arrived in: it came off a card
  /// somebody played, and shouting it back is inventing a house style for a
  /// string the table chose.
  String get label => isKeyword ? name.toUpperCase() : name;
}

/// The colours are the photograph's, not [Palette]'s.
///
/// `Palette` is the app's chrome, and chrome deliberately has no opinion so
/// the card art can. These are not chrome: they are printed plastic objects
/// with their own colours, and a green `+2/+2` that went pink to match the
/// app's accent would stop being recognisable, which is the only reason a
/// colour is on them at all. So they live here, beside the pieces.
///
/// `+1/+1` black, `+2/+2` green, `+4/+4` blue, `-1/-1` white, `+1/+0` red,
/// `+2/+0` cyan, `+0/+1` maroon, and the keywords as they appear there.
///
/// The black is a very dark grey rather than `0xFF000000`. The piece is lit
/// from above, so its top edge is a lighter stop of its own colour, and pure
/// black has nothing lighter to go to.
const _black = Color(0xFF121116);
const _white = Color(0xFFEDE9E4);

/// The box, in the order the player reaches into it. `+1/+1` first because a
/// Magic table reaches for it twenty times a game and every other kind once,
/// and because it is what the viewer starts on.
const counterPieces = <CounterPiece>[
  CounterPiece(name: '+1/+1', colour: _black, power: 1, toughness: 1),
  CounterPiece(
      name: '+2/+2', colour: Color(0xFF1F9D4D), power: 2, toughness: 2),
  CounterPiece(
      name: '+4/+4', colour: Color(0xFF2D6BD8), power: 4, toughness: 4),
  CounterPiece(name: '-1/-1', colour: _white, power: -1, toughness: -1),
  CounterPiece(name: '+1/+0', colour: Color(0xFFD22B2B), power: 1),
  CounterPiece(name: '+2/+0', colour: Color(0xFF19B7C8), power: 2),
  CounterPiece(name: '+0/+1', colour: Color(0xFF7A1F3D), toughness: 1),

  // Keyword counters, which the app has never had. A colour each, so a board
  // with four of them on it can be read at a glance rather than word by word.
  CounterPiece(name: 'flying', colour: Color(0xFF8EC3E8), isKeyword: true),
  CounterPiece(name: 'haste', colour: Color(0xFFE8641C), isKeyword: true),
  CounterPiece(name: 'trample', colour: Color(0xFF8B5A2B), isKeyword: true),
  CounterPiece(name: 'vigilance', colour: Color(0xFFE8C547), isKeyword: true),
  CounterPiece(name: 'menace', colour: Color(0xFF5B3A8E), isKeyword: true),
  CounterPiece(name: 'deathtouch', colour: Color(0xFF2E4A1F), isKeyword: true),
  CounterPiece(name: 'lifelink', colour: Color(0xFFE87FA8), isKeyword: true),
  CounterPiece(name: 'hexproof', colour: Color(0xFF3FBF8F), isKeyword: true),
  CounterPiece(
      name: 'first strike', colour: Color(0xFFB0B6C0), isKeyword: true),
  CounterPiece(
      name: 'double strike', colour: Color(0xFF6E7684), isKeyword: true),
  CounterPiece(
      name: 'indestructible', colour: Color(0xFF4A4038), isKeyword: true),
  CounterPiece(name: 'reach', colour: Color(0xFF6FA83A), isKeyword: true),
];

/// The piece of that name, or null when the box has none.
CounterPiece? pieceNamed(String name) {
  for (final piece in counterPieces) {
    if (piece.name == name) return piece;
  }
  return null;
}

/// A piece for a kind nobody printed.
///
/// `loyalty`, `charge`, `damage`, `energy`: the model has taken any counter
/// name since plan 2, and a card can arrive carrying one. Grey, because an
/// invented colour would claim to be recognisable when there is nothing to
/// recognise, and it adds nothing to power or toughness because nobody said
/// what it would add.
CounterPiece unknownPiece(String name) =>
    CounterPiece(name: name, colour: const Color(0xFF6B6577));

/// What everything on a card adds up to. A kind the box has never heard of
/// contributes nothing, however many of them there are.
int powerFrom(Map<String, int> counters) => _sum(counters, (p) => p.power);

int toughnessFrom(Map<String, int> counters) =>
    _sum(counters, (p) => p.toughness);

int _sum(Map<String, int> counters, int Function(CounterPiece) part) {
  var total = 0;
  for (final entry in counters.entries) {
    final piece = pieceNamed(entry.key);
    if (piece != null) total += part(piece) * entry.value;
  }
  return total;
}

/// Whether a kind is one of the numbers, which is what decides whether it
/// joins the marker or stands on its own.
bool isNumberKind(String kind) {
  final piece = pieceNamed(kind);
  return piece != null && !piece.isKeyword;
}

/// How the net reads on the marker. Signed both halves, always, because
/// `0/1` beside a card's printed `2/3` is a number and `+0/+1` is a change.
String netName(int power, int toughness) =>
    '${_signed(power)}/${_signed(toughness)}';

String _signed(int n) => n < 0 ? '$n' : '+$n';

/// The one marker a pile of number pieces reads as, or null when there is no
/// number on the card at all.
///
/// `+4/+4` and four `+0/+1` come back as a single `+4/+8` rather than as five
/// objects to add up by eye. The colour is the piece the net happens to equal,
/// so a net of `+2/+2` is the green one and a net of `+4/+4` the blue: that is
/// recognition where recognition exists. A sum nobody printed falls back to
/// the `+1/+1` black, and a net that takes something away to the `-1/-1`
/// white, because those two are what the player already reads as more and
/// less.
CounterPiece? netPiece(Map<String, int> counters) {
  final any = counters.entries
      .any((e) => e.value != 0 && isNumberKind(e.key));
  if (!any) return null;

  final power = powerFrom(counters);
  final toughness = toughnessFrom(counters);
  final name = netName(power, toughness);

  final printed = pieceNamed(name);
  if (printed != null) return printed;

  final fallback = power < 0 || toughness < 0 ? _white : _black;
  return CounterPiece(
    name: name,
    colour: fallback,
    power: power,
    toughness: toughness,
  );
}
