import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../decks/model/deck.dart';
import '../../decks/model/game.dart';
import '../../table/shuffle.dart';
import '../../ui/atoms/hint_bar.dart';
import '../../ui/atoms/menu_row.dart';
import '../../ui/organisms/screen_frame.dart';
import '../../ui/tokens/metrics.dart';
import '../play/play_controller.dart';
import '../play/play_screen.dart';
import 'decks_controller.dart';

/// Pick a deck and the game starts.
///
/// The same decks as the Decks screen, going somewhere else. That is the
/// difference worth having: one road is for building a deck and the other is
/// for sitting down with one, and a menu entry called Play that opened a deck
/// editor would be a lie.
class PlayDecksScreen extends ConsumerWidget {
  const PlayDecksScreen({super.key});

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
      title: 'Play',
      label: switch (decks) {
        AsyncData(:final value) when value.isEmpty => 'no decks to play with',
        AsyncData() => 'pick one and it deals',
        AsyncError() => 'could not read your decks',
        _ => 'reading',
      },
      onBack: () => Navigator.of(context).maybePop(),
      hints: const [
        Hint(button: HintBar.dpad, label: 'move'),
        Hint(button: 'A', label: 'deal'),
        Hint(button: 'B', label: 'back'),
      ],
      children: [
        ...switch (decks) {
          AsyncData(:final value) => [
              for (final deck in value)
                MenuRow(
                  title: deck.name,
                  subtitle: _describe(deck),
                  icon: _iconFor(deck.game),
                  // A deck with no cards deals nothing, so it is here and
                  // dimmed rather than missing, like every other dead row.
                  enabled: deck.cardCount > 0,
                  metrics: m,
                  autofocus: deck == value.first,
                  onActivate: () => _deal(context, ref, deck),
                ),
            ],
          _ => const <Widget>[],
        },
      ],
    );
  }

  static String _describe(Deck deck) => deck.cardCount == 0
      ? '${deck.format.label} · empty, nothing to deal'
      : '${deck.format.label} · ${deck.cardCount} cards';

  static IconData _iconFor(Game game) => switch (game) {
        Game.magic => Icons.auto_awesome_rounded,
        Game.pokemon => Icons.catching_pokemon_rounded,
      };

  /// Loads the deck's cards first. The list is deliberately read without them,
  /// so dealing straight from a row would sit down at an empty table.
  Future<void> _deal(BuildContext context, WidgetRef ref, Deck deck) async {
    final full = await ref.read(deckRepositoryProvider)?.load(deck.id);
    if (full == null || !context.mounted) return;

    ref.read(playProvider.notifier).start(full, seed: freshSeed());
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PlayScreen()),
    );
  }
}
