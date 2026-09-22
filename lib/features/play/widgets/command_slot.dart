import 'package:flutter/material.dart';

import '../../../sources/model/catalog_card.dart';
import '../../../table/model/card_instance.dart';
import '../../../ui/tokens/metrics.dart';
import '../../../ui/tokens/palette.dart';
import 'card_drag.dart';
import 'table_card.dart';

/// The commander, out where everybody can see it.
///
/// A commander does not start in the deck and never goes back into it: the
/// table already puts it in its own zone before the first shuffle. This is the
/// corner it sits in, top right of your own mat, and it stays drawn even while
/// the commander is on the battlefield, because a corner that appears and
/// disappears reads as a bug rather than as a rule.
class CommandSlot extends StatelessWidget {
  const CommandSlot({
    super.key,
    required this.metrics,
    required this.cards,
    required this.printings,
    required this.width,
    required this.onTap,
    required this.onInspect,
    required this.onSendHome,
  });

  final Metrics metrics;
  final List<CardInstance> cards;
  final Map<String, CatalogCard> printings;
  final double width;
  final void Function(CardInstance) onTap;
  final void Function(CardInstance) onInspect;

  /// A card let go over the corner, whatever it is.
  ///
  /// A commander is not the only thing that belongs in a command zone:
  /// emblems and companions live there too and the app has no notion of
  /// either, so the corner takes any card rather than checking one against
  /// the deck. The player is the one who knows.
  final void Function(CardInstance) onSendHome;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return CardDropTarget(
      onDrop: (card, _) => onSendHome(card),
      child: _corner(m),
    );
  }

  Widget _corner(Metrics m) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Command',
            style: TextStyle(fontSize: m.scaled(10), color: Palette.inkFaint),
          ),
          SizedBox(height: m.scaled(4)),
          if (cards.isEmpty)
            Container(
              width: width,
              height: width * 88 / 63,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(width * 0.05),
                border: Border.all(color: Palette.tileEdge),
              ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final card in cards)
                  Padding(
                    padding: EdgeInsets.only(left: m.scaled(6)),
                    child: TableCard(
                      metrics: m,
                      instance: card,
                      printing: printings[card.oracleId],
                      width: width,
                      onTap: () => onTap(card),
                      onLongPress: () => onInspect(card),
                    ),
                  ),
              ],
            ),
        ],
      );
}
