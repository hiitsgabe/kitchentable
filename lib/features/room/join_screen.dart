import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/atoms/menu_row.dart';
import '../../ui/atoms/slab.dart';
import '../../ui/atoms/text_field_box.dart';
import '../settings/settings_parts.dart';
import '../../ui/organisms/screen_frame.dart';
import '../../ui/tokens/metrics.dart';
import 'room_controller.dart';
import 'scan_screen.dart';
import 'room_screen.dart';

/// The ways into somebody else's table: their QR, their link, or their code.
///
/// All three are the same seven characters. The code is the room, and the
/// room screen shows it under the QR, so somebody who already has the app
/// open here can type what the host reads out and never touch a link.
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
      label: 'their QR, their link, or their code',
      onBack: () => Navigator.of(context).maybePop(),
      children: [
        // The camera first, because it is the one that needs nothing typed
        // and no messaging app in between: you are in the same room as them
        // and you point your phone at theirs.
        if (canScan)
          MenuRow(
            key: const Key('join-scan'),
            title: 'Scan their QR code',
            icon: Icons.qr_code_scanner_rounded,
            tone: SlabTone.choice,
            metrics: m,
            autofocus: true,
            onActivate: _scan,
          ),
        SettingsLabel(
          metrics: m,
          text: 'or paste their link, or type their code',
        ),
        TextFieldBox(
          key: const Key('join-input'),
          metrics: m,
          controller: _typed,
          hint: 'the link, or the seven characters',
          autofocus: !canScan,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _join(),
        ),
        SizedBox(height: m.scaled(16)),
        MenuRow(
          key: const Key('join-go'),
          title: 'Join',
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
