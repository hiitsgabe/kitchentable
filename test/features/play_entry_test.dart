import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/menu/menu_controller.dart';

void main() {
  test('Play still says what it is waiting for', () {
    const state = MenuState(cardCount: 36079, enabledSources: 1);
    final play = state.entries.firstWhere((e) => e.id == MenuEntryId.play);

    // The catalog is loaded and Play is still not a table: hosting and joining
    // are plan 3. Saying so beats a row that opens nothing.
    expect(play.subtitle, contains('deck'));
  });
}
