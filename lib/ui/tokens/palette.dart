import 'package:flutter/material.dart';

/// A kitchen table at night: dark wood, worn felt, brass.
///
/// The first palette was a near black ground with the blue every Flutter app
/// ships with, which is the look of an app that has not chosen anything. This
/// one is warm all the way down, so card art, the only thing here allowed to be
/// loud, sits on something instead of floating on a void.
abstract final class Palette {
  /// The table itself. Warm, not neutral: there is no grey anywhere in here.
  static const felt = Color(0xFF15120D);
  static const feltEdge = Color(0xFF0D0B08);

  /// Anything raised off the table: a card back, a progress panel.
  static const surface = Color(0xFF1E1A13);
  static const surfaceEdge = Color(0xFF2E2819);

  /// Paper rather than white. Pure white on a warm ground reads as a hole.
  static const ink = Color(0xFFF2EADC);
  static const inkMuted = Color(0xFFA89C86);
  static const inkFaint = Color(0xFF8A8069);

  /// Brass. Focus, selection, whatever is under your thumb right now.
  static const accent = Color(0xFFD2A63C);

  /// Fills a focused row, a hint of the brass bleeding into the wood.
  static const focusWash = Color(0xFF2A2113);

  /// Reserved for the thing the player must not miss: a legal target once a
  /// referee is plugged in, a pack waiting to be picked, a trigger on the
  /// stack. Deliberately not brass, so it never competes with focus.
  static const attention = Color(0xFFE2703F);

  /// The little rounded square at the head of a row. Present on every list in
  /// the app, so a row never starts with naked text.
  static const tile = Color(0xFF231E15);
  static const tileEdge = Color(0xFF342D1F);
  static const tileFocused = Color(0xFF3B2E13);

  /// Hairline under a header and above the hint bar.
  static const rule = Color(0xFF282216);
}
