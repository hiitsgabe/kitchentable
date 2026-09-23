import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/widgets/table_card.dart';
import 'package:kitchentable/table/model/card_instance.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

/// One card on a table, with no printing behind it.
///
/// Null on purpose rather than for want of a fixture: a token has no printing
/// and neither has a card from a source somebody cleared, so the back is what
/// this widget draws most often, and nothing here is about the art.
Widget _host(CardInstance instance) => MaterialApp(
      home: Scaffold(
        body: TableCard(
          metrics: Metrics.of(DeviceClass.handheld),
          instance: instance,
          printing: null,
          width: 90,
        ),
      ),
    );

void main() {
  testWidgets('two kinds of counter are told apart', (tester) async {
    await tester.pumpWidget(_host(
      const CardInstance(
        id: 'a',
        oracleId: 'o',
        counters: {'+1/+1': 2, 'damage': 3},
      ),
    ));
    await tester.pump();

    // Joined into one pill these read as `+2 +3`, which is a number nobody
    // can act on. A Pokemon takes damage and grows at the same time, and so
    // does a creature with a Wither fight behind it.
    expect(find.textContaining('+2'), findsOneWidget);
    expect(find.textContaining('3'), findsWidgets);
    expect(find.byKey(const Key('counter-+1/+1')), findsOneWidget);
    expect(find.byKey(const Key('counter-damage')), findsOneWidget);
  });
}
