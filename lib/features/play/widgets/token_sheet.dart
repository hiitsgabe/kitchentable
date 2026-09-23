import 'package:flutter/material.dart';

import '../../../sources/model/catalog_card.dart';
import '../../../ui/atoms/card_art.dart';
import '../../../ui/atoms/text_field_box.dart';
import '../../../ui/tokens/metrics.dart';
import '../../../ui/tokens/palette.dart';
import 'sheet_parts.dart';

/// Finding a card to make a token out of.
///
/// A token is made out of a card and never invented, because a `CardInstance`
/// carries an oracle id and nothing else: a token whose oracle id is in no
/// catalog draws as a blank back with no name on it, which is worse than no
/// token at all. Scryfall's bulk data carries real token cards, so `Goblin`
/// and `Treasure` are findable by anybody who imported them.
///
/// The text field and the rows follow the deck builder's search screen rather
/// than inventing an idiom, and the search itself is handed in: this sheet
/// does not know the catalog, which is what lets it be opened over a table
/// and tested without a database.
class TokenSheet extends StatefulWidget {
  const TokenSheet({
    super.key,
    required this.metrics,
    required this.search,
    required this.onPick,
  });

  final Metrics metrics;

  /// Whatever the catalog has by that name. Handed in rather than read off a
  /// provider so the sheet has one job.
  final Future<List<CatalogCard>> Function(String) search;

  final void Function(CatalogCard) onPick;

  @override
  State<TokenSheet> createState() => _TokenSheetState();
}

class _TokenSheetState extends State<TokenSheet> {
  final _controller = TextEditingController();
  List<CatalogCard> _results = const [];

  /// The term the rows on screen belong to, empty until something has been
  /// looked for. It is what tells a sheet nobody has typed in apart from a
  /// search that came back with nothing: the first is quiet and the second
  /// says so out loud.
  String _searched = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Not debounced, unlike the deck builder's screen, and that is the whole
  /// difference between the two. There, somebody scrolls a long list of
  /// printings and keeps typing, so a query per keystroke over 36000 rows is
  /// paid dozens of times. Here a token has a short name that is typed once
  /// and picked, and the floor of two letters already keeps `g` from matching
  /// most of the catalog.
  Future<void> _search(String term) async {
    final wanted = term.trim();
    if (wanted.length < 2) {
      setState(() {
        _results = const [];
        _searched = '';
      });
      return;
    }

    final found = await widget.search(wanted);
    // The term can have moved on while this was in flight, and an older
    // search landing last would leave the wrong list under the new word.
    if (!mounted || _controller.text.trim() != wanted) return;
    setState(() {
      _results = found;
      _searched = wanted;
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
          children: [
            SheetHeading(
              metrics: m,
              text: 'Make a token',
              note: 'out of a card in the catalog',
            ),
            SizedBox(height: m.scaled(12)),
            TextFieldBox(
              metrics: m,
              controller: _controller,
              autofocus: true,
              hint: 'Goblin, Treasure, Clue',
              onChanged: _search,
            ),
            SizedBox(height: m.scaled(12)),
            if (_results.isEmpty && _searched.isNotEmpty)
              Text(
                'Nothing by that name in the catalog. Tokens come in with '
                'the cards, so importing a source again is the fix.',
                style: TextStyle(
                  fontSize: m.scaled(12),
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
                      for (final card in _results)
                        _TokenRow(
                          metrics: m,
                          key: Key('token-${card.name}'),
                          card: card,
                          onTap: () => widget.onPick(card),
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

/// One card the token could be made out of.
class _TokenRow extends StatelessWidget {
  const _TokenRow({
    super.key,
    required this.metrics,
    required this.card,
    required this.onTap,
  });

  final Metrics metrics;
  final CatalogCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: EdgeInsets.only(bottom: m.scaled(8)),
        padding: EdgeInsets.all(m.scaled(8)),
        decoration: BoxDecoration(
          color: Palette.tile,
          borderRadius: BorderRadius.circular(m.scaled(10)),
          border: Border.all(color: Palette.tileEdge),
        ),
        child: Row(
          children: [
            // The picture, because half of recognising the right token is
            // recognising the art, the same reason the deck builder draws one.
            CardArt(metrics: m, card: card, width: m.scaled(38)),
            SizedBox(width: m.scaled(10)),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: m.scaled(13),
                      fontWeight: FontWeight.w600,
                      color: Palette.ink,
                    ),
                  ),
                  SizedBox(height: m.scaled(2)),
                  Text(
                    card.typeLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: m.scaled(11),
                      color: Palette.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.add_rounded,
              size: m.scaled(20),
              color: Palette.inkMuted,
            ),
          ],
        ),
      ),
    );
  }
}
