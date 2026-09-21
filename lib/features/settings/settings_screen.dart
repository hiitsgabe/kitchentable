import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/atoms/hint_bar.dart';
import '../../ui/atoms/menu_row.dart';
import '../../ui/background/backdrop_controller.dart';
import '../../ui/organisms/screen_frame.dart';
import '../../ui/tokens/metrics.dart';
import 'backdrop_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = MediaQuery.of(context);
    final m = Metrics.of(classifyDevice(
      size: media.size,
      hasTouch: media.navigationMode == NavigationMode.traditional,
    ));
    final backdrop = ref.watch(backdropProvider);

    return ScreenFrame(
      metrics: m,
      title: 'Settings',
      label: 'nothing here leaves the device',
      onBack: () => Navigator.of(context).maybePop(),
      hints: const [
        Hint(button: HintBar.dpad, label: 'move'),
        Hint(button: 'A', label: 'open'),
        Hint(button: 'B', label: 'back'),
      ],
      children: [
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
