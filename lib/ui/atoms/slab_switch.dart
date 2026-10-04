import 'package:flutter/material.dart';

import '../tokens/lettering.dart';
import '../tokens/metrics.dart';
import '../tokens/palette.dart';
import 'slab.dart';

/// A thing that is on or off, as a slab with the answer written on it.
///
/// Not a Material switch. Everything in this app that can be pressed is a
/// slab, and a sliding lozenge would be the one borrowed shape on the
/// screen. The state is a word in a well on the right, because a slab that
/// only changed colour would be asking people to remember which colour
/// meant on.
class SlabSwitch extends StatelessWidget {
  const SlabSwitch({
    super.key,
    required this.metrics,
    required this.title,
    required this.on,
    required this.onChanged,
    this.subtitle,
    this.icon,
    this.enabled = true,
  });

  final Metrics metrics;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool on;
  final bool enabled;
  final void Function(bool on) onChanged;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return Padding(
      padding: EdgeInsets.only(bottom: m.scaled(10)),
      child: Slab(
        metrics: m,
        tone: on ? SlabTone.choice : SlabTone.plain,
        enabled: enabled,
        onActivate: () => onChanged(!on),
        semanticLabel: '$title, ${on ? 'on' : 'off'}',
        child: Row(
          children: [
            if (icon != null) ...[
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
            SizedBox(width: m.scaled(10)),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: m.scaled(9),
                vertical: m.scaled(5),
              ),
              decoration: BoxDecoration(
                color: Palette.trayWell,
                borderRadius: BorderRadius.circular(m.scaled(7)),
                border: Border.all(
                  color: Palette.outline,
                  width: m.scaled(2),
                ),
              ),
              child: Text(
                on ? 'ON' : 'OFF',
                style: pixel(
                  size: m.scaled(11),
                  weight: 700,
                  letterSpacing: 1,
                  color: on ? Palette.slabInk : Palette.inkFaint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
