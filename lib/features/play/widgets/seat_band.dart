import 'package:flutter/material.dart';

import '../../../decks/model/game.dart';
import '../../../sources/model/catalog_card.dart';
import '../../../table/view/seat_view.dart';
import '../../../ui/tokens/metrics.dart';
import '../../../ui/tokens/palette.dart';
import 'table_card.dart';

/// One seat, compressed: who they are, how much life, how many cards they are
/// holding, and what they have on the battlefield.
///
/// It takes a [SeatView] and not a `Seat`, which is the whole point. A card
/// this viewer may not see never arrives, so there is nothing in the widget
/// tree to read off, screenshot, or accidentally draw.
class SeatBand extends StatelessWidget {
  const SeatBand({
    super.key,
    required this.metrics,
    required this.seat,
    required this.printings,
    required this.onTap,
    this.isTurn = false,
    this.focused = false,
    this.game,
  });

  final Metrics metrics;
  final SeatView seat;

  /// Printings for whatever is on their battlefield. A card the catalog has
  /// never heard of draws as a back, which [TableCard] already handles.
  final Map<String, CatalogCard> printings;

  final VoidCallback onTap;
  final bool isTurn;
  final bool focused;

  /// The game this seat is playing, which is not necessarily the viewer's: the
  /// back on a face down card belongs to whoever turned it over.
  final Game? game;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final board = seat.pile('battlefield');
    final hand = seat.pile('hand');

    return GestureDetector(
      key: Key('band-${seat.seatId}'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: EdgeInsets.only(bottom: m.scaled(8)),
        padding: EdgeInsets.all(m.scaled(10)),
        decoration: BoxDecoration(
          color: focused ? Palette.tileFocused : Palette.tile,
          borderRadius: BorderRadius.circular(m.scaled(10)),
          border: Border.all(
            color: isTurn ? Palette.accent : Palette.tileEdge,
            width: isTurn ? m.focusRing : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    seat.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: m.scaled(13), color: Palette.ink),
                  ),
                ),
                // The count and not the cards. At a real table everybody can
                // see how many somebody is holding and nobody can see which.
                Text(
                  'hand ${hand?.count ?? 0}',
                  style: TextStyle(
                    fontSize: m.scaled(11),
                    color: Palette.inkFaint,
                  ),
                ),
                SizedBox(width: m.scaled(12)),
                Text(
                  '${seat.life}',
                  style: TextStyle(
                    fontSize: m.scaled(18),
                    fontWeight: FontWeight.w700,
                    color: seat.life <= 0 ? Palette.attention : Palette.ink,
                  ),
                ),
              ],
            ),
            SizedBox(height: m.scaled(8)),
            SizedBox(
              height: m.scaled(58),
              child: board == null || board.cards.isEmpty
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'nothing out',
                        style: TextStyle(
                          fontSize: m.scaled(11),
                          color: Palette.inkFaint,
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final card in board.cards)
                            Padding(
                              padding: EdgeInsets.only(right: m.scaled(6)),
                              child: TableCard(
                                metrics: m,
                                instance: card,
                                printing: printings[card.oracleId],
                                width: m.scaled(40),
                                game: game,
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
