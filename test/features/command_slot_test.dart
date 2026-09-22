import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/widgets/command_slot.dart';
import 'package:kitchentable/features/play/widgets/table_card.dart';
import 'package:kitchentable/table/model/card_instance.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

Widget _host({
  List<CardInstance> cards = const [
    CardInstance(id: 'c0', oracleId: 'General'),
  ],
  void Function(CardInstance)? onTap,
}) =>
    MaterialApp(
      home: Scaffold(
        body: CommandSlot(
          metrics: Metrics.of(DeviceClass.handheld),
          cards: cards,
          printings: const {},
          width: 60,
          onTap: onTap ?? (_) {},
          onInspect: (_) {},
        ),
      ),
    );

void main() {
  testWidgets('the commander is drawn', (tester) async {
    await tester.pumpWidget(_host());

    expect(find.byType(TableCard), findsOneWidget);
    expect(find.text('Command'), findsOneWidget);
  });

  testWidgets('an empty slot still says what it is', (tester) async {
    await tester.pumpWidget(_host(cards: const []));

    // A Commander table always has this corner, even for the moment the
    // commander is on the battlefield. An empty corner that vanishes reads as
    // a bug.
    expect(find.text('Command'), findsOneWidget);
    expect(find.byType(TableCard), findsNothing);
  });

  testWidgets('two commanders both fit', (tester) async {
    await tester.pumpWidget(_host(cards: const [
      CardInstance(id: 'c0', oracleId: 'A'),
      CardInstance(id: 'c1', oracleId: 'B'),
    ]));

    // Partner exists, and so does Background. Two is a real hand of cards.
    expect(find.byType(TableCard), findsNWidgets(2));
  });

  testWidgets('tapping one reports it', (tester) async {
    CardInstance? tapped;
    await tester.pumpWidget(_host(onTap: (c) => tapped = c));

    await tester.tap(find.byType(TableCard).first);
    await tester.pump();

    expect(tapped?.id, 'c0');
  });
}
