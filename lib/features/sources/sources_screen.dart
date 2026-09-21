import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sources/model/source_def.dart';
import '../../sources/source_registry.dart';
import '../../ui/atoms/hint_bar.dart';
import '../../ui/atoms/menu_row.dart';
import '../../ui/tokens/metrics.dart';
import '../../ui/tokens/palette.dart';

String formatMegabytes(int bytes) =>
    '${(bytes / 1048576).toStringAsFixed(1)} MB';

class SourcesScreen extends ConsumerWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = MediaQuery.of(context);
    final m = Metrics.of(classifyDevice(
      size: media.size,
      hasTouch: media.navigationMode == NavigationMode.traditional,
    ));

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(m.safeInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sources',
                style: TextStyle(
                  fontSize: m.scaled(20),
                  fontWeight: FontWeight.w600,
                  color: Palette.ink,
                ),
              ),
              SizedBox(height: m.scaled(4)),
              Text(
                'NOTHING HAS LEFT THIS DEVICE YET',
                style: TextStyle(
                  fontSize: m.scaled(10),
                  letterSpacing: 0.8,
                  color: Palette.inkFaint,
                ),
              ),
              SizedBox(height: m.scaled(18)),
              for (final source in knownSources)
                MenuRow(
                  title: source.name,
                  subtitle: _subtitleFor(source),
                  enabled: source.available,
                  metrics: m,
                  autofocus: source.id == knownSources.first.id,
                  onActivate: () {},
                ),
              const Spacer(),
              HintBar(
                metrics: m,
                hints: const [
                  Hint(button: '▲▼', label: 'move'),
                  Hint(button: 'A', label: 'switch on'),
                  Hint(button: 'B', label: 'back'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Nobody should be surprised by a download, so the size is on the row before
  /// it is touched.
  String _subtitleFor(SourceDef source) {
    if (!source.available) return '${source.subtitle} · not ready yet';
    final bytes = source.approximateBytes;
    if (bytes == null) return source.subtitle;
    return '${source.subtitle} · ${formatMegabytes(bytes)} · downloads';
  }
}
