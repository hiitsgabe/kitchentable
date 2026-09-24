import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/counters.dart';
import 'package:kitchentable/features/play/widgets/counter_piece.dart';

Widget _host(String kind, {int count = 1}) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: CounterPieceView(
            piece: pieceNamed(kind) ?? unknownPiece(kind),
            count: count,
            width: 40,
          ),
        ),
      ),
    );

void main() {
  testWidgets('it says its value once', (tester) async {
    await tester.pumpWidget(_host('+1/+1'));
    await tester.pump();

    // The plastic prints it twice so it reads from either side of a physical
    // table. On a screen one person is looking and the upside down copy is
    // noise.
    expect(find.text('+1/+1'), findsOneWidget);
  });

  testWidgets('more than one of a kind says how many', (tester) async {
    await tester.pumpWidget(_host('+1/+1', count: 3));
    await tester.pump();

    // Three pieces drawn three times would cover the card. One piece and a
    // number is what a stack of three looks like from above anyway.
    expect(find.textContaining('3'), findsWidgets);
  });

  testWidgets('a single one does not count itself', (tester) async {
    await tester.pumpWidget(_host('+2/+2'));
    await tester.pump();

    expect(find.text('1'), findsNothing);
    expect(find.textContaining('x'), findsNothing);
  });

  testWidgets('a keyword piece says the word once', (tester) async {
    await tester.pumpWidget(_host('flying'));
    await tester.pump();

    expect(find.text('FLYING'), findsOneWidget);
  });

  testWidgets('you can read the card through it', (tester) async {
    await tester.pumpWidget(_host('+4/+4'));
    await tester.pump();

    final body = pieceNamed('+4/+4')!.colour;

    // The whole reason this was redrawn. A moulded counter is tinted
    // transparent plastic and the card's art and rules text are legible
    // straight through it; what was here was an opaque tile with a flat copy
    // of itself offset down and right, which is a sticker with a drop shadow.
    //
    // The shadow is painted before the body, which is the order that puts the
    // piece on top of its own shadow rather than under it.
    expect(
      find.byType(CounterPieceView),
      paints
        // The piece is 40 by 24.8, so a shadow that fell nowhere would end at
        // 24.8 and this point would be outside it. Deleting the shadow fails
        // this case and the next; only flattening it against the piece, which
        // leaves a glow rather than a thing lying on a card, needed a point to
        // catch it.
        ..path(
          color: const Color(0x5C000000),
          includes: const [Offset(20, 26.5)],
        )
        ..path(color: body.withValues(alpha: CounterPlastic.bodyAlpha)),
    );

    // And the see through comes from the painter and not from the box, which
    // is what stops this passing on a piece that was simply given a pale
    // colour.
    expect(body.a, 1.0);
  });

  testWidgets('it is lit from above along its own edge', (tester) async {
    await tester.pumpWidget(_host('+2/+2'));
    await tester.pump();

    // The bevel: a rim stroked light at the top and dark at the bottom, which
    // is the one cue that says a thing has a thickness. Stroked over the path
    // rather than inside a clip, because a stroke along a clipped path is half
    // a stroke and the bevel came out at half the width it asked for.
    expect(
      find.byType(CounterPieceView),
      paints
        ..path()
        ..path()
        ..path()
        // Stroke and not another fill, and last of the four, which is what
        // puts the rim on top of the sheen rather than under it. The width is
        // not asserted: the canvas keeps it as a float and 2.4800000190734863
        // is not exactly the 2.4800000000000013 this would have to compute,
        // and `paints` compares exactly.
        ..path(style: PaintingStyle.stroke),
    );
  });

  testWidgets('it is a bar with a bite out of each end', (tester) async {
    const size = Size(40, 24.8);
    final path = CounterPlastic.pathFor(size);

    // Off the photographs: every counter in them is a bar wider than it is
    // tall with a V bitten into each end. This was a tile taller than wide
    // notched top and bottom, which is why it read as a chip.
    expect(size.width, greaterThan(size.height));

    // The bite is real and it is on both ends: the middle of each end is
    // inside the shape's own box, while the corners are on it.
    expect(path.contains(Offset(size.width / 2, size.height / 2)), isTrue);
    expect(path.contains(Offset(0.5, size.height / 2)), isFalse,
        reason: 'the left end is not bitten into');
    expect(path.contains(Offset(size.width - 0.5, size.height / 2)), isFalse,
        reason: 'the right end is not bitten into');
    expect(path.contains(const Offset(0.5, 0.5)), isTrue);
  });
}
