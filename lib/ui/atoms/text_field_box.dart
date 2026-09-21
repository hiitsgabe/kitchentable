import 'package:flutter/material.dart';

import '../tokens/metrics.dart';
import '../tokens/palette.dart';

/// A text box that matches the rest of the app rather than Material's.
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
        horizontal: m.scaled(14),
        vertical: m.scaled(10),
      ),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(m.scaled(12)),
        border: Border.all(color: Palette.surfaceEdge),
      ),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        minLines: lines,
        maxLines: lines,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        cursorColor: Palette.accent,
        style: TextStyle(
          fontSize: m.scaled(14),
          height: 1.4,
          color: Palette.ink,
        ),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: m.scaled(14),
            color: Palette.inkFaint,
          ),
        ),
      ),
    );
  }
}
