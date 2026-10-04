import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../decks/model/deck.dart';
import '../../decks/model/deck_format.dart';
import '../../net/mesh.dart';
import '../../net/nostr/keys.dart';
import '../../net/nostr/relay.dart';
import '../../net/nostr/room_relays.dart';
import '../../net/signaling.dart';
import '../../net/transport.dart';
import '../../net/connection_report.dart';
import '../../net/link.dart';
import '../../net/relay_transport.dart';
import '../../sources/model/catalog_card.dart';
import '../../table/model/seat_owner.dart';
import '../../table/model/table_state.dart';
import '../../table/room/room.dart';
import '../../table/setup.dart';
import '../../table/wire/deck_wire.dart';
import '../../table/wire/wire.dart';
import '../room/room_controller.dart';
import '../settings/network.dart';

/// Somebody with a chair: who they are on the transport, and what to call
/// them.
typedef Seated = ({String peer, String name});

/// The people and their decks, before there is a table.
///
/// The host's phone is the room. A guest's browser connects to it, says who
/// they are and what they brought, and the host watches the chairs fill. When
/// every chair has somebody in it the host deals, builds the [Mesh] on the
/// same transport, and hands the transport over: from that line on the mesh
/// speaks and the lobby does not. A guest does the same the moment it is told
/// the table is dealt, and the mesh hands it the table as the late joiner it
/// is.
///
/// Chair 1 is the host's and the rest fill in the order decks arrive. A
/// guest without a deck is a connection and not a person at the table, which
/// is why a knock puts nobody in a chair.
///
/// The knock is the mesh's own `hello`, and on purpose. A guest cannot know
/// whether it arrived before the table was dealt or after, and the one word
/// that gets an answer either way is the one the mesh already answers: a
/// lobby answers it with the chairs and a mesh answers it with the table, and
/// a lobby that hears a table has its answer too.
class Lobby extends ChangeNotifier {
  Lobby.host({required this.transport, required RoomConfig this._config})
    : hosting = true,
      _host = transport.me {
    _listen();
  }

  Lobby.guest({required this.transport}) : hosting = false {
    _listen();
    for (final peer in transport.peers) {
      _knock(peer);
    }
  }

  /// The wire under this lobby, and under the mesh it becomes.
  final Transport transport;

  /// Whether this device made the room. Set here by the code that made it and
  /// never read off a message, the same rule the mesh keeps.
  final bool hosting;

  RoomConfig? _config;
  String? _host;

  /// Who has a chair, in chair order. The host's is derived from what it
  /// holds; a guest's is the last thing the host said.
  List<Seated> _chairs = const [];

  /// The host's copy of everybody's deck, keyed by peer, its own included.
  final Map<String, Deck> _decks = {};
  final Map<String, String> _names = {};

  /// Guests in the order their decks arrived, which is the chair order.
  final List<String> _order = [];

  /// A guest's deck, held until there is a host to send it to.
  ({Deck deck, String name})? _bringing;

  int _refused = 0;
  String? _lastRefusal;
  Mesh? _mesh;
  StreamSubscription<Incoming>? _listening;
  StreamSubscription<PeerEvent>? _watching;
  StreamSubscription<TableState>? _tables;

  String get me => transport.me;

  /// What the host set up. The host's own, or what the host said when it
  /// answered the knock, and null until it has.
  RoomConfig? get config => _config;

  /// Who is hosting, in the transport's names. Null for a guest nobody has
  /// answered yet.
  String? get host => _host;

  List<Seated> get seated => List.unmodifiable(_chairs);

  bool get seatedHere => _chairs.any((s) => s.peer == me);

  /// The chairs nobody is in, numbered from one, the host's first.
  List<int> get emptyChairs {
    final config = _config;
    if (config == null) return const [];
    final guests = _chairs.where((s) => s.peer != _host).length;
    return [
      if (!_chairs.any((s) => s.peer == _host)) 1,
      for (var chair = guests + 2; chair <= config.seats; chair++) chair,
    ];
  }

  /// Whether the host can deal: every chair has somebody in it and the
  /// table has not been dealt already.
  bool get canStart => hosting && _mesh == null && emptyChairs.isEmpty;

