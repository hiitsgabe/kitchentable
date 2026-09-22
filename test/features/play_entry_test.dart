import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/menu/menu_controller.dart';

void main() {
  test('the one door says it is for playing too', () {
    const state = MenuState(cardCount: 36079, enabledSources: 1);
    final play = state.entries.firstWhere((e) => e.id == MenuEntryId.decks);

    // The row is called Decks, so the subtitle is where playing gets said.
    expect(play.subtitle, contains('play'));
    expect(play.enabled, isTrue,
        reason: 'a table starts from a deck, and this is the only door to one');
  });

  test('it waits for a source first', () {
    const state = MenuState(cardCount: 0, enabledSources: 0);
    final play = state.entries.firstWhere((e) => e.id == MenuEntryId.decks);

    expect(play.enabled, isFalse);
    expect(play.subtitle, 'needs a source');
  });
}
