import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../decks/model/deck_format.dart';
import '../../decks/model/game.dart';
import '../../sources/model/draft_set.dart';
import '../../table/room/room.dart';
import '../../table/room/room_names.dart';
import '../../ui/atoms/menu_row.dart';
import '../../ui/atoms/slab.dart';
import '../../ui/atoms/slab_switch.dart';
import '../../ui/atoms/tray.dart';
import '../../ui/atoms/text_field_box.dart';
import '../../ui/organisms/screen_frame.dart';
import '../../ui/tokens/lettering.dart';
import '../../ui/tokens/metrics.dart';
import '../../ui/tokens/palette.dart';
import '../draft/draft_controller.dart';
import '../settings/player_name.dart';
import '../sources/sources_screen.dart';
import 'room_controller.dart';
import 'room_screen.dart';

/// What the room is before it exists.
///
/// No deck on this screen and no deck behind it. A room is a place: it is made,
/// it is shared, people turn up, and only then does anybody put cards on the
/// table. The old road went the other way round and there was never a moment
/// where a table existed and nobody was playing at it, which is why there was
/// nothing to invite anybody to.
class StartScreen extends ConsumerStatefulWidget {
  const StartScreen({super.key});

  @override
  ConsumerState<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends ConsumerState<StartScreen> {
  // Opens holding a name rather than empty: nobody is ever asked to name a
  // room, and an empty box is the worst thing to meet on the way in.
  final _roomName = TextEditingController(text: freshRoomName());
  final _life = TextEditingController();

  DeckFormat _format = DeckFormat.commander;
  int _seats = roomSeatChoices.first;

  /// The draft setup, which only shows when the format is Draft. The set is the
  /// one thing that can be missing: a draft cannot open packs from nothing.
  String? _draftSetCode;
  String? _draftSetName;
  bool _sealed = false;
  int _packs = 3;

  /// Whether the life box holds a number somebody chose.
  ///
  /// Until it does, changing the format moves it, because forty against twenty
  /// is the format talking. After it does, the format leaves it alone: a room
  /// playing Commander to thirty is a room, and having the number snap back
  /// would read as the app arguing.
  bool _lifeIsMine = false;

  /// Whether this room will offer microphones. Off, which is what every
  /// game that has voice ships, and the host's to change.
  var _voice = false;

  @override
  void initState() {
    super.initState();
    _life.text = '${_format.startingLife}';
  }

  @override
  void dispose() {
    _roomName.dispose();
    _life.dispose();
    super.dispose();
  }

  /// Null where the box holds something that is not a number, which is the one
  /// thing on this screen that can be wrong.
  int? get _lifeTyped => _life.text.trim().isEmpty
      ? _format.startingLife
      : int.tryParse(_life.text.trim());

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final m = Metrics.of(
      classifyDevice(
        size: media.size,
        hasTouch: media.navigationMode == NavigationMode.traditional,
      ),
    );
    final life = _lifeTyped;
    final isDraft = _format == DeckFormat.draft;
    final draftReady = !isDraft || _draftSetCode != null;
    final draftSets = isDraft
        ? (ref.watch(draftSetsProvider).value ?? const <DraftSet>[])
        : const <DraftSet>[];

    return ScreenFrame(
      metrics: m,
      title: 'Start a table',
      label: 'name it, pick a format',
      onBack: () => Navigator.of(context).maybePop(),
      primary: ScreenAction(
        slabKey: const Key('make-room'),
        label: life == null
            ? 'Starting life has to be a number'
            : !draftReady
            ? 'Pick a set to draft'
            : 'Make the room',
        icon: Icons.meeting_room_rounded,
        enabled: life != null && draftReady,
        onActivate: _open,
      ),
      children: [
        _Field(
          metrics: m,
          label: 'What to call the room',
          child: TextFieldBox(
            key: const Key('room-name'),
            metrics: m,
            controller: _roomName,
            hint: 'the kitchen table',
            onChanged: (_) => setState(() {}),
          ),
        ),
        _Field(
          metrics: m,
          label: 'Format',
          // A select: one row saying what is picked, and the five choices
          // only while you are choosing. All five laid open on the screen was
          // the first attempt and it read as a list to browse rather than a
          // setting with a value, and it made the screen five rows taller
          // for a choice most rooms never change.
          child: MenuRow(
            key: const Key('format-select'),
            title: _format.label,
            subtitle: _describe(_format),
            icon: _iconFor(_format),
            metrics: m,
            autofocus: true,
            onActivate: _chooseFormat,
          ),
        ),
        if (isDraft) ..._draftFields(m, draftSets),
        _Field(
          metrics: m,
          label: 'Chairs',
          child: _Chairs(metrics: m, seats: _seats, onMove: _moveSeats),
        ),
        _Field(
          metrics: m,
          label: 'Starting life',
          child: TextFieldBox(
            key: const Key('life-field'),
            metrics: m,
            controller: _life,
            hint: '${_format.startingLife}',
            onChanged: (_) => setState(() => _lifeIsMine = true),
          ),
        ),
        _Field(
          metrics: m,
          label: 'Talking',
          child: SlabSwitch(
            key: const Key('voice-toggle'),
            metrics: m,
            title: 'Voice chat',
            icon: Icons.mic_none_rounded,
            on: _voice,
            onChanged: (on) => setState(() => _voice = on),
          ),
        ),
      ],
    );
  }

