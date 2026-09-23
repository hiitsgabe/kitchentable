import 'dart:ui' show clampDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../sources/model/catalog_card.dart';
import '../../../table/model/card_instance.dart';
import '../../../ui/tokens/metrics.dart';
import '../../../ui/tokens/palette.dart';
import '../board_cursor.dart';
import '../renderers/mat_layout.dart';
import 'card_drag.dart';
import 'table_card.dart';

/// A pile as this widget draws it.
typedef BoardZone = ({String id, String label, List<CardInstance> cards});

/// Your own piles, walkable with a D-pad.
///
/// The keys are handled here and not through `Shortcuts` and `Actions`,
/// because `WidgetsApp.defaultActions` has no handler for `ActivateIntent` at
/// all: the intent is mapped and lands nowhere. That was already found once in
/// this project, on the menu row that would not answer a controller.
class CursorBoard extends StatefulWidget {
  const CursorBoard({
    super.key,
    required this.metrics,
    required this.zones,
    required this.printings,
    required this.onActivate,
    required this.onInspect,
    required this.onPlace,
    this.cardScale = 1,
  });

  final Metrics metrics;
  final List<BoardZone> zones;
  final Map<String, CatalogCard> printings;

  /// A press of select, on whatever the ring is around.
  final void Function(CardInstance) onActivate;
  final void Function(CardInstance) onInspect;

  /// Which pile a card was dropped on, and where on that pile's mat,
  /// normalized 0 to 1.
  ///
  /// The pile is named rather than read back off the card, because a card can
  /// arrive here from a hand, and then where it was is no guide at all to
  /// where it should go.
  final void Function(String zoneId, String cardId, double x, double y)
      onPlace;

  /// The player's own multiplier on the card size. One is the mat exactly as
  /// the layout drew it.
  final double cardScale;

  /// Which piles this board actually draws.
  ///
  /// The battlefield keeps its mat while there is nothing on it, because an
  /// empty mat is exactly where a card out of your hand has to land. A target
  /// that appears only once a card is already there could never take the
  /// first one.
  static List<BoardZone> _drawn(List<BoardZone> zones) => [
        for (final (i, zone) in zones.indexed)
          if (i == 0 || zone.cards.isNotEmpty) zone,
      ];

  /// What the label above a mat, the gap under it and the gap under the pile
  /// cost, for one pile.
  ///
  /// The label sits in a box of a known height rather than at whatever height
  /// the font comes out at, because the mat gets what is left after this and
  /// "what is left" has to be a number that can be worked out before anything
  /// is laid out.
  static double _chromeFor(Metrics m) =>
      m.scaled(14) + m.scaled(6) + m.scaled(12);

  /// The scale this board will draw its mats at, in a box this size.
  ///
  /// Said out loud so that whatever stands beside the board can be drawn to
  /// the same scale. The deck and the commander are cards off this table and
  /// have to be the size of the cards on it, and the alternative was for the
  /// screen to guess, which put the deck at 186 points beside a 99 point card
  /// on a 1900 by 900 window.
  static double scaleFor({
    required Size box,
    required List<BoardZone> zones,
    required Metrics metrics,
  }) {
    final piles = _drawn(zones).length;
    final share = piles == 0 ? 0.0 : box.height / piles;
    final chrome = _chromeFor(metrics);

    // Under its own label a pile has nothing left to draw the mat in and the
    // board scrolls instead, and then the height cannot run out. Infinity
    // says that to matScaleFor rather than a second branch saying it again.
    return matScaleFor(
      Size(box.width, share > chrome ? share - chrome : double.infinity),
    );
  }

  @override
  State<CursorBoard> createState() => _CursorBoardState();
}

class _CursorBoardState extends State<CursorBoard> {
  BoardCursor? _cursor;

  /// The card as this board lays it out. The whole size scales and not just
  /// the drawn width, so a bigger card is still centred on its own spot and
  /// still leaves a gap in the flow.
  Size get _cardSize => cardOnMat * widget.cardScale;

  List<CursorZone> get _sizes =>
      [for (final z in widget.zones) (id: z.id, size: z.cards.length)];

  @override
  void initState() {
    super.initState();
    _cursor = BoardCursor.start(_sizes);
  }

  @override
  void didUpdateWidget(CursorBoard old) {
    super.didUpdateWidget(old);
    // A card was played out of the pile the ring was on, so the index it held
    // may no longer exist. Re-clamping is what step(0) is for.
    final cursor = _cursor;
    _cursor = cursor == null
        ? BoardCursor.start(_sizes)
        : cursor.step(0, zones: _sizes);
  }

  CardInstance? get _under {
    final cursor = _cursor;
    if (cursor == null) return null;
    final zone = widget.zones.where((z) => z.id == cursor.zoneId).firstOrNull;
    if (zone == null || cursor.index >= zone.cards.length) return null;
    return zone.cards[cursor.index];
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final cursor = _cursor;
    if (cursor == null) return KeyEventResult.ignored;

    final key = event.logicalKey;
    BoardCursor? next;

    if (key == LogicalKeyboardKey.arrowRight) {
      next = cursor.step(1, zones: _sizes);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      next = cursor.step(-1, zones: _sizes);
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.gameButtonRight1) {
      next = cursor.changeZone(1, zones: _sizes);
    } else if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.gameButtonLeft1) {
      next = cursor.changeZone(-1, zones: _sizes);
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.gameButtonA) {
      final card = _under;
      if (card != null) widget.onActivate(card);
      return KeyEventResult.handled;
    } else {
      return KeyEventResult.ignored;
    }

