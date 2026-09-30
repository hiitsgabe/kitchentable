import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'nostr/keys.dart';
import 'nostr/relay.dart';

/// The three things WebRTC has to say to set up a link, and nothing else.
enum SignalKind { offer, answer, ice }

/// One of those, from one peer, for this one.
///
/// [from] is the pubkey of the event it arrived in, which the relay cannot
/// forge because the event is signed; it is never a name the sender wrote
/// into the content.
@immutable
class Signal {
  const Signal({
    required this.kind,
    required this.from,
    required this.body,
    this.replacesOwnOffer = false,
  });

  final SignalKind kind;
  final String from;

  /// An SDP description or an ICE candidate, opaque here.
  final String body;

  /// True on an offer that arrived while this side had one of its own out
  /// to the same peer. Ours has been dropped and the link has to roll back
  /// whatever it described before it can take this one.
  final bool replacesOwnOffer;

  @override
  String toString() => 'Signal(${kind.name} from ${from.substring(0, 8)}'
      '${replacesOwnOffer ? ', replacing ours' : ''})';
}

/// The facts a room screen can state about the rendezvous.
///
/// Reported as they happen, each once, so a screen can turn them into
/// "relay accepted, friend connected" rather than a note under a QR code.
enum SignalingStep {
  /// A relay's socket is open.
  relayConnected,

  /// A relay that was open went away. The client keeps trying it.
  relayLost,

  /// Not one relay could be reached when this peer tried to announce. The
  /// room exists on nobody's relay, and nobody can arrive.
  relayUnreachable,

  /// This peer's `here` went out to at least one relay, which took it.
  announced,

  /// Every relay that answered said no to a message of ours, in its own
  /// words in [SignalingStatus.reason]. A `here` refused is a room nobody
  /// can find; an offer, answer or candidate refused is a link that will
  /// not finish, and the other side never learns why. Public relays
  /// rate-limit a burst and then ban the key for a while.
  refused,

  /// A peer announced itself under the code.
  peerHere,

  offerSent,
  offerReceived,
  answerSent,
  answerReceived,

  /// An offer crossed with one of ours, and ours lost. See [Signaling].
  ownOfferDropped,

  /// A message under the code was refused: addressed to somebody else, an
  /// answer to no offer, or not decodable. Counted, never thrown, because a
  /// relay anybody can post to must not be able to end the session.
  dropped,
}

@immutable
class SignalingStatus {
  const SignalingStatus(this.step, {this.peer, this.relay, this.reason});

  final SignalingStep step;
  final String? peer;
  final Uri? relay;
  final String? reason;

  @override
  bool operator ==(Object other) =>
      other is SignalingStatus &&
      other.step == step &&
      other.peer == peer &&
      other.relay == relay &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(step, peer, relay, reason);

  @override
  String toString() => 'SignalingStatus(${step.name}'
      '${peer == null ? '' : ' ${peer!.substring(0, 8)}'}'
      '${relay == null ? '' : ' $relay'}'
      '${reason == null ? '' : ': $reason'})';
}

/// Two phones introducing themselves under a room code.
///
/// The code names a meeting place and not an address, since a link cannot
/// reach a phone behind a carrier's NAT. Every peer that opens the link
/// subscribes to the code on public relays and says `here`; the offers,
/// answers and candidates WebRTC needs then travel the same way, each inside
/// a signed event addressed to one peer's public key. The relay carries the
/// introduction and never a card, and it cannot put words in anybody's
/// mouth because every event is signed by the key it claims to be from.
///
/// **Who offers.** Two peers that see each other at the same instant would
/// both offer, and WebRTC does not sort that out. So the one with the lower
/// public key offers, which is arithmetic nobody can influence: the keys are
/// the same length in the same alphabet, so comparing the strings compares
/// the numbers. This side asks [makeOffer] for a description only when it
/// is that side, and otherwise waits to be offered to. If an offer arrives
/// anyway while ours to that peer is outstanding, from a client that does
/// not run this rule, ours is dropped and theirs is surfaced with
/// [Signal.replacesOwnOffer] set, so a link ends up with one negotiation
/// and never two.
///
/// **Not a roster.** On the relay every peer is equal; there is no host here.
/// A peer becomes the host once the links are up and the mesh stamps it.
///
/// Nothing is stored anywhere, so a `here` said before somebody was
/// listening is gone. Each peer therefore says it again on hearing a new
/// peer, on a relay coming back, and on a timer while in the room.
class Signaling {
  Signaling({
    required this._relay,
    required this._keys,
    required this.code,
    required this._makeOffer,
    this.announceEvery = const Duration(seconds: 30),
  });

