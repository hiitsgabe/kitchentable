import 'package:flutter/material.dart';

/// Black and pink, and the ground is deliberately almost nothing.
///
/// Two earlier attempts failed for the same reason: they had an opinion. The
/// blue one looked like every Flutter app, the brown one looked like Forge.
/// Card art is already as loud as a screen gets, five colours of it, so the
/// chrome gets out of the way and the pink does the pointing.
///
/// The ground here is only the fallback. What is actually behind the app is
/// whatever the player picked in settings, see [Backdrop].
abstract final class Palette {
  static const felt = Color(0xFF07060A);
  static const feltEdge = Color(0xFF030205);

  /// Anything raised off the ground. Translucent in practice, so a backdrop
  /// effect shows through instead of being covered up.
  static const surface = Color(0xFF14121A);
  static const surfaceEdge = Color(0xFF241F2E);

  static const ink = Color(0xFFF4F1F6);
  static const inkMuted = Color(0xFFA29AAE);
  static const inkFaint = Color(0xFF7A7186);

  /// Focus, selection, whatever is under your thumb right now.
  static const accent = Color(0xFFFF2E88);

  /// Fills a focused row, the pink bled almost all the way out.
  static const focusWash = Color(0xFF26091A);

  /// Reserved for the thing the player must not miss. Deliberately not pink,
  /// so it never competes with focus.
  static const attention = Color(0xFFFFB03A);

  static const tile = Color(0xFF191521);
  static const tileEdge = Color(0xFF2B2438);
  static const tileFocused = Color(0xFF341021);

  static const rule = Color(0xFF221D2C);

  // Below here is the Balatro half: trays, slabs and ledges. The benchmark
  // for it is docs/benchmarks/2026-10-03-balatro-ui.md, and the one sentence
  // worth keeping is that everything is a slab, flat and outlined in near
  // black and standing on a darker ledge, so a button reads as an object
  // lying on a surface rather than a tinted rectangle. The colours here are
  // cruder than taste would pick, on purpose.

  /// The opaque thing a screen's contents stand in. Opaque is the point: the
  /// paint behind the app is nearly full contrast and it has to stop at an
  /// edge, or nothing drawn over it can be read.
  static const tray = Color(0xFF2F3A40);

  /// The light outer border every tray carries. Two points of it, not a
  /// hairline.
  static const trayEdge = Color(0xFFA9B6BC);

  /// A hole cut in a tray: a text box, a value, anything typed into or read
  /// off rather than pressed.
  static const trayWell = Color(0xFF1C2327);

  /// Every slab edge and every letter's outline. Near black rather than
  /// black, so it sits in the same family as the tray.
  static const outline = Color(0xFF12171A);

  /// An ordinary slab, the one with no role.
  static const slabPlain = Color(0xFF55646B);

  /// A slab that steps back: Back, Skip, Later.
  static const slabWarm = Color(0xFFDE8A2C);

  /// A slab for something that cannot be undone.
  static const slabHot = Color(0xFFD03A4E);

  /// A slab for something finished or good.
  static const slabCool = Color(0xFF3F9D62);

  /// Letters on a slab. White, always, whatever the slab is.
  static const slabInk = Color(0xFFFFFFFF);
}

/// The dark underside of a slab, which is what makes it look thick.
Color ledgeUnder(Color face) =>
    Color.lerp(face, Palette.outline, 0.46) ?? Palette.outline;
