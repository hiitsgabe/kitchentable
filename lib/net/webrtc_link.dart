import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'link.dart';

/// Where a phone asks what its own address looks like from the internet.
///
/// Public STUN, and nothing else by default. STUN sees a request and answers
/// with the address it came from; it carries no game and cannot. A relay
/// for the media itself, TURN, is what the player supplies in settings and
/// is never shipped: the design's promise is that no server of ours is in
/// the path, and a default TURN server would be exactly that.
const List<String> defaultStunServers = [
  'stun:stun.l.google.com:19302',
  'stun:stun1.l.google.com:19302',
  'stun:stun.cloudflare.com:3478',
];

/// A relay for the one link in ten that STUN cannot open, brought by the
/// player. Empty by default, and empty means none.
@immutable
class TurnServer {
  const TurnServer({
    required this.url,
    required this.username,
    required this.credential,
  });

  final String url;
  final String username;
  final String credential;
}

/// The configuration a peer connection is made with.
///
/// A function and not a constant so the one place the ICE servers are put
/// together can be read under `flutter test`, where no peer connection can
/// be made.
Map<String, Object> iceConfiguration({
  List<String> stun = defaultStunServers,
  TurnServer? turn,
}) => {
  'iceServers': <Map<String, Object>>[
    {'urls': stun},
    if (turn != null)
      {
        'urls': [turn.url],
        'username': turn.username,
        'credential': turn.credential,
      },
  ],
  'sdpSemantics': 'unified-plan',
};

/// Makes real links, each over its own `RTCPeerConnection`.
class WebRtcLinkFactory implements LinkFactory {
  const WebRtcLinkFactory({this.stun = defaultStunServers, this.turn});

  final List<String> stun;
  final TurnServer? turn;

  @override
  PeerLink link({required String me, required String peer}) => WebRtcLink(
    peer: peer,
    configuration: iceConfiguration(stun: stun, turn: turn),
  );
}

/// One `RTCPeerConnection` and one data channel, named `table`, to one peer.
///
/// `flutter_webrtc` gives the same API on the phone and in the browser, so
/// there is no platform branch in here. The one place the two differ is
/// noted at the rollback, which has to carry an empty description rather
/// than none.
///
/// Nothing in here is proven by a test. The transport above is, against a
/// pair of fake links, and this file is checked by hand on two phones on two
/// networks, which the plan says at the step and the commit records.
class WebRtcLink implements PeerLink {
  WebRtcLink({required this.peer, required this._configuration});

  /// The channel's name on both ends. The answerer recognises the offerer's
  /// channel by it, and refuses one it did not expect.
  static const channelLabel = 'table';

  @override
  final String peer;

  final Map<String, Object> _configuration;
  Future<RTCPeerConnection>? _pc;
  RTCDataChannel? _channel;

  /// Candidates that arrived before the peer's description did, which the
  /// connection cannot take until then.
  final List<RTCIceCandidate> _waiting = [];
  bool _remoteSet = false;
  bool _saidReflexive = false;
  bool _gone = false;

  final _incoming = StreamController<String>.broadcast();
  final _status = StreamController<LinkStatus>.broadcast();
  final _candidates = StreamController<String>.broadcast();
  final _open = Completer<LinkFailure?>();
  final _closed = Completer<void>();

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

  /// The connection, made on first use and not before: a link that is
  /// closed before it was ever asked for anything never touches WebRTC.
  Future<RTCPeerConnection> get _connection => _pc ??= _connect();

  @override
  Future<String> makeOffer() async {
    final pc = await _connection;
    _take(
      await pc.createDataChannel(
        channelLabel,
        RTCDataChannelInit()..ordered = true,
      ),
    );
    final offer = await pc.createOffer({});
    await pc.setLocalDescription(offer);
    return offer.sdp!;
  }

  @override
  Future<String> takeOffer(String sdp, {required bool replacesOwnOffer}) async {
    final pc = await _connection;
    if (replacesOwnOffer) {
      // Ours lost, so the description and the channel that went with it are
      // withdrawn before theirs is taken. The sdp is '' and not null: on
      // web the plugin unwraps it, and the browser ignores it for a
      // rollback anyway.
      await _channel?.close();
      _channel = null;
      await pc.setLocalDescription(RTCSessionDescription('', 'rollback'));
    }
    await pc.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
    await _remoteIsSet(pc);
    final answer = await pc.createAnswer({});
    await pc.setLocalDescription(answer);
    return answer.sdp!;
  }

  @override
  Future<void> takeAnswer(String sdp) async {
    final pc = await _connection;
    await pc.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
    await _remoteIsSet(pc);
  }

  @override
  Future<void> takeCandidate(String candidate) async {
    final json = jsonDecode(candidate) as Map<String, dynamic>;
    final ice = RTCIceCandidate(
      json['candidate'] as String?,
      json['sdpMid'] as String?,
      json['sdpMLineIndex'] as int?,
    );
    if (!_remoteSet) {
      _waiting.add(ice);
      return;
    }
    await (await _connection).addCandidate(ice);
  }

