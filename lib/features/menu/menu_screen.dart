import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/atoms/menu_row.dart';
import '../../ui/atoms/slab.dart';
import '../../ui/organisms/screen_frame.dart';
import '../../ui/tokens/lettering.dart';
import '../../ui/tokens/metrics.dart';
import '../../ui/tokens/palette.dart';
import '../decks/games_screen.dart';
import '../room/join_screen.dart';
import '../room/start_screen.dart';
import '../settings/settings_screen.dart';
import 'menu_controller.dart';

class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = MediaQuery.of(context);
    final m = Metrics.of(
      classifyDevice(
        size: media.size,
        hasTouch: media.navigationMode == NavigationMode.traditional,
      ),
    );
    final async = ref.watch(menuStateProvider);

    return async.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
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
  MenuEntryId.join => Icons.qr_code_rounded,
  MenuEntryId.decks => Icons.style_rounded,
  MenuEntryId.settings => Icons.tune_rounded,
};

/// A colour each, the way the reference title screen does it: blue to play,
/// green for the collection, orange for options, red to quit. No two things
/// you might press by accident look alike, which is worth more than a tasteful
/// palette. Play takes whatever colour the player chose, because that is the
/// row their choice should reach first.
SlabTone _toneFor(MenuEntryId id) => switch (id) {
  MenuEntryId.play => SlabTone.choice,
  MenuEntryId.join => SlabTone.cool,
  MenuEntryId.decks => SlabTone.plain,
  MenuEntryId.settings => SlabTone.warm,
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
      children: [
        for (final entry in state.entries)
          if (entry.id == MenuEntryId.play)
            _PlayRow(
              key: const Key('menu-play'),
              metrics: metrics,
              title: entry.title,
              subtitle: entry.subtitle,
              onActivate: () => _open(context, entry.id),
            )
          else
            MenuRow(
              key: Key('menu-${entry.id.name}'),
              title: entry.title,
              subtitle: entry.subtitle,
              icon: _iconFor(entry.id),
              tone: _toneFor(entry.id),
              enabled: entry.enabled,
              metrics: metrics,
              onActivate: () => _open(context, entry.id),
            ),
      ],
    );
  }

  void _open(BuildContext context, MenuEntryId id) {
    final screen = switch (id) {
      // No deck on either of these roads. The room is made first and the cards
      // come out inside it.
      MenuEntryId.play => const StartScreen(),
      MenuEntryId.join => const JoinScreen(),
      MenuEntryId.decks => const GamesScreen(),
      MenuEntryId.settings => const SettingsScreen(),
    };
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }
}

/// Play, drawn as the way in rather than as the first of four.
///
/// Size, colour and placement, which is how every menu in the benchmark marks
/// its one dominant action. The rest of the screen is a list of slabs; this is
/// the same slab, twice the height, carrying one word in capitals.
class _PlayRow extends StatelessWidget {
  const _PlayRow({
    super.key,
    required this.metrics,
    required this.title,
    required this.subtitle,
    required this.onActivate,
  });

  final Metrics metrics;
  final String title;
  final String subtitle;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return Padding(
      padding: EdgeInsets.only(bottom: m.scaled(14)),
      child: Slab(
        metrics: m,
        tone: SlabTone.choice,
        autofocus: true,
        depth: m.scaled(7),
        onActivate: onActivate,
        semanticLabel: '$title. $subtitle',
        padding: EdgeInsets.symmetric(
          horizontal: m.scaled(18),
          vertical: m.scaled(18),
        ),
        child: Row(
          children: [
            Icon(
              Icons.play_arrow_rounded,
              size: m.scaled(34),
              color: Palette.slabInk,
            ),
            SizedBox(width: m.scaled(14)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title.toUpperCase(), style: slabText(m.scaled(30))),
                  SizedBox(height: m.scaled(4)),
                  Text(
                    subtitle,
                    style: pixel(
                      size: m.scaled(13),
                      weight: 500,
                      color: const Color(0xE0FFFFFF),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
