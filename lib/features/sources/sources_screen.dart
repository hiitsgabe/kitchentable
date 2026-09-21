import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sources/model/source_def.dart';
import '../../sources/source_registry.dart';
import '../../ui/atoms/hint_bar.dart';
import '../../ui/atoms/menu_row.dart';
import '../../ui/organisms/screen_frame.dart';
import '../../ui/tokens/metrics.dart';
import 'import_screen.dart';

String formatMegabytes(int bytes) =>
    '${(bytes / 1048576).toStringAsFixed(1)} MB';

IconData _iconFor(SourceKind kind) => switch (kind) {
      SourceKind.catalog => Icons.grid_view_rounded,
      SourceKind.draftSets => Icons.inventory_2_rounded,
      SourceKind.localFile => Icons.folder_rounded,
      SourceKind.url => Icons.link_rounded,
    };

class SourcesScreen extends ConsumerWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = MediaQuery.of(context);
    final m = Metrics.of(classifyDevice(
      size: media.size,
      hasTouch: media.navigationMode == NavigationMode.traditional,
    ));

    return ScreenFrame(
      metrics: m,
      title: 'Sources',
      label: 'nothing has left this device yet',
      onBack: () => Navigator.of(context).maybePop(),
      hints: const [
        Hint(button: HintBar.dpad, label: 'move'),
        Hint(button: 'A', label: 'switch on'),
        Hint(button: 'B', label: 'back'),
      ],
      children: [
        for (final source in knownSources)
          MenuRow(
            title: source.name,
            subtitle: _subtitleFor(source),
            icon: _iconFor(source.kind),
            enabled: source.available,
            metrics: m,
            autofocus: source.id == knownSources.first.id,
            onActivate: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ImportScreen(source: source),
              ),
            ),
          ),
      ],
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
