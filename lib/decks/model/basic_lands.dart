import '../../sources/catalog/catalog_db.dart';
import '../../sources/model/catalog_card.dart';
import 'deck.dart';

/// The five, in the order they sit on a Magic card's colour pie, which is the
/// order every player already has in their head.
const basicLandNames = [
  'Plains',
  'Island',
  'Swamp',
  'Mountain',
  'Forest',
];

/// The colours a deck is actually in, read off the cards already in it.
///
/// Commander would take this from the commander's colour identity, and that is
/// the right answer once there is a commander. Before there is one, what the
/// deck is made of is the only evidence there is.
Set<String> colourIdentityOf(Deck deck) {
  final commander = deck.commanders.firstOrNull;
  if (commander != null) return commander.card.colorIdentity.toSet();

  return {
    for (final slot in deck.slots) ...slot.card.colorIdentity,
  };
}

const _landForColour = {
  'W': 'Plains',
  'U': 'Island',
  'B': 'Swamp',
  'R': 'Mountain',
  'G': 'Forest',
};

/// Which basics to offer first. A deck with no colours yet gets all five,
/// because a colourless deck is rarer than an empty one.
List<String> suggestedLandsFor(Deck deck) {
  final colours = colourIdentityOf(deck);
  if (colours.isEmpty) return basicLandNames;

  final wanted = [
    for (final name in basicLandNames)
      if (colours.any((c) => _landForColour[c] == name)) name,
  ];
  return wanted.isEmpty ? basicLandNames : wanted;
}

/// A whole deck's worth of land, split evenly between the colours it is in.
///
/// The target is what is left to fill, so it stops at the format's size rather
/// than guessing a ratio. Spare cards go to the earlier colours, which is what
/// a person does when thirty seven will not divide by three.
Map<String, int> evenLandSplit(Deck deck) {
  final names = suggestedLandsFor(deck);
  final missing = deck.format.deckSize - deck.mainCount;
  if (missing <= 0 || names.isEmpty) return const {};

  final each = missing ~/ names.length;
  var spare = missing % names.length;

  return {
    for (final name in names)
      name: each + (spare-- > 0 ? 1 : 0),
  };
}

Future<Map<String, CatalogCard>> loadBasicLands(CatalogDb db) =>
    db.cardsByExactNames(basicLandNames);
