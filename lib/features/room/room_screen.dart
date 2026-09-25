import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../table/room/room.dart';
import '../../ui/atoms/hint_bar.dart';
import '../../ui/atoms/menu_row.dart';
import '../../ui/atoms/toast.dart';
import '../../ui/organisms/screen_frame.dart';
import '../../ui/tokens/metrics.dart';
import '../../ui/tokens/palette.dart';
import '../decks/play_decks_screen.dart';
import '../menu/menu_screen.dart';
import 'room_controller.dart';

/// The room, which is a place before it is a game.
///
/// It holds the three ways in, in the order they are useful: the code you read
/// out to somebody across the table, the link you send to somebody who is not,
/// and the same link as a square for their camera. Under them, the two things
/// this room is not, and then the deck.
class RoomScreen extends ConsumerWidget {
  const RoomScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = MediaQuery.of(context);
    final m = Metrics.of(classifyDevice(
      size: media.size,
      hasTouch: media.navigationMode == NavigationMode.traditional,
    ));
    final room = ref.watch(roomProvider);

    // Nobody should reach this screen without a room, and the one way it could
    // happen is a rebuild the instant after leaving. An empty frame beats a
    // crash on the way out.
    if (room == null) {
      return ScreenFrame(
        metrics: m,
        title: 'No room',
        label: 'nothing to show',
        onBack: () => Navigator.of(context).maybePop(),
        hints: const [Hint(button: 'B', label: 'back')],
        children: const [],
      );
    }

    final origin = ref.watch(roomOriginProvider);
    final link = origin == null ? null : linkFor(room.code, origin: origin);
    final config = room.config;

    return ScreenFrame(
      metrics: m,
      title: room.title,
      label: config == null
          ? 'somebody else\'s room'
          : '${config.format.label} · ${config.seats} chairs · '
              '${config.life} life',
      onBack: () => _leave(context, ref),
      hints: const [
        Hint(button: HintBar.dpad, label: 'move'),
        Hint(button: 'A', label: 'open'),
        Hint(button: 'B', label: 'leave'),
      ],
      children: [
        _Code(metrics: m, code: room.code),
        if (link != null) ...[
          _Link(metrics: m, link: link),
          MenuRow(
            key: const Key('room-copy'),
            title: 'Copy the link',
            subtitle: 'send it to whoever is not in the kitchen',
            icon: Icons.link_rounded,
            metrics: m,
            onActivate: () => _copy(context, link),
          ),
          RoomQr(key: const Key('room-qr'), metrics: m, link: link),
        ] else
          _Note(
            metrics: m,
            id: 'room-no-link',
            colour: Palette.inkMuted,
            text: 'No link from this build: a link points at the web version, '
                'and this one is not served anywhere. Read the code out, or '
                'let somebody type it in.',
          ),
        _Note(
          metrics: m,
          id: 'room-openness',
          colour: Palette.attention,
          // Plainly, and in the words somebody holding cards would use.
          // "Unencrypted" is a sentence about software; this is a sentence
          // about their hand, which is the thing they would have assumed was
          // theirs.
          text: 'Everybody in this room can see everything in it. Your hand and '
              'your deck are sent to the other phones as they are, and what '
              'keeps a card face down is their copy of the app choosing not to '
              'draw it. Fine for friends at a kitchen table. Not safe against '
              'somebody who wants to cheat, and not private.',
        ),
        _Note(
          metrics: m,
          id: 'room-reach',
          colour: Palette.inkMuted,
          text: 'Nobody can actually arrive yet: carrying people between phones '
              'is the next piece of work. The code and the link are real, and '
              'for now the only chair that fills is yours.',
        ),
        MenuRow(
          key: const Key('room-deck'),
          title: 'Pick your deck and sit down',
          subtitle: config == null
              ? 'whatever you brought'
              : 'for ${config.format.label}, starting on ${config.life}',
          icon: Icons.style_rounded,
          metrics: m,
          autofocus: true,
          onActivate: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const PlayDecksScreen()),
          ),
        ),
      ],
    );
  }

  void _copy(BuildContext context, String link) {
    Clipboard.setData(ClipboardData(text: link));
    Toast.show(context, 'Link copied', icon: Icons.check_rounded);
  }

  /// Leaving ends the room for this device. Back from here is the menu, and on
  /// a browser tab opened from a link there is nothing behind this screen to go
  /// back to, so the menu replaces it instead.
  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    ref.read(roomProvider.notifier).leave();

    if (await navigator.maybePop()) return;
    if (!context.mounted) return;
    navigator.pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const MenuScreen()),
    );
  }
}

