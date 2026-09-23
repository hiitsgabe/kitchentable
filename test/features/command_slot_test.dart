import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/decks/model/game.dart';
import 'package:kitchentable/features/play/widgets/card_drag.dart';
import 'package:kitchentable/features/play/widgets/command_slot.dart';
import 'package:kitchentable/features/play/widgets/table_card.dart';
import 'package:kitchentable/table/model/card_instance.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

Widget _host({
  List<CardInstance> cards = const [
    CardInstance(id: 'c0', oracleId: 'General'),
  ],
  void Function(CardInstance)? onTap,
  Game? game,
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
          onSendHome: (_) {},
          game: game,
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

  testWidgets('a card dropped on the corner is reported', (tester) async {
    CardInstance? sent;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            DraggableCard(
              card: const CardInstance(id: 'x', oracleId: 'General'),
              child: const SizedBox(key: Key('loose'), width: 40, height: 56),
            ),
            Expanded(
              child: CommandSlot(
                metrics: Metrics.of(DeviceClass.handheld),
                cards: const [],
                printings: const {},
                width: 60,
                onTap: (_) {},
                onInspect: (_) {},
                onSendHome: (c) => sent = c,
              ),
            ),
          ],
        ),
      ),
    ));
    await tester.pump();

    final to = tester.getCenter(find.byType(CommandSlot));
    final from = tester.getCenter(find.byKey(const Key('loose')));
    await tester.dragFrom(from, to - from);
    await tester.pumpAndSettle();

    expect(sent?.id, 'x');
  });

  testWidgets('a commander is drawn on the game s own back', (tester) async {
    await tester.pumpWidget(_host(game: Game.magic));
    await tester.pump();

    // The corner had this argument and threw it away for a while: it took the
    // game and never handed it to the card, so a commander face down in the
    // corner drew the plain box and the whole suite stayed green.
    expect(find.byKey(const Key('card-back-art')), findsOneWidget);
  });
}
