import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/menu/menu_controller.dart';

void main() {
  test('with no catalog, play and decks are shut and focus starts on sources',
      () {
    const state = MenuState(cardCount: 0, enabledSources: 0);
    final entries = state.entries;

    expect(entries.firstWhere((e) => e.id == MenuEntryId.play).enabled, isFalse);
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

  test('with a catalog, play opens and focus moves to it', () {
    const state = MenuState(cardCount: 36079, enabledSources: 1);

    expect(state.entries.firstWhere((e) => e.id == MenuEntryId.play).enabled,
        isTrue);
    expect(state.initialFocus, MenuEntryId.play);
  });

  test('Play and Decks are two doors, not one said twice', () {
    const state = MenuState(cardCount: 36079, enabledSources: 1);
    final play = state.entries.firstWhere((e) => e.id == MenuEntryId.play);
    final decks = state.entries.firstWhere((e) => e.id == MenuEntryId.decks);

    // They list the same decks and go somewhere different: one deals, the
    // other edits. They were briefly the same screen and it was worse than the
    // dead end that preceded it.
    expect(play.subtitle, isNot(decks.subtitle));
    expect(play.subtitle, contains('deals'));
    expect(decks.subtitle, contains('build'));
  });

  test('the header counts the real catalog', () {
    expect(const MenuState(cardCount: 0, enabledSources: 0).headline,
        'NO SOURCES CONFIGURED');
    expect(const MenuState(cardCount: 36079, enabledSources: 1).headline,
        '36079 CARDS');
  });

  test('a shut entry says why it is shut', () {
    const state = MenuState(cardCount: 0, enabledSources: 0);
    expect(state.entries.firstWhere((e) => e.id == MenuEntryId.play).subtitle,
        'needs a source');
  });
}