  final Relay _relay;
  final Keys _keys;
  final String code;
  final Future<String> Function(String peer) _makeOffer;
  final Duration announceEvery;

  final Set<String> _peers = {};

  /// Peers we have offered to and not yet heard an answer from.
  final Set<String> _offered = {};
  final _signals = StreamController<Signal>();
  final _status = StreamController<SignalingStatus>.broadcast();
  Subscription? _sub;
  StreamSubscription<RelayStatus>? _relayStatus;
  Timer? _timer;
  int _dropped = 0;
  bool _closed = false;

  /// Sends that have not yet been acknowledged by the relay.
  final Set<Future<void>> _inFlight = {};

  /// Numbers every message this peer sends. A Nostr event's time is in
  /// seconds and its id is a hash of its fields, so two `here`s in one
  /// second would be one event to every relay and to every dedupe.
  /// Starts somewhere random rather than at zero, so two sessions under one
  /// key cannot sign the same event. A Nostr id is the hash of pubkey, kind,
  /// tags, content and a created_at in whole seconds: a fresh session that
  /// announced within a second of the last one, from the same key and the
  /// same counter, produced an id every subscriber had already seen and
  /// dropped as a duplicate, so the peer was never heard again. The app
  /// mints a key per room, so it only met this in a test that reused one;
  /// the counter costs nothing and closes it for a phone that ever does.
  int _seq = Random.secure().nextInt(1 << 30);

  /// This peer, to everybody else.
  String get me => _keys.public;

  /// Every peer heard from under the code since [join].
  Set<String> get peers => Set.unmodifiable(_peers);

  /// Offers, answers and candidates that were for this peer and verified.
  /// An offer is answered with [answer]; a candidate arrives as it is.
  Stream<Signal> get signals => _signals.stream;

  Stream<SignalingStatus> get status => _status.stream;

  /// Messages under the code that were not passed on: the relay client's
  /// count of forged and duplicate events, plus what this layer refused.
  int get dropped => (_sub?.dropped ?? 0) + _dropped;

  /// Whether this side is the one that offers to [peer].
  bool initiates(String peer) => me.compareTo(peer) < 0;

  /// Subscribes under the code and announces this peer. Returns once every
  /// reachable relay has the subscription, which is the earliest moment a
  /// reply could be heard.
  Future<void> join() async {
    if (_sub != null) return;
    _relayStatus = _relay.status.listen(_onRelay);
    final sub = _sub = _relay.subscribe(
      Filter(kinds: const [handshakeKind], tags: {'d': [code]}),
    );
    sub.events.listen(_onEvent);
    await sub.established;
    if (_relay.connected.isEmpty) {
      _report(const SignalingStatus(SignalingStep.relayUnreachable));
    }
    await _announce();
    _timer = Timer.periodic(announceEvery, (_) => _announce());
  }

  /// Answers [peer]'s offer with [sdp].
  Future<void> answer(String peer, String sdp) async {
    await _send('answer', to: peer, body: sdp);
    _report(SignalingStatus(SignalingStep.answerSent, peer: peer));
  }

  /// Hands [peer] one ICE candidate.
  Future<void> ice(String peer, String candidate) =>
      _send('ice', to: peer, body: candidate);

