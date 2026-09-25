import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../decks/model/deck_format.dart';
import '../../decks/model/game.dart';
import '../../table/room/room.dart';
import '../../ui/atoms/hint_bar.dart';
import '../../ui/atoms/menu_row.dart';
import '../../ui/atoms/text_field_box.dart';
import '../../ui/organisms/screen_frame.dart';
import '../../ui/tokens/metrics.dart';
import '../../ui/tokens/palette.dart';
import '../settings/player_name.dart';
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
  final _roomName = TextEditingController();
  final _life = TextEditingController();

  DeckFormat _format = DeckFormat.commander;
  int _seats = roomSeatChoices.first;

  /// Whether the life box holds a number somebody chose.
  ///
  /// Until it does, changing the format moves it, because forty against twenty
  /// is the format talking. After it does, the format leaves it alone: a room
  /// playing Commander to thirty is a room, and having the number snap back
  /// would read as the app arguing.
  bool _lifeIsMine = false;

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
  int? get _lifeTyped =>
      _life.text.trim().isEmpty ? _format.startingLife : int.tryParse(_life.text.trim());

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final m = Metrics.of(classifyDevice(
      size: media.size,
      hasTouch: media.navigationMode == NavigationMode.traditional,
    ));
    final life = _lifeTyped;

    return ScreenFrame(
      metrics: m,
      title: 'Start a table',
      label: 'the room comes first',
      onBack: () => Navigator.of(context).maybePop(),
      hints: const [
        Hint(button: HintBar.dpad, label: 'move'),
        Hint(button: 'A', label: 'change'),
        Hint(button: 'B', label: 'back'),
      ],
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
          // A closed list, so all of it is on the screen and one of them is
          // picked. The row that cycled was a control the shape of a counter
          // over a choice with five answers: to see the fifth you pressed four
          // times, and the four you skipped never appeared at all.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                  onActivate: () => _pickFormat(format),
                ),
            ],
          ),
        ),
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
        MenuRow(
          key: const Key('make-room'),
          title: 'Make the room',
          subtitle: life == null
              ? 'starting life has to be a number'
              : 'and get a code to hand out',
          icon: Icons.meeting_room_rounded,
          enabled: life != null,
          metrics: m,
          onActivate: _open,
        ),
      ],
    );
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
    final stakes =
        format.winsByPrizes ? 'prize cards' : '${format.startingLife} life';
    return '${_gameOf(format).label} · ${format.deckSize} cards · $stakes';
  }

  /// Read off [Game.formats] rather than named again here, so a format that
  /// belongs to a game nobody listed is loud rather than mislabelled.
  static Game _gameOf(DeckFormat format) =>
      Game.values.firstWhere((game) => game.formats.contains(format));

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
      format: _format,
      seats: _seats,
      life: life,
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
  });

  final Metrics metrics;
  final int seats;
  final ValueChanged<int> onMove;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final at = roomSeatChoices.indexOf(seats);

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
            SizedBox(width: m.scaled(16)),
            Text(
              '$seats',
              key: const Key('seats-count'),
              style: TextStyle(
                fontSize: m.scaled(24),
                fontWeight: FontWeight.w700,
                color: Palette.ink,
              ),
            ),
            SizedBox(width: m.scaled(16)),
            _Step(
              key: const Key('seats-up'),
              metrics: m,
              icon: Icons.add_rounded,
              atEnd: at >= roomSeatChoices.length - 1,
              onTap: () => onMove(1),
            ),
          ],
        ),
        SizedBox(height: m.scaled(6)),
        Text(
          _note,
          key: const Key('seats-note'),
          style: TextStyle(
            fontSize: m.scaled(11),
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
    if (seats <= roomSeatChoices.first) {
      return '${roomSeatChoices.first} is as few as a table gets, '
          'and it goes up to ${roomSeatChoices.last}';
    }
    if (seats >= roomSeatChoices.last) {
      return '${roomSeatChoices.last} is as many as fits, '
          'and it goes down to ${roomSeatChoices.first}';
    }
    return 'anything from ${roomSeatChoices.first} '
        'to ${roomSeatChoices.last} chairs';
  }
}

/// Minus or plus. Dimmed the same way a dead row is, rather than missing, so
/// the control keeps its shape when one end of it has nothing left to do.
///
/// The press is **not** gated on [atEnd], and that is deliberate. The stepper's
/// own clamp is the one thing that decides what a press does, and a button that
/// refused to call it as well would double guard it: a probe that made the
/// clamp wrap left every case green, because the dead button meant the wrapping
/// line was never reached. [atEnd] draws the end. The clamp is the end.
///
/// Focusable, because this app is a D-pad before it is a touchscreen and the
/// hint bar promises the pad moves. MaterialApp maps the pad's A button to
/// ActivateIntent and WidgetsApp has no handler for it, so without the action
/// below the pill would take focus and do nothing when pressed, which is the
/// same trap MenuRow documents.
class _Step extends StatefulWidget {
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
  State<_Step> createState() => _StepState();
}

class _StepState extends State<_Step> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.metrics;

    return FocusableActionDetector(
      onFocusChange: (v) => setState(() => _focused = v),
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap();
            return null;
          },
        ),
      },
      child: Semantics(
        button: true,
        // Says it does nothing now, which is true: the clamp makes it a no-op.
        enabled: !widget.atEnd,
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Opacity(
            opacity: widget.atEnd ? 0.42 : 1,
            child: Container(
              width: m.scaled(40),
              height: m.scaled(40),
              decoration: BoxDecoration(
                color: _focused ? Palette.tileFocused : Palette.tile,
                borderRadius: BorderRadius.circular(m.scaled(10)),
                border: Border.all(
                  color: _focused ? Palette.accent : Palette.tileEdge,
                  width: _focused ? m.focusRing : 1,
                ),
              ),
              child: Icon(
                widget.icon,
                size: m.scaled(20),
                color: _focused ? Palette.accent : Palette.inkMuted,
              ),
            ),
          ),
        ),
      ),
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
            style: TextStyle(
              fontSize: m.scaled(10),
              letterSpacing: 1.2,
              fontWeight: FontWeight.w500,
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
