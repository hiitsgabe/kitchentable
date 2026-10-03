import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/atoms/menu_row.dart';
import '../../ui/atoms/slab.dart';
import '../../ui/background/backdrop_controller.dart';
import '../../ui/background/backdrop_style.dart';
import '../../ui/organisms/screen_frame.dart';
import '../../ui/tokens/lettering.dart';
import '../../ui/tokens/metrics.dart';
import '../../ui/tokens/palette.dart';
import 'pick_image.dart';

class BackdropScreen extends ConsumerStatefulWidget {
  const BackdropScreen({super.key});

  @override
  ConsumerState<BackdropScreen> createState() => _BackdropScreenState();
}

class _BackdropScreenState extends ConsumerState<BackdropScreen> {
  bool _picking = false;

  Future<void> _pick(BackdropStyle style) async {
    if (_picking) return;
    setState(() => _picking = true);
    final data = await pickImage();
    if (!mounted) return;
    setState(() => _picking = false);
    if (data == null) return;
    await ref
        .read(backdropProvider.notifier)
        .set(style.copyWith(kind: BackdropKind.image, imageData: data));
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
    final style = ref.watch(backdropProvider);
    final controller = ref.read(backdropProvider.notifier);

    return ScreenFrame(
      metrics: m,
      title: 'Background',
      label: '${style.kind.label} · it changes as you pick',
      onBack: () => Navigator.of(context).maybePop(),
      children: [
        _Label(metrics: m, text: 'effect'),
        for (final kind in BackdropKind.values)
          MenuRow(
            title: kind.label,
            subtitle: kind == style.kind
                ? '${kind.describe} · on now'
                : kind.describe,
            icon: _iconFor(kind),
            tone: kind == style.kind ? SlabTone.choice : SlabTone.plain,
            metrics: m,
            autofocus: kind == style.kind,
            onActivate: () => controller.set(style.copyWith(kind: kind)),
          ),
        SizedBox(height: m.scaled(20)),
        if (style.kind == BackdropKind.image) ...[
          SizedBox(height: m.scaled(10)),
          if (style.imageData case final data?)
            Padding(
              padding: EdgeInsets.only(bottom: m.scaled(10)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(m.scaled(10)),
                child: Image.memory(
                  base64Decode(data),
                  key: const Key('backdrop-preview'),
                  height: m.scaled(96),
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          if (canPickImage)
            MenuRow(
              key: const Key('backdrop-pick'),
              title: style.imageData == null
                  ? 'Choose a picture'
                  : 'Choose a different picture',
              subtitle: _picking
                  ? 'waiting for you to pick one'
                  : 'it is shrunk and kept on this device',
              icon: Icons.image_search_rounded,
              tone: SlabTone.cool,
              metrics: m,
              onActivate: () => _pick(style),
            )
          else
            Padding(
              padding: EdgeInsets.only(bottom: m.scaled(12)),
              child: Text(
                'Choosing a picture is only in the web version for now. This '
                'build has no chooser, so the colours below are what it draws.',
                style: pixel(
                  size: m.scaled(11),
                  weight: 500,
                  height: 1.45,
                  color: Palette.inkFaint,
                ),
              ),
            ),
          if (style.imageData != null)
            MenuRow(
              key: const Key('backdrop-clear'),
              title: 'Remove the picture',
              subtitle: 'back to the colours below',
              icon: Icons.delete_outline_rounded,
              metrics: m,
              onActivate: () =>
                  controller.set(style.copyWith(clearImage: true)),
            ),
          SizedBox(height: m.scaled(10)),
        ],
        _Label(metrics: m, text: 'colour'),
        _Said(
          metrics: m,
          text:
              'It is the background, and everything the app draws to point '
              'at something: borders, the focus ring, your own board, the '
              'buttons you press.',
        ),
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

  IconData _iconFor(BackdropKind k) => switch (k) {
    BackdropKind.paint => Icons.brush_rounded,
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
      style: pixel(
        size: metrics.scaled(10),
        weight: 500,
        letterSpacing: 1.3,

        color: Palette.inkFaint,
      ),
    ),
  );
}

/// A line under a heading, saying what the group changes.
class _Said extends StatelessWidget {
  const _Said({required this.metrics, required this.text});

  final Metrics metrics;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: metrics.scaled(12)),
    child: Text(
      text,
      style: pixel(
        size: metrics.scaled(11),
        weight: 500,
        height: 1.45,
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
                  color: chosen ? Palette.slabInk : Palette.outline,
                  width: m.scaled(2),
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
                style: pixel(
                  size: m.scaled(10),
                  weight: 500,
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
