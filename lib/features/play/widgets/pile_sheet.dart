import 'package:flutter/material.dart';

import '../../../sources/model/catalog_card.dart';
import '../../../table/model/card_instance.dart';
import '../../../ui/tokens/metrics.dart';
import '../../../ui/tokens/palette.dart';
import '../look_at_top.dart';
import 'sheet_parts.dart';

/// Where a card in the pile can be sent from here.
///
/// Three and not the four the deck sheet offers: a card in the graveyard is
/// already in the graveyard. These three are regrowth, a tutor that puts a
/// card back, and between them the two thirds of Magic's graveyard effects
/// that do one of those.
const _outOfThePile = [Landing.hand, Landing.top, Landing.bottom];

/// Looking through a pile that everybody can already see.
///
/// `DeckSheet`'s looking stage with no stages in front of it, and the
/// differences are all because a graveyard is not a library. It opens on the
/// cards, because there is nothing hidden to reveal. There is no shuffle. And
/// there is no default destination: in the deck sheet every card is going back
/// on top unless you say otherwise, and here a card nobody touched stays where
/// it is, so [onArrange] reports only what was moved.
class PileSheet extends StatefulWidget {
  const PileSheet({
    super.key,
    required this.metrics,
    required this.label,
    required this.cards,
    required this.printings,
    required this.onArrange,
  });

  final Metrics metrics;

  /// What the game calls the pile. The table has no opinion: `Graveyard` and
  /// `Discard` are the same thing wearing different words.
  final String label;

  /// Everything in it, which this sheet is allowed to hold because the pile is
  /// public. A library is the one that cannot be handed over like this.
  final List<CardInstance> cards;

  final Map<String, CatalogCard> printings;

  /// The cards that were moved, in the order they are shown, and nothing else.
  final void Function(List<Placement>) onArrange;

  @override
  State<PileSheet> createState() => _PileSheetState();
}

class _PileSheetState extends State<PileSheet> {
  /// Where each card is going. A card missing from here is a card staying
  /// where it is, which is why nothing fills this in when the sheet opens.
  final Map<String, Landing> _going = {};

  @override
  Widget build(BuildContext context) {
    final m = widget.metrics;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(m.scaled(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeading(
              metrics: m,
              text: widget.label,
              note: '${widget.cards.length} cards',
            ),
            SizedBox(height: m.scaled(12)),
            if (widget.cards.isEmpty)
              Text(
                'Nothing in the ${widget.label.toLowerCase()} yet.',
                style: TextStyle(
                  fontSize: m.scaled(13),
                  color: Palette.inkFaint,
                ),
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final card in widget.cards) _row(m, card),
                    ],
                  ),
                ),
              ),
            SizedBox(height: m.scaled(4)),
            SheetChoice(
              metrics: m,
              key: const Key('pile-done'),
              icon: Icons.check_rounded,
              label: 'Done',
              loud: true,
              // Only the cards somebody chose a place for. `arrange` emits a
              // move per placement it is handed, so a pile whose cards stay
              // put is a shorter list and not a flag.
              onTap: () => widget.onArrange([
                for (final card in widget.cards)
                  if (_going[card.id] case final to?)
                    (cardId: card.id, to: to),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(Metrics m, CardInstance card) => CardRow(
        key: Key('pile-card-${card.id}'),
        metrics: m,
        cardId: card.id,
        printing: widget.printings[card.oracleId],
        destinations: _outOfThePile,
        chosen: _going[card.id],
        onChoose: (to) => setState(() => _going[card.id] = to),
      );
}
