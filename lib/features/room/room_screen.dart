import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../table/room/room.dart';
import '../../table/shuffle.dart';
import '../../ui/atoms/menu_row.dart';
import '../../ui/atoms/slab.dart';
import '../../ui/atoms/toast.dart';
import '../../ui/atoms/tray.dart';
import '../../ui/organisms/screen_frame.dart';
import '../../ui/tokens/app_palette.dart';
import '../../ui/tokens/lettering.dart';
import '../../ui/tokens/metrics.dart';
import '../../ui/tokens/palette.dart';
import '../decks/play_decks_screen.dart';
import '../lobby/lobby.dart';
import '../menu/menu_screen.dart';
import '../play/play_controller.dart';
import '../play/play_screen.dart';
import 'room_controller.dart';
import '../../ui/atoms/pressable.dart';

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
        children: const [],
      );
    }

    final link = linkFor(room.code, origin: ref.watch(roomOriginProvider));
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
      children: [
        // Who is here. A lobby is the people in it, which is what every
        // client the benchmark read puts first and this screen had thirteen
        // blocks above.
        if (lobby != null && config != null)
          _Seats(
            metrics: m,
            lobby: lobby,
            seats: config.seats,
            // Connected, and no deck yet, so the lobby has given them no
            // chair. They belong in the chairs card all the same: somebody
            // who has arrived and is choosing is the thing a host is
            // waiting on, and it used to be a line in the diagnostics.
            arriving: reach.open
                .where((p) => !lobby.seated.any((s) => s.peer == p))
                .toList(),
          ),

        // Three ways of bringing somebody in, and they are all the same
        // seven characters. The code is the room: it is what every phone
        // turns into the same relays and the same channel. The link carries
        // it to somebody who does not have the app open, the QR carries it
        // across a table, and the code itself is for somebody who already
        // has the app open at Join.
        MenuRow(
          key: const Key('room-copy'),
          title: 'Send the link',
          icon: Icons.ios_share_rounded,
          tone: SlabTone.cool,
          metrics: m,
          onActivate: () => _copy(context, link),
        ),
        _Invite(
          metrics: m,
          link: link,
          code: room.code,
          onCopyCode: () => _copyCode(context, room.code),
        ),

        // What you do now, said once. The deck is the thing a player has to
        // understand here and it was the nineteenth block on the screen.
        MenuRow(
          key: const Key('room-deck'),
          title: lobby != null && lobby.seatedHere
              ? 'Change your deck'
              : 'Pick your deck',
          subtitle: lobby != null && lobby.seatedHere
              ? 'you are sitting in chair ${_chairOf(lobby)}'
              : 'to sit down',
          icon: Icons.style_rounded,
          // The one thing the host has to do before anything else can happen,
          // so it carries the colour the way Play does on the menu.
          tone: SlabTone.choice,
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
            tone: SlabTone.cool,
            enabled: lobby.canStart,
            metrics: m,
            onActivate: () => _start(context, ref, lobby, config),
          ),
        // The way back in. Back from the table lands here, and this screen
        // used to offer nothing for it: Start was dead with "the table is
        // dealt" under it, which is a sentence about the past, and somebody
        // who had stepped out for a second had no door to go back through.
        // Shown to the host and the guest alike, because both can step out.
        if (lobby != null && lobby.dealt && ref.watch(playProvider) != null)
          MenuRow(
            key: const Key('room-back-to-table'),
            title: 'Back to the table',
            icon: Icons.table_restaurant_rounded,
            tone: SlabTone.choice,
            metrics: m,
            autofocus: true,
            onActivate: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const PlayScreen())),
          ),
        if (lobby != null && !lobby.hosting && lobby.host == null)
          _Fact(
            metrics: m,
            id: 'room-answer',
            text: 'Waiting for the host to answer.',
          ),
        if (lobby != null && lobby.mesh != null && !lobby.hosting)
          _Fact(
            metrics: m,
            id: 'room-dealt',
            done: lobby.dealt,
            text: lobby.dealt
                ? '${config!.hostName} dealt the table.'
                : 'The host dealt the table. Waiting for it to arrive.',
          ),

        // The connection, which is one line while it is working and several
        // when it is not. Nobody puts a STUN line in a lobby; this says the
        // state, and the detail only when something has gone wrong.
        if (reach.relayUnreachable)
          _Fact(
            metrics: m,
            id: 'room-relay',
            failed: true,
            text: 'No relay could be reached, so nobody can find this room.',
          )
        else if (!reach.relayAnswered)
          _Fact(metrics: m, id: 'room-relay', text: 'Making the room findable'),
        if (reach.refused != null)
          _Fact(
            metrics: m,
            id: 'room-refused',
            failed: true,
            text: 'A relay refused this phone\'s message (${reach.refused})',
          ),
        for (final peer in reach.seen.difference(reach.open))
          if (!reach.failed.containsKey(peer))
            _Fact(
              metrics: m,
              id: 'room-seen-$peer',
              text: reach.progress[peer] == null
                  ? 'Somebody found this room and is connecting'
                  : 'Somebody found this room and is connecting '
                        '(${reach.progress[peer]})',
            ),
        for (final entry in reach.failed.entries)
          if (entry.value.needsTurn != true)
            _Fact(
              metrics: m,
              id: 'room-failed-${entry.key}',
              failed: true,
              text:
                  'Could not connect to ${_peerName(lobby, entry.key)}: '
                  '${entry.value.reason}',
            ),
        if (reach.needsTurn case final failure?)
          _Fact(
            metrics: m,
            id: 'room-turn',
            failed: true,
            text:
                '${_peerName(lobby, failure.peer)} could not be reached '
                'directly: both phones answered STUN and still could not '
                'reach each other, which only a relay for the connection '
                'itself fixes. Put a TURN server in Settings, under Network, '
                'on any one phone in the room, and try again.',
          ),

        // A line rather than a row. It answers "nobody is coming", which is
        // not what this screen is for, and as a row with an icon it stood
        // level with Start and read as an equal way to play.
        if (room.config case final own? when own.seats > 1 && !somebodyElse)
          _Aside(
            metrics: m,
            id: 'room-fill',
            text: 'Nobody coming? Play all ${own.seats} hands here',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PlayDecksScreen(chairs: own.seats),
              ),
            ),
          ),
        if (lobby != null && lobby.full)
          _Fact(
            metrics: m,
            id: 'room-full',
            text:
                'Every chair is taken. You can watch once the table is '
                'dealt.',
          ),
        // One line, not five. The long version was the longest thing on the
        // screen and said four times over what this says once.
        _Fact(
          metrics: m,
          id: 'room-openness',
          text:
              'Everybody can see every hand and every deck. Fine for '
              'friends.',
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

  void _copyCode(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    Toast.show(context, 'Code copied', icon: Icons.check_rounded);
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
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const PlayScreen()));
  }

  /// A guest sits down at the table the host dealt, and the screen opens on
  /// it the way the host's does. The host is not seated here: it dealt, and
  /// [_start] already opened its table.
  void _sitDown(BuildContext context, WidgetRef ref) {
    final lobby = ref.read(lobbyProvider);
    final mesh = lobby?.mesh;
    if (lobby == null || lobby.hosting || mesh?.table == null) return;

    ref.read(playProvider.notifier).join(mesh!, decks: lobby.decks);
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const PlayScreen()));
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

