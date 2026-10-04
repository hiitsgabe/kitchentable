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
    expect(
      const MenuState(cardCount: 0, enabledSources: 0).initialFocus,
      MenuEntryId.play,
    );
    expect(
      const MenuState(cardCount: 36079, enabledSources: 1).initialFocus,
      MenuEntryId.play,
    );
  });

  test('playing and joining are two doors into the same room', () {
    const state = MenuState(cardCount: 36079, enabledSources: 1);
    final play = state.entries.firstWhere((e) => e.id == MenuEntryId.play);
    final join = state.entries.firstWhere((e) => e.id == MenuEntryId.join);
    final decks = state.entries.firstWhere((e) => e.id == MenuEntryId.decks);

    // Four bare words, the way the reference title screen has them. A row
    // that can be pressed explains nothing; only a shut one says why.
    expect(play.subtitle, isNull);
    expect(join.subtitle, isNull);
    expect(decks.subtitle, isNull);
    expect(play.title, isNot(join.title));
  });
}
