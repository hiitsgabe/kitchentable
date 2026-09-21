import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../decks/model/deck.dart';
import '../../sources/model/catalog_card.dart';
import '../../ui/atoms/card_art.dart';
import '../../ui/atoms/hint_bar.dart';
import '../../ui/atoms/text_field_box.dart';
import '../../ui/organisms/screen_frame.dart';
import '../../ui/tokens/metrics.dart';
import '../../ui/tokens/palette.dart';
import '../menu/menu_controller.dart';
import 'decks_controller.dart';

class AddCardsScreen extends ConsumerStatefulWidget {
  const AddCardsScreen({super.key});

  @override
  ConsumerState<AddCardsScreen> createState() => _AddCardsScreenState();
}

class _AddCardsScreenState extends ConsumerState<AddCardsScreen> {
  final _controller = TextEditingController();
  List<CatalogCard> _results = const [];
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _search(String term) {
    // The catalog is 36000 rows and a LIKE over it runs on every keystroke
    // otherwise. A third of a second is long enough to finish a word.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final db = ref.read(catalogDbProvider);
      if (db == null || term.trim().length < 2) {
        if (mounted) setState(() => _results = const []);
        return;
      }
      final found = await db.searchByName(term.trim());
      if (mounted) setState(() => _results = found);
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final m = Metrics.of(classifyDevice(
      size: media.size,
      hasTouch: media.navigationMode == NavigationMode.traditional,
    ));
    final deck = ref.watch(deckEditorProvider);

    return ScreenFrame(
      metrics: m,
      title: 'Add cards',
      label: deck == null
          ? 'no deck open'
          : '${deck.format.label} · ${deck.mainCount} of ${deck.format.deckSize}',
      onBack: () => Navigator.of(context).maybePop(),
      hints: const [
        Hint(button: HintBar.dpad, label: 'move'),
        Hint(button: 'A', label: 'add one'),
        Hint(button: 'B', label: 'back'),
      ],
      children: [
        TextFieldBox(
          metrics: m,
          controller: _controller,
          autofocus: true,
          hint: 'Search the catalog',
          onChanged: _search,
        ),
        SizedBox(height: m.scaled(14)),
        if (deck != null)
          for (final card in _results)
            _CardRow(metrics: m, card: card, deck: deck),
        if (_results.isEmpty && _controller.text.trim().length >= 2)
          Text(
            'Nothing by that name.',
            style: TextStyle(fontSize: m.scaled(12), color: Palette.inkFaint),
          ),
      ],
    );
  }
}

class _CardRow extends ConsumerWidget {
  const _CardRow({
    required this.metrics,
    required this.card,
    required this.deck,
  });

  final Metrics metrics;
  final CatalogCard card;
  final Deck deck;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = metrics;
    final complaint = complainAbout(deck, card);
    final have = deck.totalCopiesOf(card.oracleId);
    final blocked = complaint?.blocking ?? false;

    return Opacity(
      opacity: blocked ? 0.45 : 1,
      child: GestureDetector(
        onTap: blocked
            ? null
            : () => ref
                .read(deckEditorProvider.notifier)
                .add(DeckSlot(card: card, quantity: 1)),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: m.scaled(8)),
          child: Row(
            children: [
              // The picture is the point of this row. A name alone tells you
              // nothing about whether it is the card you meant, and half of
              // Magic is people recognising art before they read anything.
              Stack(
                children: [
                  CardArt(metrics: m, card: card, width: m.scaled(46)),
                  if (have > 0)
                    Positioned(
                      left: 0,
                      top: 0,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: m.scaled(5),
                          vertical: m.scaled(1),
                        ),
                        decoration: BoxDecoration(
                          color: Palette.accent,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(m.scaled(3)),
                            bottomRight: Radius.circular(m.scaled(6)),
                          ),
                        ),
                        child: Text(
                          '$have',
                          style: TextStyle(
                            fontSize: m.scaled(11),
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(width: m.scaled(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: m.scaled(14), color: Palette.ink),
                    ),
                    SizedBox(height: m.scaled(2)),
                    Text(
                      complaint?.message ?? card.typeLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: m.scaled(11),
                        color: complaint == null
                            ? Palette.inkFaint
                            : Palette.attention,
                      ),
                    ),
                  ],
                ),
              ),
              if (!blocked)
                Icon(
                  Icons.add_rounded,
                  size: m.scaled(20),
                  color: Palette.inkMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
