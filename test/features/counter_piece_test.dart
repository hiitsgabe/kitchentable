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
        // The side of the sheet, between the shadow and the face.
        ..path()
        ..path(color: body.withValues(alpha: CounterPlastic.bodyAlpha)),
    );

    // And the see through comes from the painter and not from the box, which
    // is what stops this passing on a piece that was simply given a pale
    // colour.
    expect(body.a, 1.0);
  });

  testWidgets('you can see the side of it, not just the top', (tester) async {
    await tester.pumpWidget(_host('+4/+4'));
    await tester.pump();

    final piece = tester.getRect(find.byType(CounterPieceView));

    // The thing that was still missing after translucency, a shadow and a lit
    // edge: none of those is thickness, and a flat translucent shape with all
    // three is still a flat shape. The sheet is about three millimetres, so
    // from above you see the top face and a sliver of the side under it.
    //
    // Below the face's own bottom edge and inside the side's. It has to be
    // below: a point inside the piece is inside the face as well, so taking
    // the offset away left the whole file green and the probe proved nothing.
    // The sheet is 0.13 of the height, so at 24.8 tall the side reaches 28.
    final under = Offset(piece.width / 2, piece.height + 1.5);
    expect(
      find.byType(CounterPieceView),
      paints
        ..path()
        ..path(includes: [under]),
    );
  });

  testWidgets('its cut edge glows instead of darkening', (tester) async {
    await tester.pumpWidget(_host('+2/+2'));
    await tester.pump();

    final body = pieceNamed('+2/+2')!.colour;

    // This is the whole difference between acrylic and an opaque bevel, and it
    // is what the piece still got wrong after the first rewrite. A laser cut
    // edge in transparent acrylic pipes light along the sheet and comes out
    // the brightest part of the object. The edge was stroked black at the
    // bottom, which is how an opaque bevel behaves.
    //
    // Against the piece's own colour rather than against a number, so a darker
    // box of pieces cannot quietly make this true.
    expect(CounterPlastic.edgeLit.computeLuminance(),
        greaterThan(body.computeLuminance()));
    expect(CounterPlastic.edgeShade.computeLuminance(),
        greaterThan(body.computeLuminance()));

    expect(
      find.byType(CounterPieceView),
      paints
        ..path()
        // The side of the sheet showing under the face, which is the one that
        // makes it an object rather than a shape.
        ..path()
        ..path()
        ..path()
        // The gloss: a hard band across the face, clipped to the piece, which
        // is the room reflected in a sheet of plastic rather than a light
        // source above it.
        ..path()
        // Stroke and not another fill, and last of the five, which is what
        // puts the edge over everything else rather than under it. The width
        // is not asserted: the canvas keeps it as a float and
        // 2.4800000190734863 is not exactly the 2.4800000000000013 this would
        // have to compute, and `paints` compares exactly.
        ..path(style: PaintingStyle.stroke),
    );
  });

  testWidgets('it is a hexagon lying on its side', (tester) async {
    const size = Size(40, 24.8);
    final path = CounterPlastic.pathFor(size);

    // Wider than tall, so the text runs the long way, which is the way the
    // words on a counter are written.
    expect(size.width, greaterThan(size.height));

    // Pointed at each end: the middle of the left and right edges is on the
    // shape, and the four corners are cut away. A rectangle passes the first
    // three of these and fails the last two, and the bar with a V bitten out
    // of each end that this replaced fails the two points and passes the
    // corners, so the pair of them is what names a hexagon.
    expect(path.contains(Offset(size.width / 2, size.height / 2)), isTrue);
    expect(path.contains(Offset(0.5, size.height / 2)), isTrue,
        reason: 'the left end does not come to a point');
    expect(path.contains(Offset(size.width - 0.5, size.height / 2)), isTrue,
        reason: 'the right end does not come to a point');
    expect(path.contains(const Offset(0.5, 0.5)), isFalse,
        reason: 'the top left corner is not cut');
    expect(
      path.contains(Offset(size.width - 0.5, size.height - 0.5)),
      isFalse,
      reason: 'the bottom right corner is not cut',
    );
  });

  testWidgets('the piece after the first is hollowed out to take it',
      (tester) async {
    const size = Size(40, 24.8);
    final first = CounterPlastic.pathFor(size);
    final next = CounterPlastic.pathFor(size, joins: true);
    final point = size.width * CounterPieceView.notch;

    // The two ends are complementary: one is the other turned inside out, and
    // that is what lets a row of them seat together with no seam. Where the
    // first comes to a point the next is hollow, and where the first is cut
    // away at the corner the next is square.
    expect(first.contains(Offset(0.5, size.height / 2)), isTrue);
    expect(next.contains(Offset(0.5, size.height / 2)), isFalse,
        reason: 'the left end is not hollowed out to receive a point');

    expect(first.contains(const Offset(0.5, 0.5)), isFalse);
    expect(next.contains(const Offset(0.5, 0.5)), isTrue,
        reason: 'the corner beside the notch was cut away as well');

    // And the right end is a point on both, because every piece has something
    // that might slot onto it.
    expect(next.contains(Offset(size.width - 0.5, size.height / 2)), isTrue);

    // The notch reaches exactly as far in as the point reaches out, which is
    // the whole of why they fit.
    expect(next.contains(Offset(point + 0.5, size.height / 2)), isTrue);
  });
}
