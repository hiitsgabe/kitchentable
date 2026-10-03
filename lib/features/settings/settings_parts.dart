import 'package:flutter/material.dart';

import '../../ui/atoms/tray.dart';
import '../../ui/tokens/lettering.dart';
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
      top: metrics.scaled(10),
      bottom: metrics.scaled(8),
    ),
    child: TrayLabel(metrics: metrics, text: text),
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
      style: pixel(
        size: metrics.scaled(12),
        weight: 500,
        height: 1.45,
        color: Palette.inkFaint,
      ),
    ),
  );
}
