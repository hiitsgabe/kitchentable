import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'connection_report.dart';
import 'link.dart';
import 'nostr/keys.dart';
import 'nostr/relay.dart';
import 'signaling.dart';
import 'transport.dart';

/// Events the game itself rides on, as opposed to the handshake. A different
/// kind so a relay and a subscription can tell room traffic from the
/// WebRTC introduction, and so the two can run side by side later.
const int roomDataKind = 25050;

/// A [Transport] that carries the game over the relays themselves.
///
/// There is no link to another phone here and no NAT to get through. Every
/// phone in the room holds an outbound connection to the same public
/// relays, which is a thing every network allows, and a message to another
/// phone is an event the relay fans out to it. Two players on two carriers,
/// who can never open a direct link to each other, both reach the relay,
/// so the moment they can find each other the game can start. That is the
/// whole point: the relay the room was found on is the relay the room is
/// played on.
///
/// The cost is the relay in the path: a message is a round trip to it and
/// back, about a fifth of a second, and the relay sees the traffic go by.
/// For friends playing cards that is a fair trade for a connection that
/// never needs a server of anybody's or a setting anybody fills in. A
/// direct WebRTC link, when two phones can open one, is the faster path and
/// belongs over this as an upgrade, not in its place.
///
/// Modelled on [Signaling], which already does the same dance for the
/// handshake: subscribe under the code, announce, hear the others. The
/// difference is what rides on top, which here is the mesh's own strings.
class RelayTransport implements Transport, ReportsConnection {
  RelayTransport({
    required this._relay,
    required this._keys,
    required this._code,
    this.announceEvery = const Duration(seconds: 20),
  });

  final Relay _relay;
  final Keys _keys;

  /// The room, in the tag every event under it carries.
  final String _code;

  /// How often this phone says it is still here. A peer not heard from in
  /// three of these is taken to have gone; its own beacon at this pace
  /// keeps it from being dropped.
  final Duration announceEvery;

  @override
  String get me => _keys.public;

  final Set<String> _peers = {};
  final Map<String, DateTime> _lastSeen = {};

  final _incoming = StreamController<Incoming>.broadcast();
  final _presence = StreamController<PeerEvent>.broadcast();
  final _steps = StreamController<ConnectionStep>.broadcast();

  Subscription? _sub;
  StreamSubscription<NostrEvent>? _events;
  StreamSubscription<RelayStatus>? _relayStatus;
  Timer? _timer;
  bool _announced = false;
  bool _closed = false;

  /// Numbers every message, so two sent in the same whole second are two
  /// events and not one the relays dedupe away. The same collision
  /// [Signaling] documents, and the same fix: start somewhere random so
  /// two sessions under one key cannot sign the same id either.
  int _seq = Random.secure().nextInt(1 << 30);

  @override
  Set<String> get peers => Set.unmodifiable(_peers);

  @override
  Stream<Incoming> get incoming => _incoming.stream;

  @override
  Stream<PeerEvent> get presence => _presence.stream;

  @override
  Stream<ConnectionStep> get steps => _steps.stream;

  /// Subscribes under the code and announces this phone. Returns once every
  /// reachable relay has the subscription, the earliest a peer could be
  /// heard.
  Future<void> join() async {
    if (_sub != null) return;
    _relayStatus = _relay.status.listen(_onRelay);
    final sub = _sub = _relay.subscribe(
      Filter(
        kinds: const [roomDataKind],
        tags: {
          'd': [_code],
        },
      ),
    );
    _events = sub.events.listen(_onEvent);
    await sub.established;
    if (_relay.connected.isEmpty) {
      _report(const SignalingStatus(SignalingStep.relayUnreachable));
    }
    await _announce();
    _timer = Timer.periodic(announceEvery, (_) {
      _announce();
      _sweep();
    });
  }

