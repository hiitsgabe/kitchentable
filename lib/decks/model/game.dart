import 'deck_format.dart';

/// Which card game a deck belongs to.
///
/// The app has been quietly assuming Magic everywhere, which was fine while
/// Magic was the only catalog. A deck now says which game it is, because a
/// Pokemon deck and a Commander deck do not share a single rule about size,
/// copies or what counts as legal.
enum Game {
  magic,
  pokemon;

  String get label => switch (this) {
        Game.magic => 'Magic',
        Game.pokemon => 'Pokemon',
      };

  /// Pokemon has no catalog yet, so its formats are listed and its decks are
  /// refused rather than pretended at. See the source registry.
  bool get hasCatalog => this == Game.magic;

  List<DeckFormat> get formats => switch (this) {
        Game.magic => const [
            DeckFormat.commander,
            DeckFormat.standard,
            DeckFormat.pauper,
            DeckFormat.draft,
          ],
        Game.pokemon => const [DeckFormat.pokemonStandard],
      };
}
