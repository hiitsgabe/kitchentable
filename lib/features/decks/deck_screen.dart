import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../decks/model/deck.dart';
import '../../decks/model/game.dart';
import '../../ui/atoms/card_art.dart';
import '../../ui/atoms/count_pill.dart';
import '../../ui/atoms/toast.dart';
import '../../ui/organisms/card_viewer.dart';
import '../../ui/atoms/hint_bar.dart';
import '../../ui/atoms/menu_row.dart';
import '../../ui/organisms/screen_frame.dart';
import '../../ui/tokens/metrics.dart';
import '../../ui/tokens/palette.dart';
import 'add_cards_screen.dart';
import 'add_lands_screen.dart';
import 'decks_controller.dart';
import 'rename_deck_screen.dart';
import 'paste_list_screen.dart';
import '../play/play_controller.dart';
import '../play/play_screen.dart';
import '../../table/shuffle.dart';

class DeckScreen extends ConsumerWidget {
  const DeckScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = MediaQuery.of(context);
    final m = Metrics.of(
      classifyDevice(
        size: media.size,
        hasTouch: media.navigationMode == NavigationMode.traditional,
      ),
    );
    final deck = ref.watch(deckEditorProvider);

    if (deck == null) {
      return ScreenFrame(
        metrics: m,
        title: 'Deck',
        label: 'nothing open',
        onBack: () => Navigator.of(context).maybePop(),
        hints: const [Hint(button: 'B', label: 'back')],
        children: const [],
      );
    }

    return ScreenFrame(
      metrics: m,
      title: deck.name,
      label: deck.format.label,
      onBack: () => Navigator.of(context).maybePop(),
      hints: const [
        Hint(button: HintBar.dpad, label: 'move'),
        Hint(button: 'A', label: 'open'),
        Hint(button: 'B', label: 'back'),
      ],
      children: [
        _Counts(metrics: m, deck: deck),
        SizedBox(height: m.scaled(18)),
        // Present and dimmed rather than absent, which is what every other
        // dead row in this app does: Play and Decks on the menu, a game with
        // no catalog, a source that is not built, the plus button at a copy
        // limit. A row that vanishes teaches nobody that the feature exists.
        MenuRow(
          title: 'Play with this deck',
          subtitle: deck.slots.isEmpty
              ? 'add some cards first'
              : 'shuffle, draw seven, and see how it goldfishes',
          icon: Icons.play_arrow_rounded,
          enabled: deck.slots.isNotEmpty,
          metrics: m,
          onActivate: () {
            ref.read(playProvider.notifier).start(deck, seed: freshSeed());
            Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const PlayScreen()));
          },
        ),
        MenuRow(
          title: 'Rename',
          subtitle: 'it is called "${deck.name}"',
          icon: Icons.edit_rounded,
          metrics: m,
          onActivate: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const RenameDeckScreen()),
          ),
        ),
        MenuRow(
          title: 'Add cards',
          subtitle: 'search the catalog and tap to add',
          icon: Icons.search_rounded,
          metrics: m,
          autofocus: true,
          onActivate: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const AddCardsScreen()),
          ),
        ),
        if (deck.game == Game.magic)
          MenuRow(
            title: 'Add lands',
            subtitle: 'the tedious third of a deck, in one tap',
            icon: Icons.terrain_rounded,
            metrics: m,
            onActivate: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AddLandsScreen()),
            ),
          ),
        MenuRow(
          title: 'Paste a list',
          subtitle: 'the format shops and deck sites give you',
          icon: Icons.content_paste_rounded,
          metrics: m,
          onActivate: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const PasteListScreen()),
          ),
        ),
        if (deck.slots.isNotEmpty) ...[
          SizedBox(height: m.scaled(20)),
          _SectionLabel(metrics: m, text: 'in the deck'),
          for (final slot in [...deck.commanders, ...deck.main])
            _SlotRow(metrics: m, slot: slot, deck: deck),
          if (deck.side.isNotEmpty) ...[
            SizedBox(height: m.scaled(16)),
            _SectionLabel(metrics: m, text: 'sideboard'),
            for (final slot in deck.side)
              _SlotRow(metrics: m, slot: slot, deck: deck),
          ],
        ],
      ],
    );
  }
}

class _Counts extends StatelessWidget {
  const _Counts({required this.metrics, required this.deck});

  final Metrics metrics;
  final Deck deck;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final f = deck.format;

    return Wrap(
      spacing: m.scaled(8),
      runSpacing: m.scaled(8),
      children: [
        CountPill(
          metrics: m,
          label: 'cards',
          count: deck.mainCount,
          target: f.deckSize,
          exact: f.sizeIsExact,
        ),
        if (f.sideboardSize > 0)
          CountPill(
            metrics: m,
            label: 'sideboard',
            count: deck.sideCount,
            target: f.sideboardSize,
          ),
        if (f.needsCommander)
          CountPill(
            metrics: m,
            label: 'commander',
            count: deck.commanders.length,
            target: 1,
          ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.metrics, required this.text});

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

class _SlotRow extends ConsumerWidget {
  const _SlotRow({
    required this.metrics,
    required this.slot,
    required this.deck,
  });

  final Metrics metrics;
  final DeckSlot slot;
  final Deck deck;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = metrics;
    final editor = ref.read(deckEditorProvider.notifier);

    return Padding(
      padding: EdgeInsets.only(bottom: m.scaled(10)),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => CardViewer.show(context, slot.card),
            child: CardArt(metrics: m, card: slot.card, width: m.scaled(48)),
          ),
          SizedBox(width: m.scaled(12)),
          SizedBox(
            width: m.scaled(26),
            child: Text(
              '${slot.quantity}',
              style: TextStyle(
                fontSize: m.scaled(14),
                fontWeight: FontWeight.w600,
                color: Palette.accent,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.card.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: m.scaled(14), color: Palette.ink),
                ),
                SizedBox(height: m.scaled(2)),
                Text(
                  slot.card.typeLine,
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
          if (slot.commander)
            Padding(
              padding: EdgeInsets.only(right: m.scaled(8)),
              child: Icon(
                Icons.star_rounded,
                size: m.scaled(16),
                color: Palette.accent,
              ),
            ),
          _Step(
            metrics: m,
            icon: Icons.remove_rounded,
            onTap: () => editor.setQuantity(slot, slot.quantity - 1),
          ),
          SizedBox(width: m.scaled(4)),
          _Step(
            metrics: m,
            icon: Icons.add_rounded,
            // Dimmed when the format says no. A button that quietly does
            // nothing is worse than one that is plainly out of moves.
            enabled: editor.canAddMore(slot),
            onTap: () {
              if (editor.canAddMore(slot)) {
                editor.setQuantity(slot, slot.quantity + 1);
              } else {
                Toast.show(
                  context,
                  deck.format.maxCopies == 1
                      ? '${deck.format.label} is singleton'
                      : 'Already at ${deck.format.maxCopies} copies',
                  icon: Icons.block_rounded,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.metrics,
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  final Metrics metrics;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: m.scaled(34),
        height: m.scaled(34),
        decoration: BoxDecoration(
          color: Palette.tile,
          borderRadius: BorderRadius.circular(m.scaled(8)),
          border: Border.all(color: Palette.tileEdge),
        ),
        child: Icon(
          icon,
          size: m.scaled(17),
          color: enabled
              ? Palette.inkMuted
              : Palette.inkFaint.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
