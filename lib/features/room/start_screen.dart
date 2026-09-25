import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../decks/model/deck_format.dart';
import '../../table/room/room.dart';
import '../../ui/atoms/hint_bar.dart';
import '../../ui/atoms/menu_row.dart';
import '../../ui/atoms/text_field_box.dart';
import '../../ui/organisms/screen_frame.dart';
import '../../ui/tokens/metrics.dart';
import '../../ui/tokens/palette.dart';
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
  final _hostName = TextEditingController();
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
    _hostName.dispose();
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
          label: 'Your name',
          child: TextFieldBox(
            key: const Key('host-name'),
            metrics: m,
            controller: _hostName,
            hint: 'you',
            onChanged: (_) => setState(() {}),
          ),
        ),
        MenuRow(
          key: const Key('format-row'),
          title: 'Format',
          subtitle: '${_format.label} · ${_format.deckSize} cards',
          icon: Icons.rule_rounded,
          metrics: m,
          autofocus: true,
          onActivate: _nextFormat,
        ),
        MenuRow(
          key: const Key('seats-row'),
          title: 'Chairs',
          subtitle: _seats == 2 ? 'two of you' : '$_seats of you',
          icon: Icons.chair_rounded,
          metrics: m,
          onActivate: _nextSeats,
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

  void _nextFormat() => setState(() {
        final values = DeckFormat.values;
        _format = values[(values.indexOf(_format) + 1) % values.length];
        if (!_lifeIsMine) _life.text = '${_format.startingLife}';
      });

  void _nextSeats() => setState(() {
        final at = roomSeatChoices.indexOf(_seats);
        _seats = roomSeatChoices[(at + 1) % roomSeatChoices.length];
      });

  void _open() {
    final life = _lifeTyped;
    if (life == null) return;

    final config = RoomConfig(
      format: _format,
      seats: _seats,
      life: life,
      hostName: _trimmed(_hostName, 'you'),
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
