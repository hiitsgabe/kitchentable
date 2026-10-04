import 'package:flutter/material.dart';

import '../../../net/voice_link.dart';
import '../../../ui/atoms/slab.dart';
import '../../../ui/atoms/slab_switch.dart';
import '../../../ui/atoms/tray.dart';
import '../../../ui/tokens/lettering.dart';
import '../../../ui/tokens/metrics.dart';
import '../../../ui/tokens/palette.dart';
import '../voice.dart';

/// Joining, leaving, muting, and the one sentence that says what is wrong.
///
/// Everything about the microphone in one place, reached from one button,
/// and nowhere near the table. Roll20 puts its join prompt over the map and
/// players complain it covers the board; that is the mistake this is shaped
/// to avoid.
class VoiceSheet extends StatelessWidget {
  const VoiceSheet({
    super.key,
    required this.metrics,
    required this.voice,
    required this.talkers,
    required this.onJoin,
    required this.onLeave,
    required this.onMute,
  });

  final Metrics metrics;
  final Voice voice;

  /// Who is at the table and whether their voice is arriving, in seat order.
  final List<({String name, bool talking, bool reaching})> talkers;

  final VoidCallback onJoin;
  final VoidCallback onLeave;
  final void Function(bool quiet) onMute;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        m.safeInset,
        m.scaled(14),
        m.safeInset,
        m.scaled(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TrayLabel(metrics: m, text: 'Talking'),
          SizedBox(height: m.scaled(10)),
          if (voice.trouble case final why?) ...[
            Well(
              metrics: m,
              edge: Palette.attention,
              child: Text(
                _saying(why),
                key: const Key('voice-trouble'),
                style: pixel(
                  size: m.scaled(12),
                  weight: 500,
                  height: 1.45,
                  color: Palette.ink,
                ),
              ),
            ),
            SizedBox(height: m.scaled(12)),
          ],
          if (!voice.isOn) ...[
            // Our own sentence before the system's. Somebody who says no
            // here has not spent the one prompt the browser gives, so the
            // offer can be made again later.
            Text(
              'Join and the table hears you. Nothing is recorded.',
              style: pixel(
                size: m.scaled(12),
                weight: 500,
                height: 1.5,
                color: Palette.inkMuted,
              ),
            ),
            SizedBox(height: m.scaled(12)),
            Slab(
              key: const Key('voice-join'),
              metrics: m,
              tone: SlabTone.choice,
              enabled: voice.state != Talking.asking,
              onActivate: onJoin,
              semanticLabel: 'Join voice',
              child: Center(
                child: Text(
                  voice.state == Talking.asking ? 'Asking...' : 'Join voice',
                  style: slabText(m.scaled(15)),
                ),
              ),
            ),
          ] else ...[
            SlabSwitch(
              key: const Key('voice-mute'),
              metrics: m,
              title: 'Microphone',
              icon: voice.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
              on: !voice.muted,
              onChanged: (on) => onMute(!on),
            ),
            if (talkers.isNotEmpty) ...[
              SizedBox(height: m.scaled(4)),
              Well(
                metrics: m,
                label: 'Who you can hear',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final who in talkers)
                      Padding(
                        padding: EdgeInsets.only(bottom: m.scaled(6)),
                        child: Row(
                          children: [
                            Icon(
                              who.talking
                                  ? Icons.graphic_eq_rounded
                                  : who.reaching
                                  ? Icons.mic_rounded
                                  : Icons.mic_off_rounded,
                              size: m.scaled(15),
                              color: who.talking
                                  ? Palette.slabCool
                                  : who.reaching
                                  ? Palette.inkMuted
                                  : Palette.inkFaint,
                            ),
                            SizedBox(width: m.scaled(8)),
                            Expanded(
                              child: Text(
                                who.name,
                                style: pixel(
                                  size: m.scaled(12),
                                  weight: 500,
                                  color: who.reaching
                                      ? Palette.ink
                                      : Palette.inkFaint,
                                ),
                              ),
                            ),
                            Text(
                              who.reaching ? '' : 'not reachable',
                              style: pixel(
                                size: m.scaled(11),
                                weight: 500,
                                color: Palette.inkFaint,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            SizedBox(height: m.scaled(10)),
            Slab(
              key: const Key('voice-leave'),
              metrics: m,
              tone: SlabTone.warm,
              onActivate: onLeave,
              semanticLabel: 'Leave voice',
              child: Center(
                child: Text('Leave voice', style: slabText(m.scaled(14))),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// One sentence per cause, because the benchmark's clearest finding about
  /// voice going wrong is that "not connected" with no cause and no fix is
  /// the documented bad example.
  static String _saying(VoiceTrouble why) => switch (why) {
    VoiceTrouble.refused =>
      'This device would not let the app use the microphone. Allow it in '
          'your browser or system settings, then try again.',
    VoiceTrouble.noMicrophone =>
      'No microphone was found on this device. Plug one in, or join and '
          'listen without talking once somebody else does.',
    VoiceTrouble.unreachable =>
      'Your microphone works and the others cannot be reached. This is the '
          'one a relay fixes: put one in Settings, under Network.',
  };
}
