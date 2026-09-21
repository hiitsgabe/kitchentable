import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sources/model/source_def.dart';
import '../../ui/atoms/hint_bar.dart';
import '../../ui/atoms/progress_track.dart';
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
    final m = Metrics.of(classifyDevice(
      size: media.size,
      hasTouch: media.navigationMode == NavigationMode.traditional,
    ));
    final s = ref.watch(importProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(m.safeInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.source.name,
                style: TextStyle(
                  fontSize: m.scaled(20),
                  fontWeight: FontWeight.w600,
                  color: Palette.ink,
                ),
              ),
              SizedBox(height: m.scaled(18)),
              ProgressTrack(
                metrics: m,
                label: 'Downloading',
                fraction: s.downloadFraction,
                trailing: s.total == null
                    ? '${formatMegabytes(s.received)} so far'
                    : '${formatMegabytes(s.received)} of '
                        '${formatMegabytes(s.total!)}',
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
                Padding(
                  padding: EdgeInsets.only(top: m.scaled(6)),
                  child: Text(
                    s.error ?? 'It did not work',
                    style: TextStyle(
                      fontSize: m.scaled(11),
                      color: Palette.attention,
                    ),
                  ),
                ),
              if (s.phase == ImportPhase.done)
                Padding(
                  padding: EdgeInsets.only(top: m.scaled(6)),
                  child: Text(
                    'Done. ${s.indexed} cards.',
                    style: TextStyle(fontSize: m.scaled(12), color: Palette.ink),
                  ),
                ),
              const Spacer(),
              HintBar(
                metrics: m,
                hints: const [Hint(button: 'B', label: 'back')],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
