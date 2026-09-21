import '../../sources/model/catalog_card.dart';
import 'deck_format.dart';

/// Two cards escape the copy limit in every format, and both are worth knowing
/// because a deck builder that gets them wrong is wrong about real decks.
///
/// Basic lands, obviously. And the cards that say so on themselves: Relentless
/// Rats, Shadowborn Apostle, Persistent Petitioners, Dragon's Approach, Seven
/// Dwarves and the rest all carry a line of oracle text granting the exemption.
/// Reading that line is how you support them without a list to maintain.
bool hasUnlimitedCopies(CatalogCard card) {
  if (isBasicLand(card)) return true;
  final text = card.oracleText?.toLowerCase();
  if (text == null) return false;
  return text.contains('a deck can have any number of cards named');
}

bool isBasicLand(CatalogCard card) =>
    card.typeLine.toLowerCase().contains('basic') &&
    card.typeLine.toLowerCase().contains('land');

int copyLimitFor(CatalogCard card, DeckFormat format) =>
    hasUnlimitedCopies(card) ? 1 << 30 : format.maxCopies;