  /// Whether there is no chair for this guest. False once it has one, and
  /// false for the host, whose chair is always the first.
  bool get full {
    final config = _config;
    if (hosting || config == null || seatedHere) return false;
    return _chairs.where((s) => s.peer != _host).length >= config.seats - 1;
  }

  /// The deck somebody brought, on the host. Null before it arrived.
  Deck? deckOf(String peer) => _decks[peer];

  /// Every deck this phone holds, by the key of whoever brought it: all of
  /// them on the host, and on a guest the one it brought. What the controller
  /// takes when it sits down at a table dealt elsewhere, to know its own
  /// seat's game and deck size.
  Map<String, Deck> get decks => Map.unmodifiable(_decks);

  /// Every printing at this table, from the decks this lobby holds, by oracle
  /// id. The screen draws a card from here first and asks the catalog only
  /// for one that came from nowhere: a guest's deck arrived over the wire
  /// with every printing field, and the catalog on this phone may never have
  /// imported it.
  ///
  /// On the host that is every deck. On a guest it is the one it brought;
  /// nobody has sent it anybody else's, and the screen there falls back to
  /// its catalog for the rest.
  Map<String, CatalogCard> get printings => {
    for (final deck in _decks.values)
      for (final slot in deck.slots) slot.card.oracleId: slot.card,
  };

  /// How many messages could not be read, and were counted rather than
  /// thrown, because the other end may be a build somebody changed.
  int get refused => _refused;

  String? get lastRefusal => _lastRefusal;

  /// The mesh this lobby handed the transport to, once it has.
  Mesh? get mesh => _mesh;

  /// Whether the table is here. On the host, from the moment it dealt; on a
  /// guest, once the mesh has handed it over.
  bool get dealt => _mesh?.table != null;

  /// The host takes chair 1.
  void sit({required Deck deck, required String name}) {
    if (!hosting) {
      throw StateError(
        'a guest brings a deck, and the host is the one who sits',
      );
    }
    if (_mesh != null) return;
    _decks[me] = deck;
    _names[me] = name;
    _rearrange();
  }

  /// A guest says what it brought. Sent the moment there is a host to send
  /// it to, which may be later than now: somebody can pick a deck before the
  /// host has answered the knock.
  void bring({required Deck deck, required String name}) {
    if (hosting) {
      throw StateError('the host sits, and a guest is the one who brings');
    }
    // The table is dealt and the mesh is speaking. A deck now has nobody to
    // take it, so it is not sent: the lobby has handed over and does not
    // speak again.
    if (_mesh != null) return;
    _bringing = (deck: deck, name: name);
    // Kept as well as sent: the deck is what this phone draws its own cards
    // from once the table is dealt, and the host never sends it back.
    _decks[me] = deck;
    _sendDeck();
  }

  /// Deals everybody in and hands the transport to the mesh.
  ///
  /// [deal] is given one [Player] per chair, the host first and everybody as
  /// [SeatOwner.peer] under their own key, the host under [me]. The host's
  /// seat is not [SeatOwner.here]: this list becomes the table, the table is
  /// read on every phone, and `here` on a guest's phone would be the host's
  /// seat made the guest's to play.
  Mesh start(TableState Function(List<Player> players) deal) {
    if (!hosting) throw StateError('only the host deals');
    if (_mesh != null) throw StateError('the table is already dealt');
    if (!canStart) {
      throw StateError(
        'the table cannot be dealt with a chair empty: '
        '${_chairWords(emptyChairs)}',
      );
    }

    final players = <Player>[
      (deck: _decks[me]!, name: _names[me]!, owner: SeatOwner.peer(me)),
      for (final peer in _order)
        (deck: _decks[peer]!, name: _names[peer]!, owner: SeatOwner.peer(peer)),
    ];
    final table = deal(players);

    // The last word in the lobby's voice, to everybody who can hear, the
    // people without a chair included: they will ask the mesh for the table
    // and watch.
    final word = _say('dealt');
    for (final peer in transport.peers) {
      transport.send(peer, word);
    }
    return _handOver(table);
  }

