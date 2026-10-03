import 'package:flutter/foundation.dart';

/// One data channel to one peer, and the negotiation that opens it.
///
/// This is the seam under the transport, the way `Transport` is the seam
/// under the mesh. `flutter_webrtc` lives behind it in `webrtc_link.dart`
/// and nowhere else, so the transport can be run under `flutter test`
/// against a pair of links wired up in memory, and the one thing no test
/// can prove, that two phones on two networks find each other, is confined
/// to one file and one hand check.
///
/// The three negotiation calls are the WebRTC handshake with the transport
/// holding the pen: the signaling decides who offers, the transport asks the
/// link for the offer or hands it the one that arrived, and the link talks
/// to nothing but its own peer connection.
abstract class PeerLink {
  /// The peer on the other end, by public key.
  String get peer;

  /// Strings the peer sent, in the order they were sent.
  Stream<String> get incoming;

  /// Facts the link has learned that the transport could not: a STUN
  /// server found this phone's public address, and the like.
  Stream<LinkStatus> get status;

  /// ICE candidates found on this side, each as a string for the wire,
  /// which the transport passes to the peer through the signaling.
  Stream<String> get candidates;

  /// Completes with null once the channel is open, and with the reason it
  /// never will be if it fails first.
  ///
  /// Never completes with an error. The one link in ten that the design
  /// says will need a TURN server is a fact for the room screen to state
  /// and not a crash, and a future that threw would have every caller
  /// writing the same try/catch to turn it back into words.
  Future<LinkFailure?> get open;

  /// Completes when the link is gone, whether it ever opened or not, and
  /// whichever side closed it.
  Future<void> get closed;

  /// An SDP offer describing this side, which the signaling will carry to
  /// the peer. Called only when this side is the one that offers.
  Future<String> makeOffer();

  /// Takes the peer's offer and returns the answer to carry back.
  ///
  /// [replacesOwnOffer] is the signaling's word that an offer of ours to
  /// this peer crossed with theirs and lost, so whatever this side already
  /// described has to be rolled back before theirs is taken.
  Future<String> takeOffer(String sdp, {required bool replacesOwnOffer});

  /// Takes the peer's answer to the offer this side made.
  Future<void> takeAnswer(String sdp);

  /// Takes one ICE candidate the peer found, as it was put on the wire.
  Future<void> takeCandidate(String candidate);

  /// Hands one string to the peer. A datagram handed over, like
  /// `Transport.send`: nothing comes back, and a peer that is gone is
  /// reported by [closed].
  void send(String body);

  /// Closes the channel and the connection under it. The peer sees its
  /// own end close.
  Future<void> close();
}

/// Makes links. One real one, and one fake that pairs links in memory.
abstract class LinkFactory {
  /// A link from [me] to [peer], not yet negotiated, through [turn] if
  /// there is one to go through.
  PeerLink link({required String me, required String peer, TurnServer? turn});
}

/// A relay for the connection itself: what gets two phones together when
/// the networks between them let no pair of addresses through, which a
/// phone on a carrier's network against a home router never does.
///
/// It is at this seam and not under it because it travels: the phone that
/// has one announces it under the room code, and every other phone in the
/// room makes its links through it. One is enough for a room, since a
/// relayed address on either end of a link is a public one.
@immutable
class TurnServer {
  const TurnServer({
    required this.url,
    required this.username,
    required this.credential,
  });

  /// Off the wire, or null when what is there is not a server.
  static TurnServer? fromJson(Object? json) {
    if (json is! Map) return null;
    final url = json['url'];
    if (url is! String || url.isEmpty) return null;
    return TurnServer(
      url: url,
      username: '${json['username'] ?? ''}',
      credential: '${json['credential'] ?? ''}',
    );
  }

  final String url;
  final String username;
  final String credential;

  Map<String, String> toJson() => {
    'url': url,
    'username': username,
    'credential': credential,
  };

  @override
  bool operator ==(Object other) =>
      other is TurnServer &&
      other.url == url &&
      other.username == username &&
      other.credential == credential;

  @override
  int get hashCode => Object.hash(url, username, credential);

  @override
  String toString() => 'TurnServer($url as $username)';
}

/// What a link found out on its own.
enum LinkStage {
  /// A STUN server told this phone its own public address. Not the
  /// address: that is the phone's business and never crosses this seam.
  reflexive,

  /// The data channel is open and the peer can be spoken to.
  opened,

  /// The link will not open, or has stopped. The reason is in
  /// [LinkStatus.failure].
  failed,

  /// The link was closed, by either side, after having been open.
  closed,

  /// A state changed underneath, on the way to opening or failing. What
  /// changed is in [LinkStatus.detail], in the stack's own words.
  ///
  /// Here because the first two-phone check ended in one sentence ("the
  /// connection failed after a route was found") and nothing to say which
  /// states led to it. A screen that carries the sequence is a screen
  /// somebody can report from without a debugger.
  progress,
}

@immutable
class LinkStatus {
  const LinkStatus(this.stage, {required this.peer, this.failure, this.detail});

  final LinkStage stage;
  final String peer;

  /// Set on [LinkStage.failed] and on nothing else.
  final LinkFailure? failure;

  /// Set on [LinkStage.progress]: which state changed and to what, such as
  /// `ice checking` or `connection failed`. Words for a screen, not a value
  /// for code to branch on.
  final String? detail;

  @override
  bool operator ==(Object other) =>
      other is LinkStatus &&
      other.stage == stage &&
      other.peer == peer &&
      other.failure == failure &&
      other.detail == detail;

  @override
  int get hashCode => Object.hash(stage, peer, failure, detail);

  @override
  String toString() =>
      'LinkStatus(${stage.name} ${peer.substring(0, 8)}'
      '${detail == null ? '' : ' $detail'}'
      '${failure == null ? '' : ': ${failure!.reason}'})';
}

/// Why a link did not open, in words a screen can show.
///
/// A value and not an exception, deliberately. The failure that matters
/// most is the one the design predicts for one connection in ten: both
/// phones found their public addresses and no pair of them could be
/// connected, because a carrier's NAT will not let the packets through.
/// That is not an error in this code, it is the case that needs a TURN
/// server, and the room screen has to be able to say so and point at the
/// setting. [needsTurn] is that case, so the screen can say it without
/// reading the words.
@immutable
class LinkFailure {
  const LinkFailure({
    required this.peer,
    required this.reason,
    this.needsTurn = false,
  });

  final String peer;
  final String reason;

  /// True when the phones could each be reached and still not each other,
  /// which a relay for media would fix and nothing else will.
  final bool needsTurn;

  @override
  bool operator ==(Object other) =>
      other is LinkFailure &&
      other.peer == peer &&
      other.reason == reason &&
      other.needsTurn == needsTurn;

  @override
  int get hashCode => Object.hash(peer, reason, needsTurn);

  @override
  String toString() =>
      'LinkFailure(${peer.substring(0, 8)}'
      '${needsTurn ? ', needs TURN' : ''}: $reason)';
}
