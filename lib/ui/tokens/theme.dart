import 'package:flutter/material.dart';

import 'palette.dart';

ThemeData kitchentableTheme() {
  final base = ThemeData.dark(useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: Palette.felt,
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
