import 'package:flutter/material.dart';

import '../tokens/metrics.dart';
import '../tokens/palette.dart';

/// A count against a target: 63 of 100. Goes brass when the two agree, and
/// warns when the deck has run past a size that is a ceiling rather than a
/// floor, which in this app means Commander.
class CountPill extends StatelessWidget {
  const CountPill({
    super.key,
    required this.metrics,
    required this.label,
    required this.count,
    this.target,
    this.exact = false,
  });

  final Metrics metrics;
  final String label;
  final int count;
  final int? target;
  final bool exact;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final t = target;

    final Color colour;
    if (t == null) {
      colour = Palette.inkMuted;
    } else if (count == t) {
      colour = Palette.accent;
    } else if (exact && count > t) {
      colour = Palette.attention;
    } else {
      colour = Palette.inkMuted;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: m.scaled(10),
        vertical: m.scaled(6),
      ),
      decoration: BoxDecoration(
        color: Palette.tile,
        borderRadius: BorderRadius.circular(m.scaled(8)),
        border: Border.all(
          color: colour == Palette.inkMuted ? Palette.tileEdge : colour,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            t == null ? '$count' : '$count of $t',
            style: TextStyle(
              fontSize: m.scaled(13),
              fontWeight: FontWeight.w600,
              color: colour,
            ),
          ),
          SizedBox(width: m.scaled(6)),
          Text(
            label,
            style: TextStyle(fontSize: m.scaled(11), color: Palette.inkFaint),
          ),
        ],
      ),
    );
  }
}
