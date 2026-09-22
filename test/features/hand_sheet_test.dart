import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/widgets/hand_sheet.dart';
import 'package:kitchentable/features/play/widgets/table_card.dart';
import 'package:kitchentable/table/model/card_instance.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

List<CardInstance> _hand(int n) => [
      for (var i = 0; i < n; i++)
        CardInstance(id: 'h$i', oracleId: 'card$i'),
    ];

Widget _host({
  int cards = 3,
  void Function(String cardId, int to)? onReorder,
}) =>
    MaterialApp(
      home: Scaffold(
        body: HandSheet(
          metrics: Metrics.of(DeviceClass.handheld),
          cards: _hand(cards),
          printings: const {},
          onPlay: (_) {},
          onInspect: (_) {},
          onReorder: onReorder ?? (_, _) {},
        ),
      ),
    );

void main() {
  testWidgets('a few cards sit in the middle, not against the left edge',
      (tester) async {
    await tester.pumpWidget(_host(cards: 3));
    await tester.pump();

    final sheet = tester.getRect(find.byType(HandSheet));
    final first = tester.getRect(find.byType(TableCard).first);
    final last = tester.getRect(find.byType(TableCard).last);

    final leftGap = first.left - sheet.left;
    final rightGap = sheet.right - last.right;

    expect(leftGap, greaterThan(1), reason: 'it was pinned to the left edge');
    expect(leftGap, closeTo(rightGap, 1));
  });

  testWidgets('a full hand still fills the width and scrolls', (tester) async {
    await tester.pumpWidget(_host(cards: 30));
    await tester.pump();

    final sheet = tester.getRect(find.byType(HandSheet));
    final first = tester.getRect(find.byType(TableCard).first);

    // Centring a hand that does not fit would push its left edge off screen.
    expect(first.left, closeTo(sheet.left, 12));
  });

  testWidgets('an empty hand says so', (tester) async {
    await tester.pumpWidget(_host(cards: 0));

    expect(find.textContaining('No cards'), findsOneWidget);
  });

  testWidgets('a card dragged sideways reports where it was put',
      (tester) async {
    ({String id, int to})? moved;
    await tester.pumpWidget(_host(
      cards: 4,
      onReorder: (id, to) => moved = (id: id, to: to),
    ));
    await tester.pump();

    final third = tester.getCenter(find.byType(TableCard).at(2));
    final gesture = await tester.startGesture(third);
    await tester.pump(const Duration(milliseconds: 40));
    await gesture.moveTo(tester.getCenter(find.byType(TableCard).first));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(moved?.id, 'h2');
    expect(moved?.to, 0);
  });

  testWidgets('a tap still plays the card', (tester) async {
    CardInstance? played;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HandSheet(
          metrics: Metrics.of(DeviceClass.handheld),
          cards: _hand(3),
          printings: const {},
          onPlay: (c) => played = c,
          onInspect: (_) {},
          onReorder: (_, _) {},
        ),
      ),
    ));
    await tester.pump();

    // Adding a drag to a widget that already had a tap is how a tap stops
    // working. It did, once, on the board.
    await tester.tap(find.byType(TableCard).first);
    await tester.pump();

    expect(played?.id, 'h0');
  });
}
