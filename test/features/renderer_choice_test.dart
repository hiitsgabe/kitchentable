import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/renderers/renderer_choice.dart';

void main() {
  test('a phone gets bands', () {
    expect(rendererFor(width: 390, chosen: null), TableRenderer.stackedSeats);
  });

  test('a wide window gets the canvas', () {
    expect(rendererFor(width: 1280, chosen: null), TableRenderer.freeCanvas);
  });

  test('a tablet counts as wide', () {
    expect(rendererFor(width: 820, chosen: null), TableRenderer.freeCanvas);
  });

  test('the boundary belongs to the canvas', () {
    expect(rendererFor(width: 720, chosen: null), TableRenderer.freeCanvas);
    expect(rendererFor(width: 719, chosen: null), TableRenderer.stackedSeats);
  });

  test('a choice beats the width, in both directions', () {
    expect(
      rendererFor(width: 390, chosen: TableRenderer.freeCanvas),
      TableRenderer.freeCanvas,
    );
    expect(
      rendererFor(width: 1280, chosen: TableRenderer.stackedSeats),
      TableRenderer.stackedSeats,
    );
  });
}