/// The code, at the size of something you read across a table.
class _Code extends StatelessWidget {
  const _Code({required this.metrics, required this.code});

  final Metrics metrics;
  final String code;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return Padding(
      padding: EdgeInsets.only(bottom: m.scaled(14)),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: m.scaled(16),
          vertical: m.scaled(18),
        ),
        decoration: BoxDecoration(
          color: Palette.tile,
          borderRadius: BorderRadius.circular(m.scaled(14)),
          border: Border.all(color: Palette.tileEdge),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'THE CODE',
              style: TextStyle(
                fontSize: m.scaled(10),
                letterSpacing: 1.2,
                fontWeight: FontWeight.w500,
                color: Palette.inkFaint,
              ),
            ),
            SizedBox(height: m.scaled(8)),
            Text(
              code,
              key: const Key('room-code'),
              style: TextStyle(
                fontSize: m.scaled(34),
                fontWeight: FontWeight.w700,
                letterSpacing: m.scaled(4),
                color: Palette.accent,
              ),
            ),
            SizedBox(height: m.scaled(4)),
            Text(
              'nothing in it can be misheard: no o against 0, no l against 1',
              style: TextStyle(
                fontSize: m.scaled(11),
                height: 1.4,
                color: Palette.inkFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({required this.metrics, required this.link});

  final Metrics metrics;
  final String link;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return Padding(
      padding: EdgeInsets.only(bottom: m.scaled(10)),
      child: SelectionArea(
        child: Text(
          link,
          key: const Key('room-link'),
          style: TextStyle(
            fontSize: m.scaled(13),
            height: 1.4,
            color: Palette.ink,
          ),
        ),
      ),
    );
  }
}

/// The link as a square, on white, because a camera has to read it.
///
/// Public, and holding the link it was given, so a test can read the payload
/// back. `QrImageView` keeps its data private, which would leave a case able to
/// prove a QR was drawn and unable to prove what is in it: a room screen that
/// built the square from the wrong code would pass that.
class RoomQr extends StatelessWidget {
  const RoomQr({super.key, required this.metrics, required this.link});

  final Metrics metrics;
  final String link;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return Padding(
      padding: EdgeInsets.only(bottom: m.scaled(14)),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: EdgeInsets.all(m.scaled(10)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(m.scaled(10)),
          ),
          child: QrImageView(
            data: link,
            size: m.scaled(160),
            backgroundColor: Colors.white,
            semanticsLabel: 'A QR code of the link to this room',
          ),
        ),
      ),
    );
  }
}

/// A paragraph the player is meant to read rather than press.
class _Note extends StatelessWidget {
  const _Note({
    required this.metrics,
    required this.id,
    required this.text,
    required this.colour,
  });

  final Metrics metrics;
  final String id;
  final String text;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return Padding(
      padding: EdgeInsets.only(bottom: m.scaled(14)),
      child: Container(
        padding: EdgeInsets.all(m.scaled(12)),
        decoration: BoxDecoration(
          color: Palette.surface,
          borderRadius: BorderRadius.circular(m.scaled(10)),
          border: Border(left: BorderSide(color: colour, width: m.scaled(3))),
        ),
        child: Text(
          text,
          key: Key(id),
          style: TextStyle(
            fontSize: m.scaled(12),
            height: 1.5,
            color: Palette.inkMuted,
          ),
        ),
      ),
    );
  }
}
