import 'package:flutter/material.dart';

import '../tokens/lettering.dart';
import '../tokens/metrics.dart';
import '../tokens/palette.dart';

/// The opaque thing everything else stands in.
///
/// This is the piece that makes a loud background affordable. The paint
/// behind the app runs at nearly full contrast, and an afternoon went into
/// dimming it so that thin text could be read over it, which was the wrong
/// end of the problem: Balatro's background is louder than ours and its
/// interface is perfectly legible, because its interface is solid. So the
/// swirl is back at full strength and it stops here, at a light two point
/// border with a shadow under it.
///
/// A [label] is drawn above the tray rather than inside it, which is what the
/// reference does with "Profile": the group's name belongs to the room, not
/// to the furniture.
class Tray extends StatelessWidget {
  const Tray({
    super.key,
    required this.metrics,
    required this.child,
    this.label,
    this.padding,
  });

  final Metrics metrics;
  final Widget child;
  final String? label;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    final box = Container(
      padding: padding ?? EdgeInsets.all(m.scaled(16)),
      decoration: BoxDecoration(
        color: Palette.tray,
        borderRadius: BorderRadius.circular(m.scaled(16)),
        border: Border.all(color: Palette.trayEdge, width: m.scaled(2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0x8C000000),
            blurRadius: m.scaled(18),
            offset: Offset(0, m.scaled(6)),
          ),
        ],
      ),
      child: child,
    );

    if (label == null) return box;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(left: m.scaled(6), bottom: m.scaled(7)),
          child: TrayLabel(metrics: m, text: label!),
        ),
        box,
      ],
    );
  }
}

/// The small line of capitals that names a tray, or a control inside one.
class TrayLabel extends StatelessWidget {
  const TrayLabel({
    super.key,
    required this.metrics,
    required this.text,
    this.align = TextAlign.start,
  });

  final Metrics metrics;
  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    textAlign: align,
    // A taller line than the default: this face has long ascenders and the
    // label is usually the first thing in a tray, where 1.1 clipped the tops
    // of the capitals against the tray's own padding.
    style: pixel(
      size: metrics.scaled(12),
      weight: 600,
      height: 1.35,
      color: Palette.inkMuted,
      letterSpacing: 1.4,
    ),
  );
}

/// A dark inset box inside a tray: a group that is read rather than pressed.
///
/// A tray holds slabs, which stand proud of it. Anything that is not pressable
/// has to go the other way or the surface stops meaning anything, so a group
/// of facts is a hole cut in the tray with the near black outline around it.
/// [edge] paints a thick bar down the left side, for one fact that matters
/// more than the others.
class Well extends StatelessWidget {
  const Well({
    super.key,
    required this.metrics,
    required this.child,
    this.label,
    this.trailing,
    this.edge,
    this.padding,
  });

  final Metrics metrics;
  final Widget child;

  /// Drawn inside the well, along its top, with [trailing] opposite it.
  final String? label;
  final Widget? trailing;

  final Color? edge;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    final inside = Container(
      padding: padding ?? EdgeInsets.all(m.scaled(13)),
      decoration: BoxDecoration(
        color: Palette.trayWell,
        borderRadius: BorderRadius.circular(m.scaled(8)),
      ),
      child: label == null
          ? child
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    TrayLabel(metrics: m, text: label!),
                    const Spacer(),
                    ?trailing,
                  ],
                ),
                SizedBox(height: m.scaled(10)),
                child,
              ],
            ),
    );

    // The outline and the bar are one box behind the hole rather than a
    // border on it. A Border with one thick side cannot carry a borderRadius
    // in Flutter at all, and in a release build it fails by drawing something
    // else instead of by saying so.
    return Container(
      decoration: BoxDecoration(
        color: edge ?? Palette.outline,
        borderRadius: BorderRadius.circular(m.scaled(10)),
        border: Border.all(color: Palette.outline, width: m.scaled(2)),
      ),
      padding: EdgeInsets.only(left: edge == null ? 0 : m.scaled(4)),
      child: inside,
    );
  }
}
