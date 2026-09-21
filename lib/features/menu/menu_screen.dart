import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/atoms/hint_bar.dart';
import '../../ui/atoms/menu_row.dart';
import '../../ui/tokens/metrics.dart';
import '../../ui/tokens/palette.dart';
import '../sources/sources_screen.dart';
import 'menu_controller.dart';

class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = MediaQuery.of(context);
    final deviceClass = classifyDevice(
      size: media.size,
      hasTouch: media.navigationMode == NavigationMode.traditional,
    );
    final m = Metrics.of(deviceClass);
    final async = ref.watch(menuStateProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(m.safeInset),
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text('$e', style: const TextStyle(color: Palette.ink)),
            ),
            data: (state) => _Menu(state: state, metrics: m),
          ),
        ),
      ),
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu({required this.state, required this.metrics});

  final MenuState state;
  final Metrics metrics;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'kitchen'),
            TextSpan(
              text: 'table',
              style: const TextStyle(color: Palette.accent),
            ),
          ]),
          style: TextStyle(
            fontSize: m.scaled(24),
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            color: Palette.ink,
          ),
        ),
        SizedBox(height: m.scaled(4)),
        Text(
          state.headline,
          style: TextStyle(
            fontSize: m.scaled(10),
            letterSpacing: 0.8,
            color: Palette.inkFaint,
          ),
        ),
        SizedBox(height: m.scaled(20)),
        for (final entry in state.entries)
          MenuRow(
            title: entry.title,
            subtitle: entry.subtitle,
            enabled: entry.enabled,
            metrics: m,
            autofocus: entry.id == state.initialFocus,
            onActivate: () => _open(context, entry.id),
          ),
        const Spacer(),
        HintBar(
          metrics: m,
          hints: const [
            Hint(button: '▲▼', label: 'move'),
            Hint(button: 'A', label: 'open'),
          ],
        ),
      ],
    );
  }

  void _open(BuildContext context, MenuEntryId id) {
    if (id != MenuEntryId.sources) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SourcesScreen()),
    );
  }
}
