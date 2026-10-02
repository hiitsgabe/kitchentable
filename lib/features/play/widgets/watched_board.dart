import 'package:flutter/material.dart';

import '../../../decks/model/game.dart';
import '../../../sources/model/catalog_card.dart';
import '../../../table/model/card_instance.dart';
import '../../../table/view/seat_view.dart';
import '../../../ui/tokens/metrics.dart';
import '../renderers/mat_layout.dart';
import 'table_card.dart';

/// Another player's battlefield, filling the box it is given.
///
/// The same free canvas as your own, read only: their cards sit where they
/// put them, by the normalised position each carries, and the whole thing
/// stretches to the rectangle a view hands it. A card here is never picked
/// up, so there is no drop target and no drag, only a tap and a long press to
/// read it closer, which is MTGO's rule: opponents' permanents shrink to keep
/// everything visible, and hover zoom carries the detail.
///
/// It takes a [SeatView], so a card this viewer may not see is not in the
/// tree to draw: a face down card on their battlefield is a back.
class WatchedCanvas extends StatelessWidget {
  const WatchedCanvas({
    super.key,
    required this.metrics,
    required this.seat,
    required this.printings,
    required this.onTapCard,
    required this.onInspectCard,
    this.game,
  });

  final Metrics metrics;
  final SeatView seat;
  final Map<String, CatalogCard> printings;
  final void Function(CardInstance) onTapCard;
  final void Function(CardInstance) onInspectCard;
  final Game? game;

  /// The smallest an opponent's card is drawn. Under this the art stops being
  /// recognisable from across the table, which is what a watched board is for.
  static const floor = 56.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final box = constraints.biggest;
          if (box.width <= 0 || box.height <= 0 || !box.height.isFinite) {
            return const SizedBox.shrink();
          }
          final cards =
              seat.pile('battlefield')?.cards ?? const <CardInstance>[];
          // Seven across the box, and never below the floor: the box decides
          // the size, so a bigger box is bigger cards and a full board. In a
          // cell too short for two rows at that size the card shrinks until
          // two rows fit, down to a smaller floor, so a second row lands
          // under the first rather than on top of it.
          final gap = metrics.scaled(6);
          final across = ((box.width - matPadding) / 7).clamp(floor, 140.0);
          final twoRows = ((box.height - gap) / 2) * 63 / 88;
          final width = across <= twoRows ? across : twoRows.clamp(44.0, across);
          final card = Size(width, width * 88 / 63);

          return ClipRect(
            child: Stack(
              key: Key('watched-${seat.seatId}'),
              children: [
                for (final (i, instance) in cards.indexed)
                  _place(instance, i, card, box),
              ],
            ),
          );
        },
      );

  Widget _place(CardInstance instance, int index, Size card, Size box) {
    final spot = _spot(instance.position, index, card, box);
    return Positioned(
      key: Key('watched-card-${instance.id}'),
      left: spot.dx,
      top: spot.dy,
      child: TableCard(
        metrics: metrics,
        instance: instance,
        printing: printings[instance.oracleId],
        width: card.width,
        game: game,
        onTap: () => onTapCard(instance),
        onLongPress: () => onInspectCard(instance),
        hoverPreview: false,
      ),
    );
  }

  /// A card at its placed spot, or flowed left to right when it has none,
  /// held inside the box so nothing is drawn off the edge.
  Offset _spot(
    ({double x, double y})? position,
    int index,
    Size card,
    Size box,
  ) {
    // The same inset your own board keeps, so a card at the left edge of
    // theirs lines up with one at the left edge of yours.
    final gap = metrics.scaled(6);
    final maxX = (box.width - card.width - matPadding).clamp(matPadding, double.infinity);
    final maxY = (box.height - card.height - matPadding).clamp(matPadding, double.infinity);
    if (position != null) {
      return Offset(
        matPadding + position.x * (maxX - matPadding),
        matPadding + position.y * (maxY - matPadding),
      );
    }
    final perRow = ((box.width - matPadding) ~/ (card.width + gap)).clamp(1, 99);
    return Offset(
      (matPadding + (index % perRow) * (card.width + gap)).clamp(matPadding, maxX),
      (matPadding + (index ~/ perRow) * (card.height + gap)).clamp(matPadding, maxY),
    );
  }
}
