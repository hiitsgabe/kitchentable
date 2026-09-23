import 'package:flutter/material.dart';

import '../../../sources/model/catalog_card.dart';
import '../../../table/model/card_instance.dart';
import '../../../ui/tokens/metrics.dart';
import '../../../ui/tokens/palette.dart';
import '../look_at_top.dart';
import 'sheet_parts.dart';

/// How many cards the two look buttons take off the top.
///
/// Scry 1 and scry 2 are most of Magic and five covers the rest of what
/// anybody does by hand, so this is two buttons rather than a number picker
/// that would be three taps for a number nobody changes.
const _aFewCards = 2;
const _severalCards = 5;

/// What the sheet is showing right now.
///
/// One widget with three faces rather than three routes, because backing out
/// of a shuffle has to land back on the choices and not on the table.
enum _Stage { choices, confirm, looking }

/// Everything you do to your own deck that is not drawing from it.
///
/// The sheet never holds the library. It is handed [peek], and the cards exist
/// only from the moment somebody asks to see them until the sheet closes,
/// which is the whole reason a library can stay hidden from its owner and this
/// can still work.
class DeckSheet extends StatefulWidget {
  const DeckSheet({
    super.key,
    required this.metrics,
    required this.count,
    required this.printings,
    required this.peek,
    required this.onShuffle,
    required this.onArrange,
  });

  final Metrics metrics;

  /// How many cards are in the deck. Only ever drawn and counted against, so
  /// the sheet can say it without being able to read the pile.
  final int count;

  final Map<String, CatalogCard> printings;

  /// The top [n] cards, or fewer if the deck is shorter.
  final Future<List<CardInstance>> Function(int) peek;

  final VoidCallback onShuffle;

  /// Every card that was looked at, in the order it is shown, whatever was
  /// done with it.
  final void Function(List<Placement>) onArrange;

  @override
  State<DeckSheet> createState() => _DeckSheetState();
}

class _DeckSheetState extends State<DeckSheet> {
  _Stage _stage = _Stage.choices;

  /// The cards off the top, in the order they came off.
  List<CardInstance> _looked = const [];

  /// Where each one is going. A card nobody touches is missing from here and
  /// goes back on top, which is why the sheet reads it with a default rather
  /// than filling it in when the cards arrive.
  final Map<String, Landing> _going = {};

  Future<void> _look(int n) async {
    final cards = await widget.peek(n);
    if (!mounted) return;
    setState(() {
      _looked = cards;
      _going.clear();
      _stage = _Stage.looking;
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.metrics;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(m.scaled(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: switch (_stage) {
            _Stage.choices => _choices(m),
            _Stage.confirm => _confirm(m),
            _Stage.looking => _looking(m),
          },
        ),
      ),
    );
  }

  List<Widget> _choices(Metrics m) => [
        SheetHeading(
          metrics: m,
          text: 'Your deck',
          note: '${widget.count} cards',
        ),
        SizedBox(height: m.scaled(14)),
        if (widget.count == 0)
          Text(
            'Nothing left to shuffle or look at.',
            style: TextStyle(fontSize: m.scaled(13), color: Palette.inkFaint),
          )
        else ...[
          SheetChoice(
            metrics: m,
            key: const Key('deck-shuffle'),
            icon: Icons.shuffle_rounded,
            label: 'Shuffle',
            onTap: () => setState(() => _stage = _Stage.confirm),
          ),
          SizedBox(height: m.scaled(10)),
          Row(
            children: [
              Expanded(
                child: SheetChoice(
                  metrics: m,
                  key: const Key('deck-look'),
                  icon: Icons.visibility_rounded,
                  label: 'Look at $_aFewCards',
                  onTap: () => _look(_aFewCards),
                ),
              ),
              SizedBox(width: m.scaled(10)),
              Expanded(
                child: SheetChoice(
                  metrics: m,
                  key: const Key('look-5'),
                  icon: Icons.visibility_rounded,
                  label: 'Look at $_severalCards',
                  onTap: () => _look(_severalCards),
                ),
              ),
            ],
          ),
        ],
      ];

  List<Widget> _confirm(Metrics m) => [
        SheetHeading(metrics: m, text: 'Shuffle the deck?'),
        SizedBox(height: m.scaled(8)),
        Text(
          'Whatever you have set up on top goes with it. This is the one '
          'thing here that looking cannot undo.',
          style: TextStyle(
            fontSize: m.scaled(13),
            height: 1.35,
            color: Palette.inkMuted,
          ),
        ),
        SizedBox(height: m.scaled(16)),
        Row(
          children: [
            Expanded(
              child: SheetChoice(
                metrics: m,
                key: const Key('cancel-shuffle'),
                icon: Icons.close_rounded,
                label: 'Not yet',
                onTap: () => setState(() => _stage = _Stage.choices),
              ),
            ),
            SizedBox(width: m.scaled(10)),
            Expanded(
              child: SheetChoice(
                metrics: m,
                key: const Key('confirm-shuffle'),
                icon: Icons.shuffle_rounded,
                label: 'Shuffle',
                loud: true,
                onTap: widget.onShuffle,
              ),
            ),
          ],
        ),
      ];

  List<Widget> _looking(Metrics m) => [
        SheetHeading(
          metrics: m,
          text: _looked.length == 1
              ? 'The top card'
              : 'The top ${_looked.length}',
          note: 'in the order they came off',
        ),
        SizedBox(height: m.scaled(12)),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final card in _looked) _row(m, card),
              ],
            ),
          ),
        ),
        SizedBox(height: m.scaled(4)),
        SheetChoice(
          metrics: m,
          key: const Key('deck-done'),
          icon: Icons.check_rounded,
          label: 'Done',
          loud: true,
          // Every card that was looked at, touched or not, because a card
          // left alone is a card going back on top and `arrange` reads the
          // order of the top pile out of this list.
          onTap: () => widget.onArrange([
            for (final card in _looked)
              (cardId: card.id, to: _going[card.id] ?? Landing.top),
          ]),
        ),
      ];

  Widget _row(Metrics m, CardInstance card) => CardRow(
        key: Key('peeked-${card.id}'),
        metrics: m,
        cardId: card.id,
        printing: widget.printings[card.oracleId],
        destinations: Landing.values,
        // A card nobody touched is going back on top, so the row opens with
        // the top already lit rather than with nothing lit.
        chosen: _going[card.id] ?? Landing.top,
        onChoose: (to) => setState(() => _going[card.id] = to),
      );
}

