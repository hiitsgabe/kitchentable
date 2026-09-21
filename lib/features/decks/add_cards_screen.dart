import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../decks/model/deck.dart';
import '../../sources/model/catalog_card.dart';
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
              SizedBox(
                width: m.scaled(34),
                child: have > 0
                    ? Text(
                        '$have',
                        style: TextStyle(
                          fontSize: m.scaled(14),
                          fontWeight: FontWeight.w600,
                          color: Palette.accent,
                        ),
                      )
                    : null,
              ),
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