  @override
  void send(String peerId, String body) {
    // A datagram handed over, as the seam promises: published and not
    // awaited, and a peer that has gone is told on [presence], never here.
    unawaited(_publish(to: peerId, type: 'msg', body: body));
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    // A goodbye, so the others drop this phone now rather than after the
    // liveness timeout. Best effort: the socket is closing behind it.
    await _publish(type: 'bye');
    await _relayStatus?.cancel();
    await _events?.cancel();
    await _sub?.close();
    await _incoming.close();
    await _presence.close();
    await _steps.close();
  }

  Future<Published> _announce() async {
    final sent = await _publish(type: 'here');
    if (!_announced && sent.accepted.isNotEmpty) {
      _announced = true;
      _report(const SignalingStatus(SignalingStep.announced));
    }
    return sent;
  }

  Future<Published> _publish({
    String? to,
    required String type,
    String body = '',
  }) {
    if (_closed && type != 'bye') {
      return Future.value(const Published(accepted: {}, refused: {}));
    }
    final content = <String, dynamic>{'t': type, 'n': _seq++};
    if (body.isNotEmpty) content['b'] = body;
    final event = NostrEvent.sign(
      _keys,
      kind: roomDataKind,
      tags: [
        ['d', _code],
        if (to != null) ['p', to],
      ],
      content: jsonEncode(content),
    );
    return _relay.publish(event);
  }

  void _onEvent(NostrEvent event) {
    final from = event.pubkey;
    if (from == me) return; // Our own, fanned back to us.
    final String type;
    final String? body;
    try {
      final content = jsonDecode(event.content) as Map<String, dynamic>;
      type = content['t'] as String;
      body = content['b'] as String?;
    } on Object {
      return;
    }
    switch (type) {
      case 'here':
        _meet(from);
      case 'bye':
        _part(from);
      case 'msg':
        // Addressed to this phone, and carrying something.
        if (event.tag('p') != me || body == null) return;
        _meet(from);
        if (!_incoming.isClosed) {
          _incoming.add(Incoming(from: from, body: body));
        }
    }
  }

  /// A peer is here. New ones turn up on [presence] and are answered with a
  /// beacon of our own, so each side learns the other within a round trip
  /// rather than waiting for the next periodic announcement.
  void _meet(String from) {
    _lastSeen[from] = DateTime.now();
    if (!_peers.add(from)) return;
    _report(SignalingStatus(SignalingStep.peerHere, peer: from));
    _step(LinkStep(LinkStatus(LinkStage.opened, peer: from)));
    if (!_presence.isClosed) _presence.add(PeerEvent(from, Presence.arrived));
    unawaited(_publish(type: 'here'));
  }

  void _part(String from) {
    _lastSeen.remove(from);
    if (!_peers.remove(from)) return;
    _step(LinkStep(LinkStatus(LinkStage.closed, peer: from)));
    if (!_presence.isClosed) _presence.add(PeerEvent(from, Presence.left));
  }

  /// Drops peers not heard from in three announcements: a phone that closed
  /// without a goodbye, or whose network went away.
  void _sweep() {
    final stale = DateTime.now().subtract(announceEvery * 3);
    for (final peer
        in _lastSeen.entries
            .where((e) => e.value.isBefore(stale))
            .map((e) => e.key)
            .toList()) {
      _part(peer);
    }
  }

  void _onRelay(RelayStatus relay) {
    if (relay.connected) {
      _report(SignalingStatus(SignalingStep.relayConnected, relay: relay.url));
      // A relay that came back kept no copy of our last beacon; say it
      // again so the room is findable on it.
      if (_timer != null) unawaited(_announce());
    } else {
      _report(SignalingStatus(SignalingStep.relayLost, relay: relay.url));
    }
  }

  void _report(SignalingStatus status) => _step(RendezvousStep(status));

  void _step(ConnectionStep step) {
    // The browser console is the one place a phone's side can be read after
    // the fact, as it is for the WebRTC transport.
    if (kIsWeb) debugPrint('[net] $step');
    if (!_steps.isClosed) _steps.add(step);
  }
}
