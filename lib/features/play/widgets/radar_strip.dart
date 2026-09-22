import 'package:flutter/material.dart';

import '../../../ui/tokens/metrics.dart';
import '../../../ui/tokens/palette.dart';

/// Every life total, always visible, whichever renderer is drawing.
///
/// This is the whole argument for bands over tabs in the spec. A threat you are
/// not looking at is a threat you forget, and Commander is the format where the
/// rest of the table matters most.
class RadarStrip extends StatelessWidget {
  const RadarStrip({
    super.key,
    required this.metrics,
    required this.seats,
    required this.onJump,
    this.focusedSeatId,
  });

  final Metrics metrics;
  final List<({String seatId, String name, int life})> seats;
  final void Function(String seatId) onJump;
  final String? focusedSeatId;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return Row(
      children: [
        for (final seat in seats)
          Expanded(
            child: GestureDetector(
              onTap: () => onJump(seat.seatId),
              behavior: HitTestBehavior.opaque,
              child: Container(
                margin: EdgeInsets.only(right: m.scaled(5)),
                padding: EdgeInsets.symmetric(vertical: m.scaled(6)),
                decoration: BoxDecoration(
                  color: Palette.tile,
                  borderRadius: BorderRadius.circular(m.scaled(8)),
                  border: Border.all(
                    color: seat.seatId == focusedSeatId
                        ? Palette.accent
                        : Palette.tileEdge,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${seat.life}',
                      style: TextStyle(
                        fontSize: m.scaled(15),
                        fontWeight: FontWeight.w700,
                        color: seat.life <= 0
                            ? Palette.attention
                            : Palette.ink,
                      ),
                    ),
                    Text(
                      seat.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: m.scaled(9),
                        letterSpacing: .4,
                        color: Palette.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
