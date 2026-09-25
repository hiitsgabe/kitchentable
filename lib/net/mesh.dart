import 'dart:async';
import 'dart:convert';

import '../actions/apply.dart';
import '../actions/table_action.dart';
import '../model/table_state.dart';
import '../wire/wire.dart';
import 'transport.dart';

/// The number the peer that made the room holds, and the lowest there is, so it
/// hosts until it goes.
const _firstStamp = 0;

/// The whole table on every phone, kept level by passing verbs around.
///
/// A full mesh and not a host broadcasting, which the design settled and this
/// does not re-decide: a star fails at the thing players actually hit, which is
/// the host walking into a tunnel, and everybody being on mobile data on
/// different networks makes that Tuesday rather than an edge case.
///
/// Verbs travel and screens do not, because `apply` is a pure reducer and every
/// id and every roll in a verb was minted by whoever built it. Nothing in here
/// mints anything: the same verb on the same table gives the same table on three
/// phones, and that is the whole of why this is small.
///
/// It speaks to a [Transport] and has never heard of Nostr or WebRTC. That is
/// the seam: the next slice writes a real one and this file does not change.
class Mesh {
  Mesh({
    required Transport transport,
    TableState? table,
    bool creator = false,
  })  : _transport = transport,
        _creator = creator {
    // In the body and not the initializer list, because the field is not final
    // and `prefer_initializing_formals` then asks for `this._table`, which a
    // named parameter may not be called.
    _table = table;
    if (creator) _stamps[transport.me] = _firstStamp;
  }

  final Transport _transport;

  /// Whether this device made the room.
  ///
  /// Not the same question as whether it is hosting, which is [hosting]: the
  /// role moves and this does not. It is the local half of the design's rule
  /// that only the host's word about the room counts, so it is set here by the
  /// code that made the room and never taken from a message.
  final bool _creator;

  TableState? _table;

  /// What the host stamped, for every peer it has ever stamped, kept whether or
  /// not that peer is reachable now.
  ///
  /// Kept on purpose. It is what lets the peer that made the room take the role
  /// back when it comes out of the tunnel, and it is why succession needs no
  /// election: every peer works the host out of this and the transport's
  /// reachable set, gets the same answer, and sends nothing. There is no vote to
  /// win and none to forge.
  final Map<String, int> _stamps = {};

  /// True between asking for the table and being given it.
  ///
  /// A snapshot is taken only inside this window. A peer that takes state
  /// pushed at it is a peer that a modified client can hand a different game
  /// the moment it takes over, which is the second half of the attack the
  /// design names.
  bool _asked = false;

  /// Whether a peer has ever been in sight.
  ///
  /// The difference between a room that has just been made, whose table is the
  /// only one there is, and a peer coming back from a tunnel, whose table is
  /// however many verbs out of date. Both are alone and then see somebody, and
  /// only the second one has to ask.
  bool _everSawAnybody = false;

  final _tables = StreamController<TableState>.broadcast();
  final _hosts = StreamController<String?>.broadcast();
  final _refusals = StreamController<String>.broadcast();

  String? _saidTheHostWas;
  var _started = false;
  StreamSubscription<Incoming>? _listening;
  StreamSubscription<PeerEvent>? _watching;

  /// Who this device is, in the transport's names.
  String get me => _transport.me;

  /// Everything on the table, or null before this peer has been handed it.
  ///
  /// Null and not an empty table: a guest that showed an empty one would be
  /// showing its own guess at a game in progress, which is the same mistake
  /// `Room.config` refuses for a room's settings.
  TableState? get table => _table;

  /// What the host stamped everybody, as this peer last heard it.
  Map<String, int> get stamps => Map.unmodifiable(_stamps);

  int? get myStamp => _stamps[me];

  /// The lowest stamp among the peers that are here, which is the host.
  String? get hostId => _host();

  bool get hosting => hostId == me;

  /// The table, every time it changes.
  Stream<TableState> get tables => _tables.stream;

