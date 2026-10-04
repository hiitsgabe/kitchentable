import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'link.dart';
import 'webrtc_link.dart';

/// Why a microphone is not reaching somebody.
///
/// Three causes, because the benchmark's clearest finding about voice going
/// wrong is that an app has to say which one it is. A banner that says only
/// "not connected" is the documented bad example.
enum VoiceTrouble {
  /// The player said no to the microphone, or the browser did.
  refused,

  /// There is no microphone on this device.
  noMicrophone,

  /// The microphone works and the other phone cannot be reached. This is
  /// the one a relay fixes, and the one that happens to roughly a fifth of
  /// pairs on home networks.
  unreachable,
}

/// One microphone reaching one other.
///
/// Deliberately not [PeerLink]. That one carries the game and is a data
/// channel; this carries audio and has no channel at all. They are two
/// connections to the same person for two different jobs, and the day the
/// game rides WebRTC again they will still be two.
abstract class VoiceLink {
  String get peer;

  /// Steps of the introduction this side wants carried to [peer]. The room
  /// hands them to the mesh and never reads them.
  Stream<Map<String, Object?>> get signals;

  /// Completes with null once audio is flowing, and with the reason it
  /// never will be if it fails first. Never completes with an error: a link
  /// that cannot be made is a sentence for the player, not a crash.
  Future<VoiceTrouble?> get open;

  /// Whether the peer is making a noise right now, for the ring the
  /// benchmark says every app draws round a speaking avatar.
  Stream<bool> get speaking;

  /// Takes one step of the introduction that arrived from [peer].
  Future<void> take(Map<String, Object?> signal);

  Future<void> close();
}

/// Makes them. One real, one fake that the room's own cases drive.
abstract class VoiceLinks {
  VoiceLink link({
    required String peer,
    required MediaStream mine,
    required bool weOffer,
    TurnServer? turn,
  });
}

/// The real one, over an `RTCPeerConnection` carrying one audio track.
class WebRtcVoiceLinks implements VoiceLinks {
  const WebRtcVoiceLinks();

  @override
  VoiceLink link({
    required String peer,
    required MediaStream mine,
    required bool weOffer,
    TurnServer? turn,
  }) => _WebRtcVoiceLink(peer, mine, weOffer, turn);
}

/// How often the peer's loudness is read, and how loud counts as talking.
///
/// A fifth of a second is fast enough that a ring appears with the voice and
/// slow enough that it is not a strobe on somebody saying "um". The
/// threshold is well above the noise a quiet room puts through a laptop
/// microphone and well below speech.
const _listenEvery = Duration(milliseconds: 200);
const _loudEnough = 0.02;

class _WebRtcVoiceLink implements VoiceLink {
  _WebRtcVoiceLink(this.peer, this._mine, this._weOffer, this._turn) {
    unawaited(_begin());
  }

  @override
  final String peer;

  final MediaStream _mine;
  final bool _weOffer;
  final TurnServer? _turn;

  final _signals = StreamController<Map<String, Object?>>.broadcast();
  final _speaking = StreamController<bool>.broadcast();
  final _open = Completer<VoiceTrouble?>();

  RTCPeerConnection? _pc;
  RTCVideoRenderer? _playing;
  Timer? _listening;
  bool _wasSpeaking = false;
  bool _closed = false;

  /// Candidates that arrived before there was anything to put them on.
  final List<RTCIceCandidate> _early = [];
  bool _remoteIsSet = false;

  @override
  Stream<Map<String, Object?>> get signals => _signals.stream;

  @override
  Stream<bool> get speaking => _speaking.stream;

  @override
  Future<VoiceTrouble?> get open => _open.future;

