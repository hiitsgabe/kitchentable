import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../table/model/seat.dart';
import '../../ui/tokens/metrics.dart';
import '../../ui/tokens/palette.dart';
import '../lobby/lobby.dart';
import 'chat.dart';
import 'play_controller.dart';
import 'talk_here.dart';
import 'voice.dart';
import 'widgets/chat_sheet.dart';
import 'widgets/voice_sheet.dart';

/// Somebody who can be heard, as the voice sheet lists them.
typedef Talker = ({String name, bool talking, bool reaching});

/// The sheets for talking, shared by the table and the draft: the same
/// chat and the same microphones, because it is the same room.

/// Opens the chat. Reading it is what marks it read.
Future<void> openChat(BuildContext context, Metrics m) async {
  final container = ProviderScope.containerOf(context);
  container.read(chatProvider.notifier).seen();
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Palette.tray,
    isScrollControlled: true,
    builder: (sheet) {
      // Sized from the room above the keyboard, not from the screen. It
      // used to be capped at a share of the screen with the keyboard's
      // inset padded inside that cap, so the moment a phone's keyboard
      // came up the input was pushed below the sheet's own bottom edge
      // and vanished the instant somebody tapped it. The cap is still a
      // share of the screen, the way Board Game Arena caps its own chat,
      // because the table is what people came for; it is just measured
      // from what is left once the keyboard has taken its part.
      final keyboard = MediaQuery.viewInsetsOf(sheet).bottom;
      final height = MediaQuery.sizeOf(sheet).height;
      final room = math.min(height * 0.42, height - keyboard - m.scaled(24));
      return AnimatedPadding(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.only(bottom: keyboard),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: math.max(room, 0)),
          child: Consumer(
            builder: (context, ref, _) => ChatSheet(
              metrics: m,
              room: ref.watch(chatProvider),
              onSay: (text) => ref.read(talkProvider)?.say(text),
            ),
          ),
        ),
      );
    },
  );
}

/// Opens everything about the microphone. [talkers] lists who else is
/// here, read fresh each build so a microphone coming on shows.
Future<void> openVoice(
  BuildContext context,
  Metrics m,
  List<Talker> Function(WidgetRef ref, Voice voice) talkers,
) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Palette.tray,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.62,
    ),
    builder: (sheet) => Consumer(
      builder: (context, ref, _) {
        final voice = ref.watch(voiceProvider);
        return VoiceSheet(
          metrics: m,
          voice: voice,
          talkers: talkers(ref, voice),
          onJoin: () => ref.read(voiceProvider.notifier).join(),
          onLeave: () => ref.read(voiceProvider.notifier).leave(),
          onMute: ref.read(voiceProvider.notifier).mute,
        );
      },
    ),
  );
}

/// Everybody else at the table, by the chair they sit in.
List<Talker> talkersAtTable(WidgetRef ref, Voice voice) {
  final table = ref.watch(playProvider);
  final me = ref.read(transportProvider)?.me;
  return [
    for (final seat in table?.seats ?? const <Seat>[])
      if (seat.owner.peerId != null && seat.owner.peerId != me)
        (
          name: seat.name,
          talking: voice.talking.contains(seat.owner.peerId),
          reaching: voice.reaching.contains(seat.owner.peerId),
        ),
  ];
}

/// Everybody else in the room, by the chair the lobby gave them. For the
/// draft, where there is no table yet.
List<Talker> talkersInRoom(WidgetRef ref, Voice voice) {
  final lobby = ref.watch(lobbyProvider);
  if (lobby == null) return const [];
  return [
    for (final seat in lobby.seated)
      if (seat.peer != lobby.me)
        (
          name: lobby.nameOf(seat.peer),
          talking: voice.talking.contains(seat.peer),
          reaching: voice.reaching.contains(seat.peer),
        ),
  ];
}
