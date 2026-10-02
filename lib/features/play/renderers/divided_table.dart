import 'package:flutter/material.dart';

import '../../../table/view/seat_view.dart';
import '../../../ui/tokens/metrics.dart';

/// The table divided equally among the seats, each board filling its share.
///
/// The default view, and the answer to a screen that was mostly empty: every
/// seat gets an equal slice of the glass, so no board floats in a margin.
/// Your own board is one slice, the others are the rest, and each is a free
/// canvas as big as its slice. Up to [cap] slices share the screen at once;
/// past that the column scrolls rather than shrinking a board to a smudge.
///
/// Your own slice sits at the bottom, nearest your hand; the others stack
/// above in table order, which is where they would be sitting.
class DividedTable extends StatelessWidget {
  const DividedTable({
    super.key,
    required this.metrics,
    required this.seats,
    required this.viewerSeatId,
    required this.yours,
    required this.watched,
    this.cap = 4,
  });

  final Metrics metrics;

  /// Every seat, in table order.
  final List<SeatView> seats;

  /// Which slice is the interactive one.
  final String viewerSeatId;

  /// Your own board, built by the screen with its furniture and handed in.
  final Widget yours;

  /// One other player's board, read only, for the seat passed.
  final Widget Function(SeatView seat) watched;

  /// How many slices share the screen before it scrolls.
  final int cap;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final others = seats.where((s) => s.seatId != viewerSeatId).toList();

    // Others above in table order, your own slice at the bottom.
    final slices = <Widget>[
      for (final seat in others)
        Padding(
          key: Key('slice-${seat.seatId}'),
          padding: EdgeInsets.only(bottom: m.scaled(8)),
          child: watched(seat),
        ),
      KeyedSubtree(key: const Key('slice-yours'), child: yours),
    ];

    // Within the cap every slice is an equal share of the height; past it,
    // each slice is a cap-th of the viewport and the column scrolls.
    if (slices.length <= cap) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final slice in slices) Expanded(child: slice)],
      );
    }

    return LayoutBuilder(
      builder: (context, box) {
        final height = box.maxHeight / cap - m.scaled(8);
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final slice in slices)
                SizedBox(height: height, child: slice),
            ],
          ),
        );
      },
    );
  }
}
