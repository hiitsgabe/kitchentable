import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/atoms/hint_bar.dart';
import '../../ui/atoms/menu_row.dart';
import '../../ui/atoms/text_field_box.dart';
import '../../ui/organisms/screen_frame.dart';
import '../../ui/tokens/metrics.dart';
import 'decks_controller.dart';

/// Give the deck a name.
///
/// Every deck is born `Untitled Commander` and there was no way to change it,
/// so a second deck in the same format was indistinguishable from the first.
class RenameDeckScreen extends ConsumerStatefulWidget {
  const RenameDeckScreen({super.key});

  @override
  ConsumerState<RenameDeckScreen> createState() => _RenameDeckScreenState();
}

class _RenameDeckScreenState extends ConsumerState<RenameDeckScreen> {
  late final TextEditingController _controller =
      TextEditingController(text: ref.read(deckEditorProvider)?.name ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    // An empty name would leave a row with nothing to tap on in the deck list,
    // so it is refused by doing nothing rather than by a warning.
    if (name.isEmpty) return;

    await ref.read(deckEditorProvider.notifier).rename(name);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final m = Metrics.of(classifyDevice(
      size: media.size,
      hasTouch: media.navigationMode == NavigationMode.traditional,
    ));

    return ScreenFrame(
      metrics: m,
      title: 'Name',
      label: 'what this deck is called',
      onBack: () => Navigator.of(context).maybePop(),
      hints: const [Hint(button: 'B', label: 'back')],
      children: [
        TextFieldBox(
          metrics: m,
          controller: _controller,
          autofocus: true,
          hint: 'Atraxa superfriends',
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _save(),
        ),
        SizedBox(height: m.scaled(14)),
        MenuRow(
          title: 'Save',
          subtitle: _controller.text.trim().isEmpty
              ? 'a deck needs a name'
              : 'call it "${_controller.text.trim()}"',
          icon: Icons.check_rounded,
          enabled: _controller.text.trim().isNotEmpty,
          metrics: m,
          onActivate: _save,
        ),
      ],
    );
  }
}
