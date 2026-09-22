import 'package:flutter/material.dart';

import '../../../sources/model/catalog_card.dart';
import '../../../table/model/card_instance.dart';
import '../../../ui/tokens/metrics.dart';
import '../../../ui/tokens/palette.dart';
import 'table_card.dart';

/// The hand, along the bottom, scrolling sideways.
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
  });

  final Metrics metrics;
  final List<CardInstance> cards;
  final Map<String, CatalogCard> printings;
  final void Function(CardInstance) onPlay;
  final void Function(CardInstance) onInspect;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return Container(
      padding: EdgeInsets.symmetric(vertical: m.scaled(10)),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Palette.rule)),
      ),
      child: SizedBox(
        height: m.scaled(96),
        child: cards.isEmpty
            ? Center(
                child: Text(
                  'No cards in hand',
                  style:
                      TextStyle(fontSize: m.scaled(12), color: Palette.inkFaint),
                ),
              )
            : ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: cards.length,
                separatorBuilder: (_, _) => SizedBox(width: m.scaled(6)),
                itemBuilder: (_, i) => TableCard(
                  metrics: m,
                  instance: cards[i],
                  printing: printings[cards[i].oracleId],
                  width: m.scaled(64),
                  onTap: () => onPlay(cards[i]),
                  onLongPress: () => onInspect(cards[i]),
                ),
              ),
      ),
    );
  }
}
