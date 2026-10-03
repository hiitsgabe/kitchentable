import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/ui/atoms/menu_row.dart';
import 'package:kitchentable/ui/tokens/app_palette.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';
import 'package:kitchentable/ui/tokens/palette.dart';
import 'package:kitchentable/ui/tokens/theme.dart';

const _teal = Color(0xFF00E0A4);

Widget _host(Color? accent) => MaterialApp(
      theme: kitchentableTheme(accent: accent),
      home: Scaffold(
        body: MenuRow(
          title: 'Play',
          metrics: Metrics.of(DeviceClass.handheld),
          autofocus: true,
          onActivate: () {},
        ),
      ),
    );

void main() {
  test('the accent family is derived from the one colour', () {
    final teal = AppPalette.of(_teal);

    expect(teal.accent, _teal);
    // The two fills are the accent dragged most of the way back into the
    // dark, which is what the hand written pink ones were.
    expect(teal.focusWash, isNot(Palette.focusWash));
    expect(teal.tileFocused, isNot(Palette.tileFocused));
    expect(teal.focusWash.g, greaterThan(teal.focusWash.r));
  });

  testWidgets('a row drawn under a teal theme is not pink', (tester) async {
    // The whole complaint in one case: picking a colour used to paint the
    // background and leave every border, ring and fill the pink they were
    // written as.
    await tester.pumpWidget(_host(_teal));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(MenuRow));
    expect(context.palette.accent, _teal);
    expect(context.palette.accent, isNot(Palette.accent));
  });

  testWidgets('with no theme up, it is the pink the app ships with',
      (tester) async {
    await tester.pumpWidget(_host(null));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(MenuRow));
    expect(context.palette.accent, Palette.accent);
  });
}
