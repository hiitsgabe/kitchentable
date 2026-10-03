import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ui/tokens/metrics.dart';
import '../dragging.dart';

/// The piles that belong on the battle zone, standing in a narrow rail on
/// the right edge of your board: the graveyard and the command zone, a
/// thumbnail each with its count, the way TableCommander's column and
/// Forge's zone buttons work. The deck is not here; it is fixed in the
/// bottom bar beside the hand, where it is always visible and costs the
/// board nothing. The rail costs one thumbnail of width and no height.
///
/// Scrolls if it has to rather than overflowing.
class ZoneRail extends ConsumerWidget {
  const ZoneRail({
    super.key,
    required this.metrics,
    required this.width,
    required this.graveyard,
    this.command,
  });

  final Metrics metrics;

  /// How wide a thumbnail is. The board hands this over so the piles are
  /// drawn at a size that reads beside its cards.
  final double width;

  final Widget graveyard;

  /// Null in a format without commanders. An empty corner is still drawn
  /// when the format has one, because a corner that comes and goes reads as
  /// a bug rather than as a rule.
  final Widget? command;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = metrics;
    // Eight points apart at rest and a card's width apart while one is in the
    // air. The graveyard grows into a card sized target the moment a drag
    // starts, which leaves the command zone directly under it with a hair
    // between them; a player aiming at one of two things that size, from
    // under a card that covers both, lands in the other often enough to be
    // reported as a bug.
    final apart = ref.watch(draggingProvider) ? m.scaled(22) : m.scaled(8);
    return SizedBox(
      width: width,
      child: SingleChildScrollView(
        child: Column(
          key: const Key('zone-rail'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            graveyard,
            if (command case final corner?) ...[
              SizedBox(height: apart),
              corner,
            ],
          ],
        ),
      ),
    );
  }
}