    setState(() => _cursor = next);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final cursor = _cursor;
    final piles = CursorBoard._drawn(widget.zones);

    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Two piles do not each get the whole window and do not need to.
          // Each gets a share of it and each mat is scaled to its own share,
          // so both are whole and neither is cut off. A mat drawn smaller is
          // still the same shape, and the shape is what a drop means.
          final share = constraints.hasBoundedHeight
              ? constraints.maxHeight / piles.length
              : 0.0;

          // Under its own label a pile has no mat left to draw, and that
          // squeeze is not this widget's to fix: a phone in a pod hands the
          // board 28 points out of 844 and the rest went on the bands, the
          // hand and the bars. Then it scrolls, which is what it did before,
          // and each pile keeps the height the width alone gives it.
          if (share <= CursorBoard._chromeFor(widget.metrics)) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final zone in piles) _pile(zone, cursor, fits: false),
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final zone in piles)
                Expanded(child: _pile(zone, cursor, fits: true)),
            ],
          );
        },
      ),
    );
  }

  Widget _pile(BoardZone zone, BoardCursor? cursor, {required bool fits}) {
    final m = widget.metrics;

    final mat = LayoutBuilder(
      builder: (context, constraints) {
        // The mat keeps its shape whatever the window does, so a drag on a
        // phone and the same drag on a television land on the same
        // normalized spot. Only the scale moves.
        //
        // Scaled by width alone it was 1138 points tall on a 1917 point
        // window against a viewport of about 550: half your own battlefield
        // was below the fold, and a card parked there looked cut off rather
        // than scrolled away. Whichever of the two runs out first decides.
        // Scrolling, the height is infinite and the width is the only one
        // that can run out, which is the old arithmetic saying itself.
        final scale = matScaleFor(constraints.biggest);
        final size = matSize * scale;

        // The slack is real and it is not the mat's: a wide window has room
        // at the sides, a tall one above and below. Centred, that reads as a
        // table with room around it. It is also load bearing rather than
        // decoration: fitting hands this box a height it must not take, and
        // Center is what lets the mat be smaller than the box it is in.
        return Center(
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: CardDropTarget(
              onDrop: (card, at) => _drop(zone, card, at, scale),
              child: Stack(
                // The box a drop is measured against, and the one the test
                // measures it against too.
                key: Key('mat-${zone.id}'),
                children: [
                  if (zone.cards.isEmpty) _nothingHere(),
                  for (var i = 0; i < zone.cards.length; i++)
                    _card(zone, i, cursor, scale),
                ],
              ),
            ),
          ),
        );
      },
    );

    return Padding(
      padding: EdgeInsets.only(bottom: m.scaled(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: m.scaled(14),
            child: Text(
              zone.label,
              style:
                  TextStyle(fontSize: m.scaled(11), color: Palette.inkFaint),
            ),
          ),
          SizedBox(height: m.scaled(6)),
          if (fits) Expanded(child: mat) else mat,
        ],
      ),
    );
  }

  /// Said inside the mat rather than instead of it, so the words and the
  /// place a card can be put down are the same rectangle.
  Widget _nothingHere() => Positioned.fill(
        child: Center(
          child: Text(
            'Nothing on the battlefield',
            style: TextStyle(
              fontSize: widget.metrics.scaled(12),
              color: Palette.inkFaint,
            ),
          ),
        ),
      );

  Widget _card(BoardZone zone, int index, BoardCursor? cursor, double scale) {
    final m = widget.metrics;
    final card = zone.cards[index];
    final ringed =
        cursor != null && zone.id == cursor.zoneId && index == cursor.index;
    final spot = spotFor(
      position: card.position,
      index: index,
      card: _cardSize,
    );

    return Positioned(
      left: spot.dx * scale,
      top: spot.dy * scale,
      child: DraggableCard(
        card: card,
        child: Container(
          key: ringed ? Key('ring-${card.id}') : null,
          padding: EdgeInsets.all(m.focusRing),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(m.scaled(8)),
            border: Border.all(
              color: ringed ? Palette.accent : Colors.transparent,
              width: m.focusRing,
            ),
          ),
          child: TableCard(
            metrics: m,
            instance: card,
            printing: widget.printings[card.oracleId],
            width: _cardSize.width * scale,
            onTap: () => widget.onActivate(card),
            onLongPress: () => widget.onInspect(card),
            // A card on this board is drawn at the mat's scale, which on a
            // wide window is a couple of hundred points across. A preview of
            // one that big is unreadable and in the way of a drag. The long
            // press above still opens the real thing.
            hoverPreview: false,
          ),
        ),
      ),
    );
  }

  /// Where the pointer was let go, normalized against this mat.
  ///
  /// The card rides centred on the finger, so the pointer is the card's new
  /// centre, and spotFor centres a positioned card on the number it is given:
  /// the two are inverses, which is what stops a card walking on every drag.
  ///
  /// Divided by the scale first, because the mat is drawn at whatever width
  /// the board was given and a drop has to mean the same thing on a phone and
  /// on a television.
  void _drop(BoardZone zone, CardInstance card, Offset at, double scale) {
    final mat = at / scale;
    widget.onPlace(
      zone.id,
      card.id,
      clampDouble(mat.dx / matSize.width, 0, 1),
      clampDouble(mat.dy / matSize.height, 0, 1),
    );
  }
}
