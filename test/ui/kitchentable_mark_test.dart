import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/ui/atoms/kitchentable_mark.dart';
import 'package:kitchentable/ui/tokens/theme.dart';

Widget _host({Color? accent, double size = 120}) => MaterialApp(
  theme: kitchentableTheme(accent: accent),
  home: Scaffold(
    body: Center(child: KitchentableMark(size: size)),
  ),
);

Iterable<Color> _fills(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(find.byType(DecoratedBox))
    .map((b) => (b.decoration as BoxDecoration).color)
    .nonNulls;

void main() {
  testWidgets('the four cards take the colour the player picked', (
    tester,
  ) async {
    // The same shape ships as a file for the icons and the browser tab,
    // where it has to stay pink. On a screen it is drawn, so that picking a
    // teal table does not leave a pink logo sitting on it.
    const teal = Color(0xFF2EE0B0);
    await tester.pumpWidget(_host(accent: teal));
    await tester.pump();

    expect(_fills(tester).where((c) => c == teal), hasLength(4));
  });

  testWidgets('it is square and the same shape at any size', (tester) async {
    for (final size in [16.0, 96.0, 400.0]) {
      await tester.pumpWidget(_host(size: size));
      await tester.pump();

      expect(tester.getSize(find.byType(KitchentableMark)), Size(size, size));
      // Four cards, however small. A mark that dropped a card under some
      // size would be a different mark in a browser tab.
      expect(_fills(tester).length, greaterThanOrEqualTo(4));
    }
  });
}
