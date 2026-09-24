import 'package:flutter/material.dart';

import '../../../decks/model/game.dart';
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

/// How much of the cards a hand shows while it is shut, before scaling.
///
/// The whole strip is one tap target, and 34 is the smallest thing this app
/// asks a thumb for anywhere: every pill in the top bar is 34 square. It is
/// also enough of a card to tell two of them apart, which is the whole of what
/// a peek is for. At the width a phone's hand draws a card, 50.3, a card is
/// 70.3 tall and the art box of a Magic card ends 46 percent down it, so 34
/// points is the name and all of the picture.
const _peekHeight = 34.0;

/// The bar you tap to put an open hand down, before scaling.
const _handleHeight = 22.0;

/// The widest a card in the hand is ever drawn, while the hand fits.
///
/// A ceiling and not a size. The hand draws at whatever the board under it
/// draws at, and this is the point past which it stops following: a line is
/// [_lineHeight] tall and a card wider than this does not fit in one, and a
/// hand drawn at a television's card size would take the board's screen to
/// show you seven cards you are only choosing between.
const _cardWidth = 64.0;

/// The share of the screen a hand standing at its full height is worth.
///
/// Past this it peeks instead and comes up on a tap. A fifth, because that is
/// where the two windows this has to tell apart fall either side: seven cards
/// at 64 points wrap onto two lines on a 358 point phone, 198 points of an 844
/// point screen at 23 percent, and stand on one line on a desktop at 96 points
/// of 900 at 11 percent.
const _worthStandingUp = 0.2;

/// How many cards of this width fit across, never fewer than one.
int _perLineFor(double room, double width, double gap) {
  final fits = ((room + gap) / (width + gap)).floor();
  return fits < 1 ? 1 : fits;
}

/// Whether standing this hand up costs more of the screen than it is worth.
///
/// The peek was written for a phone and shipped on every window, which put a
/// strip with the top thirty points of seven cards showing on a 1909 by 989
/// desktop with room for all of it. A phone's answer is not a smaller version
/// of the right answer.
///
/// Neither a width test nor a height test, because a phone is expensive both
/// ways round and for different reasons: held upright the hand wraps onto a
/// second line and costs 198 of 844 points, and held sideways it needs only
/// one line and that line is a quarter of the 390 points there are. What both
/// have in common is the share, so the share is what this asks, and the height
/// it asks about comes out of the same arithmetic the hand lays itself out
/// with rather than an estimate standing beside it.
///
/// An empty hand is never expensive: there is nothing to stand up.
bool handIsExpensive(
  Size screen,
  Metrics m, {
  required double room,
  required double card,
  required int cards,
}) {
  if (cards == 0) return false;

  final gap = m.scaled(6);
  final ceiling = m.scaled(_cardWidth);
  final width = card < ceiling ? card : ceiling;

  var lines = (cards / _perLineFor(room, width, gap)).ceil();
  if (lines > _mostLines) lines = _mostLines;

  return lines * m.scaled(_lineHeight) + (lines - 1) * gap >
      screen.height * _worthStandingUp;
}

/// The hand, along the bottom, peeking until you ask for it.
///
/// Shut it is a strip of the tops of the cards, and one tap target: 55 points
/// of a phone rather than the 117 it took at all times so that it could be
/// ready. Open it is the hand as it has always been drawn, wrapped onto as
/// many lines as it needs, and it takes that room from the board underneath it
/// for as long as you are choosing.
///
/// It still sits below the board and never on top of it. Arena opens its phone
/// hand into a fan across the battlefield; the room an open hand here takes
/// comes out of the board's height instead, so the board is shorter rather
/// than covered, and what is left of it is still yours to look at.
class HandSheet extends StatefulWidget {
  const HandSheet({
    super.key,
    required this.metrics,
    required this.cards,
    required this.printings,
    required this.onPlay,
    required this.onInspect,
    required this.onReorder,
    this.cardWidth,
    this.game,
    this.startsOpen = false,
  });

  final Metrics metrics;

  /// What the board this hand sits under draws a card at.
  ///
  /// The hand draws at that, up to [_cardWidth]. A card in your hand was
  /// twice the same card on the table on a phone, 64 against 32.19, because
  /// this was a point size of its own and the board's came out of whatever
  /// space was left over: nothing made them disagree and nothing stopped them
  /// either.
  ///
  /// Null keeps the ceiling, which is the canvas: the card on that surface is
  /// a zoom away from any point size at all, and a hand on a narrow window
  /// there is a job of its own.
  final double? cardWidth;
  final List<CardInstance> cards;
  final Map<String, CatalogCard> printings;
  final void Function(CardInstance) onPlay;
  final void Function(CardInstance) onInspect;

