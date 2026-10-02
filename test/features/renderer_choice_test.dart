import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/renderers/renderer_choice.dart';

void main() {
  test('the table opens on the divided view, whatever the size', () {
    // No breakpoint any more: the divided view fills the screen on a phone
    // and on a wall, and is what a table opens on until the player says
    // otherwise.
    expect(rendererFor(), TableRenderer.grid);
  });

  test('a choice beats the default, each of the three', () {
    for (final choice in TableRenderer.values) {
      expect(rendererFor(chosen: choice), choice);
    }
  });
}
