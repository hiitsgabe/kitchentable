import 'dart:async';

import 'package:flutter/foundation.dart';

import 'link.dart';
import 'nostr/keys.dart';
import 'nostr/relay.dart';
import 'signaling.dart';
import 'transport.dart';

/// The real [Transport]: found through Nostr, carried over WebRTC.
///
/// The phone that starts the table is the host and every other phone
/// connects to it, and to each other, directly. Nothing of ours is in the
/// path: the relay carries the introduction and never a card, and the
/// [PeerLink]s carry the game. This file is the join between the two. It
/// drives a [Signaling] session under the room code, makes one link per
/// peer the signaling introduces, and shows the mesh the shape it already
/// knows: [me], [peers], [incoming], [presence], [send].
///
/// The mesh does not change. That is the point of the seam it was written
/// behind, and the reason this file is small: everything about who is
/// hosting and what a verb means lives above [Transport], and everything
/// about STUN and SDP lives below [PeerLink].
///
/// [peers] is the set of links that are open right now, and only those. A
/// link that has been introduced and is still negotiating is not a peer
/// yet, and one that has closed or failed is not a peer any more, in the
/// same call that reports it on [presence], so the two never disagree.
class WebRtcTransport implements Transport {
  WebRtcTransport({
    required Relay relay,
    required Keys keys,
    required String code,
    required this._links,
    Duration announceEvery = const Duration(seconds: 30),
  }) : _relay = relay,
       _me = keys.public {
    _signaling = Signaling(
      relay: relay,
      keys: keys,
      code: code,
      makeOffer: _makeOffer,
      announceEvery: announceEvery,
    );
  }

  final Relay _relay;
  final LinkFactory _links;
  final String _me;
  late final Signaling _signaling;

  /// Every link made and not yet gone, open or still negotiating.
  final Map<String, PeerLink> _ends = {};

  /// The peers whose link is open.
  final Set<String> _open = {};

  final _incoming = StreamController<Incoming>.broadcast();
  final _presence = StreamController<PeerEvent>.broadcast();
  final _steps = StreamController<ConnectionStep>.broadcast();
  StreamSubscription<Signal>? _signals;
  StreamSubscription<SignalingStatus>? _status;
  bool _closed = false;

  @override
  String get me => _me;

  @override
  Set<String> get peers => Set.unmodifiable(_open);

  @override
  Stream<Incoming> get incoming => _incoming.stream;

  @override
  Stream<PeerEvent> get presence => _presence.stream;

  /// Every fact about the connection as it happens: what the rendezvous
  /// did, and what each link did. One stream, in the order it happened, so
  /// a screen can tell the story straight: relay reached, friend here,
  /// offer sent, STUN answered, link open. Or link failed, and why.
  Stream<ConnectionStep> get steps => _steps.stream;

  /// Subscribes under the code and announces this phone. Links open as
  /// peers are heard, and show up on [presence] when they do.
  Future<void> join() async {
    if (_signals != null) return;
    _status = _signaling.status.listen((s) => _step(RendezvousStep(s)));
    _signals = _signaling.signals.listen(_onSignal);
    await _signaling.join();
  }

  @override
  void send(String peerId, String body) {
    // Only to a link that is open. One that is still negotiating has
    // nowhere to put the string, and one that is gone was reported on
    // presence, which is how a transport says a peer cannot be reached.
    if (!_open.contains(peerId)) return;
    _ends[peerId]?.send(body);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _signals?.cancel();
    await _status?.cancel();
    for (final end in List.of(_ends.values)) {
      await end.close();
    }
    await _signaling.close();
    await _relay.close();
    await _incoming.close();
    await _presence.close();
    await _steps.close();
  }

  Future<String> _makeOffer(String peer) async {
    final end = _end(peer);
    try {
      return await end.makeOffer();
    } on Object catch (e) {
      // WebRTC would not give a description at all, which on a platform
      // without it is the whole story. Said, and then the signaling's own
      // offer fails the same way, so it does not sit there offered.
      _step(
        LinkStep(
          LinkStatus(
            LinkStage.failed,
            peer: peer,
            failure: LinkFailure(
              peer: peer,
              reason: 'no offer could be made: $e',
            ),
          ),
        ),
      );
      await end.close();
      rethrow;
    }
  }

