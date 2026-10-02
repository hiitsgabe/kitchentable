import 'package:flutter/material.dart';

import '../../../decks/model/game.dart';
import '../../../sources/model/catalog_card.dart';
import '../../../table/model/card_instance.dart';
import '../../../table/view/seat_view.dart';
import '../../../ui/tokens/metrics.dart';
import '../../../ui/tokens/palette.dart';
import 'table_card.dart';

/// Another player's board, filling the box it is given.
///
/// The same free canvas as your own, read only: their cards sit where they
/// put them, by the normalised position each carries, and the whole thing
/// stretches to the rectangle a view hands it rather than a fixed mat floating
/// in empty space. A card here is never picked up, so there is no drop target
/// and no drag, only a tap to look closer and a long press to read it.
///
/// It takes a [SeatView], so a card this viewer may not see is not in the tree
/// to draw: a face down card on their battlefield is a back, and their hand is
/// a count in the header and nothing more.
class WatchedBoard extends StatelessWidget {
  const WatchedBoard({
    super.key,
    required this.metrics,
    required this.seat,
    required this.label,
    required this.printings,
    required this.onTapCard,
    required this.onInspectCard,
    this.game,
  });

  final Metrics metrics;
  final SeatView seat;

  /// What to call this player on the glass: their name, or "Player 2", never
  /// the stored default. Worked out by the view, which knows the chair.
  final String label;

  final Map<String, CatalogCard> printings;
  final void Function(CardInstance) onTapCard;
  final void Function(CardInstance) onInspectCard;
  final Game? game;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final hand = seat.pile('hand');
    final graveyard = seat.pile('graveyard');
    final command = seat.pile('command');

    return Container(
      key: Key('watched-${seat.seatId}'),
      decoration: BoxDecoration(
        color: Palette.tile,
        borderRadius: BorderRadius.circular(m.scaled(12)),
        border: Border.all(color: Palette.tileEdge),
      ),
      padding: EdgeInsets.all(m.scaled(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            metrics: m,
            label: label,
            life: seat.life,
            hand: hand?.count ?? 0,
            graveyard: graveyard?.count ?? 0,
            command: command,
            printings: printings,
            game: game,
            onInspectCard: onInspectCard,
          ),
          SizedBox(height: m.scaled(6)),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) => _Canvas(
                metrics: m,
                box: box.biggest,
                seat: seat,
                printings: printings,
                game: game,
                onTapCard: onTapCard,
                onInspectCard: onInspectCard,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Their name, life, and how many cards are in hand and graveyard: what you
/// can see of a player across a real table without touching their cards.
class _Header extends StatelessWidget {
  const _Header({
    required this.metrics,
    required this.label,
    required this.life,
    required this.hand,
    required this.graveyard,
    required this.command,
    required this.printings,
    required this.game,
    required this.onInspectCard,
  });

  final Metrics metrics;
  final String label;
  final int life;
  final int hand;
  final int graveyard;
  final ZoneView? command;
  final Map<String, CatalogCard> printings;
  final Game? game;
  final void Function(CardInstance) onInspectCard;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    return Row(
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: m.scaled(13),
              fontWeight: FontWeight.w600,
              color: Palette.ink,
            ),
          ),
        ),
        SizedBox(width: m.scaled(10)),
        _Chip(metrics: m, text: 'hand $hand'),
        SizedBox(width: m.scaled(6)),
        _Chip(metrics: m, text: 'grave $graveyard'),
        const Spacer(),
        Text(
          '$life',
          style: TextStyle(
            fontSize: m.scaled(20),
            fontWeight: FontWeight.w800,
            color: life <= 0 ? Palette.attention : Palette.ink,
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.metrics, required this.text});

  final Metrics metrics;
  final String text;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    return Text(
      text,
      style: TextStyle(fontSize: m.scaled(10), color: Palette.inkFaint),
    );
  }
}

/// The battlefield itself, their cards where they placed them.
class _Canvas extends StatelessWidget {
  const _Canvas({
    required this.metrics,
    required this.box,
    required this.seat,
    required this.printings,
    required this.game,
    required this.onTapCard,
    required this.onInspectCard,
  });

  final Metrics metrics;
  final Size box;
  final SeatView seat;
  final Map<String, CatalogCard> printings;
  final Game? game;
  final void Function(CardInstance) onTapCard;
  final void Function(CardInstance) onInspectCard;

  @override
  Widget build(BuildContext context) {
    final cards = seat.pile('battlefield')?.cards ?? const <CardInstance>[];
    // A watched board is an overview, so a card can be smaller than the
    // readable floor your own board holds: seven across the cell, within
    // bounds that keep it from a smudge on a phone or a poster on a wall.
    final cardWidth = (box.width / 7).clamp(m(28), m(140));
    final cardHeight = cardWidth * 88 / 63;
    final cardSize = Size(cardWidth, cardHeight);

    if (box.width <= 0 || box.height <= 0) return const SizedBox.shrink();

    return ClipRect(
      child: Stack(
        children: [
          for (final (i, card) in cards.indexed)
            _place(card, i, cardSize),
        ],
      ),
    );
  }

  double m(double v) => metrics.scaled(v);

  Widget _place(CardInstance card, int index, Size card_) {
    final spot = _spot(card.position, index, card_);
    return Positioned(
      key: Key('watched-card-${card.id}'),
      left: spot.dx,
      top: spot.dy,
      child: TableCard(
        metrics: metrics,
        instance: card,
        printing: printings[card.oracleId],
        width: card_.width,
        game: game,
        onTap: () => onTapCard(card),
        onLongPress: () => onInspectCard(card),
        hoverPreview: false,
      ),
    );
  }

  /// A card at its placed spot, or flowed left to right when it has none, held
  /// inside the box so nothing is drawn off the edge.
  Offset _spot(({double x, double y})? position, int index, Size card_) {
    final maxX = (box.width - card_.width).clamp(0.0, double.infinity);
    final maxY = (box.height - card_.height).clamp(0.0, double.infinity);
    if (position != null) {
      return Offset(position.x * maxX, position.y * maxY);
    }
    final perRow = (box.width ~/ (card_.width + m(6))).clamp(1, 99);
    final col = index % perRow;
    final row = index ~/ perRow;
    return Offset(
      (col * (card_.width + m(6))).clamp(0.0, maxX),
      (row * (card_.height + m(6))).clamp(0.0, maxY),
    );
  }
}
