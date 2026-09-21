import 'package:flutter/material.dart';

import '../tokens/metrics.dart';
import '../tokens/palette.dart';

class ProgressTrack extends StatelessWidget {
  const ProgressTrack({
    super.key,
    required this.metrics,
    required this.label,
    required this.fraction,
    required this.trailing,
    this.dimmed = false,
  });

  final Metrics metrics;
  final String label;

  /// Null draws an indeterminate bar. Do not invent a number.
  final double? fraction;
  final String trailing;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: Container(
        margin: EdgeInsets.only(bottom: m.scaled(8)),
        padding: EdgeInsets.all(m.scaled(12)),
        decoration: BoxDecoration(
          color: Palette.surface,
          borderRadius: BorderRadius.circular(m.scaled(10)),
          border: Border.all(color: Palette.surfaceEdge),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: m.scaled(12), color: Palette.ink),
            ),
            SizedBox(height: m.scaled(7)),
            ClipRRect(
              borderRadius: BorderRadius.circular(m.scaled(4)),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: m.scaled(5),
                backgroundColor: Palette.feltEdge,
                valueColor: const AlwaysStoppedAnimation(Palette.accent),
              ),
            ),
            SizedBox(height: m.scaled(5)),
            Text(
              trailing,
              style: TextStyle(fontSize: m.scaled(10), color: Palette.inkFaint),
            ),
          ],
        ),
      ),
    );
  }
}
