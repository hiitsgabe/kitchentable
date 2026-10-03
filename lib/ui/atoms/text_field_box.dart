import 'package:flutter/material.dart';

import '../tokens/app_palette.dart';
import '../tokens/lettering.dart';
import '../tokens/metrics.dart';
import '../tokens/palette.dart';

/// A box you type into, drawn as a hole in the tray rather than a tile on it.
///
/// Every pressable thing in the app is a slab standing proud of the surface,
/// so the one thing that is not pressable has to be the other way up: dark,
/// inset, with the near black outline on the outside of the hole. The pixel
/// face is used for what is typed, because a name typed here is read off a
/// chair at the table in the same face.
class TextFieldBox extends StatelessWidget {
  const TextFieldBox({
    super.key,
    required this.metrics,
    required this.controller,
    required this.hint,
    this.lines = 1,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
  });

  final Metrics metrics;
  final TextEditingController controller;
  final String hint;
  final int lines;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: m.scaled(13),
        vertical: m.scaled(11),
      ),
      decoration: BoxDecoration(
        color: Palette.trayWell,
        borderRadius: BorderRadius.circular(m.scaled(9)),
        border: Border.all(color: Palette.outline, width: m.scaled(2)),
      ),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        minLines: lines,
        maxLines: lines,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        cursorColor: context.palette.accent,
        style: pixel(size: m.scaled(16), weight: 600, height: 1.3),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: hint,
          hintStyle: pixel(
            size: m.scaled(16),
            weight: 500,
            color: Palette.inkFaint,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}
