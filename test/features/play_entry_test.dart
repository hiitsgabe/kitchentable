import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/menu/menu_controller.dart';

void main() {
  test('Play says it deals, which is what it does', () {
    const state = MenuState(cardCount: 36079, enabledSources: 1);
    final play = state.entries.firstWhere((e) => e.id == MenuEntryId.play);

    expect(play.subtitle, contains('deals'));
    expect(play.enabled, isTrue,
        reason: 'a table starts from a deck, and this is the door that deals');
  });

  test('it waits for a source first', () {
    const state = MenuState(cardCount: 0, enabledSources: 0);
    final play = state.entries.firstWhere((e) => e.id == MenuEntryId.play);

    expect(play.enabled, isFalse);
    expect(play.subtitle, 'needs a source');
  });
}