  @override
  void send(String body) {
    final channel = _channel;
    if (channel == null ||
        channel.state != RTCDataChannelState.RTCDataChannelOpen) {
      return;
    }
    // A whole table goes over this as one message when a peer is welcomed.
    // Browsers agree on 256 KiB per message and every phone stack on more;
    // a table bigger than that is a known bound and not a case handled here.
    // A channel that closed between the check and the send rejects, and a
    // rejection nobody awaits is an uncaught error; the close is reported
    // through [closed] and that is the whole of what there is to say.
    unawaited(
      channel.send(RTCDataChannelMessage(body)).catchError((Object _) {}),
    );
  }

  @override
  Future<void> close() => _closeDown(null);

  Future<RTCPeerConnection> _connect() async {
    final pc = await createPeerConnection(_configuration);
    pc.onIceCandidate = _found;
    pc.onIceConnectionState = _iceState;
    pc.onConnectionState = _connectionState;
    pc.onDataChannel = (channel) {
      // The offerer made it; this side is handed it. One channel and no
      // other: a peer that opens a second one is not running this code.
      if (channel.label == channelLabel && _channel == null) _take(channel);
    };
    return pc;
  }

  void _take(RTCDataChannel channel) {
    _channel = channel;
    channel.onMessage = (message) {
      if (message.isBinary || _incoming.isClosed) return;
      _incoming.add(message.text);
    };
    channel.onDataChannelState = (state) {
      switch (state) {
        case RTCDataChannelState.RTCDataChannelOpen:
          if (!_open.isCompleted) _open.complete(null);
        case RTCDataChannelState.RTCDataChannelClosed:
          _closeDown(null);
        case RTCDataChannelState.RTCDataChannelConnecting:
        case RTCDataChannelState.RTCDataChannelClosing:
          break;
      }
    };
    // On some stacks the channel handed over is open already, and the state
    // change that says so has been and gone.
    if (channel.state == RTCDataChannelState.RTCDataChannelOpen &&
        !_open.isCompleted) {
      _open.complete(null);
    }
  }

  void _found(RTCIceCandidate candidate) {
    final text = candidate.candidate;
    // The end of gathering comes as an empty candidate on some stacks and
    // as nothing on others; either way it is not a candidate.
    if (text == null || text.isEmpty || _candidates.isClosed) return;
    if (!_saidReflexive && text.contains(' typ srflx ')) {
      _saidReflexive = true;
      _say(LinkStatus(LinkStage.reflexive, peer: peer));
    }
    _candidates.add(jsonEncode(candidate.toMap()));
  }

  void _iceState(RTCIceConnectionState state) {
    switch (state) {
      case RTCIceConnectionState.RTCIceConnectionStateFailed:
        // Every pair of addresses was tried and none connected. Both phones
        // could reach STUN and neither can reach the other, which is the
        // one in ten the design predicts and the case a TURN server fixes.
        _closeDown(
          LinkFailure(
            peer: peer,
            reason:
                'no route was found between the two phones: each found its '
                'own address and no pair of them connected. This is the case '
                'that needs a TURN server.',
            needsTurn: true,
          ),
        );
      case RTCIceConnectionState.RTCIceConnectionStateClosed:
        _closeDown(null);
      case RTCIceConnectionState.RTCIceConnectionStateNew:
      case RTCIceConnectionState.RTCIceConnectionStateChecking:
      case RTCIceConnectionState.RTCIceConnectionStateConnected:
      case RTCIceConnectionState.RTCIceConnectionStateCompleted:
      case RTCIceConnectionState.RTCIceConnectionStateCount:
      case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
        // Disconnected is a wobble the stack may recover from on its own;
        // a peer that is really gone reaches failed or closed.
        break;
    }
  }

  void _connectionState(RTCPeerConnectionState state) {
    switch (state) {
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        _closeDown(
          LinkFailure(
            peer: peer,
            reason:
                'the connection failed after a route was found, which is '
                'the transport and not the network',
          ),
        );
      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        _closeDown(null);
      case RTCPeerConnectionState.RTCPeerConnectionStateNew:
      case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        break;
    }
  }

  Future<void> _remoteIsSet(RTCPeerConnection pc) async {
    _remoteSet = true;
    for (final ice in _waiting) {
      await pc.addCandidate(ice);
    }
    _waiting.clear();
  }

  /// Ends the link, once, for whichever reason came first.
  ///
  /// [failure] is why it never opened, or null when it was closed by
  /// somebody. A link that failed after opening is closed and not failed:
  /// the transport says `left`, and that is all the mesh needs.
  Future<void> _closeDown(LinkFailure? failure) async {
    if (_gone) return;
    _gone = true;
    if (!_open.isCompleted) {
      _open.complete(
        failure ?? LinkFailure(peer: peer, reason: 'closed before it opened'),
      );
    }
    final pending = _pc;
    if (pending != null) {
      try {
        final pc = await pending;
        await _channel?.close();
        await pc.close();
        await pc.dispose();
      } on Object {
        // Already gone underneath, or never came up. The same outcome.
      }
    }
    await _incoming.close();
    await _status.close();
    await _candidates.close();
    if (!_closed.isCompleted) _closed.complete();
  }

  void _say(LinkStatus status) {
    if (!_status.isClosed) _status.add(status);
  }
}
