import 'package:flutter/material.dart';

import 'palette.dart';

/// The colours that follow the one the player picked.
///
/// [Palette] is still the ground: the greys, the inks and the tiles are
/// neutral and read the same under any accent. What changes is the accent
/// family, which is every border, ring, fill and mark the app uses to say
/// "this one, here": a colour choice that leaves those pink paints a teal
/// background behind a pink app, which is what it used to do.
///
/// A [ThemeExtension] rather than a global, so Flutter rebuilds what depends
/// on it when it changes and a test can pump one without touching the next.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.accent,
    required this.focusWash,
    required this.tileFocused,
  });

  /// The three derived from one colour: the accent itself, the wash a focused
  /// row is filled with, and the fill behind something chosen. The two fills
  /// are the accent dragged most of the way back into the dark, which is what
  /// the hand-written pink ones were.
  factory AppPalette.of(Color accent) => AppPalette(
        accent: accent,
        focusWash: Color.lerp(Palette.felt, accent, 0.14)!,
        tileFocused: Color.lerp(Palette.tile, accent, 0.16)!,
      );

  final Color accent;
  final Color focusWash;
  final Color tileFocused;

  @override
  AppPalette copyWith({Color? accent, Color? focusWash, Color? tileFocused}) =>
      AppPalette(
        accent: accent ?? this.accent,
        focusWash: focusWash ?? this.focusWash,
        tileFocused: tileFocused ?? this.tileFocused,
      );

  @override
  AppPalette lerp(AppPalette? other, double t) => other == null
      ? this
      : AppPalette(
          accent: Color.lerp(accent, other.accent, t)!,
          focusWash: Color.lerp(focusWash, other.focusWash, t)!,
          tileFocused: Color.lerp(tileFocused, other.tileFocused, t)!,
        );
}

/// The live palette, or the pink default where no theme has been put up,
/// which is every widget test that pumps a bare MaterialApp.
extension PaletteOf on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.of(Palette.accent);
}
