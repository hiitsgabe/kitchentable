import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/renderers/renderer_choice.dart';

void main() {
  test('a phone gets bands', () {
    expect(
      rendererFor(width: 390, height: 844, chosen: null),
      TableRenderer.stackedSeats,
    );
  });

  test('a wide window gets the canvas', () {
    expect(
      rendererFor(width: 1280, height: 800, chosen: null),
      TableRenderer.freeCanvas,
    );
  });

  test('a tablet counts as wide', () {
    expect(
      rendererFor(width: 820, height: 1180, chosen: null),
      TableRenderer.freeCanvas,
    );
  });

  test('the boundary belongs to the canvas', () {
    expect(
      rendererFor(width: 720, height: 800, chosen: null),
      TableRenderer.freeCanvas,
    );
    expect(
      rendererFor(width: 719, height: 800, chosen: null),
      TableRenderer.stackedSeats,
    );
  });

  test('a phone held sideways is wide and has no room', () {
    // 844 by 390 clears the width cut and is the worst window the canvas
    // gets: one seat's strips take 28 percent of the width and what is left
    // has to hold a 380 unit mat in 390 points less the chrome.
    expect(
      rendererFor(width: 844, height: 390, chosen: null),
      TableRenderer.stackedSeats,
    );
  });

  test('a tablet has room in both directions', () {
    expect(
      rendererFor(width: 820, height: 1180, chosen: null),
      TableRenderer.freeCanvas,
    );
  });

  test('a choice beats the width, in both directions', () {
    expect(
      rendererFor(width: 390, height: 844, chosen: TableRenderer.freeCanvas),
      TableRenderer.freeCanvas,
    );
    expect(
      rendererFor(
        width: 1280,
        height: 800,
        chosen: TableRenderer.stackedSeats,
      ),
      TableRenderer.stackedSeats,
    );
  });
}
