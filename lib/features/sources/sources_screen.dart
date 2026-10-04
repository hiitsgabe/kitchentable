import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sources/model/source_def.dart';
import '../../sources/source_registry.dart';
import '../../ui/atoms/menu_row.dart';
import '../../ui/atoms/slab.dart';
import '../../ui/organisms/screen_frame.dart';
import '../../ui/tokens/metrics.dart';
import '../../ui/tokens/palette.dart';
import 'import_controller.dart';
import 'imported.dart';
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
    final imported = ref.watch(importedSourcesProvider);
    final media = MediaQuery.of(context);
    final m = Metrics.of(
      classifyDevice(
        size: media.size,
        hasTouch: media.navigationMode == NavigationMode.traditional,
      ),
    );
    final dim = ref.watch(betterPicturesProvider).value ?? false;

    return ScreenFrame(
      metrics: m,
      title: 'Sources',
      label: 'nothing has left this device yet',
      onBack: () => Navigator.of(context).maybePop(),
      children: [
        for (final source in knownSources)
          MenuRow(
            title: source.name,
            subtitle: imported.contains(source.id)
                ? 'imported, on this device'
                : _subtitleFor(source),
            icon: imported.contains(source.id)
                ? Icons.check_rounded
                : _iconFor(source.kind),
            // The ones that work carry a colour and the ones that do not stay
            // grey, so the list says which is which before the subtitle does.
            // One that has already come in goes quiet with a check on it:
            // this list used to draw Scryfall exactly the same before and
            // after an import, which read as the import not having happened.
            tone: imported.contains(source.id)
                ? SlabTone.plain
                : source.available
                ? SlabTone.cool
                : SlabTone.plain,
            enabled: source.available,
            metrics: m,
            autofocus: source.id == knownSources.first.id,
            onActivate: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ImportScreen(source: source),
              ),
            ),
          ),
        if (dim)
          Padding(
            padding: EdgeInsets.only(top: m.scaled(12), left: m.scaled(2)),
            child: Text(
              'Imported before sharper pictures were added. Re-import to get '
              'them.',
              style: TextStyle(
                fontSize: m.scaled(12),
                height: 1.5,
                color: Palette.inkFaint,
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
