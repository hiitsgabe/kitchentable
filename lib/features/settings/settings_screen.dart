import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/atoms/hint_bar.dart';
import '../../ui/atoms/menu_row.dart';
import '../../ui/atoms/text_field_box.dart';
import '../../ui/background/backdrop_controller.dart';
import '../../ui/organisms/screen_frame.dart';
import '../../ui/tokens/metrics.dart';
import '../../ui/tokens/palette.dart';
import 'backdrop_screen.dart';
import 'player_name.dart';

/// What this device is, as opposed to what any one room is.
///
/// Your name sits here rather than on the way into a room. It is the same name
/// in every room you ever join, and a room that asked again was asking you to
/// repeat yourself and keeping a second copy that could disagree.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _name = TextEditingController();

  /// Whether the box holds what somebody is typing right now.
  ///
  /// The stored name arrives a turn after the screen is first built, and the
  /// box has to take it then. After somebody starts typing it must not: a name
  /// that arrived late and overwrote a half typed one would eat letters.
  bool _typing = false;

  @override
  void initState() {
    super.initState();
    _name.text = ref.read(playerNameProvider);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final m = Metrics.of(classifyDevice(
      size: media.size,
      hasTouch: media.navigationMode == NavigationMode.traditional,
    ));
    final backdrop = ref.watch(backdropProvider);

    ref.listen(playerNameProvider, (_, name) {
      if (!_typing && _name.text != name) _name.text = name;
    });

    return ScreenFrame(
      metrics: m,
      title: 'Settings',
      // The old line said nothing here leaves the device, which a name makes
      // untrue: it is the one thing on this screen the other players see.
      label: 'who you are, and how it looks',
      onBack: () => Navigator.of(context).maybePop(),
      hints: const [
        Hint(button: HintBar.dpad, label: 'move'),
        Hint(button: 'A', label: 'open'),
        Hint(button: 'B', label: 'back'),
      ],
      children: [
        _Label(metrics: m, text: 'your name'),
        TextFieldBox(
          key: const Key('player-name'),
          metrics: m,
          controller: _name,
          hint: namelessPlayer,
          onChanged: (name) {
            _typing = true;
            ref.read(playerNameProvider.notifier).set(name);
          },
        ),
        _Caption(
          metrics: m,
          text: 'The people at your table see this, and it is the only thing '
              'here that leaves the device. Left empty you are $namelessPlayer.',
        ),
        MenuRow(
          title: 'Background',
          subtitle: '${backdrop.kind.label}, and the colours',
          icon: Icons.blur_on_rounded,
          metrics: m,
          autofocus: true,
          onActivate: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const BackdropScreen()),
          ),
        ),
      ],
    );
  }
}

/// The small uppercase line over a field, the same one the backdrop screen puts
/// over its two groups.
class _Label extends StatelessWidget {
  const _Label({required this.metrics, required this.text});

  final Metrics metrics;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: metrics.scaled(6)),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: metrics.scaled(10),
            letterSpacing: 1.2,
            fontWeight: FontWeight.w500,
            color: Palette.inkFaint,
          ),
        ),
      );
}

/// A sentence under a field saying what filling it in does.
class _Caption extends StatelessWidget {
  const _Caption({required this.metrics, required this.text});

  final Metrics metrics;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(
          top: metrics.scaled(6),
          bottom: metrics.scaled(18),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: metrics.scaled(11),
            height: 1.45,
            color: Palette.inkFaint,
          ),
        ),
      );
}
