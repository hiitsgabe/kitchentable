import 'package:flutter/material.dart';

import '../../../sources/model/catalog_card.dart';
import '../../../table/model/card_instance.dart';
import '../../../table/view/seat_view.dart';
import '../../../ui/tokens/metrics.dart';
import '../../../ui/tokens/palette.dart';
import '../widgets/table_card.dart';
import 'mat_layout.dart';

/// How big a card is in surface units. The canvas zooms, so this is fixed and
/// [Metrics] is deliberately not consulted for it: a card must be the same
/// size relative to the mat on a phone and on a television.
const _cardOnMat = Size(90, 90 * 88 / 63);

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
    this.turnSeatId,
    this.cardScale = 1,
  });

  final Metrics metrics;
  final List<SeatView> seats;
  final String viewerSeatId;
  final Map<String, CatalogCard> printings;
  final void Function(CardInstance) onTapCard;
  final void Function(CardInstance) onInspectCard;
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
            for (var i = 0; i < seats.length; i++)
              Positioned.fromRect(
                rect: matFor(i, seats.length),
                child: _Mat(
                  metrics: metrics,
                  seat: seats[i],
                  printings: printings,
                  isViewer: seats[i].seatId == viewerSeatId,
                  isTurn: seats[i].seatId == turnSeatId,
                  onTapCard: onTapCard,
                  onInspectCard: onInspectCard,
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
    required this.cardScale,
  });

  final Metrics metrics;
  final SeatView seat;
  final Map<String, CatalogCard> printings;
  final bool isViewer;
  final bool isTurn;
  final void Function(CardInstance) onTapCard;
  final void Function(CardInstance) onInspectCard;
  final double cardScale;

  @override
  Widget build(BuildContext context) {
    final board = seat.pile('battlefield');
    final cards = board?.cards ?? const <CardInstance>[];

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
      child: Stack(
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
      ),
    );
  }

  Widget _place(CardInstance card, int index) {
    // The whole size scales and not just the drawn width, so a bigger card is
    // still centred on its own spot and still leaves a gap in the flow.
    final size = _cardOnMat * cardScale;
    final spot = spotFor(
      position: card.position,
      index: index,
      card: size,
    );

    return Positioned(
      key: Key('card-${card.id}'),
      left: spot.dx,
      // Below the seat's name, which sits in the padding at the top.
      top: spot.dy + matPadding,
      child: TableCard(
        metrics: metrics,
        instance: card,
        printing: printings[card.oracleId],
        width: size.width,
        onTap: () => onTapCard(card),
        onLongPress: () => onInspectCard(card),
      ),
    );
  }
}
