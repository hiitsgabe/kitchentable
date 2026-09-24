import 'package:flutter/material.dart';

import '../counters.dart';

/// One plastic counter, sitting on a card.
///
/// The shape is off the photograph: a squarish tile notched into a V at the
/// top and at the bottom, so the silhouette reads as a bent corner rather than
/// as a chip. Its value is printed once. The real plastic prints it twice, the
/// lower one turned around, because a counter on a table has to be readable
/// from the other side of it: on a screen one person is looking and the upside
/// down copy is noise.
///
/// It is drawn twice instead, the same shape in a darker shade offset down and
/// right, which is the trick the deck uses to read as solid rather than as one
/// printed card. Not a perspective transform: the card it sits on turns in
/// three dimensions and a piece with a vanishing point of its own fights it.
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

  /// How many of this kind are on the card. Drawn as a number in the middle
  /// rather than as that many pieces, which would cover the card, and which is
  /// what a stack of three looks like from above anyway.
  final int count;

  final double width;

  /// A little taller than wide, which is what makes the notches read as
  /// notches rather than as a squash.
  static const _ratio = 1.18;

  /// How far each V cuts in, as a fraction of the height.
  static const _notch = 0.13;

  /// How far the side stands out from under the face, as a fraction of the
  /// width.
  ///
  /// Out of the piece's own box and not added to it. The face is drawn at the
  /// top left of the box and the side at the bottom right, both of them a
  /// [_lift] smaller than the box, so a piece with a side to it is exactly as
  /// big as one without. The row of these is positioned in the card's
  /// `Clip.none` stack rather than laid out in it, precisely so the pieces
  /// have no size of their own, and a second copy offset outwards is exactly
  /// the shape of thing that starts having one: two earlier things added to a
  /// card each cost the board nine and a half percent that way.
  static const _lift = 0.09;

  /// How tall a piece of a given width comes out.
  ///
  /// The row of them on a card has to lay a pile out before it builds one, and
  /// the shape's proportions belong to the shape rather than to its callers.
  static double heightFor(double width) => width * _ratio;

  @override
  Widget build(BuildContext context) {
    final height = width * _ratio;
    final lift = width * _lift;
    final colour = piece.colour;

    // Dark ink on the pale pieces, light on the dark ones. Off the colour
    // rather than a constant: the box holds a white `-1/-1` and a near black
    // `+1/+1` and one ink cannot sit on both.
    final ink = colour.computeLuminance() > 0.45
        ? const Color(0xFF14121A)
        : const Color(0xFFF7F5FA);

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          // The shadow, on a box of its own under the piece.
          //
          // It cannot be the clipped shape's own boxShadow: everything outside
          // the path is clipped away and the shadow with it. So what casts it
          // is a plain box inset inside the silhouette, and what shows is the
          // spill below and around, which is all a contact shadow ever is.
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: width * 0.14,
                vertical: height * 0.2,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(width * 0.1),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF000000).withValues(alpha: 0.55),
                      blurRadius: width * 0.18,
                      offset: Offset(0, height * 0.07),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // The side, under the face and down and to the right of it. Darker
          // than the face's own bottom stop, which is what makes it read as
          // the edge of a thing rather than as more of the front of one.
          Positioned(
            left: lift,
            top: lift,
            child: _shape(
              key: const Key('counter-side'),
              size: Size(width - lift, height - lift),
              colour: Color.lerp(colour, const Color(0xFF000000), 0.42)!,
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: _shape(
              key: const Key('counter-face'),
              size: Size(width - lift, height - lift),
              colour: colour,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  // Lit from above. The light stop along the top edge is the
                  // other half of the popup illusion: a flat fill reads as ink
                  // printed on the card however deep the shadow under it is.
                  //
                  // Over the piece's colour rather than mixed into it, so the
                  // colour is said once and the lighting is the only thing
                  // this says. White at 42 percent over a colour is the same
                  // pixel as that colour lerped 42 percent towards white,
                  // which is what this was.
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, 0.16, 1],
                    colors: [
                      const Color(0xFFFFFFFF).withValues(alpha: 0.42),
                      const Color(0x00FFFFFF),
                      const Color(0xFF000000).withValues(alpha: 0.26),
                    ],
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: width * 0.06,
                    vertical: (height - lift) * _notch,
                  ),
                  // Flexible and not plain children. Each print is a
                  // FittedBox, which sizes to the text and not to the room, so
                  // the two together overflowed the piece by a point at forty
                  // wide when there were three of them. Given a share each
                  // they scale down instead, and the shares are the font sizes
                  // so the count stays the big one.
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(flex: 18, child: _print(ink)),
                      if (count > 1) Flexible(flex: 26, child: _count(ink)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The silhouette once, in one flat colour.
  ///
  /// The face and the side are this shape twice and not one shape with a
  /// border on it: the notches are a clip, and a stroke along a clipped path
  /// is half a stroke.
  Widget _shape({
    required Key key,
    required Size size,
    required Color colour,
    Widget? child,
  }) =>
      SizedBox(
        key: key,
        width: size.width,
        height: size.height,
        child: ClipPath(
          clipper: const _Chevron(_notch),
          child: DecoratedBox(
            decoration: BoxDecoration(color: colour),
            child: child,
          ),
        ),
      );

  /// What is printed on it.
  ///
  /// Scaled down to fit rather than wrapped: INDESTRUCTIBLE is fourteen
  /// letters across a piece that is forty points wide, and a word broken over
  /// two lines stops looking like a moulded label.
  Widget _print(Color ink) => FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          piece.label,
          maxLines: 1,
          style: TextStyle(
            fontSize: width * 0.18,
            fontWeight: FontWeight.w800,
            letterSpacing: width * 0.004,
            color: ink,
          ),
        ),
      );

  Widget _count(Color ink) => FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '$count',
          style: TextStyle(
            fontSize: width * 0.26,
            fontWeight: FontWeight.w700,
            color: ink.withValues(alpha: 0.85),
          ),
        ),
      );
}

/// The silhouette. Straight down both sides, a V cut into the top edge and
/// another into the bottom.
class _Chevron extends CustomClipper<Path> {
  const _Chevron(this.notch);

  final double notch;

  @override
  Path getClip(Size size) {
    final dip = size.height * notch;

    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, dip)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width / 2, size.height - dip)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(_Chevron old) => old.notch != notch;
}
