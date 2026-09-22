import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/menu/menu_controller.dart';

void main() {
  test('Play points at a deck, because that is where a table starts', () {
    const state = MenuState(cardCount: 36079, enabledSources: 1);
    final play = state.entries.firstWhere((e) => e.id == MenuEntryId.play);

    expect(play.subtitle, contains('deck'));
    expect(play.enabled, isTrue,
        reason: 'an entry called Play that never opens is where somebody '
            'looks first for a way to start a game');
  });

  test('Play still waits for a source before it waits for a deck', () {
    const state = MenuState(cardCount: 0, enabledSources: 0);
    final play = state.entries.firstWhere((e) => e.id == MenuEntryId.play);

    expect(play.enabled, isFalse);
    expect(play.subtitle, 'needs a source');
  });
}
