import 'package:flutter/material.dart';

import '../../../ui/tokens/app_palette.dart';
import '../../../ui/tokens/metrics.dart';
import '../../../ui/tokens/palette.dart';

/// One seat on the rail: who, and how much life.
typedef RailSeat = ({String seatId, String label, int life, int hand, bool mine});

/// One thin row for the whole table: a chip per player with their label and
/// life, in table order, yours marked.
///
/// This is what every client the benchmark read does with life: a plate per
/// player or one stat row, never a band of boxes. It is 28 points tall, and
/// it is also the switch: a tap says which board to look at, which the view
/// that is showing decides what to do with. A threat you are not looking at
/// is still a number on this row, which is the whole reason it never goes
/// away.
class SeatRail extends StatelessWidget {
  const SeatRail({
    super.key,
    required this.metrics,
    required this.seats,
    required this.onPick,
    this.pickedSeatId,
  });

  final Metrics metrics;
  final List<RailSeat> seats;
  final void Function(String seatId) onPick;

  /// The chip drawn as chosen: the focused board, or the second board of a
  /// split. Null draws none that way.
  final String? pickedSeatId;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    return SizedBox(
      height: m.scaled(28),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final seat in seats)
            GestureDetector(
              key: Key('rail-${seat.seatId}'),
              onTap: () => onPick(seat.seatId),
              behavior: HitTestBehavior.opaque,
              child: Container(
                margin: EdgeInsets.only(right: m.scaled(6)),
                padding: EdgeInsets.symmetric(horizontal: m.scaled(10)),
                decoration: BoxDecoration(
                  color: seat.mine ? context.palette.tileFocused : Palette.tile,
                  borderRadius: BorderRadius.circular(m.scaled(14)),
                  border: Border.all(
                    color: seat.seatId == pickedSeatId
                        ? context.palette.accent
                        : Palette.tileEdge,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      seat.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: m.scaled(11),
                        fontWeight:
                            seat.mine ? FontWeight.w700 : FontWeight.w500,
                        color: Palette.ink,
                      ),
                    ),
                    SizedBox(width: m.scaled(6)),
                    Text(
                      '${seat.life}',
                      style: TextStyle(
                        fontSize: m.scaled(12),
                        fontWeight: FontWeight.w800,
                        color: seat.life <= 0 ? Palette.attention : Palette.ink,
                      ),
                    ),
                    if (!seat.mine) ...[
                      SizedBox(width: m.scaled(6)),
                      Text(
                        'h${seat.hand}',
                        style: TextStyle(
                          fontSize: m.scaled(9),
                          color: Palette.inkFaint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
