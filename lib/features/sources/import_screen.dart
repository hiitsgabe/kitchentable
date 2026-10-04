import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sources/model/source_def.dart';
import '../../ui/atoms/progress_track.dart';
import '../../ui/atoms/menu_row.dart';
import '../../ui/atoms/slab.dart';
import '../../ui/organisms/screen_frame.dart';
import '../../ui/tokens/lettering.dart';
import '../../ui/tokens/metrics.dart';
import '../../ui/tokens/palette.dart';
import 'import_controller.dart';
import 'sources_screen.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key, required this.source});

  final SourceDef source;

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(importProvider.notifier).run(widget.source);
    });
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
    final s = ref.watch(importProvider);

    return ScreenFrame(
      metrics: m,
      title: widget.source.name,
      label: _labelFor(s),
      onBack: () => Navigator.of(context).maybePop(),
      home: true,
      children: [
        ProgressTrack(
          metrics: m,
          label: 'Downloading',
          fraction: s.downloadFraction,
          trailing: s.total == null
              ? '${formatMegabytes(s.received)} so far'
              : '${formatMegabytes(s.received)} of ${formatMegabytes(s.total!)}',
        ),
        ProgressTrack(
          metrics: m,
          label: 'Indexing',
          fraction: s.phase == ImportPhase.downloading ? 0 : s.indexFraction,
          trailing: s.phase == ImportPhase.downloading
              ? 'waiting'
              : '${s.indexed} cards',
          dimmed: s.phase == ImportPhase.downloading,
        ),
        if (s.phase == ImportPhase.failed)
          _Note(metrics: m, text: s.error, bad: true),
        // A way forward, and in the colour the player picked, because this
        // is the thing to press now. It used to be a note and the frame's
        // orange Back, which is what every other screen ends with, and so
        // finishing read exactly like not having started. One pop, back to
        // whichever screen opened this, and that screen now knows.
        if (s.phase == ImportPhase.done)
          MenuRow(
            key: const Key('import-done'),
            title: 'Done',
            subtitle: '${s.indexed} cards are on this device now',
            icon: Icons.check_rounded,
            tone: SlabTone.choice,
            metrics: m,
            autofocus: true,
            onActivate: () => Navigator.of(context).maybePop(),
          ),
        if (s.phase == ImportPhase.downloading ||
            s.phase == ImportPhase.indexing)
          _Note(metrics: m, text: 'You can leave. It keeps going.'),
      ],
    );
  }

  String _labelFor(ImportState s) => switch (s.phase) {
    ImportPhase.idle => 'starting',
    ImportPhase.downloading => 'downloading',
    ImportPhase.indexing => 'indexing',
    ImportPhase.done => 'finished',
    ImportPhase.failed => 'did not work',
  };
}

class _Note extends StatelessWidget {
  const _Note({required this.metrics, required this.text, this.bad = false});

  final Metrics metrics;
  final String? text;
  final bool bad;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return Padding(
      padding: EdgeInsets.only(top: m.scaled(6), left: m.scaled(2)),
      child: Text(
        text ?? 'It did not work',
        style: pixel(
          size: m.scaled(12),
          weight: 500,
          height: 1.5,
          color: bad ? Palette.attention : Palette.inkFaint,
        ),
      ),
    );
  }
}
