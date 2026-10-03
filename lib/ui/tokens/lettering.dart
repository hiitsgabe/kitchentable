import 'package:flutter/material.dart';

import 'palette.dart';

/// The pixel face, and the one place that knows its name.
///
/// Pixelify Sans by Eifetx, SIL Open Font License, in `fonts/`. Balatro's own
/// face is m6x11 and is not ours to ship; this is the nearest thing with an
/// open licence and a weight axis. It is a variable font, which in Flutter
/// means the weight is an axis rather than a family member: asking for
/// [FontWeight.w700] on it does nothing at all, and [FontVariation] is the
/// only thing it listens to. That mistake is invisible, so it lives here once
/// instead of in forty call sites.
///
/// Sizes are rounded to whole points. A pixel font drawn at 13.4 points has
/// its grid resampled and goes soft, which looks like a cheap font rather
/// than a pixel one.
TextStyle pixel({
  required double size,
  int weight = 500,
  Color color = Palette.ink,
  double letterSpacing = 0,
  double height = 1.1,
  bool outlined = false,
}) => TextStyle(
  fontFamily: 'Pixelify',
  fontVariations: [FontVariation('wght', weight.toDouble())],
  fontSize: size.roundToDouble(),
  letterSpacing: letterSpacing,
  height: height,
  color: color,
  shadows: outlined
      ? const [
          // Not a true outline, which Flutter would want a second painted
          // pass for. One hard offset shadow in the slab's own edge colour,
          // which is what reads at this size and costs nothing.
          Shadow(color: Palette.outline, offset: Offset(0, 2)),
          Shadow(color: Palette.outline, offset: Offset(1.5, 1.5)),
          Shadow(color: Palette.outline, offset: Offset(-1.5, 1.5)),
        ]
      : null,
);

/// Letters on a slab: white, heavy, outlined, and usually a word in capitals.
TextStyle slabText(double size) => pixel(
  size: size,
  weight: 700,
  color: Palette.slabInk,
  outlined: true,
  letterSpacing: 0.5,
);
