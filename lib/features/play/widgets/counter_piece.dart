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
/// Four things that make it read as plastic, in the order they are painted:
/// the cast shadow, the see through body, a sheen down the face, and a rim
/// lit along the top and dark along the bottom.
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

  /// The bevel, as a fraction of the height. Lit along the top edge and dark
  /// along the bottom, which is the one cue that says a thing has a thickness.
  static const rimWidth = 0.1;

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

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.height * rimWidth
        ..shader = ui.Gradient.linear(
          box.topCenter,
          box.bottomCenter,
          const [Color(0xB3FFFFFF), Color(0x73000000)],
        ),
    );
  }

  @override
  bool shouldRepaint(CounterPlastic old) => old.colour != colour;
}
