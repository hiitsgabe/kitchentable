import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/atoms/menu_row.dart';
import '../../ui/atoms/slab.dart';
import '../../ui/atoms/text_field_box.dart';
import '../settings/settings_parts.dart';
import '../../ui/organisms/screen_frame.dart';
import '../../ui/tokens/lettering.dart';
import '../../ui/tokens/metrics.dart';
import '../../ui/tokens/palette.dart';
import 'room_controller.dart';
import 'scan_screen.dart';
import 'room_screen.dart';

/// The two ways into somebody else's table: their link, or their QR.
///
/// Those are the two things the room screen hands out, and it hands out
/// nothing else. It used to show a seven character code as well, and this
/// screen still led with "the code somebody read out" long after there was
/// no code on screen to read out, which is an instruction to do something
/// the app no longer lets anybody do.
///
/// A bare code is not one of them any more. Seven characters are nothing to
/// anybody who does not already have the app open at this screen, and
/// nowhere in the app hands one out, so there was nowhere for one to come
/// from.
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key, this.code});

  /// Filled in already, for a way in that arrived with the code in hand.
  final String? code;

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  late final TextEditingController _typed = TextEditingController(
    text: widget.code ?? '',
  );

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final m = Metrics.of(
      classifyDevice(
        size: media.size,
        hasTouch: media.navigationMode == NavigationMode.traditional,
      ),
    );
    final ready = looksLikeRoom(_typed.text);

    return ScreenFrame(
      metrics: m,
      title: 'Join a table',
      label: 'their link, or their QR code',
      onBack: () => Navigator.of(context).maybePop(),
      children: [
        // The camera first, because it is the one that needs nothing typed
        // and no messaging app in between: you are in the same room as them
        // and you point your phone at theirs.
        if (canScan)
          MenuRow(
            key: const Key('join-scan'),
            title: 'Scan their QR code',
            subtitle: 'point your camera at the other screen',
            icon: Icons.qr_code_scanner_rounded,
            tone: SlabTone.choice,
            metrics: m,
            autofocus: true,
            onActivate: _scan,
          ),
        SettingsLabel(metrics: m, text: 'or paste their link'),
        TextFieldBox(
          key: const Key('join-input'),
          metrics: m,
          controller: _typed,
          hint: 'the link they sent you',
          autofocus: !canScan,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _join(),
        ),
        SizedBox(height: m.scaled(10)),
        Text(
          'Whatever they sent you, pasted whole. The app finds the room in '
          'it.',
          style: pixel(
            size: m.scaled(11),
            weight: 500,
            height: 1.4,
            color: Palette.inkFaint,
          ),
        ),
        SizedBox(height: m.scaled(16)),
        MenuRow(
          key: const Key('join-go'),
          title: 'Join',
          subtitle: ready ? 'go to that room' : 'paste their link first',
          icon: Icons.meeting_room_rounded,
          enabled: ready,
          tone: canScan ? SlabTone.plain : SlabTone.choice,
          metrics: m,
          onActivate: _join,
        ),
      ],
    );
  }

  /// Opens the camera, and joins with whatever it reads.
  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const ScanScreen()),
    );
    if (code == null || !mounted) return;
    _typed.text = code;
    _join();
  }

  void _join() {
    if (!ref.read(roomProvider.notifier).arrive(_typed.text)) return;

    // Replaced, so back from the room is the menu rather than the box that has
    // already been answered.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const RoomScreen()),
    );
  }
}