  /// Where a card was dragged to, as a place in the hand.
  final void Function(String cardId, int to) onReorder;

  /// Whose cards these are, so a card held face down is held face down onto
  /// the right back.
  final Game? game;

  /// Whether it starts open rather than peeking.
  ///
  /// Shut on the screen, which is the whole point of the strip. Open is what a
  /// harness that is about how the cards inside it lay out wants, and there is
  /// nothing about that arithmetic a closed hand could show it.
  final bool startsOpen;

  @override
  State<HandSheet> createState() => _HandSheetState();
}

class _HandSheetState extends State<HandSheet> {
  late bool _open = widget.startsOpen;

  void _toggle() => setState(() => _open = !_open);

  /// Playing a card from an open hand puts the hand down with it.
  ///
  /// Otherwise you drop a card onto a board that is half the height it was and
  /// then go looking for the card, which is worse than the strip ever was.
  void _play(CardInstance card) {
    if (_open) setState(() => _open = false);
    widget.onPlay(card);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.metrics;

    return Container(
      padding: EdgeInsets.symmetric(vertical: m.scaled(10)),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Palette.rule)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _open
            ? [
                _handle(m),
                SizedBox(height: m.scaled(6)),
                _hand(m, m.scaled(_lineHeight)),
              ]
            : [_peek(m)],
      ),
    );
  }

  /// The strip: the tops of the cards, and nothing in it you can hit but the
  /// strip itself.
  ///
  /// The cards are drawn at their own size and cropped, not squashed into the
  /// strip: a card squashed out of its 63 by 88 is the one thing on a table
  /// that reads as broken. They take no taps while they are cropped, because a
  /// tap here is for the hand and not for the card whose corner it landed on.
  Widget _peek(Metrics m) {
    final peek = m.scaled(_peekHeight);

    return GestureDetector(
      key: const Key('hand-handle'),
      onTap: _toggle,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: peek,
        child: widget.cards.isEmpty
            ? _nothingInHand(m, peek)
            : ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topCenter,
                  maxHeight: double.infinity,
                  child: IgnorePointer(child: _cards(m)),
                ),
              ),
      ),
    );
  }

  /// The bar that puts it down again. A hand you cannot put down is worse than
  /// one that never moved.
  Widget _handle(Metrics m) => GestureDetector(
        key: const Key('hand-handle'),
        onTap: _toggle,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: m.scaled(_handleHeight),
          child: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: m.scaled(20),
            color: Palette.inkMuted,
          ),
        ),
      );

  Widget _hand(Metrics m, double emptyHeight) =>
      widget.cards.isEmpty ? _nothingInHand(m, emptyHeight) : _cards(m);

  Widget _nothingInHand(Metrics m, double height) => SizedBox(
        height: height,
        child: Center(
          child: Text(
            'No cards in hand',
            style: TextStyle(fontSize: m.scaled(12), color: Palette.inkFaint),
          ),
        ),
      );

  Widget _cards(Metrics m) {
    final gap = m.scaled(6);
    final ceiling = m.scaled(_cardWidth);
    final asked = widget.cardWidth ?? ceiling;
    final full = asked < ceiling ? asked : ceiling;

    return LayoutBuilder(
      builder: (context, constraints) {
        final room = constraints.maxWidth;
        var perLine = _perLineFor(room, full, gap);
        var lines = (widget.cards.length / perLine).ceil();
        var width = full;

        // A hand of sixty is a Battle of Wits deck and it still cannot be
        // allowed to eat the battlefield. Past the cap the whole hand is
        // squeezed onto the lines there are rather than asking for another.
        if (lines > _mostLines) {
          lines = _mostLines;
          perLine = (widget.cards.length / _mostLines).ceil();
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
                  for (var i = 0; i < widget.cards.length; i++)
                    _card(m, i, width),
                ],
              ),
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
        game: widget.game,
        onTap: () => _play(card),
        onLongPress: () => widget.onInspect(card),
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
    final cards = widget.cards;
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
    widget.onReorder(card.id, to);
  }
}
