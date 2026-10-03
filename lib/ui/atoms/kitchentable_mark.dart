import 'package:flutter/material.dart';

import '../tokens/app_palette.dart';
import '../tokens/palette.dart';

/// The mark: four cards laid around a table seen from above.
///
/// The app in one shape. A few people, one table, everybody facing in, which
/// is the whole of what this is for and is also the one thing about it that
/// no other card app is.
///
/// Drawn rather than drawn in: the same shape ships as `brand/mark.png` for
/// the icons and the logo, where it has to be a file, but on a screen it
/// takes the colour the player chose like every other thing the app points
/// with. An image here would stay pink on a teal table.
///
/// Every number is a fraction of [size], so it is the same shape at any size
/// and there is nothing to keep in step. They are measured off the file
/// rather than guessed, so the thing on the screen and the thing in the
/// browser tab are the same mark.
class KitchentableMark extends StatelessWidget {
  const KitchentableMark({super.key, required this.size, this.colour});

  final double size;

  /// Null takes the player's accent, which is what every use of it wants.
  final Color? colour;

  /// The solid slate square in the middle, and the rounded line around the
  /// whole thing, which is the edge of the table the cards are lying on. The
  /// square alone left four cards floating around a hole.
  static const _table = 0.47;
  static const _rim = 0.76;

  /// A card's long side and its short one. They are cards, so they are not
  /// square: the two at the top and bottom stand up and the two at the sides
  /// lie down, which is how four people sit at one table.
  static const _long = 0.30;
  static const _short = 0.235;

  static const _edge = 0.026;

  @override
  Widget build(BuildContext context) {
    final s = size;
    final accent = colour ?? context.palette.accent;
    final outline = s * _edge;

    /// One card, straddling the edge of the table it is lying on.
    Widget card({required bool standing}) => Container(
      width: s * (standing ? _short : _long),
      height: s * (standing ? _long : _short),
      decoration: BoxDecoration(
        color: Palette.outline,
        borderRadius: BorderRadius.circular(s * 0.045),
      ),
      padding: EdgeInsets.all(outline * 0.8),
      child: Container(
        decoration: BoxDecoration(
          color: Palette.slabInk,
          borderRadius: BorderRadius.circular(s * 0.032),
        ),
        padding: EdgeInsets.all(outline * 0.7),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(s * 0.02),
          ),
        ),
      ),
    );

    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The table, under the cards, so the four of them sit on its edges
          // rather than beside it. The inner line is the lip: without it the
          // square reads as a hole cut in the screen.
          Container(
            width: s * _rim,
            height: s * _rim,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(s * 0.19),
              border: Border.all(color: Palette.outline, width: outline * 1.4),
            ),
            padding: EdgeInsets.all(outline * 0.5),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(s * 0.16),
                border: Border.all(color: Palette.tray, width: outline),
              ),
            ),
          ),
          Container(
            width: s * _table,
            height: s * _table,
            decoration: BoxDecoration(
              color: Palette.tray,
              borderRadius: BorderRadius.circular(s * 0.1),
              border: Border.all(color: Palette.outline, width: outline),
            ),
          ),
          Align(alignment: Alignment.topCenter, child: card(standing: true)),
          Align(alignment: Alignment.bottomCenter, child: card(standing: true)),
          Align(alignment: Alignment.centerLeft, child: card(standing: false)),
          Align(alignment: Alignment.centerRight, child: card(standing: false)),
        ],
      ),
    );
  }
}
