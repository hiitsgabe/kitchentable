import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../net/link.dart';
import '../../net/mesh.dart';
import '../../net/voice_link.dart';
import '../settings/network.dart';

/// Where this phone's microphone is up to.
enum Talking {
  /// Not in. The room may still offer it.
  off,

  /// Waiting on the player, or on the browser, to say yes to a microphone.
  asking,

  /// Microphone in hand, reaching the others.
  joining,

  /// In.
  on,

  /// Something went wrong, and [Voice.trouble] says which of the three.
  failed,
}

/// What voice is doing, for the screen to draw.
@immutable
class Voice {
  const Voice({
    this.state = Talking.off,
    this.muted = false,
    this.talking = const {},
    this.reaching = const {},
    this.trouble,
  });

  final Talking state;

  /// Whether this phone's own microphone is off while still being in.
  final bool muted;

  /// Whose voice is arriving right now, by key. The ring.
  final Set<String> talking;

  /// Peers a link has been opened to, whether or not it is carrying yet.
  final Set<String> reaching;

  /// Why it is not working, when it is not.
  final VoiceTrouble? trouble;

  bool get isOn => state == Talking.on;

  Voice copyWith({
    Talking? state,
    bool? muted,
    Set<String>? talking,
    Set<String>? reaching,
    VoiceTrouble? trouble,
    bool clearTrouble = false,
  }) => Voice(
    state: state ?? this.state,
    muted: muted ?? this.muted,
    talking: talking ?? this.talking,
    reaching: reaching ?? this.reaching,
    trouble: clearTrouble ? null : (trouble ?? this.trouble),
  );
}

/// Asks the device for a microphone. A seam, so the room's own behaviour can
/// be driven without one.
typedef AskForMicrophone = Future<MediaStream> Function();

Future<MediaStream> _realMicrophone() =>
    navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});

/// Everybody's microphones, and this one.
///
/// A second connection to the same people, over the one that already works:
/// the mesh carries the introduction and the audio goes straight across if
/// it can. That is what every WebRTC-over-Nostr draft does and it is why the
/// signalling half needs nobody's server.
///
/// Nothing here starts by itself. Voice is a thing the room offers and a
/// person takes, which is what every game that has it does, and the
/// microphone is not touched until somebody asks for it.
class VoiceRoom extends Notifier<Voice> {
  VoiceRoom({
    this.links = const WebRtcVoiceLinks(),
    AskForMicrophone? microphone,
  }) : _ask = microphone ?? _realMicrophone;

  /// How links are made. A seam, so the room's own behaviour can be driven
  /// without a microphone or a network.
  final VoiceLinks links;
  final AskForMicrophone _ask;

  Mesh? _mesh;
  TurnServer? _turn;
  MediaStream? _mine;
  final Map<String, VoiceLink> _links_ = {};
  final List<StreamSubscription<Object?>> _watching = [];
  StreamSubscription<VoiceSignal>? _hearing;

  @override
  Voice build() {
    ref.onDispose(() => unawaited(_down()));
    return const Voice();
  }

  /// The mesh to talk over, handed in when the table opens. Changing it
  /// hangs up: a new table is new people.
  void follow(Mesh? mesh) {
    if (identical(mesh, _mesh)) return;
    unawaited(_down());
    _mesh = mesh;
    _hearing?.cancel();
    _hearing = mesh?.voiceSignals.listen(_heard);
  }

  /// Takes the room up on its offer.
  ///
  /// The microphone is asked for here and nowhere earlier, which is both
  /// platforms' guidance and the difference between a prompt somebody
  /// understands and one they refuse.
  Future<void> join() async {
    final mesh = _mesh;
    if (mesh == null || state.state == Talking.on) return;

    state = state.copyWith(state: Talking.asking, clearTrouble: true);
    // Read here and not when the table opened. A relay is a setting on this
    // device, it is read off the disk, and a table opening in a test has no
    // disk to read it from.
    _turn = ref.read(turnProvider);
    final MediaStream mine;
    try {
      mine = await _ask();
    } on Object catch (e) {
      // The browser says no the same way whether the player refused or
      // there is nothing to refuse with, so the message is read off the
      // error rather than guessed.
      final why = '$e'.toLowerCase();
      state = state.copyWith(
        state: Talking.failed,
        trouble: why.contains('notfound') || why.contains('devicesnotfound')
            ? VoiceTrouble.noMicrophone
            : VoiceTrouble.refused,
      );
      return;
    }

    _mine = mine;
    state = state.copyWith(state: Talking.joining, muted: false);
    for (final peer in mesh.peers) {
      _reach(peer);
    }
    state = state.copyWith(state: Talking.on);
  }

  /// Hangs up. The room may still be offering voice; this phone is out of it.
  Future<void> leave() async {
    await _down();
    state = const Voice();
  }

  /// Stops sending, without leaving. The link stays open, which is what
  /// makes unmuting instant.
  void mute(bool quiet) {
    for (final track in _mine?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
      track.enabled = !quiet;
    }
    state = state.copyWith(muted: quiet);
  }

  /// Somebody arrived at a table this phone is already talking at.
  void peerArrived(String peer) {
    if (state.isOn) _reach(peer);
  }

  void peerLeft(String peer) {
    unawaited(_links_.remove(peer)?.close());
    state = state.copyWith(
      reaching: {...state.reaching}..remove(peer),
      talking: {...state.talking}..remove(peer),
    );
  }

  /// Opens a link to one peer.
  ///
  /// Who offers is decided by comparing the two keys rather than by who got
  /// there first. Both sides offering at once is glare, and the cure for
  /// glare is not to have any.
  void _reach(String peer) {
    final mesh = _mesh;
    final mine = _mine;
    if (mesh == null || mine == null || _links_.containsKey(peer)) return;

    final link = links.link(
      peer: peer,
      mine: mine,
      weOffer: mesh.me.compareTo(peer) < 0,
      turn: _turn,
    );
    _links_[peer] = link;
    state = state.copyWith(reaching: {...state.reaching, peer});

    _watching.add(
      link.signals.listen((signal) => mesh.signalVoice(peer, signal)),
    );
    _watching.add(
      link.speaking.listen((loud) {
        final talking = {...state.talking};
        if (loud) {
          talking.add(peer);
        } else {
          talking.remove(peer);
        }
        state = state.copyWith(talking: talking);
      }),
    );
    unawaited(
      link.open.then((trouble) {
        if (trouble == null) return;
        // One peer being unreachable is one peer being unreachable. It is
        // not a reason to take the call down for everybody, which is what
        // reporting it as the room's state would do.
        debugPrint('[voice] $peer: ${trouble.name}');
        state = state.copyWith(
          reaching: {...state.reaching}..remove(peer),
          talking: {...state.talking}..remove(peer),
        );
      }),
    );
  }

  void _heard(VoiceSignal signal) {
    // An introduction from somebody this phone has not opened to yet, while
    // it is in, means they joined voice after it did and offered first.
    if (!_links_.containsKey(signal.from) && state.isOn) _reach(signal.from);
    unawaited(_links_[signal.from]?.take(signal.body));
  }

  Future<void> _down() async {
    for (final watching in _watching) {
      await watching.cancel();
    }
    _watching.clear();
    for (final link in _links_.values) {
      await link.close();
    }
    _links_.clear();
    for (final track in _mine?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
      await track.stop();
    }
    await _mine?.dispose();
    _mine = null;
  }
}

final voiceProvider = NotifierProvider<VoiceRoom, Voice>(VoiceRoom.new);
