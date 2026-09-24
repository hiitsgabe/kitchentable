import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';
import 'package:kitchentable/ui/atoms/card_art.dart';
import 'package:kitchentable/ui/atoms/card_image.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

const _full = CatalogCard(
  oracleId: 'o',
  name: 'Sol Ring',
  typeLine: 'Artifact',
  cmc: 1,
  imageSmall: 'small.jpg',
  imageNormal: 'normal.jpg',
  imageLarge: 'large.jpg',
);

void main() {
  test('a thumbnail in a list takes the small file', () {
    // Scryfall's small is 146 wide. A deck row draws at about 40 points.
    expect(artFor(_full, width: 40, pixelRatio: 2), 'small.jpg');
  });

  test('a card on the battlefield does not take a thumbnail', () {
    // 90 points at ratio 2 is 180 device pixels, already past small's 146.
    // This is the bug the player reported as "qualidade baixa": the board
    // asked for small and blew it up three and a half times.
    expect(artFor(_full, width: 90, pixelRatio: 2), isNot('small.jpg'));
  });

  test('a card that fills the screen takes the large file', () {
    expect(artFor(_full, width: 340, pixelRatio: 2), 'large.jpg');
  });

  test('the device pixel ratio counts, not the points', () {
    // The same card on a three times screen needs a bigger file than on a one
    // times screen, and the widget only knows points.
    expect(artFor(_full, width: 80, pixelRatio: 1), 'small.jpg');
    expect(artFor(_full, width: 80, pixelRatio: 3), isNot('small.jpg'));
  });

  test('a catalog imported before the large column falls back', () {
    const old = CatalogCard(
      oracleId: 'o',
      name: 'Sol Ring',
      typeLine: 'Artifact',
      cmc: 1,
      imageSmall: 'small.jpg',
      imageNormal: 'normal.jpg',
    );

    // A schema bump does not refetch 36000 rows. Everything imported before
    // this column has a null there and must still draw.
    expect(artFor(old, width: 340, pixelRatio: 2), 'normal.jpg');
  });

  test('a card with no pictures at all returns nothing', () {
    const bare =
        CatalogCard(oracleId: 'o', name: 'Token', typeLine: 'Token', cmc: 0);

    expect(artFor(bare, width: 340, pixelRatio: 2), isNull);
  });

  testWidgets('a card drawn bigger than it asked for takes a bigger file',
      (tester) async {
    Future<String> urlUnder(Widget Function(Widget) wrap) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: wrap(
            const CardArt(
              metrics: Metrics(scale: 1, safeInset: 16, focusRing: 2),
              card: _full,
              width: 90,
            ),
          ),
        ),
      ));
      await tester.pump();
      return tester.widget<CardImage>(find.byType(CardImage)).url;
    }

    // 90 points is what a card on the canvas asks for, in mat units. At a
    // device ratio of one that is 90 pixels, and the small file is 146, so the
    // small file is the right answer for the size this card says it is.
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    expect(await urlUnder((c) => c), 'small.jpg');

    // But the canvas scales its whole surface, so the same card is on screen
    // at twice that and the 146 pixel file is being stretched over 180. It
    // used to go on asking for the file its own width deserved however far it
    // was zoomed, which is what "a qualidade da imagem das cartas diminui" was
    // on the view with everybody's mat in it.
    expect(
      await urlUnder((c) => ArtScale(scale: 2, child: c)),
      'normal.jpg',
    );
  });
}
