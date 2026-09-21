import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../decks/model/game.dart';
import '../../ui/atoms/hint_bar.dart';
import '../../ui/atoms/menu_row.dart';
import '../../ui/organisms/screen_frame.dart';
import '../../ui/tokens/metrics.dart';
import 'decks_controller.dart';
import 'decks_screen.dart';

/// Decks opens here rather than on a list, because a Magic deck and a Pokemon
/// deck share no rule about size, copies or legality, and a single mixed list
/// would have to keep saying which is which on every row.
class GamesScreen extends ConsumerWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = MediaQuery.of(context);
    final m = Metrics.of(classifyDevice(
      size: media.size,
      hasTouch: media.navigationMode == NavigationMode.traditional,
    ));
    final decks = ref.watch(decksProvider);

    int countFor(Game game) => switch (decks) {
          AsyncData(:final value) =>
            value.where((d) => d.game == game).length,
          _ => 0,
        };

    return ScreenFrame(
      metrics: m,
      title: 'Decks',
      label: 'pick a game',
      onBack: () => Navigator.of(context).maybePop(),
      hints: const [
        Hint(button: HintBar.dpad, label: 'move'),
        Hint(button: 'A', label: 'open'),
        Hint(button: 'B', label: 'back'),
      ],
      children: [
        for (final game in Game.values)
          MenuRow(
            title: game.label,
            subtitle: _subtitle(game, countFor(game)),
            icon: _iconFor(game),
            enabled: game.hasCatalog,
            metrics: m,
            autofocus: game == Game.magic,
            onActivate: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => DecksScreen(game: game)),
            ),
          ),
      ],
    );
  }

  static String _subtitle(Game game, int count) {
    if (!game.hasCatalog) return 'needs a source, none imported yet';
    if (count == 0) return 'no decks yet';
    return count == 1 ? '1 deck' : '$count decks';
  }

  static IconData _iconFor(Game game) => switch (game) {
        Game.magic => Icons.auto_awesome_rounded,
        Game.pokemon => Icons.catching_pokemon_rounded,
      };
}
