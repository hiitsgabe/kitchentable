import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../counters.dart';

/// One plastic counter, sitting on a card.
///
/// Drawn against the photographs rather than against an idea of what a counter
/// looks like, and the photographs are of **translucent moulded plastic**:
/// the card's art and its rules text are legible straight through a piece, the
/// piece throws a soft shadow onto the card a millimetre under it, and its
/// edges are a bevel that catches the light from above while the underside
/// goes dark. What was here before was an opaque tile with a flat copy of
/// itself offset down and right, which is a sticker with a drop shadow.
///
/// Six things that make it read as acrylic, in the order they are painted:
/// the cast shadow, the thickness of the sheet showing under the face, the see
/// through body, a sheen down the face, a hard gloss streak across it, and the
/// cut edge lit all the way round.
///
/// The thickness is the one that was missing. A flat translucent shape with a
/// shadow and a lit edge is still a flat shape: what says an object is lying
/// on the card is that you can see the side of it.
///
/// One painter and not a stack of clipped boxes, because a stroke along a
/// clipped path is half a stroke: the clip eats the outer half and the bevel
/// comes out at half the width it was asked for, thinner on the curves. A
/// path drawn and then stroked keeps both halves.
///
/// A count of one draws no number. One `+1/+1` is a piece, not a pile.
class CounterPieceView extends StatelessWidget {
  const CounterPieceView({
    super.key,
    required this.piece,
    required this.width,
    this.count = 1,
  });

  final CounterPiece piece;

  /// How many of this kind are on the card. Drawn as a number at one end
  /// rather than as that many pieces, which would cover the card, and which is
  /// what a stack of three looks like from above anyway.
  final int count;

  final double width;

  /// Wider than tall, which is the shape the plastic actually is.
  ///
  /// It was 1.18, taller than wide, and that is what made the old piece read
  /// as a chip or a sticker: every counter in the photographs is a bar. It is
  /// also what the text wants, since the longest thing printed on one is a
  /// word and a word is wide.
  static const _ratio = 0.62;

  /// How far the V bites into each end, as a fraction of the width.
  static const _notch = 0.13;

  /// How tall a piece of a given width comes out.
  ///
  /// The row of them on a card has to lay a pile out before it builds one, and
  /// this is the one place that arithmetic lives.
  static double heightFor(double width) => width * _ratio;

  @override
  Widget build(BuildContext context) {
    final height = heightFor(width);
    final colour = piece.colour;

    // Dark ink on the pale pieces, light on the dark ones, off the colour
    // rather than off the theme: these are objects with their own colours.
    final ink = colour.computeLuminance() > 0.5
        ? const Color(0xFF1A1714)
        : const Color(0xFFF6F2EC);

    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: CounterPlastic(colour: colour),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: width * (_notch + 0.04),
            vertical: height * 0.16,
          ),
          // Along the bar and not down it. The reference prints the value at
          // one end and the word at the other, and a bar this shape has room
          // across and none to spare downwards.
          //
          // Flexible and not plain children: each print is a FittedBox, which
          // sizes to the text and not to the room, so the two together
          // overflowed the piece by a point at forty wide. Given a share each
          // they scale down instead, and the shares are the font sizes so the
          // count stays the big one.
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(flex: 20, child: _print(ink)),
              if (count > 1) ...[
                SizedBox(width: width * 0.05),
                Flexible(flex: 12, child: _count(ink)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// What is printed on it.
  ///
  /// Scaled down to fit rather than wrapped: INDESTRUCTIBLE is fourteen
  /// letters across a piece that is forty points wide, and a word broken over
  /// two lines on a counter is not a thing that exists.
  ///
  /// A shadow under the letters because the body under them is see through:
  /// on a pale piece over pale art the ink was landing on whatever the card
  /// happened to have there.
  Widget _print(Color ink) => FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          piece.label,
          maxLines: 1,
          style: TextStyle(
            fontSize: width * 0.2,
            fontWeight: FontWeight.w800,
            letterSpacing: width * 0.006,
            height: 1,
            color: ink,
            shadows: [
              Shadow(
                color: ink.computeLuminance() > 0.5
                    ? const Color(0x99000000)
                    : const Color(0x55FFFFFF),
                blurRadius: width * 0.03,
              ),
            ],
          ),
        ),
      );

