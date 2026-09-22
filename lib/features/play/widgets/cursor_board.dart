import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../sources/model/catalog_card.dart';
import '../../../table/model/card_instance.dart';
import '../../../ui/tokens/metrics.dart';
import '../../../ui/tokens/palette.dart';
import '../board_cursor.dart';
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
  });

  final Metrics metrics;
  final List<BoardZone> zones;
  final Map<String, CatalogCard> printings;

  /// A press of select, on whatever the ring is around.
  final void Function(CardInstance) onActivate;
  final void Function(CardInstance) onInspect;

  @override
  State<CursorBoard> createState() => _CursorBoardState();
}

class _CursorBoardState extends State<CursorBoard> {
  BoardCursor? _cursor;

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
          Wrap(
            spacing: m.scaled(8),
            runSpacing: m.scaled(10),
            children: [
              for (var i = 0; i < zone.cards.length; i++)
                _card(zone, i, cursor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _card(BoardZone zone, int index, BoardCursor cursor) {
    final m = widget.metrics;
    final card = zone.cards[index];
    final ringed = zone.id == cursor.zoneId && index == cursor.index;

    return Container(
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
        width: m.scaled(70),
        onTap: () => widget.onActivate(card),
        onLongPress: () => widget.onInspect(card),
      ),
    );
  }
}
