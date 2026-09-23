import 'package:flutter/material.dart';

import '../../../sources/model/catalog_card.dart';
import '../../../table/model/card_instance.dart';
import '../../../ui/tokens/metrics.dart';
import '../../../ui/tokens/palette.dart';
import 'card_drag.dart';
import 'table_card.dart';

/// How many lines of cards the hand ever draws.
///
/// The hand sits under the board and every point it takes is a point the
/// battlefield loses, which is what the board's own width arithmetic spent
/// itself on. Two lines holds a hand of ten at the width a card in hand has
/// always been drawn at; past that the cards get smaller instead.
const _mostLines = 2;

/// How tall one line of cards is, before scaling.
///
/// A card at the hand's width is 89.4 points tall and the rest is the room a
/// counter pill needs where it hangs off the bottom corner. This is the height
/// the sheet has always given a single line, so a hand that fits on one is
/// exactly as tall as it was.
const _lineHeight = 96.0;

/// How wide a card in the hand is drawn while the hand fits.
const _cardWidth = 64.0;

/// The hand, along the bottom, wrapped onto as many lines as it needs.
///
/// It sits below the board and never on top of it. On mobile Arena opens the
/// hand into a fan across the battlefield, so you cannot look at your hand and
/// the board at the same time, and that is the one thing this must not copy.
class HandSheet extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final m = metrics;

    return Container(
      padding: EdgeInsets.symmetric(vertical: m.scaled(10)),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Palette.rule)),
      ),
      child: cards.isEmpty
          ? SizedBox(
              height: m.scaled(_lineHeight),
              child: Center(
                child: Text(
                  'No cards in hand',
                  style:
                      TextStyle(fontSize: m.scaled(12), color: Palette.inkFaint),
                ),
              ),
            )
          : _cards(m),
    );
  }

  Widget _cards(Metrics m) {
    final gap = m.scaled(6);
    final full = m.scaled(_cardWidth);

    return LayoutBuilder(
      builder: (context, constraints) {
        final room = constraints.maxWidth;
        var perLine = _perLine(room, full, gap);
        var lines = (cards.length / perLine).ceil();
        var width = full;

        // A hand of sixty is a Battle of Wits deck and it still cannot be
        // allowed to eat the battlefield. Past the cap the whole hand is
        // squeezed onto the lines there are rather than asking for another.
        if (lines > _mostLines) {
          lines = _mostLines;
          perLine = (cards.length / _mostLines).ceil();
          width = (room - (perLine - 1) * gap) / perLine;
        }

        return SizedBox(
          height: lines * m.scaled(_lineHeight) + (lines - 1) * gap,
          // A hand you can see all of sits in the middle, where your thumb
          // is. There is no longer a hand that has to start hard against the
          // left edge: the one too wide to fit across wraps onto a second
          // line instead of scrolling off, and scrolling was never reachable
          // anyway because a card's own drag wins the gesture arena.
          child: Center(
            child: CardDropTarget(
              onDrop: (card, at) => _drop(card, at, width, gap, perLine),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (var i = 0; i < cards.length; i++) _card(m, i, width),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// How many cards of this width fit across, never fewer than one.
  int _perLine(double room, double width, double gap) {
    final fits = ((room + gap) / (width + gap)).floor();
    return fits < 1 ? 1 : fits;
  }

  Widget _card(Metrics m, int index, double width) {
    final card = cards[index];

    return DraggableCard(
      card: card,
      child: TableCard(
        key: Key('hand-card-${card.id}'),
        metrics: m,
        instance: card,
        printing: printings[card.oracleId],
        width: width,
        onTap: () => onPlay(card),
        onLongPress: () => onInspect(card),
      ),
    );
  }

  /// Which place in the hand the card was let go over.
  ///
  /// The hand wraps, so the place is a line and a column rather than a
  /// distance along one row over one pitch. A short last line is centred like
  /// every other, so its columns are counted from where that line starts and
  /// not from the left of the widest one. A card let go past either end stops
  /// at the end rather than falling out of the hand.
  void _drop(
    CardInstance card,
    Offset at,
    double width,
    double gap,
    int perLine,
  ) {
    final from = cards.indexWhere((c) => c.id == card.id);
    if (from < 0) return;

    final pitch = width + gap;
    final lines = (cards.length / perLine).ceil();
    final line = (at.dy / (width * 88 / 63 + gap)).floor().clamp(0, lines - 1);

    final left = cards.length - line * perLine;
    final onLine = left < perLine ? left : perLine;
    final widest = perLine < cards.length ? perLine : cards.length;
    final indent = (widest - onLine) * pitch / 2;
    final column =
        ((at.dx - indent) / pitch).floor().clamp(0, onLine - 1);

    final to = line * perLine + column;
    if (to == from) return;
    onReorder(card.id, to);
  }
}
