import 'package:flutter/material.dart';

import '../../../ui/atoms/slab.dart';
import '../../../ui/tokens/lettering.dart';
import '../../../ui/tokens/metrics.dart';
import '../../../ui/tokens/palette.dart';

/// The offer to put this hand back, under the deck it goes back into.
///
/// Under the deck and not in the hand, which is where it started: a mulligan
/// is a thing you do to the deck, the deck is the one pile that is on screen
/// whatever else is, and an offer that only appears once you have opened your
/// hand is an offer half the table will never find.
///
/// It takes itself away rather than being dismissed. See
/// [stillChoosingAHand]: the game starting is what ends it, and the game
/// starting is read off the cards.
class MulliganButton extends StatelessWidget {
  const MulliganButton({
    super.key,
    required this.metrics,
    required this.putBack,
    required this.onTake,
    required this.width,
  });

  final Metrics metrics;

  /// How many cards go to the bottom if this hand is kept, which is the
  /// London rule and the whole cost of having taken one.
  final int putBack;

  final VoidCallback onTake;

  /// The deck's own width, so the two of them line up in the column.
  final double width;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return Column(
      key: const Key('mulligan-column'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(height: m.scaled(6)),
        Slab(
          key: const Key('mulligan'),
          metrics: m,
          tone: SlabTone.warm,
          depth: m.scaled(4),
          onActivate: onTake,
          semanticLabel: putBack == 0
              ? 'Mulligan'
              : 'Mulligan. $putBack to put on the bottom',
          padding: EdgeInsets.symmetric(
            horizontal: m.scaled(8),
            vertical: m.scaled(6),
          ),
          child: Text(
            'Mulligan',
            textAlign: TextAlign.center,
            style: slabText(m.scaled(11)),
          ),
        ),
        if (putBack > 0) ...[
          SizedBox(height: m.scaled(4)),
          // Short, because this column is as wide as a card. The long version
          // of this sentence belongs nowhere near a deck.
          Text(
            'bottom $putBack',
            key: const Key('mulligan-owed'),
            textAlign: TextAlign.center,
            style: pixel(
              size: m.scaled(10),
              weight: 500,
              color: Palette.inkMuted,
            ),
          ),
        ],
      ],
    );
  }
}
