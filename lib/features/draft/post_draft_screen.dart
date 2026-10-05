import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../table/model/table_state.dart';
import '../../table/room/room.dart';
import '../../table/setup.dart';
import '../../table/shuffle.dart';
import '../../ui/atoms/menu_row.dart';
import '../../ui/atoms/slab.dart';
import '../../ui/organisms/screen_frame.dart';
import '../../ui/tokens/metrics.dart';
import '../lobby/lobby.dart';
import '../play/play_controller.dart';
import '../play/play_screen.dart';
import '../room/room_controller.dart';
import 'post_draft.dart';

/// How to play, once the draft is built: the host chooses, everybody plays.
///
/// One table seats the whole pod; 1v1 splits it into parallel games. The guests
/// never see this: the host picks, and each phone is told which table it is at.
class PostDraftScreen extends ConsumerWidget {
  const PostDraftScreen({super.key});

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
    final seats = lobby?.seated.length ?? 0;
    // 1v1 needs an even pod of at least four; two players are already a 1v1 at
    // one table, so there the choice is only the casual one.
    final canSplit = seats >= 4 && seats % 2 == 0;

    return ScreenFrame(
      metrics: m,
      title: 'How to play',
      label: 'every deck is built',
      onBack: () => Navigator.of(context).maybePop(),
      children: [
        for (final mode in [
          PostDraftMode.oneTable,
          if (canSplit) PostDraftMode.pairs,
          if (canSplit) PostDraftMode.tournament,
        ])
          MenuRow(
            key: Key('post-${mode.name}'),
            title: mode.label,
            subtitle: mode.blurb,
            icon: _iconFor(mode),
            tone: mode == PostDraftMode.oneTable
                ? SlabTone.choice
                : SlabTone.cool,
            metrics: m,
            autofocus: mode == PostDraftMode.oneTable,
            onActivate: () => dealDrafted(context, ref, mode),
          ),
      ],
    );
  }

  static IconData _iconFor(PostDraftMode mode) => switch (mode) {
    PostDraftMode.oneTable => Icons.table_restaurant_rounded,
    PostDraftMode.pairs => Icons.groups_2_rounded,
    PostDraftMode.tournament => Icons.emoji_events_rounded,
  };
}

/// Deals the drafted pod the way [mode] asks and opens this phone's table.
///
/// Shared by the chooser and, later, a tournament's next round. The host deals
/// every table and joins its own; the guests are carried to theirs by the
/// "play" word the deal sends, through the room's own listeners.
void dealDrafted(BuildContext context, WidgetRef ref, PostDraftMode mode) {
  final lobby = ref.read(lobbyProvider);
  final config = lobby?.config ?? ref.read(roomProvider)?.config;
  if (lobby == null || config == null) return;

  final mine = lobby.dealDraftAs(mode, (players) => _table(players, config));
  if (mine == null) {
    // The host drew a bye this round: nothing to play at, back to the room.
    Navigator.of(context).popUntil((route) => route.isFirst);
    return;
  }

  ref.read(playProvider.notifier).join(mine, decks: lobby.decks);
  Navigator.of(context).pushReplacement(
    MaterialPageRoute<void>(builder: (_) => const PlayScreen()),
  );
}

/// One table's cards from its players, at the room's life. The pure builder the
/// deal runs once per table, kept off the play controller so dealing several
/// tables does not fight over the one game this phone shows.
TableState _table(List<Player> players, RoomConfig config) {
  final table = sitDownTogether(players: players, seed: freshSeed());
  return table.copyWith(
    seats: [for (final seat in table.seats) seat.copyWith(life: config.life)],
  );
}