  /// The three draft choices, shown only when the format is Draft: which set
  /// to open, sealed or a passing draft, and how many packs each.
  List<Widget> _draftFields(Metrics m, List<DraftSet> sets) {
    return [
      _Field(
        metrics: m,
        label: 'Set to draft',
        child: MenuRow(
          key: const Key('draft-set'),
          title: _draftSetName ?? 'Choose a set',
          subtitle: sets.isEmpty
              ? 'import MTGJSON sets first'
              : (_draftSetCode == null
                    ? 'from your imported sets'
                    : _draftSetCode!),
          icon: Icons.inventory_2_rounded,
          metrics: m,
          onActivate: () => _chooseSet(sets),
        ),
      ),
      _Field(
        metrics: m,
        label: 'How it plays',
        child: SlabSwitch(
          key: const Key('draft-sealed'),
          metrics: m,
          title: 'Sealed',
          subtitle: _sealed
              ? 'open your packs, build from all of them'
              : 'pick one card, pass the pack on',
          icon: Icons.style_rounded,
          on: _sealed,
          // Sealed is six packs of your own, a draft is three passed around:
          // move the count to the usual one when the switch flips, unless the
          // host has already set their own.
          onChanged: (on) => setState(() {
            _sealed = on;
            _packs = on ? 6 : 3;
          }),
        ),
      ),
      _Field(
        metrics: m,
        label: 'Packs each',
        child: _Chairs(
          metrics: m,
          seats: _packs,
          choices: const [3, 4, 5, 6],
          noun: 'packs',
          onMove: _movePacks,
        ),
      ),
    ];
  }

  void _movePacks(int by) => setState(() {
    final next = _packs + by;
    if (next < 3 || next > 6) return;
    _packs = next;
  });

