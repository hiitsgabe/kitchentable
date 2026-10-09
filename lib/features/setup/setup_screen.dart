import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../decks/model/game.dart';
import '../../sources/source_registry.dart';
import '../../ui/atoms/menu_row.dart';
import '../../ui/atoms/slab.dart';
import '../../ui/atoms/text_field_box.dart';
import '../../ui/organisms/screen_frame.dart';
import '../../ui/tokens/lettering.dart';
import '../../ui/tokens/metrics.dart';
import '../../ui/tokens/palette.dart';
import '../decks/games_screen.dart';
import '../menu/menu_controller.dart';
import '../settings/player_name.dart';
import '../sources/import_screen.dart';
import '../sources/imported.dart';
import 'setup_controller.dart';

/// The first run: your name, somewhere for the cards to come from, and a
/// deck if you want one now.
///
/// Three steps, not a wall. The menu used to open with three rows greyed out
/// saying "needs a source" and one row saying "start here", which explains a
/// wall rather than removing it. Everything here can be skipped except
/// nothing: a person who skips the lot gets the menu, and the rows that need
/// cards will say so when they are reached.
///
/// [then] is what this was in the way of. Somebody opening a room link who
/// has never run the app lands here first and in the room after, because the
/// link is the intent and the wizard is a detour: the destination is parked
/// before the wizard starts and replayed when it ends.
///
/// [forGame] is what that link said the room plays, when it said. The
/// sources step then names the one catalog the room needs rather than
/// offering four equal rows and a skip: a guest who skips the lot arrives at
/// a table where every card is a blank back, and "you can add a source any
/// time" is no help with the host already dealing.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key, required this.then, this.forGame});

  /// Built once the last step is done or skipped.
  final WidgetBuilder then;

  /// The game of the room the launch link leads to, or null when there is no
  /// room on the way, or the link did not say.
  final Game? forGame;

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  int _step = 0;
  late final TextEditingController _name = TextEditingController(
    text: ref.read(playerNameProvider),
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _next() => setState(() => _step++);

  Future<void> _finish() async {
    await ref.read(setupDoneProvider.notifier).finish();
    if (!mounted) return;
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute<void>(builder: widget.then));
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
    // The catalog's own count, so step two knows when it is done rather than
    // taking the player's word for having pressed something.
    final cards = ref.watch(menuStateProvider).value?.cardCount ?? 0;

    return ScreenFrame(
      metrics: m,
      wordmark: _step == 0,
      title: switch (_step) {
        0 => 'kitchentable',
        1 => 'Where the cards come from',
        _ => 'A deck to play with',
      },
      label: 'STEP ${_step + 1} OF 3',
      children: switch (_step) {
        0 => _name_(m),
        1 => _source(m, cards),
        _ => _deck(m, cards),
      },
    );
  }

  List<Widget> _name_(Metrics m) => [
    _Said(metrics: m, text: 'What should the others call you?'),
    TextFieldBox(
      key: const Key('setup-name'),
      metrics: m,
      controller: _name,
      hint: namelessPlayer,
      autofocus: true,
      onChanged: (name) => ref.read(playerNameProvider.notifier).set(name),
      onSubmitted: (_) => _next(),
    ),
    SizedBox(height: m.scaled(14)),
    MenuRow(
      key: const Key('setup-next'),
      title: 'Next',
      subtitle: 'cards come next',
      icon: Icons.arrow_forward_rounded,
      tone: SlabTone.choice,
      metrics: m,
      onActivate: _next,
    ),
  ];

  List<Widget> _source(Metrics m, int cards) {
    final imported = ref.watch(importedSourcesProvider);
    // The one catalog the room on the way needs, until it is in. A local
    // file of the same cards counts too, which is why the row only insists
    // while the device has no cards at all.
    final game = widget.forGame;
    final needed = game == null ? null : catalogFor(game);
    final missing = needed != null && cards == 0;
    return [
      _Said(
        metrics: m,
        text: cards > 0
            ? 'Done: $cards cards on this device.'
            : needed != null
            ? 'The room you were invited to plays ${game!.label}. It needs '
                  'the ${needed.name} catalog on this device, or every card '
                  'at the table will be a blank back. It downloads once.'
            : 'Pick where the cards come from. They download once, onto '
                  'this device.',
      ),
      for (final source in knownSources)
        MenuRow(
          key: Key('setup-source-${source.id}'),
          title: source.name,
          // Marked on the row the moment the import is done, so coming back
          // from one shows the thing that just happened rather than the same
          // list as before, which read as no progress at all.
          subtitle: imported.contains(source.id)
              ? 'imported, on this device'
              : missing && source == needed
              ? 'needed for the room you are joining'
              : source.available
              ? source.subtitle
              : 'not ready yet',
          icon: imported.contains(source.id)
              ? Icons.check_rounded
              : Icons.download_rounded,
          // With a room on the way, the catalog it needs is the one choice
          // on the screen and the other sources step back to plain.
          tone: imported.contains(source.id)
              ? SlabTone.plain
              : missing
              ? (source == needed ? SlabTone.choice : SlabTone.plain)
              : source.available
              ? SlabTone.cool
              : SlabTone.plain,
          enabled: source.available,
          metrics: m,
          autofocus: cards == 0 && (needed ?? knownSources.first) == source,
          onActivate: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ImportScreen(source: source),
            ),
          ),
        ),
      SizedBox(height: m.scaled(14)),
      MenuRow(
        key: const Key('setup-next'),
        title: cards > 0
            ? 'Next'
            : missing
            ? 'Skip anyway'
            : 'Skip for now',
        subtitle: cards > 0
            ? 'a deck next'
            : missing
            ? 'the table will show blank cards until ${needed.name} is in'
            : 'you can add a source any time, from Settings',
        icon: Icons.arrow_forward_rounded,
        metrics: m,
        autofocus: cards > 0,
        onActivate: _next,
      ),
    ];
  }

  List<Widget> _deck(Metrics m, int cards) => [
    _Said(
      metrics: m,
      text: cards == 0
          ? 'No cards yet, so no deck yet. Decks, once a source is in.'
          : 'Now or later: a table lets you pick one when you sit down.',
    ),
    if (cards > 0)
      MenuRow(
        key: const Key('setup-deck'),
        title: 'Build a deck',
        icon: Icons.style_rounded,
        metrics: m,
        autofocus: true,
        onActivate: () => Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => const GamesScreen())),
      ),
    SizedBox(height: m.scaled(14)),
    MenuRow(
      key: const Key('setup-done'),
      title: 'Done',
      icon: Icons.check_rounded,
      tone: SlabTone.choice,
      metrics: m,
      autofocus: cards == 0,
      onActivate: _finish,
    ),
  ];
}

/// A sentence the step opens with, saying what the step is for.
class _Said extends StatelessWidget {
  const _Said({required this.metrics, required this.text});

  final Metrics metrics;
  final String text;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return Padding(
      padding: EdgeInsets.only(bottom: m.scaled(16)),
      child: Text(
        text,
        style: pixel(
          size: m.scaled(13),
          weight: 500,
          height: 1.5,
          color: Palette.inkMuted,
        ),
      ),
    );
  }
}
