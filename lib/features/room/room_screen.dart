import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../table/room/room.dart';
import '../../table/shuffle.dart';
import '../../ui/atoms/hint_bar.dart';
import '../../ui/atoms/menu_row.dart';
import '../../ui/atoms/toast.dart';
import '../../ui/organisms/screen_frame.dart';
import '../../ui/tokens/metrics.dart';
import '../../ui/tokens/palette.dart';
import '../decks/play_decks_screen.dart';
import '../lobby/lobby.dart';
import '../menu/menu_screen.dart';
import '../play/play_controller.dart';
import '../play/play_screen.dart';
import 'room_controller.dart';

/// The commit this build was made from, handed in as `--dart-define=BUILD=`
/// by whoever builds; "dev" when nobody did.
const buildStamp = String.fromEnvironment('BUILD', defaultValue: 'dev');

/// The room, which is a place before it is a game.
///
/// It holds the three ways in, in the order they are useful: the code you read
/// out to somebody across the table, the link you send to somebody who is not,
/// and the same link as a square for their camera. Under them, what the
/// connection has found out so far, stated as facts, then the chairs and who is
/// in them, then the deck.
class RoomScreen extends ConsumerWidget {
  const RoomScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = MediaQuery.of(context);
    final m = Metrics.of(
      classifyDevice(
        size: media.size,
        hasTouch: media.navigationMode == NavigationMode.traditional,
      ),
    );
    final room = ref.watch(roomProvider);

    // The moment the table is here, a guest is put in front of it. The host
    // opens it itself when it deals, and a table arriving twice is not a
    // thing: the mesh hands it over once, and this fires on the turn.
    ref.listen(dealtProvider, (was, dealt) {
      if (dealt && was != true) _sitDown(context, ref);
    });

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
    final lobby = ref.watch(lobbyProvider);
    final reach = ref.watch(reachProvider);
    // The host's own, or what the host said when it answered: a guest has no
    // settings of its own to show and shows none until then.
    final config = room.config ?? lobby?.config;
    final empty = lobby?.emptyChairs ?? const <int>[];
    final somebodyElse =
        lobby != null && lobby.seated.any((s) => s.peer != lobby.me);

