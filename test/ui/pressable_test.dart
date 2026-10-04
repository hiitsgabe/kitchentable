import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/ui/atoms/pressable.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

Widget _host({required VoidCallback onPress, bool autofocus = true}) =>
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: Pressable(
            metrics: Metrics.of(DeviceClass.handheld),
            onPress: onPress,
            autofocus: autofocus,
            semanticLabel: 'Roll',
            builder: (context, state) => Container(
              key: Key(state.focused ? 'lit' : 'dim'),
              width: 40,
              height: 40,
              color: state.focused ? Colors.white : Colors.black,
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('a tap presses it', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(_host(onPress: () => pressed++, autofocus: false));
    await tester.tap(find.byType(Pressable));
    expect(pressed, 1);
  });

  testWidgets('the select button presses what is focused, and the thing '
      'knows it is focused', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(_host(onPress: () => pressed++));
    await tester.pump();
    expect(
      find.byKey(const Key('lit')),
      findsOneWidget,
      reason: 'the builder is told about focus',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonA);
    await tester.pump();
    expect(pressed, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(pressed, 2);
  });

  testWidgets('a disabled one takes no press from anybody', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Pressable(
          metrics: Metrics.of(DeviceClass.handheld),
          onPress: () => pressed++,
          enabled: false,
          autofocus: true,
          child: const SizedBox(width: 20, height: 20),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(Pressable));
    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonA);
    await tester.pump();
    expect(pressed, 0);
  });
}
