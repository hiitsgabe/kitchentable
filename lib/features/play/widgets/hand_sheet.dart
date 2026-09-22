import 'package:flutter/material.dart';

import '../../../sources/model/catalog_card.dart';
import '../../../table/model/card_instance.dart';
import '../../../ui/tokens/metrics.dart';
import '../../../ui/tokens/palette.dart';
import 'grabbable.dart';
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
  /// How far sideways each card has been dragged and not yet let go of.
  final _dragging = <String, double>{};

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
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: widget.cards.length,
            separatorBuilder: (_, _) => SizedBox(width: gap),
            itemBuilder: (_, i) => _card(m, i, width, pitch),
          );
        }

        return Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < widget.cards.length; i++) ...[
                if (i > 0) SizedBox(width: gap),
                _card(m, i, width, pitch),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _card(Metrics m, int index, double width, double pitch) {
    final card = widget.cards[index];

    return Transform.translate(
      offset: Offset(_dragging[card.id] ?? 0, 0),
      child: Grabbable(
        onMove: (delta) => _drag(card.id, delta.dx),
        onDrop: () => _drop(index, pitch),
        child: TableCard(
          key: Key('hand-card-${card.id}'),
          metrics: m,
          instance: card,
          printing: widget.printings[card.oracleId],
          width: width,
          onTap: () => widget.onPlay(card),
          onLongPress: () => widget.onInspect(card),
        ),
      ),
    );
  }

  void _drag(String cardId, double dx) {
    setState(() {
      _dragging[cardId] = (_dragging[cardId] ?? 0) + dx;
    });
  }

  /// Which card the gap it was let go over belongs to.
  ///
  /// One pitch of travel is one place along, because every card in the hand is
  /// the same width. A card dragged off either end stops at the end rather
  /// than falling out of the hand.
  void _drop(int index, double pitch) {
    final card = widget.cards[index];
    final moved = _dragging.remove(card.id);
    setState(() {});
    if (moved == null) return;

    final to =
        (index + (moved / pitch).round()).clamp(0, widget.cards.length - 1);
    if (to == index) return;
    widget.onReorder(card.id, to);
  }
}