  Future<void> _onSignal(Signal signal) async {
    // An answer is to an offer this side made, so it belongs to a link that
    // exists. One that arrives after that link failed would otherwise make
    // a new link that can never open, and report a second failure for it.
    final end = signal.kind == SignalKind.answer
        ? _ends[signal.from]
        : _end(signal.from);
    if (end == null) return;
    try {
      switch (signal.kind) {
        case SignalKind.offer:
          final answer = await end.takeOffer(
            signal.body,
            replacesOwnOffer: signal.replacesOwnOffer,
          );
          await _signaling.answer(signal.from, answer);
        case SignalKind.answer:
          await end.takeAnswer(signal.body);
        case SignalKind.ice:
          await end.takeCandidate(signal.body);
      }
    } on Object catch (e) {
      // A description or candidate the link would not take. It came over a
      // relay anybody can post to, so it ends this link, in words, and not
      // the session.
      _step(
        LinkStep(
          LinkStatus(
            LinkStage.failed,
            peer: signal.from,
            failure: LinkFailure(
              peer: signal.from,
              reason: 'their ${signal.kind.name} could not be taken: $e',
            ),
          ),
        ),
      );
      await end.close();
    }
  }

  /// The link to [peer], made on the first word about them.
  ///
  /// A candidate can arrive ahead of the offer it belongs to, since the
  /// offerer starts gathering the moment it has a description and the
  /// relay keeps no order between two events. So any signal makes the
  /// link, and the link holds what it cannot use yet.
  PeerLink _end(String peer) =>
      _ends[peer] ??= _watch(_links.link(me: _me, peer: peer));

  PeerLink _watch(PeerLink end) {
    final peer = end.peer;
    end.incoming.listen((body) {
      if (!_incoming.isClosed) _incoming.add(Incoming(from: peer, body: body));
    });
    end.candidates.listen((candidate) => _signaling.ice(peer, candidate));
    end.status.listen((status) => _step(LinkStep(status)));

    end.open.then((failure) {
      if (failure != null) {
        _step(
          LinkStep(LinkStatus(LinkStage.failed, peer: peer, failure: failure)),
        );
        return;
      }
      if (_closed || _ends[peer] != end) return;
      _open.add(peer);
      _step(LinkStep(LinkStatus(LinkStage.opened, peer: peer)));
      _tell(PeerEvent(peer, Presence.arrived));
    });

    end.closed.then((_) {
      if (_ends[peer] == end) _ends.remove(peer);
      if (!_open.remove(peer)) return;
      _step(LinkStep(LinkStatus(LinkStage.closed, peer: peer)));
      _tell(PeerEvent(peer, Presence.left));
    });
    return end;
  }

  void _tell(PeerEvent event) {
    if (!_presence.isClosed) _presence.add(event);
  }

  void _step(ConnectionStep step) {
    if (!_steps.isClosed) _steps.add(step);
  }
}

/// One thing that happened on the way to a connection, for a screen to
/// state as a fact. Either the rendezvous said it or a link did.
@immutable
sealed class ConnectionStep {
  const ConnectionStep();
}

/// The relay side: connected, announced, a peer heard, an offer sent.
final class RendezvousStep extends ConnectionStep {
  const RendezvousStep(this.status);

  final SignalingStatus status;

  @override
  bool operator ==(Object other) =>
      other is RendezvousStep && other.status == status;

  @override
  int get hashCode => status.hashCode;

  @override
  String toString() => 'RendezvousStep($status)';
}

/// The link side: STUN answered, the channel opened, it failed and why.
final class LinkStep extends ConnectionStep {
  const LinkStep(this.status);

  final LinkStatus status;

  @override
  bool operator ==(Object other) => other is LinkStep && other.status == status;

  @override
  int get hashCode => status.hashCode;

  @override
  String toString() => 'LinkStep($status)';
}