  /// Opens the imported sets to pick one, or, with none imported, the Sources
  /// screen to import some first.
  Future<void> _chooseSet(List<DraftSet> sets) async {
    if (sets.isEmpty) {
      await Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const SourcesScreen()));
      return;
    }
    final media = MediaQuery.of(context);
    final m = Metrics.of(
      classifyDevice(
        size: media.size,
        hasTouch: media.navigationMode == NavigationMode.traditional,
      ),
    );
    final picked = await showModalBottomSheet<DraftSet>(
      context: context,
      backgroundColor: Palette.surface,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheet).size.height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final set in sets)
                MenuRow(
                  key: Key('draft-set-${set.code}'),
                  title: set.name,
                  subtitle: '${set.code} · ${set.totalSetSize} cards',
                  icon: Icons.inventory_2_rounded,
                  leading: _SetSymbol(url: set.symbolUrl, metrics: m),
                  metrics: m,
                  autofocus: set.code == _draftSetCode,
                  onActivate: () => Navigator.of(sheet).pop(set),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        _draftSetCode = picked.code;
        _draftSetName = picked.name;
      });
    }
  }

  /// Opens the five formats to choose from, and closes on the choice.
  Future<void> _chooseFormat() async {
    final media = MediaQuery.of(context);
    final m = Metrics.of(
      classifyDevice(
        size: media.size,
        hasTouch: media.navigationMode == NavigationMode.traditional,
      ),
    );
    final picked = await showModalBottomSheet<DeckFormat>(
      context: context,
      backgroundColor: Palette.surface,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final format in DeckFormat.values)
              MenuRow(
                key: Key('format-${format.name}'),
                title: format.label,
                subtitle: format == _format
                    ? '${_describe(format)} · picked'
                    : _describe(format),
                icon: _iconFor(format),
                metrics: m,
                autofocus: format == _format,
                onActivate: () => Navigator.of(sheet).pop(format),
              ),
          ],
        ),
      ),
    );
    if (picked != null) _pickFormat(picked);
  }

  void _pickFormat(DeckFormat format) => setState(() {
    _format = format;
    if (!_lifeIsMine) _life.text = '${format.startingLife}';
  });

  /// One step along [roomSeatChoices], or nothing at all at an end.
  ///
  /// Clamped and never wrapped. A stepper that came round to the other end
  /// would have lied to whoever pressed it: minus means fewer, and at the
  /// fewest there are none.
  void _moveSeats(int by) => setState(() {
    final at = roomSeatChoices.indexOf(_seats) + by;
    if (at < 0 || at >= roomSeatChoices.length) return;
    _seats = roomSeatChoices[at];
  });

  /// What a format means for a table, which is not what it means for a deck.
  ///
  /// The game is in here because two of the formats are both called Standard,
  /// and on one list the game is the only thing that tells them apart.
  static String _describe(DeckFormat format) {
    final stakes = format.winsByPrizes
        ? 'prize cards'
        : '${format.startingLife} life';
    return '${Game.of(format).label} · ${format.deckSize} cards · $stakes';
  }

  /// Read off [Game.formats] rather than named again here, so a format that
  /// belongs to a game nobody listed is loud rather than mislabelled.

  static IconData _iconFor(DeckFormat format) => switch (format) {
    DeckFormat.commander => Icons.groups_rounded,
    DeckFormat.standard => Icons.shield_rounded,
    DeckFormat.pauper => Icons.savings_rounded,
    DeckFormat.draft => Icons.inventory_2_rounded,
    DeckFormat.pokemonStandard => Icons.catching_pokemon_rounded,
  };

  void _open() {
    final life = _lifeTyped;
    if (life == null) return;

    final config = RoomConfig(
      voice: _voice,
      format: _format,
      seats: _seats,
      life: life,
      draft: _format == DeckFormat.draft
          ? DraftOptions(setCode: _draftSetCode, sealed: _sealed, packs: _packs)
          : null,
      // Read and not asked for. A name is the same in every room somebody
      // joins, so it lives with them in settings, and the room still carries
      // who made it.
      hostName: ref.read(yourNameProvider),
      roomName: _trimmed(_roomName, 'the kitchen table'),
    );
    ref.read(roomProvider.notifier).open(config);

    // Replaced rather than pushed. These settings have been answered and going
    // back to them from the room would offer to change a room that already has
    // a code out in the world; back from the room is the menu.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const RoomScreen()),
    );
  }

  static String _trimmed(TextEditingController c, String fallback) =>
      c.text.trim().isEmpty ? fallback : c.text.trim();
}

/// Chairs, as a number with two ends.
///
/// A stepper rather than a row you tap, because chairs are a count: minus takes
/// one away, plus adds one, and the number is on the screen the whole time
/// instead of only after a press.
class _Chairs extends StatelessWidget {
  const _Chairs({
    required this.metrics,
    required this.seats,
    required this.onMove,
    this.choices = roomSeatChoices,
    this.noun = 'chairs',
  });

  final Metrics metrics;
  final int seats;
  final ValueChanged<int> onMove;

