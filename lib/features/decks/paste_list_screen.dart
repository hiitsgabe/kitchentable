import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../decks/import/decklist_parser.dart';
import '../../decks/import/decklist_resolver.dart';
import '../../ui/atoms/hint_bar.dart';
import '../../ui/atoms/menu_row.dart';
import '../../ui/atoms/text_field_box.dart';
import '../../ui/organisms/screen_frame.dart';
import '../../ui/tokens/metrics.dart';
import '../../ui/tokens/palette.dart';
import '../menu/menu_controller.dart';
import 'decks_controller.dart';

/// Paste a list, see exactly what it resolved to, then decide.
///
/// The preview is the point. Every deck site and shop emits a slightly
/// different shape, and an importer that swallows the difference silently gives
/// you a deck that is quietly four cards short.
class PasteListScreen extends ConsumerStatefulWidget {
  const PasteListScreen({super.key});

  @override
  ConsumerState<PasteListScreen> createState() => _PasteListScreenState();
}

class _PasteListScreenState extends ConsumerState<PasteListScreen> {
  final _controller = TextEditingController();
  ResolvedDecklist? _preview;
  bool _working = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final db = ref.read(catalogDbProvider);
    if (db == null) return;

    setState(() => _working = true);
    final resolved = await resolveDecklist(db, parseDecklist(_controller.text));
    if (!mounted) return;
    setState(() {
      _preview = resolved;
      _working = false;
    });
  }

  Future<void> _add() async {
    final preview = _preview;
    if (preview == null) return;

    await ref.read(deckEditorProvider.notifier).addAll(preview.slots);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final m = Metrics.of(classifyDevice(
      size: media.size,
      hasTouch: media.navigationMode == NavigationMode.traditional,
    ));
    final preview = _preview;

    return ScreenFrame(
      metrics: m,
      title: 'Paste a list',
      label: _working
          ? 'looking them up'
          : preview == null
              ? 'one card per line'
              : '${preview.resolvedCount} cards found',
      onBack: () => Navigator.of(context).maybePop(),
      hints: const [Hint(button: 'B', label: 'back')],
      children: [
        TextFieldBox(
          metrics: m,
          controller: _controller,
          lines: 8,
          autofocus: true,
          hint: '4 Lightning Bolt\n1 Sol Ring (C21) 263\n\nSideboard\n2 Pyroblast',
          onChanged: (_) {
            if (_preview != null) setState(() => _preview = null);
          },
        ),
        SizedBox(height: m.scaled(14)),
        MenuRow(
          title: preview == null ? 'Check the list' : 'Add them to the deck',
          subtitle: preview == null
              ? 'nothing is added until you have seen what it found'
              : '${preview.slots.length} entries',
          icon: preview == null
              ? Icons.fact_check_rounded
              : Icons.playlist_add_rounded,
          metrics: m,
          enabled: !_working,
          onActivate: preview == null ? _check : _add,
        ),
        if (preview != null) ...[
          SizedBox(height: m.scaled(16)),
          if (preview.notFound.isNotEmpty)
            _Problem(
              metrics: m,
              title: 'Not in the catalog',
              detail: 'A typo, or a card from a source you have not imported.',
              lines: preview.notFound,
            ),
          if (preview.ignoredLines.isNotEmpty)
            _Problem(
              metrics: m,
              title: 'Could not read these lines',
              detail: 'They were left out rather than guessed at.',
              lines: preview.ignoredLines,
            ),
          if (preview.isClean)
            Text(
              'Every line resolved.',
              style: TextStyle(fontSize: m.scaled(12), color: Palette.inkMuted),
            ),
        ],
      ],
    );
  }
}

class _Problem extends StatelessWidget {
  const _Problem({
    required this.metrics,
    required this.title,
    required this.detail,
    required this.lines,
  });

  final Metrics metrics;
  final String title;
  final String detail;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return Container(
      margin: EdgeInsets.only(bottom: m.scaled(10)),
      padding: EdgeInsets.all(m.scaled(12)),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(m.scaled(10)),
        border: Border.all(color: Palette.attention.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: m.scaled(13),
              fontWeight: FontWeight.w600,
              color: Palette.attention,
            ),
          ),
          SizedBox(height: m.scaled(3)),
          Text(
            detail,
            style: TextStyle(fontSize: m.scaled(11), color: Palette.inkFaint),
          ),
          SizedBox(height: m.scaled(8)),
          for (final line in lines.take(12))
            Text(
              line,
              style: TextStyle(fontSize: m.scaled(12), color: Palette.ink),
            ),
          if (lines.length > 12)
            Text(
              'and ${lines.length - 12} more',
              style: TextStyle(fontSize: m.scaled(11), color: Palette.inkFaint),
            ),
        ],
      ),
    );
  }
}
