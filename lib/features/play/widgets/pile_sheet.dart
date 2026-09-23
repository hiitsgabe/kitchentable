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

/// How many rows a page holds.
///
/// Fifteen and not six, which is what a 390 by 844 phone fits without
/// scrolling: a graveyard of thirty is two pages at fifteen and five at six,
/// and turning five pages to find a card is its own kind of lost. A page still
/// scrolls on a short window, which is why the rows keep their scroll view.
const _pageSize = 15;

class _PileSheetState extends State<PileSheet> {
  /// Where each card is going. A card missing from here is a card staying
  /// where it is, which is why nothing fills this in when the sheet opens.
  ///
  /// Keyed by card id and living here rather than on the page, which is what
  /// makes a choice survive turning one: the page is a window on the pile and
  /// the pile is what was asked about.
  final Map<String, Landing> _going = {};

  /// Which page is showing, counted from nought.
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final m = widget.metrics;
    final pages = (widget.cards.length / _pageSize).ceil();
    // A pile that shrank under a page somebody had turned to. Clamped rather
    // than reset, so throwing one card away does not send you back to the
    // front of a hundred card graveyard.
    final page = pages == 0 ? 0 : _page.clamp(0, pages - 1);
    final showing = widget.cards.skip(page * _pageSize).take(_pageSize);

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
                      for (final card in showing) _row(m, card),
                    ],
                  ),
                ),
              ),
            if (pages > 1) _pager(m, page: page, pages: pages),
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

  /// Which page this is, with the way to the ones either side of it.
  ///
  /// A button only where there is somewhere to go, rather than a pair with one
  /// of them greyed: [SheetChoice] has no off state and inventing one to say
  /// "the pile ends here" is a word the page number already says.
  Widget _pager(Metrics m, {required int page, required int pages}) => Padding(
        padding: EdgeInsets.only(top: m.scaled(4)),
        child: Row(
          children: [
            if (page > 0)
              Expanded(
                child: SheetChoice(
                  metrics: m,
                  key: const Key('pile-back'),
                  icon: Icons.chevron_left_rounded,
                  label: 'Back',
                  onTap: () => setState(() => _page = page - 1),
                ),
              ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: m.scaled(10)),
              child: Text(
                '${page + 1} of $pages',
                style: TextStyle(
                  fontSize: m.scaled(13),
                  color: Palette.inkMuted,
                ),
              ),
            ),
            if (page < pages - 1)
              Expanded(
                child: SheetChoice(
                  metrics: m,
                  key: const Key('pile-next'),
                  icon: Icons.chevron_right_rounded,
                  label: 'Next',
                  onTap: () => setState(() => _page = page + 1),
                ),
              ),
          ],
        ),
      );

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
