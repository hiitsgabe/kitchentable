import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/ui/input/pad.dart';

/// A tiny app under the same input layer the real one runs under.
Widget _app() => MaterialApp(
  builder: (context, child) => PadInput(child: child!),
  home: Scaffold(
    body: Builder(
      builder: (context) => Center(
        child: TextButton(
          key: const Key('open'),
          autofocus: true,
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            builder: (_) => const TextButton(
              key: Key('inside'),
              autofocus: true,
              onPressed: null,
              child: Text('inside'),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  ),
);

void main() {
  group('the buttons that arrive as keys', () {
    testWidgets('B closes the sheet that is open, and then nothing more', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('inside')), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonB);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('inside')), findsNothing);

      // The first route stays: there is nowhere for it to go.
      await tester.sendKeyEvent(LogicalKeyboardKey.gameButtonB);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('open')), findsOneWidget);
    });

    testWidgets('Escape does the same', (tester) async {
      await tester.pumpWidget(_app());
      await tester.tap(find.byKey(const Key('open')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('inside')), findsNothing);
    });
  });

  group('the plugin reports', () {
    test('A and B on iOS and in the browser', () {
      final held = <String, TraversalDirection?>{};
      expect(padPress('a.circle', 1, held: held), isA<PadActivate>());
      expect(padPress('a.circle', 0, held: held), isNull, reason: 'release');
      expect(padPress('button 0', 1, held: held), isA<PadActivate>());
      expect(padPress('b.circle', 1, held: held), isA<PadDismiss>());
      expect(padPress('button 1', 1, held: held), isA<PadDismiss>());
      expect(padPress('x.circle', 1, held: held), isNull, reason: 'unused');
    });

    test('a stick pushed moves once, held moves no more, released moves '
        'nothing', () {
      final held = <String, TraversalDirection?>{};
      final first = padPress('l.joystick xAxis', 0.9, held: held);
      expect(first, isA<PadMove>());
      expect((first! as PadMove).direction, TraversalDirection.right);
      expect(padPress('l.joystick xAxis', 1.0, held: held), isNull);
      expect(padPress('l.joystick xAxis', 0.0, held: held), isNull);
      final back = padPress('l.joystick xAxis', -0.8, held: held);
      expect((back! as PadMove).direction, TraversalDirection.left);
      expect(
        padPress('l.joystick xAxis', 0.3, held: held),
        isNull,
        reason: 'half way is nowhere',
      );
    });

    test('up is up on every platform, whichever way the axis points', () {
      final held = <String, TraversalDirection?>{};
      // iOS: y positive is up.
      expect(
        (padPress('dpad yAxis', 1, held: held)! as PadMove).direction,
        TraversalDirection.up,
      );
      // The browser: y positive is down, and the D-pad is four buttons.
      expect(
        (padPress('analog 1', 1, held: held)! as PadMove).direction,
        TraversalDirection.down,
      );
      expect(
        (padPress('button 12', 1, held: held)! as PadMove).direction,
        TraversalDirection.up,
      );
      expect(
        (padPress('button 15', 1, held: held)! as PadMove).direction,
        TraversalDirection.right,
      );
    });

    test('the right stick moves nothing', () {
      final held = <String, TraversalDirection?>{};
      expect(padPress('r.joystick xAxis', 1, held: held), isNull);
      expect(padPress('analog 2', 1, held: held), isNull);
    });
  });
}
