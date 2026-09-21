import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../decks/model/deck.dart';
import '../../decks/model/deck_format.dart';
import '../../ui/atoms/hint_bar.dart';
import '../../ui/atoms/menu_row.dart';
import '../../ui/organisms/screen_frame.dart';
import '../../ui/tokens/metrics.dart';
import 'decks_controller.dart';
import 'deck_screen.dart';

/// The format comes first and is not editable afterwards, because it decides
/// the rules the rest of the screen applies. A deck that changes format halfway
/// through would need every card rechecked, and nobody actually wants that: it
/// is a new deck.
class NewDeckScreen extends ConsumerWidget {
  const NewDeckScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = MediaQuery.of(context);
    final m = Metrics.of(classifyDevice(
      size: media.size,
      hasTouch: media.navigationMode == NavigationMode.traditional,
    ));

    return ScreenFrame(
      metrics: m,
      title: 'New deck',
      label: 'the format decides the rules',
      onBack: () => Navigator.of(context).maybePop(),
      hints: const [
        Hint(button: HintBar.dpad, label: 'move'),
        Hint(button: 'A', label: 'choose'),
        Hint(button: 'B', label: 'back'),
      ],
      children: [
        for (final format in DeckFormat.values)
          MenuRow(
            title: format.label,
            subtitle: _describe(format),
            icon: _iconFor(format),
            metrics: m,
            autofocus: format == DeckFormat.commander,
            onActivate: () => _create(context, ref, format),
          ),
      ],
    );
  }

  static String _describe(DeckFormat f) => switch (f) {
        DeckFormat.commander =>
          '100 cards, one of each, a commander, 40 life',
        DeckFormat.standard => '60 cards, four of each, 15 sideboard',
        DeckFormat.pauper => '60 cards, commons only, 15 sideboard',
        DeckFormat.draft => '40 cards, whatever came out of the packs',
      };

  static IconData _iconFor(DeckFormat f) => switch (f) {
        DeckFormat.commander => Icons.groups_rounded,
        DeckFormat.standard => Icons.shield_rounded,
        DeckFormat.pauper => Icons.savings_rounded,
        DeckFormat.draft => Icons.inventory_2_rounded,
      };

  Future<void> _create(
    BuildContext context,
    WidgetRef ref,
    DeckFormat format,
  ) async {
    final repo = ref.read(deckRepositoryProvider);
    if (repo == null) return;

    final id = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final deck = Deck(id: id, name: 'Untitled ${format.label}', format: format);

    await repo.save(deck);
    ref.invalidate(decksProvider);
    await ref.read(deckEditorProvider.notifier).open(id);

    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const DeckScreen()),
    );
  }
}