    return ScreenFrame(
      metrics: m,
      title: config?.roomName.trim().isNotEmpty == true
          ? config!.roomName.trim()
          : room.title,
      label: config == null
          ? 'somebody else\'s room'
          : '${config.format.label} · '
                '${_chairsLabel(config.seats, lobby == null ? null : empty)}'
                ' · ${config.life} life',
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
            // The front half of the link is only where the app is downloaded
            // from; the table itself lives on this phone. Said so, because a
            // link that starts with somebody else's domain reads as somebody
            // else's server.
            subtitle: 'it opens the app and brings them to your phone',
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
            text:
                'No link from this build: a link points at the web version, '
                'and this one is not served anywhere. Read the code out, or '
                'let somebody type it in.',
          ),
        // What the connection has said, one fact per line, in the order they
        // happen. Somebody holding a phone that will not connect is owed the
        // step it stopped at, not a spinner.
        _Fact(
          metrics: m,
          id: 'room-relay',
          done: reach.relayAnswered,
          failed: reach.relayUnreachable,
          text: reach.relayUnreachable
              ? 'Relay: none could be reached, so nobody can find this room'
              : reach.relayAnswered
                  ? 'Relay: accepted this room, so it can be found'
                  : 'Relay: reaching one',
        ),
        // Said in the relay's own words, since they are the only ones there
        // are: "rate-limited: you are noting too much" is what damus says
        // after a burst, and a phone that trickled its candidates hit it.
        if (reach.refused != null)
          _Fact(
            metrics: m,
            id: 'room-refused',
            failed: true,
            text: 'A relay refused this phone\'s message (${reach.refused})',
          ),
        _Fact(
          metrics: m,
          id: 'room-stun',
          done: reach.stunAnswered,
          text: reach.stunAnswered
              ? 'STUN: answered, so this phone knows its own address'
              : 'STUN: waiting for an answer',
        ),
        for (final peer in reach.open)
          _Fact(
            metrics: m,
            id: 'room-peer-$peer',
            done: true,
            text: _peerWords(lobby, peer),
          ),
        // Heard but not yet connected. On the first two-phone check the host
        // heard the phone and the link never opened, and this screen said
        // "chair 2: empty" with no hint that anybody had been seen.
        for (final peer in reach.seen.difference(reach.open))
          if (!reach.failed.containsKey(peer))
            _Fact(
              metrics: m,
              id: 'room-seen-$peer',
              // With the link's last word about itself, so a screenshot of
              // this line says where it stopped.
              text: reach.progress[peer] == null
                  ? 'Somebody found this room and is connecting'
                  : 'Somebody found this room and is connecting '
                      '(${reach.progress[peer]})',
            ),
        // Failed for a reason a TURN server would not fix. Said with the
        // reason, because a failure with no line is a failure nobody can
        // report.
        for (final entry in reach.failed.entries)
          if (entry.value.needsTurn != true)
            _Fact(
              metrics: m,
              id: 'room-failed-${entry.key}',
              failed: true,
              text: 'Could not connect to ${_peerName(lobby, entry.key)}: '
                  '${entry.value.reason}',
            ),
        if (reach.needsTurn case final failure?)
          _Fact(
            metrics: m,
            id: 'room-turn',
            failed: true,
            text:
                '${_peerName(lobby, failure.peer)} could not be reached '
                'directly: both phones answered STUN and still could not reach '
                'each other, which only a relay for the connection itself '
                'fixes. Put a TURN server in Settings, under Network, on any '
                'one phone in the room, and try again.',
          ),
        if (lobby != null && !lobby.hosting)
          _Note(
            metrics: m,
            id: 'room-answer',
            colour: lobby.host == null ? Palette.attention : Palette.inkMuted,
            text: lobby.host == null
                ? 'Nobody has answered under this code yet. If the host is '
                    'here, their phone will answer as soon as the two connect.'
                : '${config!.hostName} answered: ${config.format.label}, '
                    '${config.seats} chairs, ${config.life} life.',
          ),
        if (lobby != null && config != null)
          _Chairs(metrics: m, lobby: lobby, seats: config.seats),
        // Which build this is, since a browser keeps the last one for hours
        // and a screenshot of an old sentence reads as the new code failing.
        _Note(
          metrics: m,
          id: 'room-build',
          colour: Palette.inkMuted,
          text: 'build $buildStamp',
        ),
        _Note(
          metrics: m,
          id: 'room-openness',
          colour: Palette.attention,
          // Plainly, and in the words somebody holding cards would use.
          // "Unencrypted" is a sentence about software; this is a sentence
          // about their hand, which is the thing they would have assumed was
          // theirs.
          text:
              'Everybody in this room can see everything in it. Your hand and '
              'your deck are sent to the other phones as they are, and what '
              'keeps a card face down is their copy of the app choosing not to '
              'draw it. Fine for friends at a kitchen table. Not safe against '
              'somebody who wants to cheat, and not private.',
        ),
        if (lobby != null && lobby.full)
          _Note(
            metrics: m,
            id: 'room-full',
            colour: Palette.attention,
            text: 'The room is full: ${config!.seats} chairs and every one of '
                'them taken. You can watch once the table is dealt.',
          ),
        if (lobby != null && lobby.mesh != null && !lobby.hosting)
          _Note(
            metrics: m,
            id: 'room-dealt',
            colour: Palette.accent,
            text: lobby.dealt
                ? '${config!.hostName} dealt the table and your phone has it.'
                : 'The host dealt the table. Waiting for it to arrive.',
          ),
        MenuRow(
          key: const Key('room-deck'),
          title: lobby != null && lobby.seatedHere
              ? 'Pick a different deck'
              : 'Pick your deck and sit down',
          subtitle: lobby != null && lobby.seatedHere
              ? 'you are in chair ${_chairOf(lobby)}'
              : config == null
                  ? 'whatever you brought'
                  : 'for ${config.format.label}, starting on ${config.life}',
          icon: Icons.style_rounded,
          metrics: m,
          autofocus: true,
          onActivate: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const PlayDecksScreen()),
          ),
        ),
        if (lobby != null && lobby.hosting && config != null)
          MenuRow(
            key: const Key('room-start'),
            title: 'Start',
            // Dimmed rather than missing while a chair is empty, and the
            // subtitle says which, so the host knows who they are waiting on
            // rather than why a button is grey.
            subtitle: lobby.dealt ? 'the table is dealt' : startWords(empty),
            icon: Icons.play_arrow_rounded,
            enabled: lobby.canStart,
            metrics: m,
            onActivate: () => _start(context, ref, lobby, config),
          ),
        // Only for the host, whose chairs they are, and only until a real
        // person has taken one: it is still true that this device can play
        // every hand, and it stops being the only way the moment somebody
        // arrives.
        if (room.config case final own? when own.seats > 1 && !somebodyElse)
          MenuRow(
            key: const Key('room-fill'),
            // Said rather than implied. This row used to live on the deck
            // picker as "More than one seat", over "collect several decks and
            // deal them as one table", and a player reading that had to work
            // out for themselves that it meant playing everybody at the table.
            title: 'Fill the other chairs from this device',
            subtitle:
                'bring a deck for each chair and play all '
                '${own.seats} hands yourself, if nobody else is coming.',
            icon: Icons.group_add_rounded,
            metrics: m,
            onActivate: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PlayDecksScreen(chairs: own.seats),
              ),
            ),
          ),
      ],
    );
  }

  /// "2 of 4 chairs empty", or that every one is taken. Null empties is a
  /// room with no lobby to count them, which says only how many there are.
  static String _chairsLabel(int seats, List<int>? empty) {
    if (empty == null) return '$seats chairs';
    if (empty.isEmpty) return '$seats chairs, every one taken';
    return '${empty.length} of $seats chairs empty';
  }

  static String _peerName(Lobby? lobby, String peer) =>
      lobby?.seated.where((s) => s.peer == peer).firstOrNull?.name ??
      'somebody';

  /// "ana connected", once ana has said who she is, and before that only that
  /// somebody has.
  static String _peerWords(Lobby? lobby, String peer) {
    final seat = lobby?.seated.where((s) => s.peer == peer).firstOrNull;
    return seat == null
        ? 'Somebody connected, and has not brought a deck yet'
        : '${seat.name} connected, with a deck';
  }

  /// Chair 1 is the host's. The seated list leaves it out while the host
  /// has not sat down, so a guest's chair is its place among the guests,
  /// counted from 2, and never its index in the list.
  static int _chairOf(Lobby lobby) {
    if (lobby.me == lobby.host) return 1;
    final guests = lobby.seated.where((s) => s.peer != lobby.host).toList();
    return guests.indexWhere((s) => s.peer == lobby.me) + 2;
  }

  void _copy(BuildContext context, String link) {
    Clipboard.setData(ClipboardData(text: link));
    Toast.show(context, 'Link copied', icon: Icons.check_rounded);
  }

  /// Deals everybody in, on this phone, and opens the table. The lobby hands
  /// the transport to the mesh in the same call, so from here on the guests
  /// hear the table and not the chairs.
  void _start(
    BuildContext context,
    WidgetRef ref,
    Lobby lobby,
    RoomConfig config,
  ) {
    final play = ref.read(playProvider.notifier);
    final mesh = lobby.start((players) {
      play.startPod(players: players, seed: freshSeed(), life: config.life);
      return ref.read(playProvider)!;
    });
    // From here on a verb this phone runs goes through the mesh, and one a
    // guest runs comes back through it.
    play.follow(mesh);
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PlayScreen()),
    );
  }

  /// A guest sits down at the table the host dealt, and the screen opens on
  /// it the way the host's does. The host is not seated here: it dealt, and
  /// [_start] already opened its table.
  void _sitDown(BuildContext context, WidgetRef ref) {
    final lobby = ref.read(lobbyProvider);
    final mesh = lobby?.mesh;
    if (lobby == null || lobby.hosting || mesh?.table == null) return;

    ref.read(playProvider.notifier).join(mesh!, decks: lobby.decks);
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PlayScreen()),
    );
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

