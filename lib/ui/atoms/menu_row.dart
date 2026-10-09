import 'package:flutter/material.dart';

import '../tokens/lettering.dart';
import '../tokens/metrics.dart';
import '../tokens/palette.dart';
import 'slab.dart';

/// One line in a list, and a slab like everything else you can press.
///
/// It used to be a transparent rectangle that grew a one point border when
/// focused, which is how every Flutter app looks and was the specific
/// complaint: "tá muito com cara de AI". It is now a tile with a colour, an
/// outline and a thickness, whether it is focused or not, and focus is a
/// white edge rather than the only thing that makes it visible at all.
///
/// A disabled row can still be focused under directional navigation, which is
/// Flutter's choice and the right one. Its subtitle usually says why it is
/// disabled, and that sentence is worth reaching. It just never activates.
class MenuRow extends StatelessWidget {
  const MenuRow({
    super.key,
    required this.title,
    required this.metrics,
    required this.onActivate,
    this.subtitle,
    this.icon,
    this.leading,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    this.tone = SlabTone.plain,
  });

  final String title;
  final String? subtitle;

  /// Optional, but every list in the app passes one. A row that opens with
  /// naked text reads as a paragraph, not as something you can press.
  final IconData? icon;

  /// Something drawn in the icon's place: a set symbol, say. It is laid out
  /// at the icon's size, and wins over [icon] when both are given.
  final Widget? leading;

  final Metrics metrics;
  final VoidCallback onActivate;
  final bool enabled;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Ordinary rows are [SlabTone.plain]. A screen marks its own one dominant
  /// action, and the reference screens never have two.
  final SlabTone tone;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return Padding(
      padding: EdgeInsets.only(bottom: m.scaled(10)),
      child: Slab(
        metrics: m,
        tone: tone,
        enabled: enabled,
        focusNode: focusNode,
        autofocus: autofocus,
        onActivate: onActivate,
        semanticLabel: subtitle == null ? title : '$title. $subtitle',
        child: Row(
          children: [
            if (leading != null) ...[
              SizedBox.square(
                dimension: m.scaled(20),
                child: Center(child: leading),
              ),
              SizedBox(width: m.scaled(12)),
            ] else if (icon != null) ...[
              Icon(icon, size: m.scaled(20), color: Palette.slabInk),
              SizedBox(width: m.scaled(12)),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: slabText(m.scaled(16))),
                  if (subtitle != null) ...[
                    SizedBox(height: m.scaled(4)),
                    Text(
                      subtitle!,
                      style: pixel(
                        size: m.scaled(12),
                        weight: 500,
                        height: 1.25,
                        color: const Color(0xD6FFFFFF),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
