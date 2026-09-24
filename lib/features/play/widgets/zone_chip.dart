import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../sources/model/catalog_card.dart';
import '../../../table/model/card_instance.dart';
import '../../../ui/atoms/card_art.dart';
import '../../../ui/tokens/metrics.dart';
import '../../../ui/tokens/palette.dart';
import '../dragging.dart';
import 'card_drag.dart';

/// How tall a chip stands when nothing is in the air, before scaling.
///
/// Two lines of nothing: a word and a number at the smallest size this app puts
/// either at, and the room around them. A card of the size a phone's board
/// draws one at is 70 points tall, so a zone nobody has used yet costs half of
/// what an outline of a card cost and says more than the outline did.
const _resting = 36.0;

/// How tall a chip stands when nothing is being dragged at it.
///
/// Said out loud so the row under the board can stand its other furniture in
/// a band of the same height. A row of five things 21.7, 36, 51, 77 and 122.9
/// points tall, bottom aligned, is what "toda confusa e desalinhada" was: no
/// two of them agreed about anything, so the eye had nothing to follow.
const zoneChipHeight = _resting;

/// A pile of cards as a chip, which is what a zone is worth until you aim at
/// something at it.
///
/// An empty graveyard was a card sized outline of a card that is not there, 50
/// by 70, and it was the leftmost and most prominent object on a 390 point
/// screen. A zone with cards in it shows the top card cropped into the same
/// chip, which is the pile barely sticking out past the edge that every phone
/// client and the practice literature both arrive at.
///
/// **It grows while a card is in the air.** A drop target only has to be the
/// size of a card while you are dragging one at it, so the chip takes a card of
/// room for exactly as long as the drag and gives it back afterwards. That is
/// the whole justification for the room, and it is worth the length of a drag.
class ZoneChip extends ConsumerWidget {
  const ZoneChip({
    super.key,
    required this.metrics,
    required this.pileName,
    required this.label,
    required this.count,
    required this.cardWidth,
    this.face,
    this.onTap,
    this.onDrop,
  });

  final Metrics metrics;

  /// What this zone is called in the widget tree: `graveyard-stack` is the box
  /// and `graveyard-open` the gesture on it. The same shape of name the pile it
  /// replaces used, because these are the names the suite aims at.
  final String pileName;

  /// The word on the chip. A zone with nothing in it has to say what it is.
  final String label;

  final int count;

  /// What a card on the board beside this is drawn at, which is the size the
  /// chip grows to while a card is in the air: a drop target the size of the
  /// card being dropped.
  final double cardWidth;

  /// The printing of the card on top, where the app has a picture of it. Null
  /// draws the chip with no card in it, which is also what an empty zone is.
  final CatalogCard? face;

  /// A tap, which opens the sheet the pile already had. Null, and a zone with
  /// nothing in it, take no taps: an empty pile's sheet is an empty sheet.
  final VoidCallback? onTap;

  /// A card let go over the chip. Null takes no drops.
  final void Function(CardInstance)? onDrop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = metrics;
    final card = cardWidth * 88 / 63;
    // Never taller than the card it stands in for, which is the one thing a
    // chip is. A television scales the resting height up and a phone in a four
    // seat pod draws a very small card, and those two meet somewhere.
    final height = ref.watch(draggingProvider)
        ? card
        : math.min(m.scaled(_resting), card);
    final showing = face;

    final chip = SizedBox(
      key: Key('$pileName-stack'),
      width: cardWidth,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(m.scaled(8)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: Palette.tile,
                border: Border.all(color: Palette.tileEdge),
              ),
            ),
            // The card at its own size with the chip cropping it, not a card
            // squashed into the chip: a card squashed out of its 63 by 88 is
            // the one thing on a table that reads as broken.
            if (showing != null)
              OverflowBox(
                alignment: Alignment.topCenter,
                maxHeight: card,
                child: CardArt(metrics: m, card: showing, width: cardWidth),
              ),
            Positioned(left: 0, right: 0, bottom: 0, child: _caption(m)),
          ],
        ),
      ),
    );

    // An empty pile takes no tap, which is what the pile did: opening it shows
    // you a sheet with nothing in it.
    final tap = onTap;
    final tappable = tap == null || count == 0
        ? chip
        : GestureDetector(
            key: Key('$pileName-open'),
            onTap: tap,
            behavior: HitTestBehavior.opaque,
            child: chip,
          );

    final thrownAt = onDrop;

    return thrownAt == null
        ? tappable
        : CardDropTarget(
            onDrop: (card, _) => thrownAt(card),
            child: tappable,
          );
  }

  /// The word and the number, along the bottom edge.
  ///
  /// Over the card rather than beside it, on a band of the chip's own colour,
  /// so a chip with a card in it is exactly as big as one without. Scaled down
  /// inside the chip's width the way the pile's caption was: a word longer than
  /// the thing it names used to set the width of the column the chip stands in,
  /// and that column's width comes out of the board.
  Widget _caption(Metrics m) => Container(
        padding: EdgeInsets.symmetric(
          horizontal: m.scaled(4),
          vertical: m.scaled(2),
        ),
        color: Palette.tile.withValues(alpha: 0.86),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: m.scaled(10),
                  color: Palette.inkFaint,
                ),
              ),
              SizedBox(width: m.scaled(6)),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: m.scaled(11),
                  fontWeight: FontWeight.w700,
                  color: Palette.ink,
                ),
              ),
            ],
          ),
        ),
      );
}