  /// Stops listening. Not the mesh: once handed over it is the table's, and
  /// the transport under it belongs to whoever made it.
  Future<void> close() async => dispose();

  bool _closed = false;

  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    unawaited(_stopListening());
    unawaited(_tables?.cancel());
    _tables = null;
    super.dispose();
  }

  // Listening, and stopping.

  void _listen() {
    _listening = transport.incoming.listen(_heard);
    _watching = transport.presence.listen(_sawPeer);
  }

  Future<void> _stopListening() async {
    await _listening?.cancel();
    await _watching?.cancel();
    _listening = null;
    _watching = null;
  }

  /// Stops listening and gives the transport to a [Mesh]. Cancelled before
  /// the mesh is made, so no message is ever heard by both.
  Mesh _handOver(TableState? table) {
    _stopListening();
    final mesh = _mesh = Mesh(
      transport: transport,
      table: table,
      creator: hosting,
    )..start();
    _tables = mesh.tables.listen((_) => notifyListeners());
    notifyListeners();
    return mesh;
  }

  void _sawPeer(PeerEvent event) {
    switch (event.presence) {
      case Presence.arrived:
        if (!hosting) _knock(event.peerId);
      case Presence.left:
        if (hosting) {
          _guestLeft(event.peerId);
        } else if (event.peerId == _host) {
          _hostLeft();
        }
    }
  }

  void _heard(Incoming message) {
    try {
      final json = _read(message.body);
      switch (json['kind']) {
        case 'hello':
          if (hosting) _tellChairs(message.from);
        // A guest hears every other guest knock, because a knock goes to
        // everybody. Nothing to answer and nothing to refuse.
        case 'chairs':
          if (hosting) {
            _refuse('${message.from} told the host what the chairs are');
          } else {
            _takeChairs(message.from, json);
          }
        case 'bring':
          if (hosting) {
            _takeDeck(message.from, json);
          } else {
            _refuse('${message.from} brought a deck to a guest');
          }
        case 'dealt':
          if (hosting || message.from != _host) {
            _refuse(
              '${message.from} said the table is dealt and is not '
              'hosting',
            );
          } else {
            _handOver(null);
          }
        case 'welcome':
          // The mesh's answer to a knock: there is a table already. The mesh
          // this makes asks again and checks who answers; this only learns
          // that the lobby is over.
          if (hosting) {
            _refuse('${message.from} welcomed the host to its own table');
          } else {
            _handOver(null);
          }
        default:
          _refuse(
            '${message.from} sent "${json['kind']}", which is not something a '
            'lobby says',
          );
      }
    } on WireError catch (e) {
      _refuse('${message.from}: ${e.message}');
    }
  }

  // The host's side.

  void _tellChairs(String peer) => transport.send(peer, _chairsWire());

  void _takeDeck(String from, Map<String, Object?> json) {
    final name = _string(json, 'name');
    final deck = deckFromWire(_string(json, 'deck'));
    final config = _config!;

    if (!_order.contains(from)) {
      if (_order.length >= config.seats - 1) {
        // No chair. Told the chairs so they can see that for themselves,
        // and nothing else changes.
        _tellChairs(from);
        return;
      }
      _order.add(from);
    }
    _decks[from] = deck;
    _names[from] = name;
    _rearrange();
  }

  void _guestLeft(String peer) {
    if (!_order.remove(peer)) return;
    _decks.remove(peer);
    _names.remove(peer);
    _rearrange();
  }

  /// Recomputes the chairs from what the host holds and tells everybody.
  void _rearrange() {
    _chairs = [
      if (_decks.containsKey(me)) (peer: me, name: _names[me]!),
      for (final peer in _order) (peer: peer, name: _names[peer]!),
    ];
    final wire = _chairsWire();
    for (final peer in transport.peers) {
      transport.send(peer, wire);
    }
    notifyListeners();
  }

  String _chairsWire() => _say('chairs', {
    'config': _configToJson(_config!),
    'seated': [
      for (final s in _chairs) {'peer': s.peer, 'name': s.name},
    ],
  });

  // A guest's side.

  void _knock(String peer) => transport.send(peer, _say('hello'));

  void _takeChairs(String from, Map<String, Object?> json) {
    final host = _host;
    if (host != null && from != host) {
      _refuse('$from said what the chairs are and $host is hosting');
      return;
    }

    // Read whole before anything is kept, so a message that will not read
    // leaves what the host last said alone.
    final config = _configFrom(_object(json['config'], 'config'));
    final chairs = <Seated>[
      for (final entry in _list(json, 'seated'))
        _seatedFrom(_object(entry, 'chair')),
    ];

    _host = from;
    _config = config;
    _chairs = chairs;
    _sendDeck();
    notifyListeners();
  }

  void _sendDeck() {
    final bringing = _bringing;
    final host = _host;
    if (bringing == null || host == null) return;
    _bringing = null;
    transport.send(
      host,
      _say('bring', {'name': bringing.name, 'deck': deckToWire(bringing.deck)}),
    );
  }

  void _hostLeft() {
    _host = null;
    _config = null;
    _chairs = const [];
    notifyListeners();
  }

  void _refuse(String why) {
    _refused++;
    _lastRefusal = why;
    notifyListeners();
  }

  // The envelope: the wire's version, a kind, and the deck carried as the
  // string its own wire makes, the way the mesh carries a verb.

  String _say(String kind, [Map<String, Object?> more = const {}]) =>
      jsonEncode({'v': wireVersion, 'kind': kind, ...more});

  Map<String, Object?> _read(String body) {
    final Object? json;
    try {
      json = jsonDecode(body);
    } on FormatException catch (e) {
      throw WireError('this is not JSON: ${e.message}');
    }
    final object = _object(json, 'lobby message');
    final version = object['v'];
    if (version != wireVersion) {
      throw WireError(
        'lobby version $version, and this build speaks $wireVersion. Somebody '
        'at this table is running a different one.',
      );
    }
    return object;
  }

  static Map<String, Object?> _configToJson(RoomConfig config) => {
    'format': config.format.name,
    'seats': config.seats,
    'life': config.life,
    'hostName': config.hostName,
    'roomName': config.roomName,
    'voice': config.voice,
  };

  static RoomConfig _configFrom(Map<String, Object?> json) {
    final name = _string(json, 'format');
    final format = DeckFormat.values.where((f) => f.name == name).firstOrNull;
    if (format == null) {
      throw WireError(
        'the room is in the format "$name", which this build '
        'does not know',
      );
    }
    final seats = _int(json, 'seats');
    if (!roomSeatChoices.contains(seats)) {
      throw WireError('a room seats one of $roomSeatChoices, not $seats');
    }
    return RoomConfig(
      format: format,
      seats: seats,
      life: _int(json, 'life'),
      hostName: _string(json, 'hostName'),
      roomName: _string(json, 'roomName'),
      // Lenient, unlike the rest of this: a host built before voice existed
      // sends a room without the field, and the honest reading of silence is
      // that the table does not talk.
      voice: json['voice'] == true,
    );
  }

  static Seated _seatedFrom(Map<String, Object?> json) =>
      (peer: _string(json, 'peer'), name: _string(json, 'name'));

  static Map<String, Object?> _object(Object? json, String what) {
    if (json is Map<String, Object?>) return json;
    throw WireError(
      'a $what should be an object and this is ${json.runtimeType}',
    );
  }

  static String _string(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is String) return value;
    throw WireError(
      '"$key" should be a string and it is ${value.runtimeType} ($value)',
    );
  }

  static int _int(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is int) return value;
    throw WireError(
      '"$key" should be a whole number and it is ${value.runtimeType} ($value)',
    );
  }

  static List<Object?> _list(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is List) return value;
    throw WireError('"$key" should be a list and it is ${value.runtimeType}');
  }
}

