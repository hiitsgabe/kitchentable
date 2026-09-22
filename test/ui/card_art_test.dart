import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';
import 'package:kitchentable/ui/atoms/card_art.dart';

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
}
