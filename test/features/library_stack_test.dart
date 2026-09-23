import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/decks/model/game.dart';
import 'package:kitchentable/features/play/widgets/library_stack.dart';
import 'package:kitchentable/ui/atoms/card_art.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

Widget _host({
  String? label,
  int count = 60,
  double width = 70,
  Game? game,
  VoidCallback? onDraw,
  VoidCallback? onWork,
}) =>
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: LibraryStack(
            metrics: Metrics.of(DeviceClass.handheld),
            count: count,
          label: label,
            width: width,
            game: game,
            onDraw: onDraw ?? () {},
            onWork: onWork ?? () {},
          ),
        ),
      ),
    );

void main() {
  testWidgets('the label never makes the pile wider than a card',
      (tester) async {
    await tester.pumpWidget(_host(count: 53, label: 'Graveyard'));
    await tester.pump();

    final pile = tester.getSize(find.byKey(const Key('library-stack')));
    final whole = tester.getSize(find.byType(LibraryStack));

    // A word longer than the pile it names used to set the column's width,
    // and the column's width comes out of the board: on a 390 point phone
    // "Graveyard" made the left column 92.3 points against the 19.2 the
    // board's arithmetic budgets, and the card on the board went from 36.0 to
    // 24.5, a third smaller, for a caption.
    expect(whole.width, lessThanOrEqualTo(pile.width + 1));
  });

  testWidgets('it says how many are left', (tester) async {
    await tester.pumpWidget(_host(count: 53));

    expect(find.text('53'), findsOneWidget);
  });

  testWidgets('tapping it draws', (tester) async {
    var drew = 0;
    await tester.pumpWidget(_host(onDraw: () => drew++));

    await tester.tap(find.byKey(const Key('library-draw')));
    await tester.pump();

    expect(drew, 1);
  });

  testWidgets('a fat deck is taller than a thin one', (tester) async {
    await tester.pumpWidget(_host(count: 99));
    final fat = tester.getSize(find.byKey(const Key('library-stack'))).height;

    await tester.pumpWidget(_host(count: 4));
    await tester.pump();
    final thin = tester.getSize(find.byKey(const Key('library-stack'))).height;

    // The whole point the player asked for: the pile shrinks as it is drawn,
    // so the table looks like a table.
    expect(fat, greaterThan(thin));
  });

  testWidgets('an empty library is drawn as nothing, not as one card',
      (tester) async {
    await tester.pumpWidget(_host(count: 0));

    expect(find.text('0'), findsOneWidget);
    expect(find.byKey(const Key('library-draw')), findsNothing,
        reason: 'there is nothing to draw, so nothing offers to');
  });

  testWidgets('the stack stops growing long before a hundred', (tester) async {
    await tester.pumpWidget(_host(count: 100));
    final hundred =
        tester.getSize(find.byKey(const Key('library-stack'))).height;

    await tester.pumpWidget(_host(count: 250));
    await tester.pump();
    final many = tester.getSize(find.byKey(const Key('library-stack'))).height;

    // A Commander deck is a hundred and a real pile is about two centimetres.
    // Letting the height track the count linearly would put a two hundred and
    // fifty card pile off the screen.
    expect(many, hundred);
  });

  testWidgets('there is a way into the deck that is not drawing',
      (tester) async {
    var worked = 0;
    await tester.pumpWidget(_host(onWork: () => worked++));

    await tester.tap(find.byKey(const Key('library-work')));
    await tester.pump();

    expect(worked, 1);
  });

  testWidgets('the pile is drawn as card backs', (tester) async {
    await tester.pumpWidget(_host(count: 8, game: Game.magic));
    await tester.pump();

    // The top card and the leaves under it. A blank tile reads as a hole in
    // the table rather than as a deck, and the pile was already made of
    // CardBacks before this, so counting those proves nothing: what is new
    // is that each one has the game's picture on it.
    expect(find.byType(CardBack), findsNWidgets(9));
    expect(find.byKey(const Key('card-back-art')), findsNWidgets(9));
  });
}
