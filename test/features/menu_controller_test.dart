import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/menu/menu_controller.dart';

void main() {
  test('with no catalog, play and decks are shut and focus starts on sources',
      () {
    const state = MenuState(cardCount: 0, enabledSources: 0);
    final entries = state.entries;

    expect(entries.firstWhere((e) => e.id == MenuEntryId.decks).enabled, isFalse);
    expect(state.initialFocus, MenuEntryId.sources);
    // One door to decks, not two. There used to be a Play as well, and once
    // it stopped being a dead end the two opened the same screen.
    expect(entries.length, 3);
  });

  test('sources and settings are always reachable', () {
    const state = MenuState(cardCount: 0, enabledSources: 0);
    final entries = state.entries;

    expect(
        entries.firstWhere((e) => e.id == MenuEntryId.sources).enabled, isTrue);
    expect(
        entries.firstWhere((e) => e.id == MenuEntryId.settings).enabled, isTrue);
  });

  test('with a catalog, decks opens and focus moves to it', () {
    const state = MenuState(cardCount: 36079, enabledSources: 1);

    expect(state.entries.firstWhere((e) => e.id == MenuEntryId.decks).enabled,
        isTrue);
    expect(state.initialFocus, MenuEntryId.decks);
  });

  test('the header counts the real catalog', () {
    expect(const MenuState(cardCount: 0, enabledSources: 0).headline,
        'NO SOURCES CONFIGURED');
    expect(const MenuState(cardCount: 36079, enabledSources: 1).headline,
        '36079 CARDS');
  });

  test('a shut entry says why it is shut', () {
    const state = MenuState(cardCount: 0, enabledSources: 0);
    expect(state.entries.firstWhere((e) => e.id == MenuEntryId.decks).subtitle,
        'needs a source');
  });
}
