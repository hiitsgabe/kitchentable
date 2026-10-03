import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/menu/menu_controller.dart';

void main() {
  test('the menu is four rows, and Sources is not one of them', () {
    const state = MenuState(cardCount: 36079, enabledSources: 1);

    expect(state.entries.map((e) => e.id), [
      MenuEntryId.play,
      MenuEntryId.join,
      MenuEntryId.decks,
      MenuEntryId.settings,
    ]);
    // Configuration, touched once, and it used to be the brightest thing on
    // the first screen. It lives in Settings now.
    expect(state.entries.map((e) => e.title), isNot(contains('Sources')));
    expect(
      state.entries.firstWhere((e) => e.id == MenuEntryId.settings).subtitle,
      contains('sources'),
    );
  });

  test('playing and joining are open with no catalog, because the first run '
      'puts the cards in', () {
    const state = MenuState(cardCount: 0, enabledSources: 0);
    final entries = state.entries;

    // These were shut, with "needs a source" written on them, which is a wall
    // with an explanation. The wizard puts a source in before the menu is
    // ever reached, and somebody who skipped it can still make a room and
    // pick a deck in it.
    expect(entries.firstWhere((e) => e.id == MenuEntryId.play).enabled, isTrue);
    expect(entries.firstWhere((e) => e.id == MenuEntryId.join).enabled, isTrue);
    expect(
      entries.firstWhere((e) => e.id == MenuEntryId.settings).enabled,
      isTrue,
    );
  });

  test('a deck needs cards, and says so', () {
    const state = MenuState(cardCount: 0, enabledSources: 0);
    final decks = state.entries.firstWhere((e) => e.id == MenuEntryId.decks);

    expect(decks.enabled, isFalse);
    expect(decks.subtitle, 'needs a source');
  });

  test('focus is always on the way in', () {
    expect(const MenuState(cardCount: 0, enabledSources: 0).initialFocus,
        MenuEntryId.play);
    expect(const MenuState(cardCount: 36079, enabledSources: 1).initialFocus,
        MenuEntryId.play);
  });

  test('playing and joining are two doors into the same room', () {
    const state = MenuState(cardCount: 36079, enabledSources: 1);
    final play = state.entries.firstWhere((e) => e.id == MenuEntryId.play);
    final join = state.entries.firstWhere((e) => e.id == MenuEntryId.join);
    final decks = state.entries.firstWhere((e) => e.id == MenuEntryId.decks);

    // Neither of the two doors says anything about dealing: a room is made
    // first and the cards come out inside it. Decks is still the editor.
    expect(play.subtitle, isNot(join.subtitle));
    expect(play.subtitle, contains('table'));
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
}
