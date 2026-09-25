import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/atoms/hint_bar.dart';
import '../../ui/atoms/menu_row.dart';
import '../../ui/atoms/text_field_box.dart';
import '../../ui/organisms/screen_frame.dart';
import '../../ui/tokens/metrics.dart';
import '../../ui/tokens/palette.dart';
import 'room_controller.dart';
import 'room_screen.dart';

/// One box that takes a link or a code, because the person typing does not know
/// which of those they are holding.
///
/// A link works because the code is in it. Seven characters work because
/// somebody read them out. Both go through the same door and the same refusal:
/// a line that could not have been minted is not a room, and the button stays
/// dim rather than carrying a typo as far as the mesh.
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key, this.code});

  /// Filled in already, for a way in that arrived with the code in hand.
  final String? code;

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  late final TextEditingController _typed =
      TextEditingController(text: widget.code ?? '');

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final m = Metrics.of(classifyDevice(
      size: media.size,
      hasTouch: media.navigationMode == NavigationMode.traditional,
    ));
    final ready = looksLikeRoom(_typed.text);

    return ScreenFrame(
      metrics: m,
      title: 'Join a table',
      label: 'a link, or the code somebody read out',
      onBack: () => Navigator.of(context).maybePop(),
      hints: const [
        Hint(button: HintBar.dpad, label: 'move'),
        Hint(button: 'A', label: 'join'),
        Hint(button: 'B', label: 'back'),
      ],
      children: [
        TextFieldBox(
          key: const Key('join-input'),
          metrics: m,
          controller: _typed,
          hint: 'abcd-efg',
          autofocus: true,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _join(),
        ),
        SizedBox(height: m.scaled(10)),
        Text(
          'Upper case, lower case and the whole link around it are all fine.',
          style: TextStyle(
            fontSize: m.scaled(11),
            height: 1.4,
            color: Palette.inkFaint,
          ),
        ),
        SizedBox(height: m.scaled(16)),
        MenuRow(
          key: const Key('join-go'),
          title: 'Join',
          subtitle: ready
              ? 'go to that room'
              : 'paste a link, or type the seven characters',
          icon: Icons.meeting_room_rounded,
          enabled: ready,
          metrics: m,
          onActivate: _join,
        ),
      ],
    );
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
