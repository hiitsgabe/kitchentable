import 'package:flutter/material.dart';

import '../../../sources/model/catalog_card.dart';
import '../../../ui/atoms/card_art.dart';
import '../../../ui/tokens/metrics.dart';
import '../../../ui/tokens/palette.dart';
import '../look_at_top.dart';

/// The parts a sheet that looks through a pile is made of.
///
/// Here rather than in either sheet because there are two of them now, and
/// they are two only in what they offer: the deck sheet has four destinations
/// and a default, and the graveyard has three and none. Everything else, the
/// heading, the wide buttons, and the row of a card and the places it can go,
/// is one thing written once. Copied, the row is what would stop looking alike
/// first: it is the part that changes whenever a destination is added.

/// The word on each destination button. `Landing.graveyard` is the game's
/// word for the pile and `Grave` is what fits, which is the only reason this
/// is a table and not `to.name`.
const landingLabels = {
  Landing.top: 'Top',
  Landing.bottom: 'Bottom',
  Landing.graveyard: 'Grave',
  Landing.hand: 'Hand',
};

class SheetHeading extends StatelessWidget {
  const SheetHeading({
    super.key,
    required this.metrics,
    required this.text,
    this.note,
  });

  final Metrics metrics;
  final String text;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final aside = note;

    return Row(
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: m.scaled(16),
            fontWeight: FontWeight.w700,
            color: Palette.ink,
          ),
        ),
        if (aside != null) ...[
          SizedBox(width: m.scaled(10)),
          Expanded(
            child: Text(
              aside,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  TextStyle(fontSize: m.scaled(12), color: Palette.inkFaint),
            ),
          ),
        ],
      ],
    );
  }
}

/// One thing you can do, drawn wide enough to hit without looking.
class SheetChoice extends StatelessWidget {
  const SheetChoice({
    super.key,
    required this.metrics,
    required this.icon,
    required this.label,
    required this.onTap,
    this.loud = false,
  });

  final Metrics metrics;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// The one the sheet is expecting, filled in pink.
  final bool loud;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: m.scaled(12)),
        decoration: BoxDecoration(
          color: loud ? Palette.accent : Palette.tile,
          borderRadius: BorderRadius.circular(m.scaled(10)),
          border: Border.all(
            color: loud ? Palette.accent : Palette.tileEdge,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: m.scaled(17),
              color: loud ? Colors.black : Palette.inkMuted,
            ),
            SizedBox(width: m.scaled(8)),
            Text(
              label,
              style: TextStyle(
                fontSize: m.scaled(13),
                fontWeight: FontWeight.w600,
                color: loud ? Colors.black : Palette.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One card, and the places its owner can send it from here.
class CardRow extends StatelessWidget {
  const CardRow({
    super.key,
    required this.metrics,
    required this.cardId,
    required this.printing,
    required this.destinations,
    required this.chosen,
    required this.onChoose,
  });

  final Metrics metrics;

  /// Named here and not read off a `CardInstance`, because the button keys are
  /// built from it and a caller aiming a tap at one knows the id and not the
  /// card.
  final String cardId;

  final CatalogCard? printing;

  /// Where this card may go, in the order the buttons are drawn.
  final List<Landing> destinations;

  /// Where it is going now. Null lights nothing, which is a pile whose cards
  /// stay where they are unless somebody says otherwise; the deck sheet hands
  /// this the top, because a card left alone there is going back on top.
  final Landing? chosen;

  final void Function(Landing) onChoose;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final art = printing;

    return Container(
      margin: EdgeInsets.only(bottom: m.scaled(8)),
      padding: EdgeInsets.all(m.scaled(8)),
      decoration: BoxDecoration(
        color: Palette.tile,
        borderRadius: BorderRadius.circular(m.scaled(10)),
        border: Border.all(color: Palette.tileEdge),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (art == null)
            CardBack(width: m.scaled(38))
          else
            CardArt(metrics: m, card: art, width: m.scaled(38)),
          SizedBox(width: m.scaled(10)),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  art?.name ?? 'A card',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: m.scaled(13),
                    fontWeight: FontWeight.w600,
                    color: Palette.ink,
                  ),
                ),
                SizedBox(height: m.scaled(8)),
                // Equal shares of whatever width is left rather than buttons
                // as wide as their words, because `Bottom` and `Top` together
                // are half a pixel over on a 390 point phone and that is a
                // rendering error, not a squeeze.
                Row(
                  children: [
                    for (final to in destinations) ...[
                      Expanded(
                        child: _Where(
                          metrics: m,
                          key: Key('${to.name}-$cardId'),
                          label: landingLabels[to]!,
                          chosen: to == chosen,
                          onTap: () => onChoose(to),
                        ),
                      ),
                      if (to != destinations.last)
                        SizedBox(width: m.scaled(6)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Where one card is going. A row of these, at most one of them lit.
class _Where extends StatelessWidget {
  const _Where({
    super.key,
    required this.metrics,
    required this.label,
    required this.chosen,
    required this.onTap,
  });

  final Metrics metrics;
  final String label;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: m.scaled(8),
          vertical: m.scaled(6),
        ),
        decoration: BoxDecoration(
          color: chosen ? Palette.tileFocused : Palette.surface,
          borderRadius: BorderRadius.circular(m.scaled(8)),
          border: Border.all(
            color: chosen ? Palette.accent : Palette.surfaceEdge,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: m.scaled(11),
            fontWeight: chosen ? FontWeight.w700 : FontWeight.w500,
            color: chosen ? Palette.ink : Palette.inkMuted,
          ),
        ),
      ),
    );
  }
}
