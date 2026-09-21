import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';
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
  testWidgets('it draws the card', (tester) async {
    await _open(tester);
    expect(find.text('Sol Ring'), findsOneWidget);
  });

  testWidgets('it survives being spun many times', (tester) async {
    await _open(tester);

    // The complaint was that more than one full turn made everything go
    // black, so this goes round several times in the same direction.
    for (var i = 0; i < 24; i++) {
      await tester.drag(find.text('Sol Ring'), const Offset(0, 0));
      await tester.timedDrag(
        find.byType(CardViewer),
        const Offset(300, 0),
        const Duration(milliseconds: 60),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Sol Ring'), findsOneWidget);
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
    expect(find.text('Sol Ring'), findsOneWidget);
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
