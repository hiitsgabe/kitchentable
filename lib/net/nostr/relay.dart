import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'keys.dart';

/// The one event kind this app ever publishes.
///
/// NIP-01 makes 20000 to 29999 ephemeral: a relay fans such an event out to
/// whoever is listening at that moment and keeps no copy. Everything said
/// under a room code is who is here and how to reach them, and the design's
/// promise is that a relay sees a handshake and never a table; a stored
/// handshake on a hundred public relays would be the next best thing to a
/// stored table. 25000 sits in that range clear of the kinds other NIPs have
/// claimed (21000, 22242, 23194, 24133, 27235), so a relay that treats any of
/// those specially leaves this one alone.
const int handshakeKind = 25000;

/// One signed Nostr event, as NIP-01 lays it out.
///
/// The id is the sha256 of the canonical serialization and the signature is
/// BIP-340 over the id, so a relay, or anybody between, can change nothing
/// without [verify] saying so.
@immutable
class NostrEvent {
  const NostrEvent({
    required this.id,
    required this.pubkey,
    required this.createdAt,
    required this.kind,
    required this.tags,
    required this.content,
    required this.sig,
  });

  final String id;
  final String pubkey;

  /// Seconds since the epoch, which is the resolution Nostr has.
  final int createdAt;
  final int kind;
  final List<List<String>> tags;
  final String content;
  final String sig;

  /// A new event from [keys], hashed and signed.
  static NostrEvent sign(
    Keys keys, {
    required int kind,
    required List<List<String>> tags,
    required String content,
    DateTime? at,
  }) {
    final unsigned = NostrEvent(
      id: '',
      pubkey: keys.public,
      createdAt: (at ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000,
      kind: kind,
      tags: tags,
      content: content,
      sig: '',
    );
    final id = idOf(unsigned);
    return NostrEvent(
      id: id,
      pubkey: unsigned.pubkey,
      createdAt: unsigned.createdAt,
      kind: kind,
      tags: tags,
      content: content,
      sig: keys.sign(id),
    );
  }

  /// The id [event]'s fields hash to, whatever its [id] field says.
  static String idOf(NostrEvent event) {
    final serialized = jsonEncode([
      0,
      event.pubkey,
      event.createdAt,
      event.kind,
      event.tags,
      event.content,
    ]);
    return sha256.convert(utf8.encode(serialized)).toString();
  }

  /// Whether the id is the hash of the fields and the signature is
  /// [pubkey]'s over that id. Both, because a forger who rehashes is
  /// caught by the second and one who does not is caught by the first.
  bool verify() => idOf(this) == id && Keys.verify(pubkey, id, sig);

  /// The first value of the first tag named [name], if any.
  String? tag(String name) {
    for (final t in tags) {
      if (t.length > 1 && t[0] == name) return t[1];
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'pubkey': pubkey,
        'created_at': createdAt,
        'kind': kind,
        'tags': tags,
        'content': content,
        'sig': sig,
      };

  factory NostrEvent.fromJson(Map<String, dynamic> json) => NostrEvent(
        id: json['id'] as String,
        pubkey: json['pubkey'] as String,
        createdAt: json['created_at'] as int,
        kind: json['kind'] as int,
        tags: [
          for (final t in json['tags'] as List<dynamic>)
            (t as List<dynamic>).cast<String>(),
        ],
        content: json['content'] as String,
        sig: json['sig'] as String,
      );

  @override
  String toString() => 'NostrEvent($kind ${id.substring(0, 8)} from '
      '${pubkey.substring(0, 8)})';
}

/// What a subscription asks a relay for: any of [kinds], and for each tag
/// name in [tags], any of its values. `{'d': [code]}` goes out as `#d`.
///
/// The relay does the matching. The client never filters what comes back,
/// so a relay that sends the wrong room is a relay that is wrong, and a test
/// against the fake one can tell.
@immutable
class Filter {
  const Filter({this.kinds, this.tags = const {}});

  final List<int>? kinds;
  final Map<String, List<String>> tags;

  Map<String, dynamic> toJson() => {
        if (kinds != null) 'kinds': kinds,
        for (final entry in tags.entries) '#${entry.key}': entry.value,
      };
}

/// One relay coming or going.
@immutable
class RelayStatus {
  const RelayStatus(this.url, {required this.connected});

  final Uri url;
  final bool connected;

  @override
  bool operator ==(Object other) =>
      other is RelayStatus &&
      other.url == url &&
      other.connected == connected;

  @override
  int get hashCode => Object.hash(url, connected);

  @override
  String toString() =>
      'RelayStatus($url ${connected ? 'connected' : 'disconnected'})';
}

/// A standing interest in events matching a filter, on every relay.
class Subscription {
  Subscription._(this._relay, this.id, this.filter);

  final Relay _relay;
  final String id;
  final Filter filter;
  final _events = StreamController<NostrEvent>();
  final _seen = <String>{};

  /// Events the relays sent that were not passed on: forged, malformed, or
  /// already seen from another relay. Counted rather than thrown, because
  /// a hostile relay must not be able to end the session by sending junk.
  int dropped = 0;

  /// Matching events, each exactly once however many relays carry it.
  Stream<NostrEvent> get events => _events.stream;

  /// Completes when every relay that could be reached has acknowledged the
  /// request. An event published before this may be missed, since nothing
  /// the app publishes is stored anywhere.
  late final Future<void> established;

  /// Tells every relay to stop and ends [events].
  Future<void> close() => _relay._unsubscribe(this);

  void _offer(NostrEvent event) {
    if (!event.verify() || !_seen.add(event.id)) {
      dropped += 1;
      return;
    }
    _events.add(event);
  }
}

/// Enough of a Nostr client to find each other.
///
/// Connects to every url given, publishes to all of them, subscribes on all
/// of them and hands each event to the caller once. A relay that goes away
/// is reported on [status] and reconnected to after [reconnectAfter], and
/// every open subscription is asked for again on the new socket.
///
/// Nothing is stored: not events, not what was published. This is a client
/// for ephemeral events on public relays, and the app's identity is the only
/// state it has, which lives in [Keys] and not here.
class Relay {
  Relay(
    List<Uri> urls, {
    this.reconnectAfter = const Duration(seconds: 2),
    this.okTimeout = const Duration(seconds: 5),
    WebSocketChannel Function(Uri url)? connect,
  }) : _connect = connect ?? WebSocketChannel.connect {
    for (final url in urls) {
      _sockets.add(_Socket(this, url).._run());
    }
  }

  final Duration reconnectAfter;

  /// How long [publish] waits for a relay's `OK` before giving up on it.
  final Duration okTimeout;
  final WebSocketChannel Function(Uri url) _connect;
  final List<_Socket> _sockets = [];
  final Map<String, Subscription> _subs = {};
  final _status = StreamController<RelayStatus>.broadcast();
  final _random = Random();
  bool _closed = false;

  Stream<RelayStatus> get status => _status.stream;

  /// Which relays are up right now.
  Set<Uri> get connected => {
        for (final s in _sockets)
          if (s.open) s.url,
      };

  /// Sends [event] to every relay and returns once each has answered or
  /// timed out. A relay that is down when this is called is skipped; there
  /// is nowhere to keep the event for it, and by the time it is back the
  /// event would be stale anyway.
  Future<void> publish(NostrEvent event) async {
    await Future.wait([for (final s in _sockets) s._publish(event)]);
  }

  /// Asks every relay for events matching [filter], from now on.
  Subscription subscribe(Filter filter) {
    final id = hexOf(List.generate(8, (_) => _random.nextInt(256)));
    final sub = Subscription._(this, id, filter);
    _subs[id] = sub;
    sub.established = Future.wait([for (final s in _sockets) s._request(sub)]);
    return sub;
  }

  Future<void> _unsubscribe(Subscription sub) async {
    if (_subs.remove(sub.id) == null) return;
    for (final s in _sockets) {
      s._send(['CLOSE', sub.id]);
    }
    await sub._events.close();
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final sub in List.of(_subs.values)) {
      await _unsubscribe(sub);
    }
    await Future.wait([for (final s in _sockets) s._close()]);
    await _status.close();
  }

  void _handle(_Socket from, dynamic data) {
    final List<dynamic> message;
    try {
      message = jsonDecode(data as String) as List<dynamic>;
    } on Object {
      return;
    }
    switch (message[0]) {
      case 'EVENT':
        final sub = _subs[message[1]];
        if (sub == null) return;
        try {
          sub._offer(NostrEvent.fromJson(message[2] as Map<String, dynamic>));
        } on Object {
          sub.dropped += 1;
        }
      case 'OK':
        from._oks.remove(message[1])?.complete();
      case 'EOSE':
        from._eoses.remove(message[1])?.complete();
    }
  }
}

/// One relay's socket, and the loop that keeps it open.
class _Socket {
  _Socket(this._relay, this.url);

