import 'package:flutter/gestures.dart';
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
Widget _host(
  CardInstance instance, {
  Game? game,
  void Function(CardInstance)? onTap,
  void Function(CardInstance)? onInspect,
}) =>
    MaterialApp(
      home: Scaffold(
        body: TableCard(
          metrics: Metrics.of(DeviceClass.handheld),
          instance: instance,
          printing: null,
          width: 90,
          game: game,
          onTap: onTap == null ? null : () => onTap(instance),
          onLongPress: onInspect == null ? null : () => onInspect(instance),
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

  testWidgets('the marker takes the colour of the piece it equals',
      (tester) async {
    Color colourOf(String key) => tester
        .widget<CounterPieceView>(find.byKey(Key(key)))
        .piece
        .colour;

    // Three branches, asserted against each other and not against the
    // production function that produced them. Comparing a marker's colour to
    // `pieceNamed('+2/+2')!.colour` would move both sides at once: a mutation
    // giving every piece one colour keeps that green. These fail under that
    // mutation and under "always black" alike.
    await tester.pumpWidget(_host(const CardInstance(
      id: 'a', oracleId: 'o', counters: {'+1/+1': 2})));
    await tester.pump();
    final printed = colourOf('counter-+2/+2');

    await tester.pumpWidget(_host(const CardInstance(
      id: 'a', oracleId: 'o', counters: {'+4/+4': 1, '+0/+1': 4})));
    await tester.pump();
    final unprinted = colourOf('counter-+4/+8');

    await tester.pumpWidget(_host(const CardInstance(
      id: 'a', oracleId: 'o', counters: {'-1/-1': 2})));
    await tester.pump();
    final negative = colourOf('counter--2/-2');

    // A net the box prints is recognisable by its colour, which is the whole
    // reason the box is coloured. A net nobody prints falls back, and a
    // negative net falls back somewhere else again.
    expect(printed, isNot(unprinted));
    expect(negative, isNot(unprinted));
    expect(negative, isNot(printed));

    // And one literal, so a mutation that gives every piece its own colour
    // but the wrong one cannot pass on the three comparisons alone.
    expect(unprinted, const Color(0xFF121116));
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
    //
    // One print of the net and not two. The piece printed its value at both
    // ends, the lower one turned around, the way the plastic does so it reads
    // from the other side of a table; on a screen one person is looking. This
    // asserted two because there were two of the same Text, so it counted the
    // second print rather than a second marker, and the marker count above is
    // the part that says there is one of those.
    expect(find.byType(CounterPieceView), findsNWidgets(2));
    expect(find.text('+4/+8'), findsOneWidget);
  });

  testWidgets('a kind nobody printed is stamped like the rest', (tester) async {
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
    //
    // Once, for the reason the case above gives: the two matches were the one
    // marker's two prints, not two markers.
    expect(find.text('+2/+2'), findsOneWidget);
    expect(find.textContaining('CHARGE'), findsWidgets);
  });

  testWidgets('a right click opens what a hold opens', (tester) async {
    CardInstance? held;
    CardInstance? clicked;
    await tester.pumpWidget(_host(
      const CardInstance(id: 'a', oracleId: 'o'),
      onInspect: (c) => held = c,
    ));
    await tester.pump();

    await tester.longPress(find.byType(TableCard));
    await tester.pump();
    expect(held?.id, 'a');

    held = null;
    await tester.tap(find.byType(TableCard), buttons: kSecondaryButton);
    await tester.pump();
    clicked = held;

    // The same door, not a second one. A right click that opened a different
    // menu would be two menus to keep in step.
    expect(clicked?.id, 'a');
  });

  testWidgets('a left click still turns the card', (tester) async {
    CardInstance? turned;
    CardInstance? inspected;
    await tester.pumpWidget(_host(
      const CardInstance(id: 'a', oracleId: 'o'),
      onTap: (c) => turned = c,
      onInspect: (c) => inspected = c,
    ));
    await tester.pump();

    await tester.tap(find.byType(TableCard));
    await tester.pump();

    expect(turned?.id, 'a');
    expect(inspected, isNull, reason: 'a tap opened the menu as well');
  });

  testWidgets('a row of counters interlocks rather than overlapping',
      (tester) async {
    await tester.pumpWidget(_host(
      const CardInstance(
        id: 'a',
        oracleId: 'o',
        counters: {'flying': 1, 'vigilance': 1},
      ),
    ));
    await tester.pumpAndSettle();

    final first = tester.getRect(find.byKey(const Key('counter-flying')));
    final second = tester.getRect(find.byKey(const Key('counter-vigilance')));

    // Seated, not stacked. The step was a flat 0.82 of the width, which buried
    // a fifth of every piece under the next one; the second piece is hollowed
    // out on its left by exactly the angle the first comes to a point at, so
    // the gap between them is that point and nothing else.
    final point = first.width * CounterPieceView.notch;
    expect(second.left, moreOrLessEquals(first.right - point, epsilon: 0.01));
  });
}
