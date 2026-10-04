import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/dice/die_view.dart';
import 'package:vector_math/vector_math_64.dart' show Quaternion;
import 'package:kitchentable/features/play/dice/dice_tray.dart';

Widget _host({
  List<int> showing = const [20, 12, 6],
  void Function(int, List<int>)? onRoll,
  ({int die, int value, int turn})? announced,
}) => MaterialApp(
  home: Scaffold(
    body: DiceTray(
      showing: showing,
      width: 120,
      onRoll: onRoll ?? (_, _) {},
      announced: announced,
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

  testWidgets('tapping one rolls that one and leaves the others', (
    tester,
  ) async {
    List<int>? rolled;
    await tester.pumpWidget(
      _host(showing: const [17, 3, 5], onRoll: (_, r) => rolled = r),
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
      _host(showing: const [17, 3, 5], onRoll: (_, r) => rolled = r),
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
    expect(
      best,
      lessThanOrEqualTo(12),
      reason: 'the d12 is rolling something bigger',
    );
  });

  testWidgets('a die that has not been rolled yet still draws', (tester) async {
    await tester.pumpWidget(_host(showing: const []));
    await tester.pump();

    // A table opens with no dice thrown. Three blanks would be three holes.
    expect(find.byKey(const Key('die-20')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a throw somebody else made is acted out here', (tester) async {
    // The whole point. Before this a die rolled at the other end of a call
    // was a number on this phone that quietly read differently, with nothing
    // to watch and nobody named.
    await tester.pumpWidget(_host(showing: const [20, 12, 6]));
    await tester.pump();

    await tester.pumpWidget(
      _host(showing: const [20, 12, 2], announced: (die: 2, value: 2, turn: 1)),
    );
    await tester.pump();

    expect(
      _turning(tester, 6),
      isNotNull,
      reason: 'the d6 did not start turning',
    );

    await tester.pumpAndSettle();
    expect(_turning(tester, 6), isNull, reason: 'it never came to rest');
    expect(find.text('2'), findsWidgets);
  });

  testWidgets('the same number twice is still two throws', (tester) async {
    // A die that lands on the number it was already on changes nothing about
    // the table, so the numbers alone cannot carry this.
    await tester.pumpWidget(
      _host(showing: const [20, 12, 4], announced: (die: 2, value: 4, turn: 1)),
    );
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      _host(showing: const [20, 12, 4], announced: (die: 2, value: 4, turn: 2)),
    );
    await tester.pump();

    expect(_turning(tester, 6), isNotNull);
  });

  testWidgets('an announcement already acted out is not acted again', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(showing: const [20, 12, 4], announced: (die: 2, value: 4, turn: 7)),
    );
    await tester.pumpAndSettle();

    // Same turn, rebuilt for some other reason: a tray that started over
    // every time its parent rebuilt would never stop turning.
    await tester.pumpWidget(
      _host(showing: const [20, 12, 4], announced: (die: 2, value: 4, turn: 7)),
    );
    await tester.pump();

    expect(_turning(tester, 6), isNull);
  });

  testWidgets('a die acted out turns, then stops on the number it was given', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RollingDie(solid: trayDice[2].solid, to: 4, size: 40),
        ),
      ),
    );
    await tester.pump();
    Quaternion turn() => tester.widget<DieView>(find.byType(DieView)).turn;

    final early = turn().storage.toList();
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      turn().storage.toList(),
      isNot(equals(early)),
      reason: 'it never turned',
    );

    // Nothing here rolls anything: the throw is acted out, and the number
    // it stops on is the one everybody already agreed on.
    await tester.pumpAndSettle();
    expect(
      turn().storage.toList(),
      trayDice[2].solid.settle(3).storage.toList(),
    );
    expect(tester.widget<DieView>(find.byType(DieView)).showing, 3);
  });
}

/// How far through its throw the die with [sides] sides is, or null when it is
/// at rest.
double? _turning(WidgetTester tester, int sides) {
  final die = find.byKey(Key('die-$sides'));
  final widget = tester.widget(die);
  return (widget as dynamic).turning as double?;
}