/// "chair 3", or "chairs 2 and 3", or "chairs 1, 2 and 3", in the words the
/// start button uses for what is still empty.
String _chairWords(List<int> chairs) {
  if (chairs.length == 1) return 'chair ${chairs.single}';
  final head = chairs.sublist(0, chairs.length - 1).join(', ');
  return 'chairs $head and ${chairs.last}';
}

/// What the start button says under "Start" for a room with these chairs
/// empty, or for one with none.
String startWords(List<int> emptyChairs) => emptyChairs.isEmpty
    ? 'everybody has a deck: deal the table'
    : 'waiting on ${_chairWords(emptyChairs)}';

// What the connection has said so far, for the room screen to state as
// facts rather than as a note.

/// The three facts a phone can state about reaching the others, and the
/// fourth it has to when they could not be reached.
@immutable
class Reach {
  const Reach({
    this.relayAnswered = false,
    this.relayUnreachable = false,
    this.stunAnswered = false,
    this.seen = const {},
    this.open = const {},
    this.failed = const {},
    this.progress = const {},
    this.needsTurn,
    this.refused,
  });

  /// A relay took this phone's announcement under the code.
  final bool relayAnswered;

  /// Not one relay could be reached, so nobody can find this room.
  final bool relayUnreachable;

  /// A STUN server told this phone its own public address.
  final bool stunAnswered;

