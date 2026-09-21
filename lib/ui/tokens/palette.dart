import 'package:flutter/material.dart';

/// The table is dark on purpose. Card art is the only thing in this app that
/// is allowed to be loud, so everything around it stays quiet.
abstract final class Palette {
  static const felt = Color(0xFF12171D);
  static const feltEdge = Color(0xFF0E1116);
  static const surface = Color(0xFF171C23);
  static const surfaceEdge = Color(0xFF262C35);

  static const ink = Color(0xFFE6EDF3);
  static const inkMuted = Color(0xFF8B949E);
  static const inkFaint = Color(0xFF6E7681);

  static const accent = Color(0xFF1F6FEB);

  /// Reserved for the thing the player must not miss: a legal target once a
  /// referee is plugged in, a pack waiting to be picked, a trigger on the stack.
  static const attention = Color(0xFFF0B429);
}
