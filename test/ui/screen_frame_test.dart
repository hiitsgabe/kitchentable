import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/ui/atoms/hint_bar.dart';
import 'package:kitchentable/ui/organisms/screen_frame.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

Widget _host({VoidCallback? onBack}) => MaterialApp(
      home: ScreenFrame(
        metrics: Metrics.of(DeviceClass.handheld),
        title: 'Sources',
        label: 'nothing has left this device yet',
        onBack: onBack,
        hints: const [Hint(button: 'B', label: 'back')],
        children: const [Text('a row')],
      ),
    );

void main() {
  testWidgets('the label is shouted, because it says what is true now',
      (tester) async {
    await tester.pumpWidget(_host());
    expect(find.text('NOTHING HAS LEFT THIS DEVICE YET'), findsOneWidget);
  });

  testWidgets('there is no back affordance when there is nowhere to go',
      (tester) async {
    await tester.pumpWidget(_host());
    expect(find.text('Back'), findsNothing);
  });

  testWidgets('tapping back goes back', (tester) async {
    var popped = 0;
    await tester.pumpWidget(_host(onBack: () => popped++));

    await tester.tap(find.text('Back'));
    await tester.pump();

    expect(popped, 1);
  });

  testWidgets('the back target is big enough to hit', (tester) async {
    await tester.pumpWidget(_host(onBack: () {}));

    final box = tester.getSize(
      find.ancestor(of: find.text('Back'), matching: find.byType(Container)).first,
    );

    // Anything under about forty points is a target people miss. The first
    // version was roughly sixty by sixteen and read as broken.
    expect(box.height, greaterThanOrEqualTo(40));
  });

  testWidgets('escape goes back, for a keyboard and a browser', (tester) async {
    var popped = 0;
    await tester.pumpWidget(_host(onBack: () => popped++));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(popped, 1);
  });

  testWidgets('the gamepad B button goes back', (tester) async {
    var popped = 0;
    await tester.pumpWidget(_host(onBack: () => popped++));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonB);
    await tester.pump();

    expect(popped, 1);
  });
}