  /// Peers that have announced themselves under this code, whether or not
  /// a link to them has opened yet.
  ///
  /// The screen used to show a peer only once its channel was open. On the
  /// first two-phone check the host's browser heard the phone, gathered its
  /// own address for it, and the link never opened, and the screen said
  /// "chair 2: empty" with no hint that anybody had been seen at all. A peer
  /// that was heard is a fact worth a line before it becomes a chair.
  final Set<String> seen;

  /// Peers whose data channel is open right now.
  final Set<String> open;

  /// The last thing each link said about its own state, by peer, in the
  /// stack's words: `ice checking`, `connection failed`. Shown while the
  /// link is neither open nor failed, so the screen carries the sequence a
  /// report needs.
  final Map<String, String> progress;

  /// Every link that failed, by peer, for whatever reason. [needsTurn] is the
  /// one of these a relay would fix; the rest were invisible on the screen
  /// and are not any more.
  final Map<String, LinkFailure> failed;

  /// A link that failed the way only a relay for the connection itself
  /// would fix, if one has.
  final LinkFailure? needsTurn;

  /// The last message of ours every relay said no to, in the relay's own
  /// words, until the next one they took. Null when nothing was refused.
  final String? refused;

  /// This, after one more thing happened.
  Reach after(ConnectionStep step) => switch (step) {
    RendezvousStep(:final status) => switch (status.step) {
      SignalingStep.announced => _copy(
        relayAnswered: true,
        relayUnreachable: false,
        refused: '',
      ),
      SignalingStep.refused => _copy(refused: status.reason ?? ''),
      SignalingStep.relayUnreachable => _copy(relayUnreachable: true),
      SignalingStep.relayConnected => _copy(relayUnreachable: false),
      SignalingStep.peerHere =>
        status.peer == null ? this : _copy(seen: {...seen, status.peer!}),
      _ => this,
    },
    LinkStep(:final status) => switch (status.stage) {
      LinkStage.reflexive => _copy(
        stunAnswered: true,
        seen: {...seen, status.peer},
      ),
      LinkStage.progress => _copy(
        seen: {...seen, status.peer},
        progress: {...progress, status.peer: status.detail ?? ''},
      ),
      LinkStage.opened => _copy(
        seen: {...seen, status.peer},
        open: {...open, status.peer},
        failed: {...failed}..remove(status.peer),
        progress: {...progress}..remove(status.peer),
      ),
      LinkStage.closed => _copy(
        seen: {...seen}..remove(status.peer),
        open: {...open}..remove(status.peer),
      ),
      LinkStage.failed => _copy(
        seen: {...seen}..remove(status.peer),
        open: {...open}..remove(status.peer),
        failed: status.failure == null
            ? failed
            : {...failed, status.peer: status.failure!},
        needsTurn: status.failure?.needsTurn == true
            ? status.failure
            : needsTurn,
      ),
    },
  };