  /// The values the stepper may land on, in order. Chairs by default; the
  /// draft reuses this for packs with its own range.
  final List<int> choices;
  final String noun;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final at = choices.indexOf(seats);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Step(
              key: const Key('seats-down'),
              metrics: m,
              icon: Icons.remove_rounded,
              atEnd: at <= 0,
              onTap: () => onMove(-1),
            ),
            SizedBox(width: m.scaled(10)),
            Well(
              metrics: m,
              padding: EdgeInsets.symmetric(
                horizontal: m.scaled(22),
                vertical: m.scaled(7),
              ),
              child: Text(
                '$seats',
                key: const Key('seats-count'),
                style: pixel(size: m.scaled(24), weight: 700),
              ),
            ),
            SizedBox(width: m.scaled(10)),
            _Step(
              key: const Key('seats-up'),
              metrics: m,
              icon: Icons.add_rounded,
              atEnd: at >= choices.length - 1,
              onTap: () => onMove(1),
            ),
          ],
        ),
        SizedBox(height: m.scaled(6)),
        Text(
          _note,
          key: const Key('seats-note'),
          style: pixel(
            size: m.scaled(11),
            weight: 500,
            height: 1.45,
            color: Palette.inkFaint,
          ),
        ),
      ],
    );
  }

  /// Which way there is still room to go, and at an end, that there is not.
  ///
  /// A dimmed button on its own is a button somebody presses twice before
  /// believing it, so the end says so in words as well.
  String get _note {
    if (seats <= choices.first) return '${choices.first} is the fewest';
    if (seats >= choices.last) return '${choices.last} is the most';
    return '${choices.first} to ${choices.last} $noun';
  }
}

/// Minus or plus, as a small square slab.
///
/// The press is **not** gated on [atEnd], and that is deliberate. The stepper's
/// own clamp is the one thing that decides what a press does, and a button that
/// refused to call it as well would double guard it: a probe that made the
/// clamp wrap left every case green, because the dead button meant the wrapping
/// line was never reached. [atEnd] draws the end, which is what Slab's dimmed
/// flag is for. The clamp is the end.
class _Step extends StatelessWidget {
  const _Step({
    super.key,
    required this.metrics,
    required this.icon,
    required this.atEnd,
    required this.onTap,
  });

  final Metrics metrics;
  final IconData icon;
  final bool atEnd;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return Slab(
      metrics: m,
      tone: SlabTone.plain,
      dimmed: atEnd,
      depth: m.scaled(4),
      onActivate: onTap,
      semanticLabel: icon == Icons.remove_rounded
          ? 'Fewer chairs'
          : 'More chairs',
      padding: EdgeInsets.all(m.scaled(8)),
      child: Icon(icon, size: m.scaled(20), color: Palette.slabInk),
    );
  }
}

/// A labelled box. The rest of the app is rows, and a bare text field in a list
/// of rows reads as a gap rather than as something to fill in.
class _Field extends StatelessWidget {
  const _Field({
    required this.metrics,
    required this.label,
    required this.child,
  });

  final Metrics metrics;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return Padding(
      padding: EdgeInsets.only(bottom: m.scaled(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: pixel(
              size: m.scaled(10),
              weight: 500,
              letterSpacing: 1.2,

              color: Palette.inkFaint,
            ),
          ),
          SizedBox(height: m.scaled(6)),
          child,
        ],
      ),
    );
  }
}

/// The set's symbol off Scryfall, in the row's ink. A small spinner holds
/// the space while it is on its way, so the row does not flash a box icon
/// and then swap it; the box stands in only if the symbol never arrives.
class _SetSymbol extends StatelessWidget {
  const _SetSymbol({required this.url, required this.metrics});

  final String url;
  final Metrics metrics;

  @override
  Widget build(BuildContext context) {
    final size = metrics.scaled(20);
    return SvgPicture.network(
      url,
      width: size,
      height: size,
      colorFilter: const ColorFilter.mode(Palette.slabInk, BlendMode.srcIn),
      placeholderBuilder: (_) => SizedBox.square(
        dimension: size * 0.7,
        child: const CircularProgressIndicator(
          strokeWidth: 2,
          color: Palette.slabInk,
        ),
      ),
      errorBuilder: (_, _, _) =>
          Icon(Icons.inventory_2_rounded, size: size, color: Palette.slabInk),
    );
  }
}
