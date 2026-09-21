import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';
import 'package:kitchentable/ui/atoms/card_image.dart';
import 'package:kitchentable/ui/organisms/card_viewer.dart';

const _card = CatalogCard(
  oracleId: 'a',
  name: 'Sol Ring',
  typeLine: 'Artifact',
  cmc: 1,
  imageNormal: 'https://example.invalid/n.jpg',
);

Future<void> _open(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: CardViewer(card: _card)));
  await tester.pump();
}

void main() {
  testWidgets('both faces are in the tree at once', (tester) async {
    await _open(tester);

    // Two, not one. A widget that is in the tree fetches its picture, so the
    // far side is already there when the card turns. The first version built
    // one face at a time and turning over showed a black rectangle loading.
    expect(find.byType(CardImage), findsNWidgets(2));
  });

  testWidgets('a card with a second face shows that, not the generic back',
      (tester) async {
    const twoFaced = CatalogCard(
      oracleId: 'b',
      name: 'Delver of Secrets',
      typeLine: 'Creature',
      cmc: 1,
      imageNormal: 'https://example.invalid/front.jpg',
      imageBack: 'https://example.invalid/back.jpg',
    );

    await tester.pumpWidget(
      const MaterialApp(home: CardViewer(card: twoFaced)),
    );
    await tester.pump();

    final urls = tester
        .widgetList<CardImage>(find.byType(CardImage))
        .map((w) => w.url)
        .toList();

    expect(urls, contains('https://example.invalid/front.jpg'));
    expect(urls, contains('https://example.invalid/back.jpg'));
  });

  testWidgets('a one faced card turns over onto the generic back',
      (tester) async {
    await _open(tester);

    final urls = tester
        .widgetList<CardImage>(find.byType(CardImage))
        .map((w) => w.url)
        .toList();

    expect(urls.any((u) => u.contains('backs.scryfall.io')), isTrue);
  });

  testWidgets('it draws the card', (tester) async {
    await _open(tester);
    // The caption, not the name: with both faces mounted and no network in a
    // test, the name also shows on each fallback.
    expect(find.textContaining('drag to turn it over'), findsOneWidget);
  });

  testWidgets('it survives being spun many times', (tester) async {
    await _open(tester);

    // The complaint was that more than one full turn made everything go
    // black, so this goes round several times in the same direction.
    for (var i = 0; i < 24; i++) {
      await tester.timedDrag(
        find.byType(CardViewer),
        const Offset(300, 0),
        const Duration(milliseconds: 60),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('drag to turn it over'), findsOneWidget);
  });

  testWidgets('it survives being spun the other way too', (tester) async {
    await _open(tester);

    for (var i = 0; i < 24; i++) {
      await tester.timedDrag(
        find.byType(CardViewer),
        const Offset(-300, 0),
        const Duration(milliseconds: 60),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('drag to turn it over'), findsOneWidget);
  });

  testWidgets('tilting up and down does not throw', (tester) async {
    await _open(tester);

    for (final dy in [400.0, -800.0, 600.0]) {
      await tester.timedDrag(
        find.byType(CardViewer),
        Offset(0, dy),
        const Duration(milliseconds: 60),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
