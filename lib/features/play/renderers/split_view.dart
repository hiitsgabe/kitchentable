import 'package:flutter/material.dart';

import '../../../table/view/seat_view.dart';
import '../../../ui/tokens/metrics.dart';

/// Two boards: yours and one other, each half the area.
///
/// Side by side on a wide screen, stacked on a tall one with yours below.
/// The seat rail picks the other; with two players there is nothing to pick.
/// This is untap's Split and TableCommander's Side-by-side.
class SplitView extends StatelessWidget {
  const SplitView({
    super.key,
    required this.metrics,
    required this.seats,
    required this.mineId,
    required this.watchedSeatId,
    required this.board,
  });

  final Metrics metrics;
  final List<SeatView> seats;
  final String mineId;

  /// The other seat to show, or null for the first one after yours.
  final String? watchedSeatId;

  final Widget Function(SeatView seat) board;

  @override
  Widget build(BuildContext context) {
    final gap = metrics.scaled(8);
    final mine = seats.where((s) => s.seatId == mineId).firstOrNull;
    final others = seats.where((s) => s.seatId != mineId).toList();
    final other =
        others.where((s) => s.seatId == watchedSeatId).firstOrNull ??
        others.firstOrNull;
    if (mine == null) return other == null ? const SizedBox() : board(other);
    if (other == null) return board(mine);

    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth > box.maxHeight;
        final cells = [
          Expanded(
            child: KeyedSubtree(
              key: const Key('split-other'),
              child: board(other),
            ),
          ),
          wide ? SizedBox(width: gap) : SizedBox(height: gap),
          Expanded(
            child: KeyedSubtree(
              key: const Key('split-mine'),
              child: board(mine),
            ),
          ),
        ];
        return wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: cells,
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: cells,
              );
      },
    );
  }
}
