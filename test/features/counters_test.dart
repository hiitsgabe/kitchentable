import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/counters.dart';

void main() {
  test('the box holds the denominations the box holds', () {
    final names = counterPieces.map((p) => p.name).toList();

    // Straight off the photograph. Four power and four toughness is a +4/+4,
    // not four +1/+1s in a pile, which is the whole reason these are
    // denominations and not a count.
    expect(names, containsAll(
        ['+1/+1', '+2/+2', '+4/+4', '-1/-1', '+1/+0', '+2/+0', '+0/+1']));
  });

  test('the keyword counters are there too', () {
    final names = counterPieces.map((p) => p.name).toList();

    expect(names, containsAll([
      'flying', 'haste', 'trample', 'vigilance', 'menace', 'deathtouch',
      'lifelink', 'hexproof', 'first strike', 'double strike',
      'indestructible', 'reach',
    ]));
  });

  test('every piece has its own colour', () {
    final colours = counterPieces.map((p) => p.colour.toARGB32()).toList();

    // A box where two pieces are the same colour is a box you have to read
    // rather than recognise.
    expect(colours.toSet(), hasLength(colours.length));
  });

  test('a number piece says what it does to power and toughness', () {
    expect(pieceNamed('+4/+4')!.power, 4);
    expect(pieceNamed('+4/+4')!.toughness, 4);
    expect(pieceNamed('-1/-1')!.power, -1);
    expect(pieceNamed('+1/+0')!.toughness, 0);
    expect(pieceNamed('+0/+1')!.power, 0);
  });

  test('a keyword piece changes no numbers', () {
    for (final piece in counterPieces.where((p) => p.isKeyword)) {
      expect(piece.power, 0);
      expect(piece.toughness, 0);
    }
  });

  test('a kind nobody printed is still a counter', () {
    // `ChangeCounter` has taken any name since plan 2 and a card can arrive
    // carrying `charge` or `loyalty`. Those are not in the box and still have
    // to draw.
    expect(pieceNamed('loyalty'), isNull);
    expect(unknownPiece('loyalty').name, 'loyalty');
    expect(unknownPiece('loyalty').power, 0);
  });

  test('what a pile of pieces does to a creature', () {
    final on = {'+4/+4': 1, '+0/+1': 4, 'flying': 1, 'charge': 3};

    // Four and four from the one piece, four more toughness from the four,
    // and nothing at all from the keyword or from the kind nobody printed.
    expect(powerFrom(on), 4);
    expect(toughnessFrom(on), 8);
  });

  test('nothing on a card is nothing added', () {
    expect(powerFrom(const {}), 0);
    expect(toughnessFrom(const {}), 0);
  });
}
