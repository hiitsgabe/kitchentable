import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../decks/model/deck.dart';
import '../../ui/atoms/hint_bar.dart';
import '../../ui/atoms/menu_row.dart';
import '../../ui/organisms/screen_frame.dart';
import '../../ui/tokens/metrics.dart';
import 'decks_controller.dart';
import 'deck_screen.dart';
import 'new_deck_screen.dart';

class DecksScreen extends ConsumerWidget {
  const DecksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = MediaQuery.of(context);
    final m = Metrics.of(classifyDevice(
      size: media.size,
      hasTouch: media.navigationMode == NavigationMode.traditional,
    ));
    final decks = ref.watch(decksProvider);

    return ScreenFrame(
      metrics: m,
      title: 'Decks',
      label: switch (decks) {
        AsyncData(:final value) when value.isEmpty => 'none yet',
        AsyncData(:final value) => '${value.length} saved',
        AsyncError() => 'could not read them',
        _ => 'reading',
      },
      onBack: () => Navigator.of(context).maybePop(),
      hints: const [
        Hint(button: HintBar.dpad, label: 'move'),
        Hint(button: 'A', label: 'open'),
        Hint(button: 'B', label: 'back'),
      ],
      children: [
        MenuRow(
          title: 'New deck',
          subtitle: 'pick a format first, it decides the rules',
          icon: Icons.add_rounded,
          metrics: m,
          autofocus: true,
          onActivate: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const NewDeckScreen()),
            );
          },
        ),
        ...switch (decks) {
          AsyncData(:final value) => value.map((d) => _row(context, ref, m, d)),
          _ => const <Widget>[],
        },
      ],
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, Metrics m, Deck deck) =>
      MenuRow(
        title: deck.name,
        subtitle: deck.format.label,
        icon: Icons.style_rounded,
        metrics: m,
        onActivate: () async {
          await ref.read(deckEditorProvider.notifier).open(deck.id);
          if (!context.mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const DeckScreen()),
          );
        },
      );
}
