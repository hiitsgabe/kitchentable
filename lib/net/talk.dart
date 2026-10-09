import 'dart:async';
import 'dart:convert';

import '../table/wire/wire.dart';
import 'transport.dart';

/// One step of a WebRTC introduction, on its way to or from one peer.
///
/// Carried and never read. Voice is a second connection to the same people,
/// opened over the one that already works: the relays carry the
/// introduction, and the audio goes straight across if it can. That is what
/// every Nostr WebRTC draft does, and it is why nobody needs a server for
/// the signalling half.
typedef VoiceSignal = ({String from, Map<String, Object?> body});

/// Something somebody typed, and whose key typed it.
///
/// Deliberately not a table action. A line of chat is not a thing that
/// happened to the cards: it must not be undone by undo, it must not arrive
/// in the snapshot a late guest is handed, and the referee has no opinion
/// about it. It rides the same wire and nothing else.
typedef Said = ({String by, String text});

/// The people at a room talking to each other: typed lines, and the
/// introductions between microphones that voice is built on.
///
/// An interface rather than the mesh, because the mesh is the table and a
/// room talks before it has one: the chairs are filling, the draft is going
/// round, and the people in it are the same people. The mesh is one of
/// these; a [TalkChannel] over the room's transport is the other.
abstract interface class Talk {
  /// Who this device is, in the transport's names.
  String get me;

  /// Everybody reachable right now, by key.
  Set<String> get peers;

  /// Somebody arriving or leaving, so a microphone can reach them or let
  /// them go.
  Stream<PeerEvent> get presence;

  /// Everything anybody has typed, this phone included.
  Stream<Said> get chatter;

  /// Introductions between microphones, forwarded and never read. Not
  /// fanned back to the sender: an offer is for one peer.
  Stream<VoiceSignal> get voiceSignals;

  /// Says something to everybody.
  void say(String text);

  /// Hands one step of an introduction to one peer.
  void signalVoice(String peer, Map<String, Object?> body);
}

/// Talk over a shared transport, beside whatever else rides it.
///
/// Its messages carry their own scope, so a mesh on the same transport
/// ignores them the way it ignores another table's, and its kinds are its
/// own, so nothing else mistakes a line of chat for a verb. It is the
/// lobby's, made when the room is and kept for the room's life, which is
/// what lets two people talk while the third is still finding the link.
class TalkChannel implements Talk {
  TalkChannel(this._transport) {
    _listening = _transport.incoming.listen(_heard);
  }

  /// The scope every message of this channel carries. A mesh of any scope
  /// sees a message of another scope and leaves it alone.
  static const scope = 'talk';

  final Transport _transport;
  final _chatter = StreamController<Said>.broadcast();
  final _voice = StreamController<VoiceSignal>.broadcast();
  StreamSubscription<Incoming>? _listening;

  @override
  String get me => _transport.me;

  @override
  Set<String> get peers => _transport.peers;

  @override
  Stream<PeerEvent> get presence => _transport.presence;

  @override
  Stream<Said> get chatter => _chatter.stream;

  @override
  Stream<VoiceSignal> get voiceSignals => _voice.stream;

  @override
  void say(String text) {
    final said = text.trim();
    if (said.isEmpty || _chatter.isClosed) return;
    _chatter.add((by: me, text: said));
    final body = _wrap('talk', {'text': said});
    for (final peer in _transport.peers) {
      _transport.send(peer, body);
    }
  }

  @override
  void signalVoice(String peer, Map<String, Object?> body) {
    if (!_transport.peers.contains(peer)) return;
    _transport.send(peer, _wrap('talk-voice', {'body': body}));
  }

  Future<void> close() async {
    await _listening?.cancel();
    _listening = null;
    await _chatter.close();
    await _voice.close();
  }

  /// The envelope: the wire's version, so a lobby reading it sees a message
  /// of this build, the scope, so it sees one that is not its own, and the
  /// kind.
  String _wrap(String kind, Map<String, Object?> more) =>
      jsonEncode({'v': wireVersion, 'kind': kind, 'scope': scope, ...more});

  void _heard(Incoming message) {
    final Map<String, Object?> json;
    try {
      json = (jsonDecode(message.body) as Map).cast<String, Object?>();
    } catch (_) {
      return;
    }
    if (json['scope'] != scope) return;
    switch (json['kind']) {
      case 'talk':
        final text = json['text'];
        if (text is String && text.trim().isNotEmpty && !_chatter.isClosed) {
          _chatter.add((by: message.from, text: text.trim()));
        }
      case 'talk-voice':
        final body = json['body'];
        if (body is Map<String, Object?> && !_voice.isClosed) {
          _voice.add((from: message.from, body: body));
        }
    }
  }
}
