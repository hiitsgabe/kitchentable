import 'package:flutter/material.dart';

import '../../../ui/tokens/app_palette.dart';
import '../../../ui/tokens/metrics.dart';
import '../../../ui/tokens/palette.dart';

/// One seat's board, dressed: the canvas it was handed, a badge in the
/// corner with the label and life, an accent edge when it is yours, and your
/// zone rail down the right side.
///
/// Every view draws every seat through this, so a board looks the same in
/// Focus, Grid and Split and the only thing a view decides is how big a
/// rectangle it gets. Yours has the edge because whose board it is must never
/// need reading; Hearthstone and Arena both draw your side distinct.
class SeatBoard extends StatelessWidget {
  const SeatBoard({
    super.key,
    required this.metrics,
    required this.seatId,
    required this.label,
    required this.life,
    required this.mine,
    required this.canvas,
    this.hand,
    this.zoneRail,
    this.onTapBadge,
  });

  final Metrics metrics;
  final String seatId;
  final String label;
  final int life;
  final bool mine;

  /// The battlefield itself, filling what is left: your own interactive
  /// board, or a watched canvas.
  final Widget canvas;

  /// How many cards this seat holds, shown on the badge for everybody but
  /// you: at a real table everybody can see how many, nobody which.
  final int? hand;

  /// Your piles, standing to the right of the canvas. Null on a watched board.
  final Widget? zoneRail;

  final VoidCallback? onTapBadge;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    return Container(
      key: Key('board-$seatId'),
      decoration: BoxDecoration(
        color: mine ? context.palette.tileFocused : Palette.tile,
        borderRadius: BorderRadius.circular(m.scaled(12)),
        border: Border.all(
          color: mine ? context.palette.accent.withValues(alpha: 0.7) : Palette.tileEdge,
          width: mine ? m.scaled(1.5) : 1,
        ),
      ),
      padding: EdgeInsets.all(m.scaled(6)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: onTapBadge,
            behavior: HitTestBehavior.opaque,
            child: LayoutBuilder(builder: (context, badge) => Row(
              children: [
                // The name takes the row and gives way last: what else is
                // here is a count and a number, and a name cut to one letter
                // beside a whole "hand 3" is the wrong thing kept.
                Expanded(
                  child: Text(
                    label,
                    key: Key('badge-$seatId'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: m.scaled(12),
                      fontWeight: FontWeight.w700,
                      color: mine ? context.palette.accent : Palette.ink,
                    ),
                  ),
                ),
                // The count gives way to the name in a narrow cell; the rail
                // carries it anyway.
                if (hand case final n? when badge.maxWidth >= m.scaled(180)) ...[
                  SizedBox(width: m.scaled(8)),
                  Text(
                    'hand $n',
                    style: TextStyle(
                      fontSize: m.scaled(10),
                      color: Palette.inkFaint,
                    ),
                  ),
                ],
                SizedBox(width: m.scaled(8)),
                Text(
                  '$life',
                  style: TextStyle(
                    fontSize: m.scaled(16),
                    fontWeight: FontWeight.w800,
                    color: life <= 0 ? Palette.attention : Palette.ink,
                  ),
                ),
              ],
            )),
          ),
          SizedBox(height: m.scaled(4)),
          Expanded(
            child: zoneRail == null
                ? canvas
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: canvas),
                      SizedBox(width: m.scaled(6)),
                      zoneRail!,
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