/// The chairs, one line each, numbered the way the start button numbers them.
class _Chairs extends StatelessWidget {
  const _Chairs({required this.metrics, required this.lobby, required this.seats});

  final Metrics metrics;
  final Lobby lobby;
  final int seats;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return Padding(
      key: const Key('room-chairs'),
      padding: EdgeInsets.only(bottom: m.scaled(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var chair = 1; chair <= seats; chair++)
            Padding(
              padding: EdgeInsets.only(bottom: m.scaled(4)),
              child: Text(
                _words(chair),
                key: Key('room-chair-$chair'),
                style: TextStyle(
                  fontSize: m.scaled(12),
                  height: 1.4,
                  color: _in(chair) == null ? Palette.inkFaint : Palette.ink,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Who is in a chair. Chair 1 is the host's, and the seated list leaves it
  /// out while the host has not sat down, so the guests are counted from 2
  /// on their own and never by their index in the list.
  Seated? _in(int chair) {
    if (chair == 1) {
      return lobby.seated.where((s) => s.peer == lobby.host).firstOrNull;
    }
    final guests = lobby.seated.where((s) => s.peer != lobby.host).toList();
    return chair - 2 < guests.length ? guests[chair - 2] : null;
  }

  /// An empty chair 1 is the host not sat down yet and never somebody
  /// else's to take.
  String _words(int chair) {
    final who = _in(chair);
    if (who != null) {
      final you = who.peer == lobby.me ? ' (you)' : '';
      return 'chair $chair: ${who.name}$you';
    }
    if (chair == 1) {
      return lobby.hosting
          ? 'chair 1: yours, once you pick a deck'
          : 'chair 1: the host, not sat down yet';
    }
    return 'chair $chair: empty';
  }
}

/// One thing the connection found out, as a line with a mark in front of it.
class _Fact extends StatelessWidget {
  const _Fact({
    required this.metrics,
    required this.id,
    required this.text,
    this.done = false,
    this.failed = false,
  });

  final Metrics metrics;
  final String id;
  final String text;
  final bool done;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final colour = failed
        ? Palette.attention
        : done
            ? Palette.accent
            : Palette.inkFaint;

    return Padding(
      padding: EdgeInsets.only(bottom: m.scaled(6)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: m.scaled(5), right: m.scaled(8)),
            child: Icon(
              failed
                  ? Icons.close_rounded
                  : done
                      ? Icons.check_rounded
                      : Icons.more_horiz_rounded,
              size: m.scaled(12),
              color: colour,
            ),
          ),
          Expanded(
            child: Text(
              text,
              key: Key(id),
              style: TextStyle(
                fontSize: m.scaled(12),
                height: 1.4,
                color: failed ? Palette.attention : Palette.inkMuted,
              ),
            ),
          ),
        ],
      ),
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
              // What the code is, said in the terms of the person holding the
              // phone. It is how a friend finds this table: they type it into
              // Join, or open the link, and their phone connects to yours.
              'read it out, or send the link. Either one brings a friend to '
              'this table, on your phone, from anywhere.',
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
          border: Border(
            left: BorderSide(color: colour, width: m.scaled(3)),
          ),
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
