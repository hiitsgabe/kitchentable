import '../../sources/model/catalog_card.dart';
import 'copy_limit.dart';
import 'deck_format.dart';
import 'game.dart';

/// A card in a deck, with the catalog entry already resolved.
class DeckSlot {
  const DeckSlot({
    required this.card,
    required this.quantity,
    this.sideboard = false,
    this.commander = false,
  });

  final CatalogCard card;
  final int quantity;
  final bool sideboard;
  final bool commander;

  DeckSlot withQuantity(int q) => DeckSlot(
        card: card,
        quantity: q,
        sideboard: sideboard,
        commander: commander,
      );
}

class Deck {
  const Deck({
    required this.id,
    required this.name,
    required this.format,
    this.game = Game.magic,
    this.slots = const [],
    this.knownCardCount,
  });

  final String id;
  final String name;
  final DeckFormat format;
  final Game game;
  final List<DeckSlot> slots;

  /// How many cards the deck holds, when that was counted without loading
  /// them. The deck list reads this: loading every card of every deck to draw
  /// a row saying how many there are would be silly, and a row that cannot say
  /// whether a deck is empty cannot dim itself either.
  final int? knownCardCount;

  Iterable<DeckSlot> get main =>
      slots.where((s) => !s.sideboard && !s.commander);
  Iterable<DeckSlot> get side => slots.where((s) => s.sideboard);
  Iterable<DeckSlot> get commanders => slots.where((s) => s.commander);

  /// Commander counts its commander inside the hundred. That is the part people
  /// get wrong, and it is the reason this is a method on the deck rather than a
  /// sum the screen does for itself.
  int get mainCount =>
      main.fold(0, (n, s) => n + s.quantity) +
      commanders.fold(0, (n, s) => n + s.quantity);

  int get sideCount => side.fold(0, (n, s) => n + s.quantity);

  int quantityOf(String oracleId, {bool sideboard = false}) => slots
      .where((s) => s.card.oracleId == oracleId && s.sideboard == sideboard)
      .fold(0, (n, s) => n + s.quantity);

  /// Copies everywhere. The limit is on the deck, not on a pile: four Bolts in
  /// the deck and one more in the sideboard is five Bolts and it is illegal.
  int totalCopiesOf(String oracleId) => slots
      .where((s) => s.card.oracleId == oracleId)
      .fold(0, (n, s) => n + s.quantity);

  /// The count to show, from whichever source knows it.
  int get cardCount => slots.isNotEmpty ? mainCount : (knownCardCount ?? 0);

  Deck copyWith({String? name, List<DeckSlot>? slots}) => Deck(
        id: id,
        name: name ?? this.name,
        format: format,
        game: game,
        slots: slots ?? this.slots,
        knownCardCount: knownCardCount,
      );
}

/// Why a card cannot go in, in words a player can act on.
class DeckComplaint {
  const DeckComplaint(this.message, {this.blocking = true});

  final String message;

  /// A blocking complaint stops the add. A soft one is said out loud and
  /// allowed, because a kitchen table deck is allowed to be illegal and the app
  /// does not get to be the judge. See the referee slot in the spec.
  final bool blocking;
}

/// Checks one card against one deck. Nothing here understands what a card does,
/// it counts copies and reads the legality field Scryfall already ships.
DeckComplaint? complainAbout(
  Deck deck,
  CatalogCard card, {
  bool sideboard = false,
}) {
  final limit = copyLimitFor(card, deck.format);
  final already = deck.totalCopiesOf(card.oracleId);

  if (already >= limit) {
    return DeckComplaint(
      limit == 1
          ? '${deck.format.label} is singleton, one of each'
          : 'Already at $limit copies',
    );
  }

  final key = deck.format.legalityKey;
  if (key != null && !card.isLegalIn(key)) {
    return DeckComplaint(
      'Not legal in ${deck.format.label}',
      blocking: false,
    );
  }

  return null;
}