  /// Who is hosting, every time that changes.
  Stream<String?> get hosts => _hosts.stream;

  /// Something this peer would not act on, and why.
  ///
  /// Not an exception, because the thing on the other end may be a modified
  /// client and an exception would let it take the table down. Not silence
  /// either, which is what the wire refuses for the same reason: a peer being
  /// refused is a table about to disagree with itself, or somebody trying to
  /// make it, and either way a screen that goes on looking correct is the worst
  /// of the outcomes.
  Stream<String> get refusals => _refusals.stream;

  /// Starts listening, and asks for the table if this peer does not have one.
  void start() {
    if (_started) return;
    _started = true;
    _listening = _transport.incoming.listen(_heard);
    _watching = _transport.presence.listen(_sawPeer);
    if (!_creator) _askForTheTable();
    _sayWhoIsHosting();
  }

  /// Runs a verb here and puts it on every wire.
  ///
  /// Applied here first and not after an acknowledgement. A verb that waited for
  /// the mesh would make tapping a card take a round trip over mobile data, and
  /// there is nothing to wait for: no peer can refuse a verb, because the only
  /// referee so far permits everything and the table has no opinion about whose
  /// turn it is.
  void run(TableAction action) {
    final table = _table;
    if (table == null) {
      throw StateError(
        'there is no table here yet, so there is nothing to run this verb on. A '
        'peer that has not been handed the table cannot start playing on a '
        'guess at what is on it.',
      );
    }

    _holds(apply(table, action));

    final body = _say('action', {'body': toWire(action)});
    for (final peer in _transport.peers) {
      _transport.send(peer, body);
    }
  }

  Future<void> close() async {
    await _listening?.cancel();
    await _watching?.cancel();
    await _tables.close();
    await _hosts.close();
    await _refusals.close();
  }

  // Asking, and being asked.

  /// Asks whoever is out there for the table.
  ///
  /// Everybody, because this peer does not know who is hosting yet and cannot be
  /// told by anybody it would have to believe. Exactly one of them answers, and
  /// which one is arithmetic they each do themselves.
  ///
  /// The ask carries nothing. Every field a peer could put in here about its own
  /// seniority is a field succession must not read, so there are none: no
  /// claimed stamp, no time it joined, not even a name.
  void _askForTheTable() {
    _asked = true;
    for (final peer in _transport.peers) {
      _everSawAnybody = true;
      _transport.send(peer, _say('hello'));
    }
  }

  void _sawPeer(PeerEvent event) {
    if (event.presence == Presence.arrived) {
      final wasAlone = !_transport.peers.any((peer) => peer != event.peerId);

      // Still waiting for a table, or back in contact after having lost sight of
      // everybody. The second one is the same situation as the first: whatever
      // this peer holds is however many verbs behind, and it cannot tell whether
      // it was the one who left.
      if (_asked || (wasAlone && _everSawAnybody)) {
        _asked = true;
        _transport.send(event.peerId, _say('hello'));
      }
      _everSawAnybody = true;
    }

    // A peer arriving or leaving can change who is hosting, and nobody sends a
    // message about that.
    _sayWhoIsHosting();
  }

  void _heard(Incoming message) {
    try {
      final json = _read(message.body);
      switch (json['kind']) {
        case 'hello':
          _handTheTableTo(message.from);
        case 'welcome':
          _takeTheTable(message.from, json);
        case 'roster':
          _takeTheRoster(message.from, json);
        case 'action':
          _takeAVerb(message.from, json);
        default:
          _refuse(
            '${message.from} sent "${json['kind']}", which is not one of the '
            'four kinds this build speaks',
          );
      }
    } on WireError catch (e) {
      _refuse('${message.from}: ${e.message}');
    }
  }

