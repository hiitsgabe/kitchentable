import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/dice/dice_tray.dart';

Widget _host({
  List<int> showing = const [20, 12, 6],
  void Function(List<int>)? onRoll,
}) =>
    MaterialApp(
      home: Scaffold(
        body: DiceTray(
          showing: showing,
          width: 120,
          onRoll: onRoll ?? (_) {},
        ),
      ),
    );

void main() {
  testWidgets('there are three of them', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    expect(find.byKey(const Key('die-20')), findsOneWidget);
    expect(find.byKey(const Key('die-12')), findsOneWidget);
    expect(find.byKey(const Key('die-6')), findsOneWidget);
  });

  testWidgets('each shows what it last landed on', (tester) async {
    await tester.pumpWidget(_host(showing: const [17, 3, 5]));
    await tester.pumpAndSettle();

    expect(find.text('17'), findsWidgets);
    expect(find.text('3'), findsWidgets);
    expect(find.text('5'), findsWidgets);
  });

  testWidgets('tapping one rolls that one and leaves the others',
      (tester) async {
    List<int>? rolled;
    await tester.pumpWidget(
      _host(showing: const [17, 3, 5], onRoll: (r) => rolled = r),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('die-12')));
    await tester.pumpAndSettle();

    expect(rolled, hasLength(3));
    expect(rolled![0], 17, reason: 'the d20 was not touched');
    expect(rolled![2], 5, reason: 'the d6 was not touched');
    expect(rolled![1], inInclusiveRange(1, 12));
  });

  testWidgets('the d12 rolls a number no d6 has', (tester) async {
    List<int>? rolled;
    await tester.pumpWidget(
      _host(showing: const [17, 3, 5], onRoll: (r) => rolled = r),
    );
    await tester.pump();

    // One tap and a range check cannot tell a d12 from the d6 beside it,
    // because every number a d6 shows is a number a d12 shows too: a tray
    // where each die reads its neighbour's solid passes
    // `inInclusiveRange(1, 12)` every time. Forty taps can. A d12 that never
    // leaves the bottom half of its range in forty throws is one chance in a
    // million million, and a d12 that is really a d6 never leaves it at all.
    var best = 0;
    for (var i = 0; i < 40; i++) {
      await tester.tap(find.byKey(const Key('die-12')));
      await tester.pumpAndSettle();
      best = math.max(best, rolled![1]);
    }

    expect(best, greaterThan(6), reason: 'the d12 is rolling somebody else');
    // And the other neighbour, which the single tap above catches only two
    // times in five: forty taps of a d20 that never clear a twelve is one
    // chance in a thousand million.
    expect(best, lessThanOrEqualTo(12),
        reason: 'the d12 is rolling something bigger');
  });

  testWidgets('a die that has not been rolled yet still draws',
      (tester) async {
    await tester.pumpWidget(_host(showing: const []));
    await tester.pump();

    // A table opens with no dice thrown. Three blanks would be three holes.
    expect(find.byKey(const Key('die-20')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
