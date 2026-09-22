import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/atoms/hint_bar.dart';
import '../../ui/atoms/menu_row.dart';
import '../../ui/organisms/screen_frame.dart';
import '../../ui/tokens/metrics.dart';
import '../../ui/tokens/palette.dart';
import '../decks/games_screen.dart';
import '../settings/settings_screen.dart';
import '../sources/sources_screen.dart';
import 'menu_controller.dart';

class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = MediaQuery.of(context);
    final m = Metrics.of(classifyDevice(
      size: media.size,
      hasTouch: media.navigationMode == NavigationMode.traditional,
    ));
    final async = ref.watch(menuStateProvider);

    return async.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(m.safeInset),
            child: Text(
              '$e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Palette.ink),
            ),
          ),
        ),
      ),
      data: (state) => _Menu(state: state, metrics: m),
    );
  }
}

IconData _iconFor(MenuEntryId id) => switch (id) {
      MenuEntryId.play => Icons.play_arrow_rounded,
      MenuEntryId.decks => Icons.style_rounded,
      MenuEntryId.sources => Icons.download_rounded,
      MenuEntryId.settings => Icons.tune_rounded,
    };

class _Menu extends StatelessWidget {
  const _Menu({required this.state, required this.metrics});

  final MenuState state;
  final Metrics metrics;

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      metrics: metrics,
      wordmark: true,
      title: 'kitchentable',
      label: state.headline,
      hints: const [
        Hint(button: HintBar.dpad, label: 'move'),
        Hint(button: 'A', label: 'open'),
      ],
      children: [
        for (final entry in state.entries)
          MenuRow(
            title: entry.title,
            subtitle: entry.subtitle,
            icon: _iconFor(entry.id),
            enabled: entry.enabled,
            metrics: metrics,
            autofocus: entry.id == state.initialFocus,
            onActivate: () => _open(context, entry.id),
          ),
      ],
    );
  }

  void _open(BuildContext context, MenuEntryId id) {
    final screen = switch (id) {
      MenuEntryId.sources => const SourcesScreen(),
      // Play and Decks land in the same place on purpose. A table is started
      // from a deck, so both roads lead to the deck list, and the one called
      // Play stops being a dead end.
      MenuEntryId.decks || MenuEntryId.play => const GamesScreen(),
      MenuEntryId.settings => const SettingsScreen(),
    };
    if (screen == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }
}
