import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/decks/model/game.dart';
import 'package:kitchentable/ui/atoms/card_art.dart';

void main() {
  test('Magic has a back and it is the real one', () {
    // Scryfall serves the Magic back, which the card viewer has used since
    // plan 1 for a card with no second face.
    expect(backFor(Game.magic), isNotNull);
    expect(backFor(Game.magic), contains('scryfall'));
  });

  test('Pokemon has no back to fetch, and does not borrow Magic\'s', () {
    // Nothing the app imports serves a Pokemon back, and a fan site is not a
    // source. Null is the honest answer until the catalog that serves one
    // arrives, and it draws the plain box.
    expect(backFor(Game.pokemon), isNull);
  });

  testWidgets('a back with a picture draws it', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: CardBack(width: 60, game: Game.magic),
      ),
    ));
    await tester.pump();

    expect(find.byKey(const Key('card-back-art')), findsOneWidget);
  });

  testWidgets('a back with no picture is still a card shaped box',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: CardBack(width: 60)),
    ));
    await tester.pump();

    // No game means no back to fetch, which is a token or a card the table
    // knows nothing about. It still has to occupy a card's worth of space.
    expect(find.byKey(const Key('card-back-art')), findsNothing);
    expect(
      tester.getSize(find.byType(CardBack)),
      const Size(60, 60 * 88 / 63),
    );
  });
}