  Widget _count(Color ink) => FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '$count',
          maxLines: 1,
          style: TextStyle(
            fontSize: width * 0.26,
            fontWeight: FontWeight.w900,
            height: 1,
            color: ink,
          ),
        ),
      );
}

/// Every counter a card is wearing, in a row along its bottom edge.
///
/// One place, used by the card on the battlefield and by the big view. They
/// were two copies of this arithmetic and they had already drifted: opening a
/// card with counters on it showed a card with no counters on it.
///
/// Sized off the card and not off the metrics, and positioned rather than laid
/// out, so a card wearing counters is exactly as big as a card wearing none.
/// Two earlier things added to a card each cost the board nine and a half
/// percent by having a size of their own.
class CountersOnCard extends StatelessWidget {
  const CountersOnCard({
    super.key,
    required this.counters,
    required this.width,
  });

  final Map<String, int> counters;

  /// The card's width, which every size here is a fraction of.
  final double width;

  @override
  Widget build(BuildContext context) {
    final pieces = <CounterPiece>[];
    final counts = <int>[];

    final net = netPiece(counters);
    if (net != null) {
      pieces.add(net);
      counts.add(1);
    }
    for (final entry in counters.entries) {
      // The numbers have already gone into the marker. A keyword and a kind
      // nobody printed have nothing to add to, so they stand on their own.
      if (entry.value == 0 || isNumberKind(entry.key)) continue;
      pieces.add(pieceNamed(entry.key) ?? unknownPiece(entry.key));
      counts.add(entry.value);
    }
    if (pieces.isEmpty) return const SizedBox.shrink();

    final pieceWidth = width * 0.27;
    final pieceHeight = CounterPieceView.heightFor(pieceWidth);
    // Overlapping, the way a handful of them dropped on a card does.
    final step = pieceWidth * 0.82;

    return Positioned(
      left: 0,
      right: 0,
      bottom: -pieceHeight * 0.2,
      // Scaled down rather than overflowing. A card wearing five kinds has a
      // row of pieces wider than the card, and pieces getting smaller is what
      // a crowded card looks like anyway.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: pieceWidth + step * (pieces.length - 1),
          height: pieceHeight,
          child: Stack(
            children: [
              for (var i = 0; i < pieces.length; i++)
                Positioned(
                  left: step * i,
                  child: CounterPieceView(
                    key: Key('counter-${pieces[i].name}'),
                    piece: pieces[i],
                    count: counts[i],
                    width: pieceWidth,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The piece itself: shadow, body, sheen and rim.
///
/// Public so a test can read what it was told to draw. There are no goldens
/// in this project, so the alternative to asserting on the painter's inputs is
/// asserting on a widget tree that no longer has one box per visual effect,
/// which is what the old shape had and is the reason a probe that took the
/// shadow off could pass.
class CounterPlastic extends CustomPainter {
  const CounterPlastic({required this.colour});

  final Color colour;

  /// How see through the body is.
  ///
  /// The whole point of the rewrite. Moulded counters are tinted transparent
  /// plastic and you read the card through them; an opaque one is a sticker.
  /// Not lower than this, because the label has to stay legible over whatever
  /// art happens to be underneath.
  static const bodyAlpha = 0.78;

  /// How far the shadow falls and how soft it is, as fractions of the height.
  static const shadowDrop = 0.16;
  static const shadowBlur = 0.18;

  /// The cut edge, as a fraction of the height.
  ///
  /// **Bright, not dark.** These are laser cut from transparent acrylic, and a
  /// cut edge in transparent acrylic pipes light along the sheet and glows: it
  /// is the lightest part of the object, not the darkest. The first version
  /// had it lit along the top and dark along the bottom, which is how an
  /// opaque bevel behaves and is why the piece still read as a printed shape
  /// with a highlight on it.
  static const rimWidth = 0.1;

  /// How thick the sheet is, as a fraction of the height.
  ///
  /// The piece is cut from acrylic about three millimetres thick, so from
  /// above you see the top face and a sliver of the side under it, and that
  /// sliver is the whole of why it reads as an object rather than a shape.
  /// Translucency, a shadow and a lit edge were all true of the flat version
  /// and it still looked printed: none of them is thickness.
  ///
  /// The side is the same colour seen through more material, so it is darker
  /// and more saturated than the face, not a shade of grey.
  static const thickness = 0.13;

  /// The gloss: a hard diagonal streak across the upper half.
  ///
  /// The other half of what says acrylic. A sheet of it is glossy and catches
  /// the room in a band with an edge to it, which is different from the soft
  /// vertical shading that says "lit from above" and which was all this had.
  static const glossAt = 0.34;

  /// The two ends of the cut edge. Both lighter than any piece in the box:
  /// the edge is where the light comes out, so the darker of the two is still
  /// white, just less of it. This was `0x73000000`, black, which is what an
  /// opaque bevel does and what made the piece read as printed.
  static const edgeLit = Color(0xD9FFFFFF);
  static const edgeShade = Color(0x8CFFFFFF);

  /// The silhouette: a bar with a V bitten out of each end.
  static Path pathFor(Size size) {
    final bite = size.width * CounterPieceView._notch;
    final middle = size.height / 2;

    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width - bite, middle)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..lineTo(bite, middle)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = pathFor(size);
    final box = Offset.zero & size;

    canvas.drawPath(
      path.shift(Offset(0, size.height * shadowDrop)),
      Paint()
        ..color = const Color(0x5C000000)
        ..maskFilter = ui.MaskFilter.blur(
          ui.BlurStyle.normal,
          size.height * shadowBlur,
        ),
    );

    // The side, under the face and offset down by the sheet's thickness. Drawn
    // before the face so the face sits on top of it, which is what the two of
    // them are: one object seen from slightly above.
    final deep = size.height * thickness;
    canvas.drawPath(
      path.shift(Offset(0, deep)),
      Paint()
        ..color = Color.lerp(colour, const Color(0xFF000000), 0.45)!
            .withValues(alpha: 0.92),
    );

    canvas.drawPath(
      path,
      Paint()..color = colour.withValues(alpha: bodyAlpha),
    );

    // Lit from above. The light stop along the top edge and the dark one along
    // the bottom are the other half of the illusion: a flat fill reads as ink
    // printed on the card however deep the shadow under it is.
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          box.topCenter,
          box.bottomCenter,
          const [Color(0x6BFFFFFF), Color(0x00FFFFFF), Color(0x4D000000)],
          const [0, 0.46, 1],
        ),
    );

    // The gloss, clipped to the piece: a band with an edge to it, running
    // across rather than down, which is the room reflected in a sheet of
    // plastic and not a light source above it.

    // The gloss, clipped to the piece: a band with an edge to it, running
    // across rather than down, which is the room reflected in a sheet of
    // plastic and not a light source above it.
    canvas.save();
    canvas.clipPath(path);
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          box.topLeft,
          box.bottomRight,
          const [
            Color(0x00FFFFFF),
            Color(0x59FFFFFF),
            Color(0x59FFFFFF),
            Color(0x00FFFFFF),
          ],
          const [0, glossAt, glossAt + 0.1, glossAt + 0.16],
        ),
    );
    canvas.restore();

    // The cut edge last and brightest, all the way round. Stroked over the
    // path rather than inside a clip, because a stroke along a clipped path is
    // half a stroke and the edge came out at half the width it asked for.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.height * rimWidth
        ..shader = ui.Gradient.linear(
          box.topCenter,
          box.bottomCenter,
          const [edgeLit, edgeShade],
        ),
    );
  }

  @override
  bool shouldRepaint(CounterPlastic old) => old.colour != colour;
}