  /// Answers a peer that asked for the table, if this is the peer that should.
  void _handTheTableTo(String asking) {
    // Exactly one peer answers and there is no negotiation about which: the
    // lowest stamp that is not the asker. Not simply the host, because the peer
    // that made the room is the host again the moment it reconnects and it is
    // the one asking, so it would be answering itself with the stale table it
    // just came back with.
    if (_host(ignoring: asking) != me) return;

    // Minted here, or remembered from the last time this peer was at the table.
    // Never read off the ask. A number a peer says about itself is a number a
    // modified client sets to zero, wins every succession with, and pushes
    // whatever state it likes the moment it takes over: that is the attack the
    // design names and this line is where it is refused.
    final known = _stamps.containsKey(asking);
    _stamps[asking] ??= _nextStamp();

    _transport.send(
      asking,
      _say('welcome', {
        'stamps': _stamps,
        'state': _table == null ? null : stateToWire(_table!),
      }),
    );

    // And everybody else needs a number nobody had before, or they cannot agree
    // about who takes over next. Only a new one: a peer coming back out of a
    // tunnel changes nothing about the roster everybody already holds, and a
    // roster sent anyway would arrive from an acting host that the peers who can
    // still see the real one are right to refuse.
    if (!known) {
      for (final peer in _transport.peers) {
        if (peer == asking) continue;
        _transport.send(peer, _say('roster', {'stamps': _stamps}));
      }
    }
    _sayWhoIsHosting();
  }

  /// One past the highest stamp anybody holds.
  ///
  /// Read off the roster rather than kept in a counter, so a peer that takes the
  /// role over carries the sequence on instead of starting again and handing out
  /// a number somebody at the table already has.
  int _nextStamp() =>
      _stamps.values.fold(_firstStamp, (a, b) => a > b ? a : b) + 1;

  void _takeTheTable(String from, Map<String, Object?> json) {
    if (!_asked) {
      _refuse('$from sent a table nobody asked for');
      return;
    }

    // Whoever would answer this peer's ask, which is the lowest stamp other than
    // its own.
    //
    // A peer holding no roster at all has nothing to check this against and
    // takes the first answer it gets. That is the one hole left here: somebody
    // can race the host and give a newcomer a wrong idea of who is hosting until
    // the host's next roster corrects it. It costs the newcomer and never costs
    // anybody already at the table anything, and closing it needs agreement
    // between peers who do not know each other yet, which is a protocol and not
    // a line.
    final answering = _host(ignoring: me);
    if (answering != null && answering != from) {
      _refuse('$from answered for the table and $answering is hosting');
      return;
    }

    final stamps = _readStamps(json);
    if (!stamps.containsKey(me)) {
      _refuse('$from sent a roster with no stamp in it for this peer');
      return;
    }

    // Decoded before anything is kept, so a state that will not read leaves the
    // roster alone as well.
    final state = json['state'];
    final next = state is String ? stateFromWire(state) : null;

    _asked = false;
    _stamps
      ..clear()
      ..addAll(stamps);
    if (next != null) _holds(next);
    _sayWhoIsHosting();
  }

  void _takeTheRoster(String from, Map<String, Object?> json) {
    // Not stamped yet, so there is nothing here to judge this against, and no
    // need: the answer this peer is waiting for carries the roster. Taking one
    // now would let any peer hand a newcomer a roster that then refuses the real
    // host's answer when it arrives, which turns a forgery into a lockout.
    if (myStamp == null) return;

    // A roster arrives unasked, so it has to come from the peer this one already
    // believes is hosting. That is a stricter test than the one a welcome gets,
    // and deliberately: a welcome is the answer to a question this peer asked
    // precisely because it might be the stale host itself, so it cannot insist
    // the answer comes from a host that would be it.
    if (hostId != from) {
      _refuse('$from sent a roster and ${hostId ?? 'nobody'} is hosting');
      return;
    }

    final stamps = _readStamps(json);
    if (!stamps.containsKey(me)) {
      _refuse('$from sent a roster with no stamp in it for this peer');
      return;
    }

    _stamps
      ..clear()
      ..addAll(stamps);
    _sayWhoIsHosting();
  }

