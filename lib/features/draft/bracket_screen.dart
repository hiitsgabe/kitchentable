import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/atoms/slab.dart';
import '../../ui/atoms/tray.dart';
import '../../ui/organisms/screen_frame.dart';
import '../../ui/tokens/lettering.dart';
import '../../ui/tokens/metrics.dart';
import '../../ui/tokens/palette.dart';
import '../lobby/lobby.dart';
import '../play/play_controller.dart';
import '../play/play_screen.dart';

/// The tournament hub: the standings, and this seat's one thing to do — play
/// its game, report how it went, or watch the rest play out.
///
/// Everyone lands here when a tournament starts and comes back here after each
/// game. The host's standings are the ones that count; a guest shows what the
/// host last sent it.
class BracketScreen extends ConsumerWidget {
  const BracketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = MediaQuery.of(context);
    final m = Metrics.of(
      classifyDevice(
        size: media.size,
        hasTouch: media.navigationMode == NavigationMode.traditional,
      ),
    );

    final lobby = ref.watch(lobbyProvider);
    final bracket = lobby?.bracket;
    final standings =
        (bracket?['standings'] as List?)?.cast<Map<String, Object?>>() ??
        const [];
    final champion = bracket?['championName'] as String?;
    final round = (bracket?['round'] as num?)?.toInt() ?? 0;

    return ScreenFrame(
      metrics: m,
      title: 'Tournament',
      label: champion != null ? 'we have a winner' : 'round ${round + 1}',
      onBack: () => Navigator.of(context).maybePop(),
      backLabel: 'Room',
      children: [
        if (champion != null)
          _Banner(metrics: m, text: '$champion wins the pod'),
        _Standings(metrics: m, rows: standings, me: lobby?.me),
        SizedBox(height: m.scaled(14)),
        if (lobby != null) _Action(metrics: m, lobby: lobby),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.metrics, required this.text});

  final Metrics metrics;
  final String text;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    return Padding(
      padding: EdgeInsets.only(bottom: m.scaled(14)),
      child: Well(
        metrics: m,
        edge: Palette.attention,
        child: Row(
          children: [
            Icon(
              Icons.emoji_events_rounded,
              color: Palette.attention,
              size: m.scaled(28),
            ),
            SizedBox(width: m.scaled(10)),
            Expanded(
              child: Text(text, style: slabText(m.scaled(16))),
            ),
          ],
        ),
      ),
    );
  }
}

class _Standings extends StatelessWidget {
  const _Standings({required this.metrics, required this.rows, required this.me});

  final Metrics metrics;
  final List<Map<String, Object?>> rows;
  final String? me;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    return Well(
      metrics: m,
      label: 'Standings',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final row in rows)
            Padding(
              padding: EdgeInsets.symmetric(vertical: m.scaled(5)),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${row['name']}${row['seat'] == me ? ' (you)' : ''}',
                      style: pixel(
                        size: m.scaled(14),
                        color: row['out'] == true
                            ? Palette.inkFaint
                            : Palette.ink,
                      ),
                    ),
                  ),
                  if (row['champion'] == true)
                    Icon(
                      Icons.emoji_events_rounded,
                      size: m.scaled(16),
                      color: Palette.attention,
                    )
                  else if (row['out'] == true)
                    Text(
                      'out',
                      style: pixel(size: m.scaled(11), color: Palette.inkFaint),
                    ),
                  SizedBox(width: m.scaled(8)),
                  Text(
                    '${row['wins']}W',
                    style: pixel(size: m.scaled(12), color: Palette.inkMuted),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The one thing this seat does now, from its place in the tournament.
class _Action extends ConsumerWidget {
  const _Action({required this.metrics, required this.lobby});

  final Metrics metrics;
  final Lobby lobby;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = metrics;
    final bracket = lobby.bracket;
    final over = bracket?['champion'] != null;

    if (over) {
      return Slab(
        metrics: m,
        tone: SlabTone.cool,
        onActivate: () =>
            Navigator.of(context).popUntil((route) => route.isFirst),
        child: Center(child: Text('DONE', style: slabText(m.scaled(15)))),
      );
    }
    if (lobby.eliminated) {
      return _note(m, "You're out. Watch the rest play out.");
    }

    final scope = lobby.myGameScope;
    if (scope == null) {
      return _note(m, 'Sitting this round out.');
    }
    if (lobby.reported) {
      return _note(m, 'Reported. Waiting for the round to finish.');
    }

    // Find this seat's game, for the opponent's name and the report buttons.
    final games =
        (bracket?['games'] as List?)?.cast<Map<String, Object?>>() ?? const [];
    final game = games.where((g) => g['scope'] == scope).firstOrNull;
    final seats = (game?['seats'] as List?)?.cast<String>() ?? const [];
    final names = (game?['names'] as List?)?.cast<String>() ?? const [];
    final meIndex = seats.indexOf(lobby.me);
    final oppIndex = meIndex == 0 ? 1 : 0;
    final oppName = names.length > oppIndex && oppIndex >= 0
        ? names[oppIndex]
        : 'your opponent';
    final oppSeat = seats.length > oppIndex && oppIndex >= 0
        ? seats[oppIndex]
        : null;

    final ready = lobby.mesh?.table != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Slab(
          key: const Key('bracket-play'),
          metrics: m,
          tone: SlabTone.choice,
          dimmed: !ready,
          onActivate: ready ? () => _play(context, ref) : () {},
          child: Center(
            child: Text(
              ready ? 'PLAY  vs ${oppName.toUpperCase()}' : 'CONNECTING…',
              style: slabText(m.scaled(14)),
            ),
          ),
        ),
        SizedBox(height: m.scaled(10)),
        TrayLabel(metrics: m, text: 'When the game is done'),
        SizedBox(height: m.scaled(6)),
        Row(
          children: [
            Expanded(
              child: Slab(
                key: const Key('bracket-won'),
                metrics: m,
                tone: SlabTone.cool,
                onActivate: () => lobby.reportWinner(scope, lobby.me),
                child: Center(
                  child: Text('I WON', style: slabText(m.scaled(13))),
                ),
              ),
            ),
            SizedBox(width: m.scaled(8)),
            Expanded(
              child: Slab(
                key: const Key('bracket-lost'),
                metrics: m,
                tone: SlabTone.plain,
                onActivate: oppSeat == null
                    ? () {}
                    : () => lobby.reportWinner(scope, oppSeat),
                child: Center(
                  child: Text(
                    '${oppName.toUpperCase()} WON',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: slabText(m.scaled(13)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _play(BuildContext context, WidgetRef ref) {
    final mesh = lobby.mesh;
    if (mesh?.table == null) return;
    ref.read(playProvider.notifier).join(mesh!, decks: lobby.decks);
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PlayScreen()),
    );
  }

  Widget _note(Metrics m, String text) => Padding(
    padding: EdgeInsets.symmetric(vertical: m.scaled(12)),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: pixel(size: m.scaled(13), color: Palette.inkMuted),
    ),
  );
}
