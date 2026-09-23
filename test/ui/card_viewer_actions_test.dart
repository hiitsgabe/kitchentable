import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';
import 'package:kitchentable/table/model/card_instance.dart';
import 'package:kitchentable/ui/organisms/card_viewer.dart';

const _printing = CatalogCard(
  oracleId: 'o',
  name: 'Goblin Chieftain',
  typeLine: 'Creature',
  cmc: 3,
);

Widget _host({
  CardInstance? instance,
  void Function(CardAction)? onAct,
  bool hasCommandZone = false,
}) =>
    MaterialApp(
      home: Scaffold(
        body: CardViewer(
          card: _printing,
          instance: instance,
          onAct: onAct,
          hasCommandZone: hasCommandZone,
        ),
      ),
    );

void main() {
  testWidgets('the action bar fits a phone', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(
      instance: const CardInstance(id: 'a', oracleId: 'o'),
      hasCommandZone: true,
    ));
    await tester.pump();

    // Every other case in this file runs at the default 800 wide, where the
    // bar has always fitted. On a phone a Row of these overflowed by 152
    // points, and had by 141 since before the command zone button existed:
    // nothing saw it because nothing ever built this at phone width.
    expect(tester.takeException(), isNull);
  });

  testWidgets('with no card behind it, it is just a viewer', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    // The deck builder opens this on a printing that is not on any table.
    // There is nothing to turn over, so nothing offers to.
    expect(find.byKey(const Key('act-flip')), findsNothing);
    expect(find.byKey(const Key('act-upside-down')), findsNothing);
  });

  testWidgets('a card on the table gets its controls', (tester) async {
    await tester.pumpWidget(
      _host(instance: const CardInstance(id: 'a', oracleId: 'o')),
    );
    await tester.pump();

    expect(find.byKey(const Key('act-upside-down')), findsOneWidget);
    expect(find.byKey(const Key('act-flip')), findsOneWidget);
    expect(find.byKey(const Key('act-counter-up')), findsOneWidget);
    expect(find.byKey(const Key('act-counter-down')), findsOneWidget);
  });

  testWidgets('turning it upside down is reported', (tester) async {
    CardAction? acted;
    await tester.pumpWidget(_host(
      instance: const CardInstance(id: 'a', oracleId: 'o'),
      onAct: (a) => acted = a,
    ));
    await tester.pump();

    await tester.tap(find.byKey(const Key('act-upside-down')));
    await tester.pump();

    expect(acted, CardAction.upsideDown);
  });

  testWidgets('a card already upside down offers to be straightened',
      (tester) async {
    await tester.pumpWidget(_host(
      instance: const CardInstance(id: 'a', oracleId: 'o', rotation: 180),
    ));
    await tester.pump();

    expect(find.byKey(const Key('act-straighten')), findsOneWidget);
    expect(find.byKey(const Key('act-upside-down')), findsNothing);
  });

  testWidgets('counters read back off the card', (tester) async {
    await tester.pumpWidget(_host(
      instance: const CardInstance(
        id: 'a',
        oracleId: 'o',
        counters: {'+1/+1': 3},
      ),
    ));
    await tester.pump();

    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('both counter directions report', (tester) async {
    final acted = <CardAction>[];
    await tester.pumpWidget(_host(
      instance: const CardInstance(id: 'a', oracleId: 'o'),
      onAct: acted.add,
    ));
    await tester.pump();

    await tester.tap(find.byKey(const Key('act-counter-up')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('act-counter-down')));
    await tester.pump();

    expect(acted, [CardAction.counterUp, CardAction.counterDown]);
  });

  testWidgets('a card can be sent to the command zone from the big view',
      (tester) async {
    CardAction? acted;
    await tester.pumpWidget(_host(
      instance: const CardInstance(id: 'a', oracleId: 'o'),
      onAct: (a) => acted = a,
      hasCommandZone: true,
    ));
    await tester.pump();

    await tester.tap(find.byKey(const Key('act-command')));
    await tester.pump();

    expect(acted, CardAction.commandZone);
  });

  testWidgets('a table with no command zone does not offer it',
      (tester) async {
    await tester.pumpWidget(
      _host(instance: const CardInstance(id: 'a', oracleId: 'o')),
    );
    await tester.pump();

    // Standard and Pauper have no such corner, and an action that moves a
    // card into a zone that does not exist is a silent no op.
    expect(find.byKey(const Key('act-command')), findsNothing);
  });

  testWidgets('a card on the table can be copied', (tester) async {
    CardAction? acted;
    await tester.pumpWidget(_host(
      instance: const CardInstance(id: 'a', oracleId: 'o'),
      onAct: (a) => acted = a,
    ));
    await tester.pump();

    await tester.tap(find.byKey(const Key('act-copy')));
    await tester.pump();

    expect(acted, CardAction.copy);
  });

  testWidgets('a printing with no card behind it cannot be copied',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    // The deck builder opens this on a printing that is on no table. There is
    // nothing to copy onto a battlefield that does not exist.
    expect(find.byKey(const Key('act-copy')), findsNothing);
  });
}
