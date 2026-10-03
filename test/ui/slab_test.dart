import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/ui/atoms/slab.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

Widget _host({
  required VoidCallback onActivate,
  bool enabled = true,
  bool dimmed = false,
  bool autofocus = false,
}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: Slab(
        metrics: Metrics.of(DeviceClass.handheld),
        enabled: enabled,
        dimmed: dimmed,
        autofocus: autofocus,
        onActivate: onActivate,
        semanticLabel: 'Press me',
        child: const Text('Press me'),
      ),
    ),
  ),
);

double _dimming(WidgetTester tester) => tester
    .widget<Opacity>(
      find.descendant(of: find.byType(Slab), matching: find.byType(Opacity)),
    )
    .opacity;

void main() {
  testWidgets('a tap activates it', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(_host(onActivate: () => pressed++));

    await tester.tap(find.text('Press me'));
    await tester.pump();

    expect(pressed, 1);
  });

  testWidgets('a disabled slab does nothing when pressed', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(_host(onActivate: () => pressed++, enabled: false));

    await tester.tap(find.text('Press me'), warnIfMissed: false);
    await tester.pump();

    expect(pressed, 0);
    expect(_dimming(tester), lessThan(1));
  });

  testWidgets('a dimmed slab is drawn dead and still presses', (tester) async {
    // The whole reason the two flags are separate. A stepper at the end of
    // its range looks finished and still calls its own clamp, because a
    // button that refused to call it would hide a broken clamp behind a
    // disabled button, and every test of the clamp would pass.
    var pressed = 0;
    await tester.pumpWidget(_host(onActivate: () => pressed++, dimmed: true));

    expect(_dimming(tester), lessThan(1));

    await tester.tap(find.text('Press me'));
    await tester.pump();

    expect(pressed, 1);
  });

  testWidgets('the gamepad A button activates it, like a tap', (tester) async {
    // MaterialApp maps select and gameButtonA to ActivateIntent, and
    // WidgetsApp.defaultActions has no handler for it. Without the action
    // inside Slab a focused slab draws its ring and does nothing.
    var pressed = 0;
    await tester.pumpWidget(
      _host(onActivate: () => pressed++, autofocus: true),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonA);
    await tester.pump();

    expect(pressed, 1);
  });

  testWidgets('it stands on a ledge, so it has a thickness', (tester) async {
    // The ledge is what the whole look rests on: a slab with none is a tinted
    // rectangle. It shows as the face being shorter than the slab.
    await tester.pumpWidget(_host(onActivate: () {}));

    final whole = tester.getSize(find.byType(Slab));
    final face = tester.getSize(
      find
          .ancestor(of: find.text('Press me'), matching: find.byType(Container))
          .first,
    );

    expect(face.height, lessThan(whole.height));
  });
}
