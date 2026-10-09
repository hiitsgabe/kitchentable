import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ui/tokens/metrics.dart';
import '../chat.dart';
import '../talk_here.dart';
import '../talk_sheets.dart';
import '../voice.dart';
import 'pill.dart';

/// The chat and the microphone, for a screen that is not the table: the
/// draft, where the people are the same and the table is not dealt yet.
///
/// Nothing is drawn alone. A chat with nobody at the other end is a box to
/// type into the void, and the microphone is only there where the host
/// turned it on for the room.
class TalkBar extends ConsumerWidget {
  const TalkBar({super.key, required this.metrics});

  final Metrics metrics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = metrics;
    final talk = ref.watch(talkProvider);
    if (talk == null) return const SizedBox.shrink();
    final chat = ref.watch(chatProvider);
    final voice = ref.watch(tableTalksProvider)
        ? ref.watch(voiceProvider)
        : null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (voice != null) ...[
          Pill(
            metrics: m,
            key: const Key('draft-voice'),
            icon: switch (voice.state) {
              Talking.on =>
                voice.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
              Talking.failed => Icons.mic_off_rounded,
              _ => Icons.mic_none_rounded,
            },
            label: 'Microphone',
            onTap: () => openVoice(context, m, talkersInRoom),
            lit: voice.isOn && !voice.muted,
            warn: voice.state == Talking.failed,
          ),
          SizedBox(width: m.scaled(7)),
        ],
        Pill(
          metrics: m,
          key: const Key('draft-talk'),
          icon: Icons.chat_bubble_outline_rounded,
          label: 'Chat',
          onTap: () => openChat(context, m),
          badge: chat.unread,
        ),
      ],
    );
  }
}
