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
    // `ChangeCounter` has taken any name since plan 2, so a card can arrive
    // carrying anything at all. The box has grown loyalty and charge since
    // this was written; `rust` stands for whatever it has not grown.
    expect(pieceNamed('rust'), isNull);
    expect(unknownPiece('rust').name, 'rust');
    expect(unknownPiece('rust').power, 0);

    // A tally, because counting is the only thing anybody knows about a kind
    // nobody described.
    expect(unknownPiece('rust').kind, CounterKind.tally);
  });

  test('loyalty is a tally and never a creature s power', () {
    // Jace was being offered `+1/+1` as though loyalty were power, and the
    // only counter a planeswalker ever wears was drawn as a grey unknown with
    // a word on it.
    final loyalty = pieceNamed('loyalty');
    expect(loyalty, isNotNull);
    expect(loyalty!.kind, CounterKind.tally);
    expect(loyalty.power, 0);
    expect(loyalty.toughness, 0);

    // And it must not join the marker, which is the arithmetic a creature's
    // numbers go into.
    expect(isNumberKind('loyalty'), isFalse);
    expect(netPiece({'loyalty': 4}), isNull);
    expect(powerFrom({'loyalty': 4}), 0);
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
