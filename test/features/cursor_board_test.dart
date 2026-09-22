import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/widgets/cursor_board.dart';
import 'package:kitchentable/table/model/card_instance.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

List<CardInstance> _cards(int n) => [
      for (var i = 0; i < n; i++)
        CardInstance(id: 'b$i', oracleId: 'card$i'),
    ];

Widget _host({
  int board = 3,
  int graveyard = 0,
  void Function(CardInstance)? onActivate,
}) =>
    MaterialApp(
      home: Scaffold(
        body: CursorBoard(
          metrics: Metrics.of(DeviceClass.tv),
          zones: [
            (id: 'battlefield-s1', label: 'Battlefield', cards: _cards(board)),
            (
              id: 'graveyard-s1',
              label: 'Graveyard',
              cards: [
                for (var i = 0; i < graveyard; i++)
                  CardInstance(id: 'g$i', oracleId: 'card$i'),
              ],
            ),
          ],
          printings: const {},
          onActivate: onActivate ?? (_) {},
          onInspect: (_) {},
        ),
      ),
    );

void main() {
  testWidgets('the ring starts on the first card', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    expect(find.byKey(const Key('ring-b0')), findsOneWidget);
    expect(find.byKey(const Key('ring-b1')), findsNothing);
  });

  testWidgets('right walks the ring along', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(find.byKey(const Key('ring-b1')), findsOneWidget);
    expect(find.byKey(const Key('ring-b0')), findsNothing);
  });

  testWidgets('the shoulder button changes pile', (tester) async {
    await tester.pumpWidget(_host(graveyard: 2));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(find.byKey(const Key('ring-g0')), findsOneWidget);
  });

  testWidgets('select acts on the card under the ring', (tester) async {
    CardInstance? acted;
    await tester.pumpWidget(_host(onActivate: (c) => acted = c));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(acted?.id, 'b1');
  });

  testWidgets('an empty board draws no ring and does not crash',
      (tester) async {
    await tester.pumpWidget(_host(board: 0));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(find.textContaining('Nothing'), findsOneWidget);
  });
}
