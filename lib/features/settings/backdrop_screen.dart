import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/atoms/hint_bar.dart';
import '../../ui/atoms/menu_row.dart';
import '../../ui/background/backdrop_controller.dart';
import '../../ui/background/backdrop_style.dart';
import '../../ui/organisms/screen_frame.dart';
import '../../ui/tokens/metrics.dart';
import '../../ui/tokens/palette.dart';

class BackdropScreen extends ConsumerWidget {
  const BackdropScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = MediaQuery.of(context);
    final m = Metrics.of(classifyDevice(
      size: media.size,
      hasTouch: media.navigationMode == NavigationMode.traditional,
    ));
    final style = ref.watch(backdropProvider);
    final controller = ref.read(backdropProvider.notifier);

    return ScreenFrame(
      metrics: m,
      title: 'Background',
      label: '${style.kind.label} · it changes as you pick',
      onBack: () => Navigator.of(context).maybePop(),
      hints: const [
        Hint(button: HintBar.dpad, label: 'move'),
        Hint(button: 'A', label: 'pick'),
        Hint(button: 'B', label: 'back'),
      ],
      children: [
        _Label(metrics: m, text: 'effect'),
        for (final kind in BackdropKind.values)
          MenuRow(
            title: kind.label,
            subtitle: kind == style.kind
                ? '${kind.describe} · on now'
                : kind.describe,
            icon: _iconFor(kind),
            metrics: m,
            autofocus: kind == style.kind,
            onActivate: () => controller.set(style.copyWith(kind: kind)),
          ),
        SizedBox(height: m.scaled(20)),
        _Label(metrics: m, text: 'colour'),
        Wrap(
          spacing: m.scaled(10),
          runSpacing: m.scaled(10),
          children: [
            for (final entry in backdropPresets.entries)
              _Swatch(
                metrics: m,
                name: entry.key,
                top: entry.value.$1,
                bottom: entry.value.$2,
                chosen: style.top == entry.value.$1,
                onTap: () => controller.set(
                  style.copyWith(top: entry.value.$1, bottom: entry.value.$2),
                ),
              ),
          ],
        ),
      ],
    );
  }

  static IconData _iconFor(BackdropKind k) => switch (k) {
        BackdropKind.aurora => Icons.blur_on_rounded,
        BackdropKind.drift => Icons.bubble_chart_rounded,
        BackdropKind.flat => Icons.gradient_rounded,
        BackdropKind.image => Icons.image_rounded,
      };
}

class _Label extends StatelessWidget {
  const _Label({required this.metrics, required this.text});

  final Metrics metrics;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: metrics.scaled(10)),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: metrics.scaled(10),
            letterSpacing: 1.3,
            fontWeight: FontWeight.w500,
            color: Palette.inkFaint,
          ),
        ),
      );
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.metrics,
    required this.name,
    required this.top,
    required this.bottom,
    required this.chosen,
    required this.onTap,
  });

  final Metrics metrics;
  final String name;
  final Color top;
  final Color bottom;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return Semantics(
      button: true,
      selected: chosen,
      label: name,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: m.scaled(64),
              height: m.scaled(44),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(m.scaled(10)),
                border: Border.all(
                  color: chosen ? Palette.accent : Palette.tileEdge,
                  width: chosen ? m.focusRing : 1,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color.lerp(bottom, top, 0.7)!, bottom],
                ),
              ),
            ),
            SizedBox(height: m.scaled(5)),
            SizedBox(
              width: m.scaled(70),
              child: Text(
                name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: m.scaled(10),
                  color: chosen ? Palette.ink : Palette.inkFaint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
