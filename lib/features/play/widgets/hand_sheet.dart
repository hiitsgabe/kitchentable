import 'package:flutter/material.dart';

import '../../../sources/model/catalog_card.dart';
import '../../../table/model/card_instance.dart';
import '../../../ui/tokens/metrics.dart';
import '../../../ui/tokens/palette.dart';
import 'card_drag.dart';
import 'table_card.dart';

/// The hand, along the bottom, scrolling sideways.
///
/// It sits below the board and never on top of it. On mobile Arena opens the
/// hand into a fan across the battlefield, so you cannot look at your hand and
/// the board at the same time, and that is the one thing this must not copy.
class HandSheet extends StatefulWidget {
  const HandSheet({
    super.key,
    required this.metrics,
    required this.cards,
    required this.printings,
    required this.onPlay,
    required this.onInspect,
    required this.onReorder,
  });

  final Metrics metrics;
  final List<CardInstance> cards;
  final Map<String, CatalogCard> printings;
  final void Function(CardInstance) onPlay;
  final void Function(CardInstance) onInspect;

  /// Where a card was dragged to, as a place in the hand.
  final void Function(String cardId, int to) onReorder;

  @override
  State<HandSheet> createState() => _HandSheetState();
}

class _HandSheetState extends State<HandSheet> {
  /// Held because a hand too long to fit scrolls, and how far it has been
  /// scrolled is part of reading where a card was let go.
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.metrics;

    return Container(
      padding: EdgeInsets.symmetric(vertical: m.scaled(10)),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Palette.rule)),
      ),
      child: SizedBox(
        height: m.scaled(96),
        child: widget.cards.isEmpty
            ? Center(
                child: Text(
                  'No cards in hand',
                  style:
                      TextStyle(fontSize: m.scaled(12), color: Palette.inkFaint),
                ),
              )
            : _cards(m),
      ),
    );
  }

  Widget _cards(Metrics m) {
    final width = m.scaled(64);
    final gap = m.scaled(6);
    final pitch = width + gap;

    return LayoutBuilder(
      builder: (context, constraints) {
        // A hand you can see all of sits in the middle, where your thumb is.
        // Centring one that does not fit would push its first card off the
        // left of the screen, so that one starts at the edge and scrolls, as
        // it always did.
        if (widget.cards.length * pitch > constraints.maxWidth) {
          return CardDropTarget(
            onDrop: (card, at) => _drop(
              card,
              at.dx + (_scroll.hasClients ? _scroll.offset : 0),
              pitch,
            ),
            child: ListView.separated(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              itemCount: widget.cards.length,
              separatorBuilder: (_, _) => SizedBox(width: gap),
              itemBuilder: (_, i) => _card(m, i, width),
            ),
          );
        }

        // The target is the row and not the sheet, so the arithmetic below
        // counts from the first card rather than from wherever centring
        // happened to put it.
        return Center(
          child: CardDropTarget(
            onDrop: (card, at) => _drop(card, at.dx, pitch),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < widget.cards.length; i++) ...[
                  if (i > 0) SizedBox(width: gap),
                  _card(m, i, width),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _card(Metrics m, int index, double width) {
    final card = widget.cards[index];

    return DraggableCard(
      card: card,
      child: TableCard(
        key: Key('hand-card-${card.id}'),
        metrics: m,
        instance: card,
        printing: widget.printings[card.oracleId],
        width: width,
        onTap: () => widget.onPlay(card),
        onLongPress: () => widget.onInspect(card),
      ),
    );
  }

  /// Which place in the hand the card was let go over.
  ///
  /// Every card in the hand is the same width, so the place is the distance
  /// from the front of the hand over one pitch. A card let go past either end
  /// stops at the end rather than falling out of the hand.
  void _drop(CardInstance card, double x, double pitch) {
    final from = widget.cards.indexWhere((c) => c.id == card.id);
    if (from < 0) return;

    final to = (x / pitch).floor().clamp(0, widget.cards.length - 1);
    if (to == from) return;
    widget.onReorder(card.id, to);
  }
}
