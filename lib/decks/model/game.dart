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

  List<DeckFormat> get formats => switch (this) {
    Game.magic => const [
      DeckFormat.commander,
      DeckFormat.standard,
      DeckFormat.pauper,
      DeckFormat.draft,
    ],
    Game.pokemon => const [DeckFormat.pokemonStandard],
  };

  /// The game a format belongs to.
  static Game of(DeckFormat format) =>
      values.firstWhere((game) => game.formats.contains(format));

  /// The game by its name, as a link spells it. Null for a word that is not
  /// one, so a link somebody edited by hand names nothing rather than throws.
  static Game? named(String? name) {
    for (final game in values) {
      if (game.name == name) return game;
    }
    return null;
  }
}
