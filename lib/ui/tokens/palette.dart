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
}
