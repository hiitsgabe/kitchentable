import 'package:flutter/material.dart';

import '../../../sources/model/catalog_card.dart';
import '../../../table/view/seat_view.dart';
import '../../../ui/tokens/metrics.dart';
import '../widgets/seat_band.dart';

/// The phone view. Opponents stacked above, your own seat below and taller.
///
/// Bands rather than tabs, because a threat you are not looking at is a threat
/// you forget, and Commander is the format where the rest of the table matters
/// most. Nobody has to switch to anything to know they are about to die.
class StackedSeats extends StatelessWidget {
  const StackedSeats({
    super.key,
    required this.metrics,
    required this.seats,
    required this.viewerSeatId,
    required this.printings,
    required this.onFocusSeat,
    required this.yours,
    this.turnSeatId,
    this.focusedSeatId,
  });

  final Metrics metrics;

  /// Every seat, in table order, already filtered for this viewer.
  final List<SeatView> seats;

  /// Whose eyes. Empty or unknown means a spectator, and then every seat is
  /// somebody else's.
  final String viewerSeatId;

  final Map<String, CatalogCard> printings;
  final void Function(String seatId) onFocusSeat;

  /// Your own seat, drawn by whoever owns that layout. This renderer decides
  /// where it goes and has no opinion about what is in it, which is what keeps
  /// the board, the piles and the hand out of here.
  final Widget yours;

  final String? turnSeatId;
  final String? focusedSeatId;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final others = seats.where((s) => s.seatId != viewerSeatId).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (others.isNotEmpty)
          Expanded(
            flex: 2,
            child: ListView(
              padding: EdgeInsets.only(bottom: m.scaled(4)),
              children: [
                for (final seat in others)
                  SeatBand(
                    metrics: m,
                    seat: seat,
                    printings: printings,
                    isTurn: seat.seatId == turnSeatId,
                    focused: seat.seatId == focusedSeatId,
                    onTap: () => onFocusSeat(seat.seatId),
                  ),
              ],
            ),
          ),
        // Three to two: your own seat is where the game is played from, and a
        // fair split makes a four card hand and four opponents equally cramped.
        Expanded(flex: 3, child: yours),
      ],
    );
  }
}