  /// Leaves the room. Returns once nothing of ours is still on its way to a
  /// relay, so the socket can be closed behind it without cutting a message
  /// in half.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    await _relayStatus?.cancel();
    await _sub?.close();
    await Future.wait(_inFlight);
    // Not awaited: a single subscription stream's close settles only once
    // a listener has heard the end, and there may never have been one.
    unawaited(_signals.close());
    await _status.close();
  }

  Future<void> _announce() async {
    final sent = await _send('here');
    if (sent.accepted.isNotEmpty) {
      _report(const SignalingStatus(SignalingStep.announced));
    }
  }

  Future<void> _offer(String peer) async {
    final sdp = await _makeOffer(peer);
    _offered.add(peer);
    await _send('offer', to: peer, body: sdp);
    _report(SignalingStatus(SignalingStep.offerSent, peer: peer));
  }

  Future<Published> _send(String type, {String? to, String body = ''}) async {
    if (_closed) return const Published(accepted: {}, refused: {});
    final sent = _relay.publish(NostrEvent.sign(
      _keys,
      kind: handshakeKind,
      tags: [
        ['d', code],
        if (to != null) ['p', to],
      ],
      content: jsonEncode({'type': type, 'body': body, 'n': _seq++}),
    ));
    _inFlight.add(sent);
    final Published outcome;
    try {
      outcome = await sent;
    } finally {
      _inFlight.remove(sent);
    }
    if (outcome.accepted.isEmpty && outcome.refused.isNotEmpty) {
      _report(SignalingStatus(
        SignalingStep.refused,
        peer: to,
        reason: '$type: ${outcome.refused.values.first}',
      ));
    }
    return outcome;
  }

  void _onRelay(RelayStatus relay) {
    if (relay.connected) {
      _report(SignalingStatus(SignalingStep.relayConnected, relay: relay.url));
      // A relay that came back kept no copy of the last announcement. It
      // has the subscription again before it is reported up, so this is
      // heard. Before join there is nothing to say yet; join says it.
      if (_timer != null) _announce();
    } else {
      _report(SignalingStatus(SignalingStep.relayLost, relay: relay.url));
    }
  }

  void _onEvent(NostrEvent event) {
    final from = event.pubkey;
    // Our own, fanned back to us: expected, and not worth a count.
    if (from == me) return;
    final String type;
    final String body;
    try {
      final content = jsonDecode(event.content) as Map<String, dynamic>;
      type = content['type'] as String;
      body = content['body'] as String;
    } on Object {
      _drop(from, 'not a handshake message');
      return;
    }
    if (type == 'here') {
      _onHere(from);
      return;
    }
    if (event.tag('p') != me) {
      _drop(from, 'addressed to somebody else');
      return;
    }
    switch (type) {
      case 'offer':
        final crossed = _offered.remove(from);
        if (crossed) {
          _report(SignalingStatus(SignalingStep.ownOfferDropped, peer: from));
        }
        _report(SignalingStatus(SignalingStep.offerReceived, peer: from));
        _surface(Signal(
          kind: SignalKind.offer,
          from: from,
          body: body,
          replacesOwnOffer: crossed,
        ));
      case 'answer':
        if (!_offered.remove(from)) {
          _drop(from, 'an answer to no offer');
          return;
        }
        _report(SignalingStatus(SignalingStep.answerReceived, peer: from));
        _surface(Signal(kind: SignalKind.answer, from: from, body: body));
      case 'ice':
        _surface(Signal(kind: SignalKind.ice, from: from, body: body));
      default:
        _drop(from, 'unknown message $type');
    }
  }

  /// Forgets [peer], so their next announcement is a first one again.
  ///
  /// A link that failed or closed has to be tried again, and the only thing
  /// that starts a link is the arithmetic in [_onHere], which runs once per
  /// peer. Without this a failed link was final: the peer went on
  /// announcing every thirty seconds and every announcement was a repeat,
  /// so nothing was offered again until somebody reloaded and minted a new
  /// key. Found on the first two-phone check.
  void forget(String peer) {
    _peers.remove(peer);
    _offered.remove(peer);
  }

  void _onHere(String peer) {
    if (!_peers.add(peer)) return;
    _report(SignalingStatus(SignalingStep.peerHere, peer: peer));
    // They may not have heard ours: nothing is stored, and they may have
    // subscribed after we spoke. Then the arithmetic.
    _announce();
    if (initiates(peer)) _offer(peer);
  }

  void _surface(Signal signal) {
    if (!_signals.isClosed) _signals.add(signal);
  }

  void _drop(String from, String why) {
    _dropped += 1;
    _report(SignalingStatus(SignalingStep.dropped, peer: from, reason: why));
  }

  void _report(SignalingStatus status) {
    if (!_status.isClosed) _status.add(status);
  }
}
