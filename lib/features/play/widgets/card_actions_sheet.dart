import 'package:flutter/material.dart';

import '../../../sources/model/catalog_card.dart';
import '../../../table/model/card_instance.dart';
import '../../../ui/tokens/metrics.dart';
import 'sheet_parts.dart';

/// What can be done to a card on the battlefield, in a list.
///
/// A finger has a drag for every pile and a tap for the turn; a pad has
/// select, and select on a card asks this. One press, every verb reachable,
/// and nothing to remember, which is how Master Duel does it and the reason
/// a rules-free table needs it: the app cannot know what a card does, so it
/// asks what you want done with it. Tap is first, so select twice is the
/// turn, the thing done most.
enum CardMenuAction { tap, flip, toGraveyard, toHand, toTop, toBottom, look }

class CardActionsSheet extends StatelessWidget {
  const CardActionsSheet({
    super.key,
    required this.metrics,
    required this.card,
    required this.onAct,
    this.printing,
  });

  final Metrics metrics;
  final CardInstance card;
  final CatalogCard? printing;
  final void Function(CardMenuAction action) onAct;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final tapped = card.rotation != 0;

    Widget choice(
      Key key,
      IconData icon,
      String label,
      CardMenuAction action, {
      bool first = false,
    }) => Padding(
      padding: EdgeInsets.only(bottom: m.scaled(8)),
      child: SheetChoice(
        key: key,
        metrics: m,
        icon: icon,
        label: label,
        autofocus: first,
        onTap: () => onAct(action),
      ),
    );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          m.safeInset,
          m.scaled(14),
          m.safeInset,
          m.scaled(10),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetHeading(metrics: m, text: printing?.name ?? 'This card'),
              SizedBox(height: m.scaled(12)),
              choice(
                const Key('act-tap'),
                tapped ? Icons.rotate_left_rounded : Icons.rotate_right_rounded,
                tapped ? 'Untap' : 'Tap',
                CardMenuAction.tap,
                first: true,
              ),
              choice(
                const Key('act-flip'),
                Icons.flip_rounded,
                card.faceDown ? 'Turn face up' : 'Turn face down',
                CardMenuAction.flip,
              ),
              choice(
                const Key('act-look'),
                Icons.zoom_in_rounded,
                'Look, counters',
                CardMenuAction.look,
              ),
              choice(
                const Key('act-graveyard'),
                Icons.delete_outline_rounded,
                'To the graveyard',
                CardMenuAction.toGraveyard,
              ),
              choice(
                const Key('act-hand'),
                Icons.back_hand_outlined,
                'Back to hand',
                CardMenuAction.toHand,
              ),
              choice(
                const Key('act-top'),
                Icons.vertical_align_top_rounded,
                'Top of the library',
                CardMenuAction.toTop,
              ),
              choice(
                const Key('act-bottom'),
                Icons.vertical_align_bottom_rounded,
                'Bottom of the library',
                CardMenuAction.toBottom,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
