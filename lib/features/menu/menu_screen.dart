import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/atoms/hint_bar.dart';
import '../../ui/atoms/menu_row.dart';
import '../../ui/organisms/screen_frame.dart';
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
      MenuEntryId.join => Icons.qr_code_rounded,
      MenuEntryId.decks => Icons.style_rounded,
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
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }
}

/// Play, drawn as the way in rather than as the first of five.
///
/// Size, colour and placement, which is how every menu in the benchmark marks
/// its one dominant action. The rest of the screen is a list; this is a door.
class _PlayRow extends StatefulWidget {
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
  State<_PlayRow> createState() => _PlayRowState();
}

class _PlayRowState extends State<_PlayRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.metrics;

    return FocusableActionDetector(
      autofocus: true,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onActivate();
            return null;
          },
        ),
      },
      onShowFocusHighlight: (on) => setState(() => _focused = on),
      onShowHoverHighlight: (on) => setState(() => _focused = on),
      child: GestureDetector(
        onTap: widget.onActivate,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: EdgeInsets.only(bottom: m.scaled(14)),
          padding: EdgeInsets.symmetric(
            horizontal: m.scaled(18),
            vertical: m.scaled(20),
          ),
          decoration: BoxDecoration(
            color: Palette.focusWash,
            borderRadius: BorderRadius.circular(m.scaled(16)),
            border: Border.all(
              color: Palette.accent,
              width: m.scaled(_focused ? 2.5 : 1.5),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.play_arrow_rounded,
                size: m.scaled(30),
                color: Palette.accent,
              ),
              SizedBox(width: m.scaled(14)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: m.scaled(24),
                        fontWeight: FontWeight.w700,
                        color: Palette.ink,
                      ),
                    ),
                    SizedBox(height: m.scaled(2)),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: m.scaled(12),
                        color: Palette.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: m.scaled(20),
                color: Palette.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
