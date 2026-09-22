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

/// The same card size the canvas uses, so both renderers place alike.
const _cardOnMat = Size(90, 90 * 88 / 63);

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

  /// Where a card was dropped, normalized 0 to 1 against this mat.
  final void Function(String cardId, double x, double y) onPlace;

  /// The player's own multiplier on the card size. One is the mat exactly as
  /// the layout drew it.
  final double cardScale;

  @override
  State<CursorBoard> createState() => _CursorBoardState();
}

class _CursorBoardState extends State<CursorBoard> {
  BoardCursor? _cursor;

  /// The card as this board lays it out. The whole size scales and not just
  /// the drawn width, so a bigger card is still centred on its own spot and
  /// still leaves a gap in the flow.
  Size get _cardSize => _cardOnMat * widget.cardScale;

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
    final m = widget.metrics;
    final cursor = _cursor;

    if (cursor == null) {
      return Center(
        child: Text(
          'Nothing on the battlefield',
          style: TextStyle(fontSize: m.scaled(12), color: Palette.inkFaint),
        ),
      );
    }

    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final zone in widget.zones)
              if (zone.cards.isNotEmpty) _pile(zone, cursor),
          ],
        ),
      ),
    );
  }

  Widget _pile(BoardZone zone, BoardCursor cursor) {
    final m = widget.metrics;

    return Padding(
      padding: EdgeInsets.only(bottom: m.scaled(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            zone.label,
            style: TextStyle(fontSize: m.scaled(11), color: Palette.inkFaint),
          ),
          SizedBox(height: m.scaled(6)),
          LayoutBuilder(
            builder: (context, constraints) {
              // The mat keeps its shape whatever the window does, so a drag
              // on a phone and the same drag on a television land on the same
              // normalized spot.
              final scale = constraints.maxWidth / matSize.width;
              return SizedBox(
                width: constraints.maxWidth,
                height: matSize.height * scale,
                child: CardDropTarget(
                  onDrop: (card, at) => _drop(card, at, scale),
                  child: Stack(
                    // The box a drop is measured against, and the one the
                    // test measures it against too.
                    key: Key('mat-${zone.id}'),
                    children: [
                      for (var i = 0; i < zone.cards.length; i++)
                        _card(zone, i, cursor, scale),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _card(BoardZone zone, int index, BoardCursor cursor, double scale) {
    final m = widget.metrics;
    final card = zone.cards[index];
    final ringed = zone.id == cursor.zoneId && index == cursor.index;
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
  void _drop(CardInstance card, Offset at, double scale) {
    final mat = at / scale;
    widget.onPlace(
      card.id,
      clampDouble(mat.dx / matSize.width, 0, 1),
      clampDouble(mat.dy / matSize.height, 0, 1),
    );
  }
}
