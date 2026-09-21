import 'package:flutter/material.dart';

import 'palette.dart';

ThemeData kitchentableTheme() {
  final base = ThemeData.dark(useMaterial3: true);

  return base.copyWith(
    // Transparent so the backdrop shows through. Every Scaffold in the app
    // sits on top of it rather than covering it.
    scaffoldBackgroundColor: Colors.transparent,
    colorScheme: base.colorScheme.copyWith(
      primary: Palette.accent,
      surface: Palette.surface,
      onSurface: Palette.ink,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: Palette.ink,
      displayColor: Palette.ink,
    ),
  );
}