/// The chairs and who is in them, which is what a lobby is for.
///
/// A card at the top of the screen rather than a list two thirds down it:
/// Jackbox pops an avatar in, Among Us stands the player in the room, and
/// the arrival is the feedback. Each chair carries a status of its own, so a
/// host waiting on somebody can see which somebody.
class _Seats extends StatelessWidget {
  const _Seats({
    required this.metrics,
    required this.lobby,
    required this.seats,
    this.arriving = const [],
  });

  final Metrics metrics;
  final Lobby lobby;
  final int seats;

  /// Peers that are connected and have brought no deck yet, so the lobby has
  /// seated none of them.
  final List<String> arriving;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final taken = [for (var c = 1; c <= seats; c++) _in(c)].nonNulls.length;

    return Padding(
      key: const Key('room-chairs'),
      padding: EdgeInsets.only(bottom: m.scaled(14)),
      child: Well(
        metrics: m,
        label: 'Chairs',
        trailing: Text(
          '$taken of $seats',
          key: const Key('room-chairs-count'),
          style: pixel(
            size: m.scaled(12),
            weight: 700,
            color: taken == seats ? context.palette.accent : Palette.inkMuted,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var chair = 1; chair <= seats; chair++) ...[
              if (chair > 1) SizedBox(height: m.scaled(8)),
              _Chair(
                metrics: m,
                chair: chair,
                name: _name(chair),
                status: _status(chair),
                here: _in(chair) != null,
                mine: _in(chair)?.peer == lobby.me,
              ),
            ],
            for (final peer in arriving) ...[
              SizedBox(height: m.scaled(8)),
              _Chair(
                key: Key('room-peer-$peer'),
                metrics: m,
                chair: null,
                name: 'Somebody',
                status: 'connected, picking a deck',
                here: true,
                mine: false,
              ),
            ],
          ],
        ),
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

  String _name(int chair) {
    final who = _in(chair);
    if (who != null) return who.peer == lobby.me ? 'You' : who.name;
    if (chair == 1) return lobby.hosting ? 'You' : 'The host';
    return 'Empty';
  }

  /// An empty chair 1 is the host not sat down yet and never somebody
  /// else's to take.
  String _status(int chair) {
    if (_in(chair) != null) return 'ready';
    if (chair == 1) {
      return lobby.hosting ? 'pick a deck to sit down' : 'not sat down yet';
    }
    return 'waiting for somebody';
  }
}

/// One chair: its number, who is in it, and what it is waiting for.
class _Chair extends StatelessWidget {
  const _Chair({
    super.key,
    required this.metrics,
    required this.chair,
    required this.name,
    required this.status,
    required this.here,
    required this.mine,
  });

