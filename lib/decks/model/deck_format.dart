/// What a format demands of a deck.
///
/// These are the four the app opens with. They are declarations, not code: the
/// rules engine slot in the spec is still empty and nothing here understands a
/// card, it only counts them.
enum DeckFormat {
  commander,
  standard,
  pauper,
  draft,
  pokemonStandard;

  String get label => switch (this) {
        DeckFormat.commander => 'Commander',
        DeckFormat.standard => 'Standard',
        DeckFormat.pauper => 'Pauper',
        DeckFormat.draft => 'Draft',
        DeckFormat.pokemonStandard => 'Standard',
      };

  /// How many cards the main deck must hold. Commander counts its commander
  /// inside the hundred, which is the part people get wrong.
  int get deckSize => switch (this) {
        DeckFormat.commander => 100,
        DeckFormat.standard => 60,
        DeckFormat.pauper => 60,
        DeckFormat.draft => 40,
        DeckFormat.pokemonStandard => 60,
      };

  /// Commander is the only one of the four where the size is a ceiling as well
  /// as a floor. The others are a minimum and people play more.
  bool get sizeIsExact => this == DeckFormat.commander;

  /// Copies of any one card, before the two exemptions below.
  int get maxCopies => this == DeckFormat.commander ? 1 : 4;

  /// Six prize cards rather than a life total. The table has not been built
  /// yet, so this is a declaration waiting for it, the same as everything else
  /// about Pokemon here.
  bool get winsByPrizes => this == DeckFormat.pokemonStandard;

  int get sideboardSize => switch (this) {
        DeckFormat.commander => 0,
        DeckFormat.draft => 0,
        DeckFormat.pokemonStandard => 0,
        _ => 15,
      };

  bool get needsCommander => this == DeckFormat.commander;

  int get startingLife => switch (this) {
        DeckFormat.commander => 40,
        DeckFormat.pokemonStandard => 0,
        _ => 20,
      };

  /// The key to look up in Scryfall's `legalities` map, or null where the
  /// format does not restrict which cards exist. A draft pool is whatever came
  /// out of the packs, so nothing to check.
  String? get legalityKey => switch (this) {
        DeckFormat.commander => 'commander',
        DeckFormat.standard => 'standard',
        DeckFormat.pauper => 'pauper',
        DeckFormat.draft => null,
        DeckFormat.pokemonStandard => null,
      };
}
