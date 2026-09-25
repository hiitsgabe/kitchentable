import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/menu/menu_controller.dart';

void main() {
  test('with no catalog, every road to a card is shut and focus starts on '
      'sources', () {
    const state = MenuState(cardCount: 0, enabledSources: 0);
    final entries = state.entries;

    expect(
        entries.firstWhere((e) => e.id == MenuEntryId.start).enabled, isFalse);
    expect(entries.firstWhere((e) => e.id == MenuEntryId.join).enabled, isFalse);
    expect(entries.firstWhere((e) => e.id == MenuEntryId.decks).enabled, isFalse);
    expect(state.initialFocus, MenuEntryId.sources);
  });

  test('sources and settings are always reachable', () {
    const state = MenuState(cardCount: 0, enabledSources: 0);
    final entries = state.entries;

    expect(
        entries.firstWhere((e) => e.id == MenuEntryId.sources).enabled, isTrue);
    expect(
        entries.firstWhere((e) => e.id == MenuEntryId.settings).enabled, isTrue);
  });

  test('with a catalog, starting a table opens and focus moves to it', () {
    const state = MenuState(cardCount: 36079, enabledSources: 1);

    expect(state.entries.firstWhere((e) => e.id == MenuEntryId.start).enabled,
        isTrue);
    expect(state.initialFocus, MenuEntryId.start);
  });

  test('starting and joining are two doors into the same room', () {
    const state = MenuState(cardCount: 36079, enabledSources: 1);
    final start = state.entries.firstWhere((e) => e.id == MenuEntryId.start);
    final join = state.entries.firstWhere((e) => e.id == MenuEntryId.join);
    final decks = state.entries.firstWhere((e) => e.id == MenuEntryId.decks);

    // This case used to read Play against Decks, and what it asserted was that
    // Play dealt a deck. That is the road this slice removes: a room is made
    // first and the cards come out inside it, so neither of the two doors to it
    // says anything about dealing. Decks is still the editor and still the only
    // one of the three that is about a deck at all.
    expect(start.subtitle, isNot(join.subtitle));
    expect(start.subtitle, contains('room'));
    expect(join.subtitle, contains('code'));
    expect(decks.subtitle, contains('build'));
    for (final entry in state.entries) {
      expect(entry.subtitle, isNot(contains('deals')), reason: entry.title);
    }
  });

  test('the header counts the real catalog', () {
    expect(const MenuState(cardCount: 0, enabledSources: 0).headline,
        'NO SOURCES CONFIGURED');
    expect(const MenuState(cardCount: 36079, enabledSources: 1).headline,
        '36079 CARDS');
  });

  test('a shut entry says why it is shut', () {
    const state = MenuState(cardCount: 0, enabledSources: 0);
    expect(state.entries.firstWhere((e) => e.id == MenuEntryId.start).subtitle,
        'needs a source');
  });
}