  final Metrics metrics;

  /// The chair's number, or null for somebody who has arrived and has no
  /// chair yet.
  final int? chair;

  final String name;
  final String status;
  final bool here;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return Row(
      key: chair == null ? null : Key('room-chair-$chair'),
      children: [
        SizedBox(
          width: m.scaled(18),
          child: Text(
            chair == null ? '' : '$chair',
            style: pixel(
              size: m.scaled(12),
              weight: 700,

              color: here ? Palette.inkMuted : Palette.inkFaint,
            ),
          ),
        ),
        SizedBox(width: m.scaled(6)),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: pixel(
              size: m.scaled(14),
              weight: mine ? 700 : 500,
              color: here
                  ? (mine ? context.palette.accent : Palette.ink)
                  : Palette.inkFaint,
            ),
          ),
        ),
        SizedBox(width: m.scaled(10)),
        Text(
          status,
          maxLines: 1,
          style: pixel(
            size: m.scaled(11),
            weight: 500,
            color: here ? context.palette.accent : Palette.inkFaint,
          ),
        ),
      ],
    );
  }
}

/// One thing the connection found out, as a line.
///
/// No mark in front of it. An icon column started this text eight points in
/// from every other line on the screen, and the mark it drew said nothing
/// the colour does not: a sentence about privacy was wearing an ellipsis
/// because it was neither done nor failed.
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

    return Padding(
      padding: EdgeInsets.only(bottom: m.scaled(10)),
      child: Well(
        metrics: m,
        edge: failed
            ? Palette.attention
            : done
            ? context.palette.accent
            : null,
        padding: EdgeInsets.symmetric(
          horizontal: m.scaled(12),
          vertical: m.scaled(10),
        ),
        child: Text(
          text,
          key: Key(id),
          style: pixel(
            size: m.scaled(12),
            weight: 500,
            height: 1.4,
            color: failed
                ? Palette.attention
                : done
                ? Palette.inkMuted
                : Palette.inkFaint,
          ),
        ),
      ),
    );
  }
}

/// The square, and the code under it.
///
/// The code went away once, on the grounds that a link does the whole job.
/// It came back because the code is the room and the link is only one way
/// of carrying it: somebody across the table scans the square, somebody
/// with the app already open at Join types the seven characters, and
/// somebody on the phone reads them out. Tapping the code copies it.
class _Invite extends StatelessWidget {
  const _Invite({
    required this.metrics,
    required this.link,
    required this.code,
    required this.onCopyCode,
  });

  final Metrics metrics;
  final String link;
  final String code;
  final VoidCallback onCopyCode;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return Padding(
      padding: EdgeInsets.only(bottom: m.scaled(14)),
      child: Well(
        metrics: m,
        child: Column(
          children: [
            RoomQr(key: const Key('room-qr'), metrics: m, link: link),
            SizedBox(height: m.scaled(10)),
            Text(
              'scan it, or type the code',
              textAlign: TextAlign.center,
              style: pixel(
                size: m.scaled(12),
                weight: 500,
                height: 1.4,
                color: Palette.inkFaint,
              ),
            ),
            SizedBox(height: m.scaled(8)),
            Pressable(
              metrics: m,
              onPress: onCopyCode,
              semanticLabel: 'Room code $code. Copies it',
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: m.scaled(8),
                  vertical: m.scaled(2),
                ),
                child: Text(
                  code,
                  key: const Key('room-code'),
                  textAlign: TextAlign.center,
                  style: pixel(
                    size: m.scaled(28),
                    weight: 700,
                    color: Palette.ink,
                    letterSpacing: 4,
                    outlined: true,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The code, as a line you can read out, where there is no link to put it

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

    return Container(
      padding: EdgeInsets.all(m.scaled(8)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(m.scaled(8)),
      ),
      child: QrImageView(
        data: link,
        size: m.scaled(116),
        backgroundColor: Colors.white,
        semanticsLabel: 'A QR code of the link to this room',
      ),
    );
  }
}

/// A line you can press, for a way out of this screen that is not the way
/// the screen is for.
class _Aside extends StatelessWidget {
  const _Aside({
    required this.metrics,
    required this.id,
    required this.text,
    required this.onTap,
  });

  final Metrics metrics;
  final String id;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return Padding(
      padding: EdgeInsets.only(bottom: m.scaled(14)),
      child: Pressable(
        metrics: m,
        onPress: onTap,
        semanticLabel: text,
        child: Text(
          text,
          key: Key(id),
          style:
              pixel(
                size: m.scaled(12),
                weight: 500,
                color: Palette.inkFaint.withValues(alpha: 0.8),
              ).copyWith(
                decoration: TextDecoration.underline,
                decorationColor: Palette.inkFaint.withValues(alpha: 0.4),
              ),
        ),
      ),
    );
  }
}
