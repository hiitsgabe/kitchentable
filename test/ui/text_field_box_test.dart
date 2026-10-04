import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/ui/atoms/text_field_box.dart';
import 'package:kitchentable/ui/input/pad.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

Widget _host(TextEditingController controller, {bool autofocus = false}) =>
    MaterialApp(
      builder: (context, child) => PadInput(child: child!),
      home: Scaffold(
        body: Column(
          children: [
            TextButton(
              key: const Key('above'),
              autofocus: !autofocus,
              onPressed: () {},
              child: const Text('above'),
            ),
            TextFieldBox(
              key: const Key('box'),
              metrics: Metrics.of(DeviceClass.handheld),
              controller: controller,
              hint: 'your name',
              autofocus: autofocus,
            ),
            TextButton(
              key: const Key('below'),
              onPressed: () {},
              child: const Text('below'),
            ),
          ],
        ),
      ),
    );

bool _typing(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus;

void main() {
  testWidgets('the D-pad lands on the box, select opens it for typing, back '
      'returns to the box', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller));
    await tester.pump();

    // Down from the button above: the box is one stop, the caret is not.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(_typing(tester), isFalse, reason: 'the ring is on the box');

    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonA);
    await tester.pump();
    expect(_typing(tester), isTrue, reason: 'select opens it');
    await tester.enterText(find.byType(TextField), 'kit');
    expect(controller.text, 'kit');

    // Back shuts the field and not the screen: the box has the ring again
    // and the next press down leaves it.
    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonB);
    await tester.pump();
    expect(_typing(tester), isFalse);
    expect(find.byKey(const Key('box')), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(
      tester
              .widget<TextButton>(find.byKey(const Key('below')))
              .focusNode
              ?.hasFocus ??
          Focus.of(tester.element(find.text('below'))).hasFocus,
      isTrue,
    );
  });

  testWidgets('Enter leaves the field as well, and still submits', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller, autofocus: true));
    await tester.pump();
    await tester.pump();
    expect(_typing(tester), isTrue, reason: 'autofocus opens it straight away');

    await tester.enterText(find.byType(TextField), 'kit');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(_typing(tester), isFalse);
  });

  testWidgets('a tap on the field types straight away, as it always did', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(_typing(tester), isTrue);
  });
}