  Future<void> _begin() async {
    try {
      final pc = _pc = await createPeerConnection(
        iceConfiguration(turn: _turn),
      );
      for (final track in _mine.getAudioTracks()) {
        await pc.addTrack(track, _mine);
      }
      pc.onIceCandidate = (c) {
        final candidate = c.candidate;
        if (candidate == null || _signals.isClosed) return;
        _signals.add({
          'ice': candidate,
          'mid': c.sdpMid,
          'line': c.sdpMLineIndex,
        });
      };
      pc.onTrack = (event) => unawaited(_play(event.streams.firstOrNull));
      pc.onConnectionState = _moved;

      // One side offers and the other waits, decided by the keys rather than
      // by who got there first. Both sides offering at once is glare, and
      // the cure for glare is to not have any.
      if (_weOffer) {
        final offer = await pc.createOffer({});
        await pc.setLocalDescription(offer);
        if (!_signals.isClosed) _signals.add({'offer': offer.sdp});
      }
    } on Object catch (e) {
      debugPrint('[voice] $peer could not start: $e');
      _trouble(VoiceTrouble.unreachable);
    }
  }

  /// Puts the peer's audio somewhere it can be heard.
  ///
  /// A renderer and not a widget: audio needs an element on the web and
  /// nothing on a phone, and a renderer is the one thing that covers both.
  /// It is never drawn.
  Future<void> _play(MediaStream? theirs) async {
    if (theirs == null || _closed) return;
    final playing = _playing ??= RTCVideoRenderer();
    await playing.initialize();
    playing.srcObject = theirs;
    _listening ??= Timer.periodic(_listenEvery, (_) => unawaited(_listen()));
  }

  /// Reads how loud the peer is, for the ring.
  Future<void> _listen() async {
    final pc = _pc;
    if (pc == null || _closed) return;
    try {
      var loudest = 0.0;
      for (final report in await pc.getStats()) {
        if (report.type != 'inbound-rtp') continue;
        final level = report.values['audioLevel'];
        if (level is num) {
          loudest = loudest > level ? loudest : level.toDouble();
        }
      }
      final speaking = loudest >= _loudEnough;
      if (speaking == _wasSpeaking) return;
      _wasSpeaking = speaking;
      if (!_speaking.isClosed) _speaking.add(speaking);
    } on Object {
      // Stats are a nicety. A link that cannot report its loudness still
      // carries the voice, and a ring that never lights is not a reason to
      // tear a working call down.
    }
  }

  void _moved(RTCPeerConnectionState state) {
    switch (state) {
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        if (!_open.isCompleted) _open.complete(null);
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        _trouble(VoiceTrouble.unreachable);
      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        _trouble(VoiceTrouble.unreachable);
      default:
        break;
    }
  }

  void _trouble(VoiceTrouble why) {
    if (!_open.isCompleted) _open.complete(why);
  }

  @override
  Future<void> take(Map<String, Object?> signal) async {
    final pc = _pc;
    if (pc == null || _closed) return;
    try {
      if (signal['offer'] case final String sdp) {
        await pc.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
        _remoteIsSet = true;
        await _drain(pc);
        final answer = await pc.createAnswer({});
        await pc.setLocalDescription(answer);
        if (!_signals.isClosed) _signals.add({'answer': answer.sdp});
        return;
      }
      if (signal['answer'] case final String sdp) {
        await pc.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
        _remoteIsSet = true;
        await _drain(pc);
        return;
      }
      if (signal['ice'] case final String candidate) {
        final found = RTCIceCandidate(
          candidate,
          signal['mid'] as String?,
          (signal['line'] as num?)?.toInt(),
        );
        // A candidate that arrives before the description it belongs to is
        // kept rather than thrown away. Dropping them loses exactly the
        // addresses a hard pair of networks needs.
        if (!_remoteIsSet) {
          _early.add(found);
          return;
        }
        await pc.addCandidate(found);
      }
    } on Object catch (e) {
      debugPrint('[voice] $peer refused a signal: $e');
    }
  }

  Future<void> _drain(RTCPeerConnection pc) async {
    for (final candidate in _early) {
      try {
        await pc.addCandidate(candidate);
      } on Object {
        // One bad candidate is not the end of a connection.
      }
    }
    _early.clear();
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _listening?.cancel();
    _trouble(VoiceTrouble.unreachable);
    final playing = _playing;
    if (playing != null) {
      playing.srcObject = null;
      await playing.dispose();
    }
    await _pc?.close();
    await _signals.close();
    await _speaking.close();
  }
}