  Reach _copy({
    bool? relayAnswered,
    bool? relayUnreachable,
    bool? stunAnswered,
    Set<String>? seen,
    Set<String>? open,
    Map<String, LinkFailure>? failed,
    Map<String, String>? progress,
    LinkFailure? needsTurn,
    String? refused,
  }) => Reach(
    refused: refused == null ? this.refused : (refused == '' ? null : refused),
    relayAnswered: relayAnswered ?? this.relayAnswered,
    relayUnreachable: relayUnreachable ?? this.relayUnreachable,
    stunAnswered: stunAnswered ?? this.stunAnswered,
    seen: seen ?? this.seen,
    open: open ?? this.open,
    failed: failed ?? this.failed,
    progress: progress ?? this.progress,
    needsTurn: needsTurn ?? this.needsTurn,
  );
}

// The providers. The room screen reads these and nothing under them.

/// Which relays a room is held on comes from the room's own code now. See
/// [relaysFor] and the pool it draws from.

/// How this device reaches the others, given the room code.
///
/// A provider so tests can hand the room a network in memory; the real one
/// is Nostr for the introduction and WebRTC for the connection, and it
/// starts joining the moment it is made.
final transportFactoryProvider = Provider<Transport Function(String code)>((
  ref,
) {
  final turn = ref.watch(turnProvider);
  return (code) => _reachOut(code, turn: turn);
});

Transport _reachOut(String code, {TurnServer? turn}) {
  // The relay path: the game rides on the relays the room is found on, which
  // every network reaches with an outbound connection, so two phones that
  // could never open a direct link to each other still play. A direct
  // WebRTC link is the faster path and belongs over this as an upgrade; it
  // is kept in the tree for that and is not what a room uses to connect
  // today, because this connects everywhere and needs nothing filled in.
  final transport = RelayTransport(
    relay: Relay(relaysFor(code)),
    keys: Keys.mint(),
    code: code,
  );
  // Not awaited: the room screen has to draw while the relay is being
  // reached, and everything join finds out is reported on `steps`, which
  // is what the screen reads.
  unawaited(transport.join());
  return transport;
}

/// The transport for the room this device is in, or null outside one. Made
/// when a room is opened or arrived at, closed when it is left.
final transportProvider = Provider<Transport?>((ref) {
  final room = ref.watch(roomProvider);
  if (room == null) return null;
  final transport = ref.watch(transportFactoryProvider)(room.code);
  ref.onDispose(transport.close);
  return transport;
});

/// The lobby for the room this device is in.
///
/// A [Lobby] is a [ChangeNotifier], so the provider passes its changes on and
/// a screen watching this rebuilds as chairs fill.
class LobbyHere extends Notifier<Lobby?> {
  @override
  Lobby? build() {
    final room = ref.watch(roomProvider);
    final transport = ref.watch(transportProvider);
    if (room == null || transport == null) return null;

    final config = room.config;
    final lobby = room.hosting && config != null
        ? Lobby.host(transport: transport, config: config)
        : Lobby.guest(transport: transport);
    lobby.addListener(ref.notifyListeners);
    ref.onDispose(lobby.close);
    return lobby;
  }
}

final lobbyProvider = NotifierProvider<LobbyHere, Lobby?>(LobbyHere.new);

/// Whether the table is on this phone.
///
/// Its own provider and not a read off [lobbyProvider], because that one
/// notifies on every chair and every verb and this changes once. A screen
/// that opens the table when this turns true listens here and hears it the
/// one time it happens.
final dealtProvider = Provider<bool>(
  (ref) => ref.watch(lobbyProvider)?.dealt ?? false,
);

/// What the connection has said, for the room this device is in.
class ReachHere extends Notifier<Reach> {
  @override
  Reach build() {
    final transport = ref.watch(transportProvider);
    if (transport is ReportsConnection) {
      final steps = (transport as ReportsConnection).steps.listen(note);
      ref.onDispose(steps.cancel);
    }
    return const Reach();
  }

  /// One more thing happened. Public so a test can say it did without a
  /// relay or a STUN server in the room.
  void note(ConnectionStep step) => state = state.after(step);
}

final reachProvider = NotifierProvider<ReachHere, Reach>(ReachHere.new);
