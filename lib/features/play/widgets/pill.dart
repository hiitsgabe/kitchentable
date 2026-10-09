import 'package:flutter/material.dart';

import '../../../ui/atoms/pressable.dart';
import '../../../ui/tokens/app_palette.dart';
import '../../../ui/tokens/lettering.dart';
import '../../../ui/tokens/metrics.dart';
import '../../../ui/tokens/palette.dart';

/// A small square button for a bar of them: the table's top bar, and the
/// chat and microphone on a draft screen. A badge for a count, lit when
/// the thing it stands for is on, and the one warning colour when it is
/// not working.
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.metrics,
    required this.icon,
    required this.onTap,
    this.badge,
    this.lit = false,
    this.warn = false,
    this.label,
  });

  /// What a screen reader calls it. The icon is the only word on it.
  final String? label;

  final Metrics metrics;
  final IconData icon;
  final VoidCallback onTap;

  /// A count to draw on the corner. Zero and null draw nothing: an empty
  /// badge is a mark saying there is nothing to see.
  final int? badge;

  /// On and working, which is drawn in the colour the player picked.
  final bool lit;

  /// Not working, which is drawn in the one colour reserved for a thing
  /// somebody has to notice.
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final count = badge ?? 0;

    return Pressable(
      metrics: m,
      onPress: onTap,
      ring: false,
      semanticLabel: label,
      builder: (context, state) => Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: m.scaled(34),
            height: m.scaled(34),
            decoration: BoxDecoration(
              color: lit || state.focused || state.hovered
                  ? context.palette.tileFocused
                  : Palette.tile,
              borderRadius: BorderRadius.circular(m.scaled(8)),
              border: Border.all(
                color: warn
                    ? Palette.attention
                    : lit || state.focused
                    ? context.palette.accent
                    : Palette.tileEdge,
                width: state.focused ? m.focusRing : 1,
              ),
            ),
            child: Icon(
              icon,
              size: m.scaled(17),
              color: warn
                  ? Palette.attention
                  : lit
                  ? context.palette.accent
                  : Palette.inkMuted,
            ),
          ),
          if (count > 0)
            Positioned(
              top: -m.scaled(5),
              right: -m.scaled(5),
              child: Container(
                key: const Key('unread'),
                padding: EdgeInsets.symmetric(
                  horizontal: m.scaled(5),
                  vertical: m.scaled(1),
                ),
                constraints: BoxConstraints(minWidth: m.scaled(17)),
                decoration: BoxDecoration(
                  color: context.palette.accent,
                  borderRadius: BorderRadius.circular(m.scaled(9)),
                  border: Border.all(
                    color: Palette.outline,
                    width: m.scaled(1.5),
                  ),
                ),
                child: Text(
                  count > 9 ? '9+' : '$count',
                  textAlign: TextAlign.center,
                  style: pixel(
                    size: m.scaled(10),
                    weight: 700,
                    color: Palette.slabInk,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
