import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';

void main() {
  test('an ordinary card has a front and no back', () {
    final card = CatalogCard.fromScryfall(jsonDecode('''
{
  "oracle_id": "a", "name": "Sol Ring", "type_line": "Artifact", "cmc": 1,
  "image_uris": {"small": "s.jpg", "normal": "n.jpg"}
}
''') as Map<String, dynamic>);

    expect(card.imageNormal, 'n.jpg');
    expect(card.imageBack, isNull,
        reason: 'it turns over onto the generic Magic back');
  });

  test('the large file is kept, because the board draws cards big', () {
    final card = CatalogCard.fromScryfall(jsonDecode('''
{
  "oracle_id": "a", "name": "Sol Ring", "type_line": "Artifact", "cmc": 1,
  "image_uris": {"small": "s.jpg", "normal": "n.jpg", "large": "l.jpg"}
}
''') as Map<String, dynamic>);

    // Scryfall's normal is 488 pixels wide and a card on a wide window is
    // past that, which is what "qualidade baixa" was. Throwing the large URL
    // away at import time cannot be recovered without refetching the catalog.
    expect(card.imageLarge, 'l.jpg');
  });

  test('a card whose record has no large file says so', () {
    final card = CatalogCard.fromScryfall(jsonDecode('''
{
  "oracle_id": "a", "name": "Sol Ring", "type_line": "Artifact", "cmc": 1,
  "image_uris": {"small": "s.jpg", "normal": "n.jpg"}
}
''') as Map<String, dynamic>);

    expect(card.imageLarge, isNull);
  });

  test('a transforming card takes the front face large file', () {
    final card = CatalogCard.fromScryfall(jsonDecode('''
{
  "oracle_id": "b", "name": "Delver of Secrets // Insectile Aberration",
  "type_line": "Creature - Human Wizard", "cmc": 1, "layout": "transform",
  "card_faces": [
    {"name": "Delver of Secrets",
     "image_uris": {"small": "front-s.jpg", "large": "front-l.jpg"}},
    {"name": "Insectile Aberration",
     "image_uris": {"small": "back-s.jpg", "large": "back-l.jpg"}}
  ]
}
''') as Map<String, dynamic>);

    expect(card.imageLarge, 'front-l.jpg');
  });

  test('a transforming card carries its real second face', () {
    // Shape taken from the live Delver of Secrets record: no top level
    // image_uris at all, and two faces each with their own.
    final card = CatalogCard.fromScryfall(jsonDecode('''
{
  "oracle_id": "b", "name": "Delver of Secrets // Insectile Aberration",
  "type_line": "Creature - Human Wizard", "cmc": 1, "layout": "transform",
  "card_faces": [
    {"name": "Delver of Secrets",
     "image_uris": {"small": "front-s.jpg", "normal": "front-n.jpg"}},
    {"name": "Insectile Aberration",
     "image_uris": {"small": "back-s.jpg", "normal": "back-n.jpg"}}
  ]
}
''') as Map<String, dynamic>);

    expect(card.imageNormal, 'front-n.jpg',
        reason: 'the front face stands in for the card');
    expect(card.imageBack, 'back-n.jpg');
  });

  test('a split card has one face worth of art and no back', () {
    final card = CatalogCard.fromScryfall(jsonDecode('''
{
  "oracle_id": "c", "name": "Fire // Ice", "type_line": "Instant // Instant",
  "cmc": 2, "layout": "split",
  "image_uris": {"small": "s.jpg", "normal": "n.jpg"},
  "card_faces": [{"name": "Fire"}, {"name": "Ice"}]
}
''') as Map<String, dynamic>);

    expect(card.imageNormal, 'n.jpg');
    expect(card.imageBack, isNull,
        reason: 'both halves are printed on the one side');
  });

  test('a card with no art anywhere does not throw', () {
    final card = CatalogCard.fromScryfall(jsonDecode('''
{"oracle_id": "d", "name": "A Token", "type_line": "Token", "cmc": 0}
''') as Map<String, dynamic>);

    expect(card.imageNormal, isNull);
    expect(card.imageSmall, isNull);
    expect(card.imageBack, isNull);
  });
}
