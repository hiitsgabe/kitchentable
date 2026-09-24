import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/widgets/zone_chip.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';
import 'package:kitchentable/ui/atoms/card_art.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

const _printing = CatalogCard(
  oracleId: 'c0',
  name: 'Mountain',
  typeLine: 'Basic Land',
  cmc: 0,
);

/// A card of the size a phone's board draws one at, which is what the chip is
/// being compared against: the chip stands in for a card and the whole point of
/// it is that it is not one.
const _card = 50.0;

Widget _host({
  int count = 0,
  CatalogCard? face,
  VoidCallback? onTap,
}) =>
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: ZoneChip(
              metrics: Metrics.of(DeviceClass.handheld),
              pileName: 'graveyard',
              label: 'graveyard',
              count: count,
              cardWidth: _card,
              face: face,
              onTap: onTap,
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('an empty one says how many and draws no card', (tester) async {
    await tester.pumpWidget(_host());

    // Sixteen percent of a phone went on two outlines of cards that are not
    // there, and the emptier of the two was the leftmost thing on the screen.
    expect(find.text('0'), findsOneWidget);
    expect(find.byType(CardArt), findsNothing);
  });

  testWidgets('one with cards in it shows the top card', (tester) async {
    await tester.pumpWidget(_host(count: 3, face: _printing));

    expect(find.text('3'), findsOneWidget);
    final art = tester.widget<CardArt>(find.byType(CardArt));
    expect(art.card.name, 'Mountain');
  });

  testWidgets('it is not as tall as a card', (tester) async {
    await tester.pumpWidget(_host(count: 3, face: _printing));

    final chip = tester.getSize(find.byKey(const Key('graveyard-stack')));

    // A card of this width is 69.8 points tall. The card is cropped into the
    // chip rather than shrunk into it, which is the pile barely sticking out
    // past the edge the literature describes.
    expect(chip.height, lessThan(_card * 88 / 63 * 0.7));
  });
}
