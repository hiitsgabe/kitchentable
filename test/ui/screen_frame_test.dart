import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/ui/organisms/screen_frame.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

Widget _host({VoidCallback? onBack, bool home = false}) => MaterialApp(
  home: ScreenFrame(
    metrics: Metrics.of(DeviceClass.handheld),
    title: 'Sources',
    label: 'nothing has left this device yet',
    onBack: onBack,
    home: home,
    children: const [Text('a row')],
  ),
);

/// A screen [depth] steps below the root, each one a frame of its own, the
/// way Decks, a game, a deck and its cards stack up in the app.
Widget _deep(int depth) => ScreenFrame(
  metrics: Metrics.of(DeviceClass.handheld),
  title: 'Screen $depth',
  label: 'step $depth',
  home: depth >= 2,
  onBack: depth == 0 ? null : () {},
  children: [
    Builder(
      builder: (context) => TextButton(
        key: Key('down-$depth'),
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => _deep(depth + 1))),
        child: const Text('down'),
      ),
    ),
  ],
);

void main() {
  testWidgets('the label is shouted, because it says what is true now', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    expect(find.text('NOTHING HAS LEFT THIS DEVICE YET'), findsOneWidget);
  });

  testWidgets('there is no back affordance when there is nowhere to go', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    expect(find.text('Back'), findsNothing);
  });

  testWidgets('there is no home affordance unless the screen asks', (
    tester,
  ) async {
    await tester.pumpWidget(_host(onBack: () {}));
    expect(find.byKey(const Key('home')), findsNothing);

    await tester.pumpWidget(_host(onBack: () {}, home: true));
    expect(find.byKey(const Key('home')), findsOneWidget);
    expect(find.text('Back'), findsOneWidget, reason: 'home is beside back');
  });

  testWidgets('home goes to the first screen in one press', (tester) async {
    await tester.pumpWidget(MaterialApp(home: _deep(0)));
    for (final step in [0, 1, 2]) {
      await tester.tap(find.byKey(Key('down-$step')));
      await tester.pumpAndSettle();
    }
    expect(find.text('STEP 3'), findsOneWidget);

    // Three screens down and Back three times was the only way out.
    await tester.tap(find.byKey(const Key('home')));
    await tester.pumpAndSettle();

    expect(find.text('STEP 0'), findsOneWidget);
    expect(find.text('Back'), findsNothing, reason: 'the root has no back');
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
      find
          .ancestor(of: find.text('Back'), matching: find.byType(Container))
          .first,
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

  testWidgets('there is no hint footer on a screen', (tester) async {
    // It named D-pad buttons along the bottom of every menu in the app, on a
    // phone and a desktop, neither of which has a D-pad.
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(find.text('move'), findsNothing);
    expect(find.text('open'), findsNothing);
    expect(find.text('back'), findsNothing);
  });
}
