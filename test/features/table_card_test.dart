import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/decks/model/game.dart';
import 'package:kitchentable/features/play/widgets/counter_piece.dart';
import 'package:kitchentable/features/play/widgets/table_card.dart';
import 'package:kitchentable/table/model/card_instance.dart';
import 'package:kitchentable/ui/atoms/card_art.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

/// One card on a table, with no printing behind it.
///
/// Null on purpose rather than for want of a fixture: a token has no printing
/// and neither has a card from a source somebody cleared, so the back is what
/// this widget draws most often, and nothing here is about the art.
Widget _host(CardInstance instance, {Game? game}) => MaterialApp(
      home: Scaffold(
        body: TableCard(
          metrics: Metrics.of(DeviceClass.handheld),
          instance: instance,
          printing: null,
          width: 90,
          game: game,
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

    // Still the same thing this case has always said: a Pokemon takes damage
    // and grows at the same time, and so does a creature with a Wither fight
    // behind it, so the two cannot be one object.
    //
    // What changed is which object the numbers land on. Two `+1/+1` are a
    // `+2/+2`, which is a piece the box actually holds, so the marker is
    // keyed by the piece it comes out as and `counter-+1/+1` is no longer a
    // thing on the card. `counter-damage` means exactly what it meant.
    expect(find.byKey(const Key('counter-+2/+2')), findsOneWidget);
    expect(find.byKey(const Key('counter-damage')), findsOneWidget);
    expect(find.byKey(const Key('counter-+1/+1')), findsNothing);
    expect(find.textContaining('3'), findsWidgets);
  });

  testWidgets('a face down card shows the game s own back', (tester) async {
    await tester.pumpWidget(_host(
      const CardInstance(id: 'a', oracleId: 'o', faceDown: true),
      game: Game.magic,
    ));
    await tester.pump();

    // The real back, not the outlined box a CardBack draws when it does not
    // know which game it is. That box is for a token and for a card the
    // catalog has never heard of.
    expect(find.byKey(const Key('card-back-art')), findsOneWidget);
  });

  testWidgets('a card of no game still draws something', (tester) async {
    await tester.pumpWidget(_host(
      const CardInstance(id: 'a', oracleId: 'o', faceDown: true),
    ));
    await tester.pump();

    expect(find.byType(CardBack), findsOneWidget);
    expect(find.byKey(const Key('card-back-art')), findsNothing);
  });

  testWidgets('a card wearing counters shows the pieces', (tester) async {
    await tester.pumpWidget(_host(
      const CardInstance(
        id: 'a',
        oracleId: 'o',
        counters: {'+4/+4': 1, 'flying': 1},
      ),
    ));
    await tester.pump();

    expect(find.byType(CounterPieceView), findsNWidgets(2));
  });

  testWidgets('a pile of numbers reads as one marker', (tester) async {
    await tester.pumpWidget(_host(
      const CardInstance(
        id: 'a',
        oracleId: 'o',
        counters: {'+4/+4': 1, '+0/+1': 4, 'flying': 1},
      ),
    ));
    await tester.pump();

    // Five objects to add up by eye is what the raw map looked like. One
    // marker saying the net, plus the keyword, which is not a number and has
    // nothing to add to.
    expect(find.byType(CounterPieceView), findsNWidgets(2));
    expect(find.text('+4/+8'), findsNWidgets(2));
  });

  testWidgets('a kind nobody printed keeps its own name', (tester) async {
    await tester.pumpWidget(_host(
      const CardInstance(
        id: 'a',
        oracleId: 'o',
        counters: {'+1/+1': 2, 'charge': 3},
      ),
    ));
    await tester.pump();

    // `charge` does nothing to power or toughness, so it cannot join the sum
    // and has to stand on its own with its count.
    expect(find.text('+2/+2'), findsNWidgets(2));
    expect(find.textContaining('charge'), findsWidgets);
  });
}
