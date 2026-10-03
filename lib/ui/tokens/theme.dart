import 'package:flutter/material.dart';

import 'app_palette.dart';
import 'palette.dart';

/// [accent] is the colour the player picked, which everything that marks a
/// choice is drawn in. Null is the pink the app ships with.
ThemeData kitchentableTheme({Color? accent}) {
  final base = ThemeData.dark(useMaterial3: true);
  final palette = AppPalette.of(accent ?? Palette.accent);

  return base.copyWith(
    extensions: [palette],
    // Transparent so the backdrop shows through. Every Scaffold in the app
    // sits on top of it rather than covering it.
    scaffoldBackgroundColor: Colors.transparent,
    colorScheme: base.colorScheme.copyWith(
      primary: palette.accent,
      surface: Palette.surface,
      onSurface: Palette.ink,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: Palette.ink,
      displayColor: Palette.ink,
    ),
  );
}
