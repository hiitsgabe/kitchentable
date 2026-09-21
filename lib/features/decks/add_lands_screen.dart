import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../decks/model/basic_lands.dart';
import '../../decks/model/deck.dart';
import '../../sources/model/catalog_card.dart';
import '../../ui/atoms/card_art.dart';
import '../../ui/atoms/hint_bar.dart';
import '../../ui/atoms/menu_row.dart';
import '../../ui/atoms/toast.dart';
import '../../ui/organisms/card_viewer.dart';
import '../../ui/organisms/screen_frame.dart';
import '../../ui/tokens/metrics.dart';
import '../../ui/tokens/palette.dart';
import '../menu/menu_controller.dart';
import 'decks_controller.dart';

/// Basic lands, which are a third of most decks and the most tedious third.
///
/// Searching for Mountain and tapping thirty seven times is nobody's idea of
/// building a deck, so this offers the colours the deck is actually in and a
/// one tap fill for whatever is still missing.
class AddLandsScreen extends ConsumerStatefulWidget {
  const AddLandsScreen({super.key});

  @override
  ConsumerState<AddLandsScreen> createState() => _AddLandsScreenState();
}

class _AddLandsScreenState extends ConsumerState<AddLandsScreen> {
  Map<String, CatalogCard> _lands = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(catalogDbProvider);
    if (db == null) return;
    final found = await loadBasicLands(db);
    if (mounted) setState(() => _lands = found);
  }

  CatalogCard? _cardFor(String name) => _lands[name.toLowerCase()];

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final m = Metrics.of(classifyDevice(
      size: media.size,
      hasTouch: media.navigationMode == NavigationMode.traditional,
    ));
    final deck = ref.watch(deckEditorProvider);
    final editor = ref.read(deckEditorProvider.notifier);

    if (deck == null) {
      return ScreenFrame(
        metrics: m,
        title: 'Lands',
        label: 'no deck open',
        onBack: () => Navigator.of(context).maybePop(),
        hints: const [Hint(button: 'B', label: 'back')],
        children: const [],
      );
    }

    final offered = suggestedLandsFor(deck);
    final split = evenLandSplit(deck);
    final missing = deck.format.deckSize - deck.mainCount;

    return ScreenFrame(
      metrics: m,
      title: 'Lands',
      label: missing > 0
          ? '$missing still to fill'
          : 'the deck is already full',
      onBack: () => Navigator.of(context).maybePop(),
      hints: const [
        Hint(button: HintBar.dpad, label: 'move'),
        Hint(button: 'A', label: 'add'),
        Hint(button: 'B', label: 'back'),
      ],
      children: [
        if (split.isNotEmpty)
          MenuRow(
            title: 'Fill the rest with land',
            subtitle: split.entries
                .map((e) => '${e.value} ${e.key}')
                .join(' · '),
            icon: Icons.auto_fix_high_rounded,
            metrics: m,
            autofocus: true,
            onActivate: () async {
              final slots = <DeckSlot>[];
              for (final entry in split.entries) {
                final card = _cardFor(entry.key);
                if (card != null) {
                  slots.add(DeckSlot(card: card, quantity: entry.value));
                }
              }
              await editor.addAll(slots);
              if (!context.mounted) return;
              Toast.show(
                context,
                'Added ${split.values.fold(0, (a, b) => a + b)} lands',
                icon: Icons.check_rounded,
              );
              Navigator.of(context).pop();
            },
          ),
        SizedBox(height: m.scaled(18)),
        _Label(
          metrics: m,
          text: offered.length == basicLandNames.length
              ? 'every basic'
              : "the colours this deck is in",
        ),
        for (final name in offered)
          _LandRow(
            metrics: m,
            name: name,
            card: _cardFor(name),
            have: _cardFor(name) == null
                ? 0
                : deck.quantityOf(_cardFor(name)!.oracleId),
          ),
        if (_lands.isEmpty) ...[
          SizedBox(height: m.scaled(8)),
          Text(
            'No basic lands in the catalog. Import a source first.',
            style: TextStyle(fontSize: m.scaled(12), color: Palette.inkFaint),
          ),
        ],
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.metrics, required this.text});

  final Metrics metrics;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: metrics.scaled(10)),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: metrics.scaled(10),
            letterSpacing: 1.3,
            fontWeight: FontWeight.w500,
            color: Palette.inkFaint,
          ),
        ),
      );
}

class _LandRow extends ConsumerWidget {
  const _LandRow({
    required this.metrics,
    required this.name,
    required this.card,
    required this.have,
  });

  final Metrics metrics;
  final String name;
  final CatalogCard? card;
  final int have;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = metrics;
    final editor = ref.read(deckEditorProvider.notifier);
    final found = card;

    void bump(int by) {
      if (found == null) return;
      final slot = DeckSlot(card: found, quantity: by.abs());
      if (by > 0) {
        editor.add(slot);
      } else {
        editor.setQuantity(DeckSlot(card: found, quantity: have), have - 1);
      }
    }

    return Opacity(
      opacity: found == null ? 0.4 : 1,
      child: Padding(
        padding: EdgeInsets.only(bottom: m.scaled(10)),
        child: Row(
          children: [
            if (found != null)
              GestureDetector(
                onTap: () => CardViewer.show(context, found),
                child: CardArt(metrics: m, card: found, width: m.scaled(48)),
              )
            else
              SizedBox(width: m.scaled(48), height: m.scaled(48) * 88 / 63),
            SizedBox(width: m.scaled(12)),
            SizedBox(
              width: m.scaled(30),
              child: Text(
                have > 0 ? '$have' : '',
                style: TextStyle(
                  fontSize: m.scaled(14),
                  fontWeight: FontWeight.w600,
                  color: Palette.accent,
                ),
              ),
            ),
            Expanded(
              child: Text(
                name,
                style: TextStyle(fontSize: m.scaled(14), color: Palette.ink),
              ),
            ),
            for (final (icon, by) in [
              (Icons.remove_rounded, -1),
              (Icons.add_rounded, 1),
              (Icons.keyboard_double_arrow_up_rounded, 5),
            ]) ...[
              GestureDetector(
                onTap: found == null ? null : () => bump(by),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: m.scaled(34),
                  height: m.scaled(34),
                  margin: EdgeInsets.only(left: m.scaled(4)),
                  decoration: BoxDecoration(
                    color: Palette.tile,
                    borderRadius: BorderRadius.circular(m.scaled(8)),
                    border: Border.all(color: Palette.tileEdge),
                  ),
                  child: Icon(
                    icon,
                    size: m.scaled(17),
                    color: Palette.inkMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