  final Relay _relay;
  final Uri url;
  WebSocketChannel? _channel;

  /// The first attempt, succeeded or failed. Publishing and subscribing
  /// wait on it so that a client used the moment it is built does not skip
  /// a relay that was a few milliseconds from being up.
  final _first = Completer<void>();
  final Map<String, Completer<void>> _oks = {};
  final Map<String, Completer<void>> _eoses = {};
  bool _closing = false;

  bool get open => _channel != null;

  Future<void> _run() async {
    while (!_closing) {
      try {
        final channel = _relay._connect(url);
        await channel.ready;
        _channel = channel;
        for (final sub in _relay._subs.values) {
          _request(sub);
        }
        _settleFirst();
        _relay._status.add(RelayStatus(url, connected: true));
        await for (final data in channel.stream) {
          _relay._handle(this, data);
        }
      } on Object {
        // A refused connection or a socket error. Either way it is down.
      }
      _settleFirst();
      if (_channel != null) {
        _channel = null;
        _relay._status.add(RelayStatus(url, connected: false));
      }
      // Nobody is going to answer on a socket that is gone.
      for (final waiting in [..._oks.values, ..._eoses.values]) {
        waiting.complete();
      }
      _oks.clear();
      _eoses.clear();
      if (_closing) break;
      await Future<void>.delayed(_relay.reconnectAfter);
    }
  }

  void _settleFirst() {
    if (!_first.isCompleted) _first.complete();
  }

  void _send(List<dynamic> message) => _channel?.sink.add(jsonEncode(message));

  Future<void> _publish(NostrEvent event) async {
    await _first.future;
    if (!open) return;
    final ok = _oks[event.id] = Completer<void>();
    _send(['EVENT', event.toJson()]);
    await ok.future.timeout(_relay.okTimeout, onTimeout: () {
      _oks.remove(event.id);
    });
  }

  Future<void> _request(Subscription sub) async {
    await _first.future;
    if (!open) return;
    // Asked twice on one socket, by the subscriber and by the connect loop
    // waking up at the same moment, is asked once.
    final pending = _eoses[sub.id];
    if (pending != null) return pending.future;
    final eose = _eoses[sub.id] = Completer<void>();
    _send(['REQ', sub.id, sub.filter.toJson()]);
    await eose.future;
  }

  Future<void> _close() async {
    _closing = true;
    await _channel?.sink.close();
  }
}
