import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/atoms/menu_row.dart';
import '../../ui/atoms/text_field_box.dart';
import '../../ui/background/backdrop_controller.dart';
import '../../ui/organisms/screen_frame.dart';
import '../../ui/tokens/metrics.dart';
import '../sources/sources_screen.dart';
import '../menu/menu_screen.dart';
import '../setup/setup_controller.dart';
import '../setup/setup_screen.dart';
import 'backdrop_screen.dart';
import 'player_name.dart';
import 'network.dart';
import 'network_screen.dart';
import 'settings_parts.dart';

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
    final turn = ref.watch(turnProvider);

    ref.listen(playerNameProvider, (_, name) {
      if (!_typing && _name.text != name) _name.text = name;
    });

    return ScreenFrame(
      metrics: m,
      title: 'Settings',
      // The old line said nothing here leaves the device, which a name makes
      // untrue: it is the one thing on this screen the other players see.
      label: 'this device',
      onBack: () => Navigator.of(context).maybePop(),
      children: [
        SettingsLabel(metrics: m, text: 'you'),
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
        SettingsCaption(
          metrics: m,
          text: 'The people at your table see this, and it is the only thing '
              'here that leaves the device. Left empty you are $namelessPlayer.',
        ),

        // Four groups, which is the benchmark's number, each a subscreen of
        // its own rather than another slab of fields on this one.
        SettingsLabel(metrics: m, text: 'the app'),
        MenuRow(
          key: const Key('settings-look'),
          title: 'Look',
          subtitle: '${backdrop.kind.label}, and the colour it is drawn in',
          icon: Icons.palette_rounded,
          metrics: m,
          autofocus: true,
          onActivate: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const BackdropScreen()),
          ),
        ),
        MenuRow(
          key: const Key('settings-sources'),
          title: 'Sources',
          subtitle: 'where the cards come from',
          icon: Icons.download_rounded,
          metrics: m,
          onActivate: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SourcesScreen()),
          ),
        ),
        MenuRow(
          key: const Key('settings-network'),
          title: 'Network',
          subtitle: turn == null
              ? 'a relay, for two phones that cannot reach each other'
              : 'a relay is set',
          icon: Icons.lan_rounded,
          metrics: m,
          onActivate: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const NetworkScreen()),
          ),
        ),
        MenuRow(
          key: const Key('settings-setup'),
          title: 'Run the first-run setup again',
          subtitle: 'your name, a source, a deck',
          icon: Icons.restart_alt_rounded,
          metrics: m,
          onActivate: () async {
            await ref.read(setupDoneProvider.notifier).again();
            if (!context.mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute<void>(
                builder: (_) => SetupScreen(then: (_) => const MenuScreen()),
              ),
              (route) => false,
            );
          },
        ),
      ],
    );
  }
}
