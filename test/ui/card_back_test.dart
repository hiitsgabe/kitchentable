import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/decks/model/game.dart';
import 'package:kitchentable/ui/atoms/card_art.dart';
import 'package:kitchentable/ui/atoms/card_image.dart';

void main() {
  testWidgets('a Pokemon back is painted in its own tint', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CardBack(width: 60, game: Game.pokemon)),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('pokemon-back')), findsOneWidget);
    expect(find.byKey(const Key('magic-back')), findsNothing);
  });

  testWidgets('a Magic back is painted too, nothing fetched', (tester) async {
    // The printed back is the publisher's. It used to come off the card
    // source's CDN; now nothing is requested that the user did not ask for.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CardBack(width: 60, game: Game.magic)),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('card-back-art')), findsOneWidget);
    expect(find.byKey(const Key('magic-back')), findsOneWidget);
    expect(find.byType(CardImage), findsNothing);
  });

  testWidgets('a back with no picture is still a card shaped box', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CardBack(width: 60))),
    );
    await tester.pump();

    // No game means no back to fetch, which is a token or a card the table
    // knows nothing about. It still has to occupy a card's worth of space.
    expect(find.byKey(const Key('card-back-art')), findsNothing);
    expect(tester.getSize(find.byType(CardBack)), const Size(60, 60 * 88 / 63));
  });
}
