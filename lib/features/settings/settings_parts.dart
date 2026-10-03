import 'package:flutter/material.dart';

import '../../ui/tokens/metrics.dart';
import '../../ui/tokens/palette.dart';

/// The small uppercase line that names a group of settings.
///
/// Shared, because the benchmark's first rule is that settings are grouped
/// and the groups are named, and three screens each writing their own heading
/// is how two of them end up different.
class SettingsLabel extends StatelessWidget {
  const SettingsLabel({super.key, required this.metrics, required this.text});

  final Metrics metrics;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(
          top: metrics.scaled(6),
          bottom: metrics.scaled(8),
        ),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: metrics.scaled(10),
            letterSpacing: 1.2,
            fontWeight: FontWeight.w500,
            color: Palette.inkFaint,
          ),
        ),
      );
}

/// A sentence under a field or a group saying what it is for.
class SettingsCaption extends StatelessWidget {
  const SettingsCaption({super.key, required this.metrics, required this.text});

  final Metrics metrics;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(
          top: metrics.scaled(6),
          bottom: metrics.scaled(18),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: metrics.scaled(11),
            height: 1.45,
            color: Palette.inkFaint,
          ),
        ),
      );
}
