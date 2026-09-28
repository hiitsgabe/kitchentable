import 'dart:async';

import 'package:kitchentable/net/link.dart';

/// Links wired up in memory, two ends at a time.
///
/// A link from a to b and a link from b to a are the two ends of one
/// channel: a string sent on one arrives on the other and nowhere else, and
/// closing either end closes both, which is what a real data channel does.
///
/// The negotiation is honest about its shape and nothing else. A link opens
/// only once the offerer has taken an answer and the answerer has taken an
/// offer, so a transport that never carried the handshake through the
/// signaling has a pair of links that sit there closed, and a case that
/// forgot to wait for the relay sees no peers at all. The bodies are labels
/// naming the side that made them, so a case can tell whose description
/// landed where.
class FakeLinks implements LinkFactory {
  FakeLinks({this.unreachable = const {}});

  /// Peers no link can be opened to or from. A link between one of these
  /// and anybody negotiates and then fails the way ICE does when the two
  /// phones cannot reach each other: with a reason, and never an error.
  final Set<String> unreachable;

  final Map<String, Map<String, FakeLink>> _ends = {};

  /// Every link made, in the order asked for.
  final List<FakeLink> made = [];

  /// The end [me] holds of the link to [peer], or null if [me] never asked
  /// for one.
  FakeLink? between(String me, String peer) => _ends[me]?[peer];

  @override
  PeerLink link({required String me, required String peer}) {
    final end = FakeLink._(this, me: me, peer: peer);
    (_ends[me] ??= {})[peer] = end;
    made.add(end);
    final other = _ends[peer]?[me];
    if (other != null && other._other == null && !other._gone) {
      end._other = other;
      other._other = end;
      end._tryOpen();
    }
    return end;
  }
}

class FakeLink implements PeerLink {
  FakeLink._(this._links, {required this.me, required this.peer});

  final FakeLinks _links;
  final String me;

  @override
  final String peer;

  FakeLink? _other;
  bool _offered = false;
  bool _tookOffer = false;
  bool _tookAnswer = false;
  bool _isOpen = false;
  bool _gone = false;

  /// What the negotiation handed this end, so a case can check the
  /// transport carried each half to the right side.
  String? offerTaken;

  /// Whether an offer arrived with the word that ours had lost, which is
  /// the transport's to pass on and the real link's to act on.
  bool rolledBack = false;
  String? answerTaken;
  final List<String> candidatesTaken = [];

  /// Every string handed to [send], whether or not the link was open to
  /// carry it, and every string that arrived from the other end.
  final List<String> sent = [];
  final List<String> received = [];

  final _incoming = StreamController<String>.broadcast();
  final _status = StreamController<LinkStatus>.broadcast();
  final _candidates = StreamController<String>.broadcast();
  final _open = Completer<LinkFailure?>();
  final _closed = Completer<void>();

  bool get isOpen => _isOpen;

  @override
  Stream<String> get incoming => _incoming.stream;

  @override
  Stream<LinkStatus> get status => _status.stream;

  @override
  Stream<String> get candidates => _candidates.stream;

  @override
  Future<LinkFailure?> get open => _open.future;

  @override
  Future<void> get closed => _closed.future;

  /// What the real link would say when a STUN server answered.
  void foundReflexive() {
    _status.add(LinkStatus(LinkStage.reflexive, peer: peer));
  }

  @override
  Future<String> makeOffer() async {
    _offered = true;
    _candidates.add('candidate from $me');
    return 'offer from $me';
  }

  @override
  Future<String> takeOffer(String sdp, {required bool replacesOwnOffer}) async {
    if (replacesOwnOffer) {
      _offered = false;
      rolledBack = true;
    }
    offerTaken = sdp;
    _tookOffer = true;
    _candidates.add('candidate from $me');
    _tryOpen();
    return 'answer from $me';
  }

  @override
  Future<void> takeAnswer(String sdp) async {
    if (!_offered) {
      throw StateError('$me took an answer from $peer and never offered');
    }
    answerTaken = sdp;
    _tookAnswer = true;
    _tryOpen();
  }

  @override
  Future<void> takeCandidate(String candidate) async {
    candidatesTaken.add(candidate);
  }

  @override
  void send(String body) {
    sent.add(body);
    final other = _other;
    if (!_isOpen || other == null) return;
    other.received.add(body);
    if (!other._incoming.isClosed) other._incoming.add(body);
  }

  @override
  Future<void> close() async {
    if (_gone) return;
    _gone = true;
    final wasOpen = _isOpen;
    _isOpen = false;
    if (!_open.isCompleted) {
      _open.complete(LinkFailure(peer: peer, reason: 'closed before opening'));
    }
    await _incoming.close();
    await _status.close();
    await _candidates.close();
    if (!_closed.isCompleted) _closed.complete();
    // The other end sees the channel go, as a real one would.
    if (wasOpen) await _other?.close();
  }

  bool get _negotiated => _tookOffer || _tookAnswer;

  void _tryOpen() {
    final other = _other;
    if (other == null || !_negotiated || !other._negotiated) return;
    if (_isOpen || _gone || other._gone) return;
    final blocked = _links.unreachable;
    if (blocked.contains(me) || blocked.contains(peer)) {
      _fail();
      other._fail();
      return;
    }
    _isOpen = true;
    other._isOpen = true;
    _open.complete(null);
    other._open.complete(null);
  }

  void _fail() {
    if (_open.isCompleted) return;
    _gone = true;
    _open.complete(
      LinkFailure(
        peer: peer,
        reason: 'ICE finished with no candidate pair between $me and $peer',
        needsTurn: true,
      ),
    );
    _closed.complete();
  }
}