  void _takeAVerb(String from, Map<String, Object?> json) {
    final body = json['body'];
    if (body is! String) {
      throw WireError(
        'a verb should carry a wire and this one carries ${body.runtimeType}',
      );
    }

    final table = _table;
    if (table == null) {
      _refuse('$from sent a verb and there is no table here yet to run it on');
      return;
    }

    // Applied and not passed on. In a full mesh the sender reached everybody
    // itself, so a peer that relayed what it received would deliver every verb
    // once per peer and the copies would move the card again.
    _holds(apply(table, fromWire(body)));
  }

  // Who is hosting, which is arithmetic rather than a message.

  /// The lowest stamp among the peers that can be reached, and this one.
  ///
  /// A peer with no stamp is not a candidate: it has not been let in yet, and a
  /// peer that could host without a stamp could host by arriving.
  String? _host({String? ignoring}) {
    String? best;
    for (final peer in _stamps.keys) {
      if (peer == ignoring) continue;
      if (peer != me && !_transport.peers.contains(peer)) continue;
      if (best == null || _outranks(peer, best)) best = peer;
    }
    return best;
  }

  /// Lower stamp first, and the name only to break a tie.
  ///
  /// A tie means somebody was stamped twice, which is a bug rather than a state.
  /// Breaking it on the name keeps every peer's answer the same instead of
  /// leaving it to the order of a map, because two peers disagreeing about who
  /// is hosting is worse than either answer.
  bool _outranks(String peer, String other) {
    final stamp = _stamps[peer]!;
    final theirs = _stamps[other]!;
    return stamp == theirs ? peer.compareTo(other) < 0 : stamp < theirs;
  }

  void _sayWhoIsHosting() {
    final host = hostId;
    if (host == _saidTheHostWas) return;
    _saidTheHostWas = host;
    if (!_hosts.isClosed) _hosts.add(host);
  }

  void _holds(TableState next) {
    if (identical(next, _table)) return;
    _table = next;
    if (!_tables.isClosed) _tables.add(next);
  }

  void _refuse(String why) {
    if (!_refusals.isClosed) _refusals.add(why);
  }

  // The envelope. Four kinds, a version, and a verb carried as the string the
  // wire already makes rather than unpacked and repacked here: the mesh moves
  // verbs and has no business knowing what is in one.

  String _say(String kind, [Map<String, Object?> more = const {}]) =>
      jsonEncode({'v': wireVersion, 'kind': kind, ...more});

  /// The envelope, or a [WireError] saying which part of it was wrong.
  ///
  /// The version is the wire's, not a second number. One build speaks one
  /// protocol, and a mesh envelope whose shape changed is exactly as fatal as a
  /// verb whose shape changed: two numbers would only let somebody bump one and
  /// believe the other half still matched.
  Map<String, Object?> _read(String body) {
    final Object? json;
    try {
      json = jsonDecode(body);
    } on FormatException catch (e) {
      throw WireError('this is not JSON: ${e.message}');
    }
    if (json is! Map<String, Object?>) {
      throw WireError(
        'a mesh message should be an object and this is ${json.runtimeType}',
      );
    }

    final version = json['v'];
    if (version != wireVersion) {
      throw WireError(
        'mesh version $version, and this build speaks $wireVersion. Somebody at '
        'this table is running a different one.',
      );
    }
    return json;
  }

  Map<String, int> _readStamps(Map<String, Object?> json) {
    final stamps = json['stamps'];
    if (stamps is! Map<String, Object?>) {
      throw WireError(
        '"stamps" should be an object and it is ${stamps.runtimeType}',
      );
    }

    return {
      for (final entry in stamps.entries)
        entry.key: entry.value is int
            ? entry.value as int
            : throw WireError(
                'a stamp should be a whole number and ${entry.key} has '
                '${entry.value}',
              ),
    };
  }
}
