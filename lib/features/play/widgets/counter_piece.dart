import 'package:flutter/material.dart';

import '../counters.dart';

/// One plastic counter, sitting on a card.
///
/// The shape is off the photograph: a squarish tile notched into a V at the
/// top and at the bottom, so the silhouette reads as a bent corner rather than
/// as a chip. Its value is printed twice, the lower one turned around, because
/// a counter on a table has to be readable from the other side of it.
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

  /// How tall a piece of a given width comes out.
  ///
  /// The row of them on a card has to lay a pile out before it builds one, and
  /// the shape's proportions belong to the shape rather than to its callers.
  static double heightFor(double width) => width * _ratio;

  @override
  Widget build(BuildContext context) {
    final height = width * _ratio;
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
          ClipPath(
            clipper: const _Chevron(_notch),
            child: DecoratedBox(
              decoration: BoxDecoration(
                // Lit from above. The light stop along the top edge is the
                // other half of the popup illusion: a flat fill reads as ink
                // printed on the card however deep the shadow under it is.
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, 0.16, 1],
                  colors: [
                    Color.lerp(colour, const Color(0xFFFFFFFF), 0.42)!,
                    colour,
                    Color.lerp(colour, const Color(0xFF000000), 0.26)!,
                  ],
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: width * 0.06,
                  vertical: height * _notch,
                ),
                // Flexible and not three plain children. Each print is a
                // FittedBox, which sizes to the text and not to the room, so
                // the three together overflowed the piece by a point at forty
                // wide. Given a share each they scale down instead, and the
                // shares are the font sizes so the count stays the big one.
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(flex: 18, child: _print(ink)),
                    if (count > 1) Flexible(flex: 26, child: _count(ink)),
                    // Turned around, not a second string: the two are the same
                    // Text so they cannot drift apart.
                    Flexible(
                      flex: 18,
                      child: RotatedBox(quarterTurns: 2, child: _print(ink)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// What is printed on it, at whichever end.
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
