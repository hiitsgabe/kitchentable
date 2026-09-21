import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/decks/import/decklist_parser.dart';

void main() {
  test('a plain count and a name', () {
    final r = parseDecklist('4 Lightning Bolt');
    expect(r.entries.single.quantity, 4);
    expect(r.entries.single.name, 'Lightning Bolt');
  });

  test('the x form every shop uses', () {
    expect(parseDecklist('4x Lightning Bolt').entries.single.quantity, 4);
    expect(parseDecklist('4 x Lightning Bolt').entries.single.name,
        'Lightning Bolt');
  });

  test('no count at all means one', () {
    final r = parseDecklist('Sol Ring');
    expect(r.entries.single.quantity, 1);
    expect(r.entries.single.name, 'Sol Ring');
  });

  test('a set code and collector number are stripped off the name', () {
    final r = parseDecklist('1 Sol Ring (C21) 263');
    expect(r.entries.single.name, 'Sol Ring');
    expect(r.entries.single.setCode, 'C21');
  });

  test('a name with a number in it survives', () {
    expect(parseDecklist('2 Borrowing 100,000 Arrows').entries.single.name,
        'Borrowing 100,000 Arrows');
  });

  test('a name with a comma and an apostrophe survives', () {
    final r = parseDecklist("1 Urza's Saga\n1 Jace, the Mind Sculptor");
    expect(r.entries.map((e) => e.name),
        ["Urza's Saga", 'Jace, the Mind Sculptor']);
  });

  test('blank lines and comments are skipped without complaint', () {
    final r = parseDecklist('''
// my deck
4 Lightning Bolt

# another comment
2 Counterspell
''');
    expect(r.entries.length, 2);
    expect(r.ignored, isEmpty);
  });

  test('a sideboard header moves everything after it', () {
    final r = parseDecklist('''
4 Lightning Bolt

Sideboard
2 Pyroblast
''');
    expect(r.entries.where((e) => !e.sideboard).single.name, 'Lightning Bolt');
    expect(r.entries.where((e) => e.sideboard).single.name, 'Pyroblast');
  });

  test('a deck header switches back out of the sideboard', () {
    final r = parseDecklist('''
Sideboard
2 Pyroblast
Deck
4 Lightning Bolt
''');
    expect(r.entries.where((e) => e.sideboard).single.name, 'Pyroblast');
    expect(r.entries.where((e) => !e.sideboard).single.name, 'Lightning Bolt');
  });

  test('it counts both piles separately', () {
    final r = parseDecklist('''
4 Lightning Bolt
56 Mountain
Sideboard
15 Pyroblast
''');
    expect(r.cardCount, 60);
    expect(r.sideboardCount, 15);
  });

  test('a line it cannot read is reported, never silently dropped', () {
    final r = parseDecklist('4 Lightning Bolt\n0 Nothing');
    expect(r.entries.single.name, 'Lightning Bolt');
    expect(r.ignored, ['0 Nothing']);
  });

  test('export junk is reported, not imported as a card', () {
    final r = parseDecklist('''
4 Lightning Bolt
Total: 75
==========
Approx. price: 412.00
56 Mountain
''');
    expect(r.entries.map((e) => e.name), ['Lightning Bolt', 'Mountain']);
    expect(r.ignored, ['Total: 75', '==========', 'Approx. price: 412.00']);
  });

  test('a bracketed count on a header does not become a card', () {
    final r = parseDecklist('''
Mainboard (60)
4 Lightning Bolt
Sideboard (15)
2 Pyroblast
''');
    expect(r.entries.length, 2);
    expect(r.entries.where((e) => e.sideboard).single.name, 'Pyroblast');
    expect(r.ignored, isEmpty);
  });

  test("Commander's Sphere is a card, not a section break", () {
    // No quantity on purpose. With a quantity the line can never be mistaken
    // for a header, so the version of this test that had one proved nothing.
    final r = parseDecklist("Sideboard\nCommander's Sphere\n1 Pyroblast");
    expect(r.entries.map((e) => e.name), ["Commander's Sphere", 'Pyroblast']);
    expect(r.entries.every((e) => e.sideboard), isTrue,
        reason: 'the Sphere must not have switched the section back to deck');
  });

  test('windows line endings do not glue themselves to the last name', () {
    final r = parseDecklist('4 Lightning Bolt\r\n2 Counterspell\r\n');
    expect(r.entries.map((e) => e.name), ['Lightning Bolt', 'Counterspell']);
  });
}
