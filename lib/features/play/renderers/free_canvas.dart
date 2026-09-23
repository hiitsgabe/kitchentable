import 'dart:ui' show clampDouble;

import 'package:flutter/material.dart';

import '../../../sources/model/catalog_card.dart';
import '../../../table/model/card_instance.dart';
import '../../../table/view/seat_view.dart';
import '../../../ui/tokens/metrics.dart';
import '../../../ui/tokens/palette.dart';
import '../widgets/card_drag.dart';
import '../widgets/table_card.dart';
import 'mat_layout.dart';

/// The wide view. Every mat on one surface you pan and pinch.
///
/// Only battlefields are here. A hand belongs to one person and lives in its
/// own sheet below the board, which is the Arena rule the spec pins by
/// geometry: you must be able to look at your hand and the table at once.
class FreeCanvas extends StatelessWidget {
  const FreeCanvas({
    super.key,
    required this.metrics,
    required this.seats,
    required this.viewerSeatId,
    required this.printings,
    required this.onTapCard,
    required this.onInspectCard,
    required this.onPlace,
    this.turnSeatId,
    this.cardScale = 1,
  });

  final Metrics metrics;
  final List<SeatView> seats;
  final String viewerSeatId;
  final Map<String, CatalogCard> printings;
  final void Function(CardInstance) onTapCard;
  final void Function(CardInstance) onInspectCard;

  /// Where one of your own cards was dropped, normalized 0 to 1 against your
  /// mat. Somebody else's card never reports: it is theirs to move.
  final void Function(String cardId, double x, double y) onPlace;

  final String? turnSeatId;

  /// The player's own multiplier on the card size. One is the surface exactly
  /// as the layout drew it.
  final double cardScale;

  @override
  Widget build(BuildContext context) {
    final surface = surfaceFor(seats.length);

    return InteractiveViewer(
      constrained: false,
      minScale: 0.2,
      maxScale: 2.5,
      boundaryMargin: const EdgeInsets.all(matGap),
      child: SizedBox(
        width: surface.width,
        height: surface.height,
        child: Stack(
          children: [
            // Walked in seat order and not in table order, so your own mat
            // is the one at the bottom, next to your hand.
            for (final (slot, seatAt) in seatOrder(
              count: seats.length,
              viewerAt: seats.indexWhere((s) => s.seatId == viewerSeatId),
            ).indexed)
              Positioned.fromRect(
                rect: matFor(slot, seats.length),
                child: _Mat(
                  metrics: metrics,
                  seat: seats[seatAt],
                  printings: printings,
                  isViewer: seats[seatAt].seatId == viewerSeatId,
                  isTurn: seats[seatAt].seatId == turnSeatId,
                  onTapCard: onTapCard,
                  onInspectCard: onInspectCard,
                  onPlace: onPlace,
                  cardScale: cardScale,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Mat extends StatelessWidget {
  const _Mat({
    required this.metrics,
    required this.seat,
    required this.printings,
    required this.isViewer,
    required this.isTurn,
    required this.onTapCard,
    required this.onInspectCard,
    required this.onPlace,
    required this.cardScale,
  });

  final Metrics metrics;
  final SeatView seat;
  final Map<String, CatalogCard> printings;
  final bool isViewer;
  final bool isTurn;
  final void Function(CardInstance) onTapCard;
  final void Function(CardInstance) onInspectCard;
  final void Function(String cardId, double x, double y) onPlace;
  final double cardScale;

  /// The card as this mat lays it out. The whole size scales and not just the
  /// drawn width, so a bigger card is still centred on its own spot and still
  /// leaves a gap in the flow.
  Size get _cardSize => cardOnMat * cardScale;

  @override
  Widget build(BuildContext context) {
    final board = seat.pile('battlefield');
    final cards = board?.cards ?? const <CardInstance>[];

    // Keyed apart from the mat because the mat's border insets it by the
    // border's width, so this and not the mat is the box a position is
    // measured against, and the two are a unit out.
    final surface = Stack(
      key: Key('mat-surface-${seat.seatId}'),
      children: [
        Positioned(
          left: matPadding,
          top: matPadding / 2,
          child: Text(
            '${seat.name} · ${seat.life}',
            style: TextStyle(
              fontSize: 18,
              color: seat.life <= 0 ? Palette.attention : Palette.inkMuted,
            ),
          ),
        ),
        for (var i = 0; i < cards.length; i++)
          _place(cards[i], i),
      ],
    );

    return Container(
      key: Key('mat-${seat.seatId}'),
      decoration: BoxDecoration(
        color: isViewer ? Palette.tileFocused : Palette.tile,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isTurn ? Palette.accent : Palette.tileEdge,
          width: isTurn ? 3 : 1,
        ),
      ),
      // Only your own mat takes a card. Letting go over somebody else's is
      // letting go over nothing, and the card stays where it was, which is
      // what it did when a foreign card simply could not be picked up.
      child: isViewer ? CardDropTarget(onDrop: _drop, child: surface) : surface,
    );
  }

  Widget _place(CardInstance card, int index) {
    final spot = spotFor(
      position: card.position,
      index: index,
      card: _cardSize,
    );

    final face = TableCard(
      metrics: metrics,
      instance: card,
      printing: printings[card.oracleId],
      width: _cardSize.width,
      onTap: () => onTapCard(card),
      onLongPress: () => onInspectCard(card),
      // The same as the D-pad board: the canvas draws a card at the mat's
      // scale, and a preview of one that is already big helps nobody.
      hoverPreview: false,
    );

    return Positioned(
      key: Key('card-${card.id}'),
      left: spot.dx,
      // Below the seat's name, which sits in the padding at the top.
      top: spot.dy + matPadding,
      // A card on somebody else's mat is theirs to move, so it is not even
      // picked up: no drag, no half move that snaps back.
      child: DraggableCard(card: card, canDrag: isViewer, child: face),
    );
  }

  void _drop(CardInstance card, Offset at) {
    // Where the pointer was let go, in this mat's own units, which the
    // canvas's zoom is already out of: globalToLocal walks the
    // InteractiveViewer's transform, so a screen pixel on a zoomed table is
    // not mistaken for a mat unit.
    //
    // The card rides centred on the finger, so the pointer is the card's new
    // centre and spotFor is its inverse. The padding the seat's name sits in
    // shifts every card down and so is in the reported position too: it used
    // to cancel between two numbers in the same frame, and now it has to come
    // back out by hand.
    onPlace(
      card.id,
      clampDouble(at.dx / matSize.width, 0, 1),
      clampDouble((at.dy - matPadding) / matSize.height, 0, 1),
    );
  }
}
