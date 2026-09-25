import 'package:flutter/foundation.dart';

/// A way of getting a string to another seat, and nothing else.
///
/// This is the seam. Behind it, in the next slice, are Nostr for the
/// introduction and WebRTC for the connection; in this one there is a fake
/// wired up in memory. Nothing above this line may learn which, because the
/// moment the mesh knows what a relay is, the mesh is what has to be rewritten
/// when the relay changes.
///
/// It carries [String]s. The wire in `table/wire/` already turns a verb and a
/// whole table into one, and a transport that took a `Map` would have to be
/// told about the shapes it carries, which is the coupling this file exists to
/// refuse.
abstract class Transport {
  /// Who this device is, in whatever names peers on this transport.
  ///
  /// Given by the transport rather than chosen above it: a real one has an
  /// identity already, a Nostr key or a channel, and a mesh that minted its own
  /// name would have two.
  String get me;

  /// Who can be reached right now, never including [me].
  ///
  /// The set the mesh reads to decide who is at the table, so it changes as
  /// connections come and go and it is the transport's answer rather than a
  /// remembered list.
  Set<String> get peers;

  /// What arrived, and who from.
  ///
  /// The `from` is the transport's word, not the sender's: a peer that could
  /// put any name on its own messages could impersonate the host, and the
  /// succession rules here are built on knowing who spoke.
  Stream<Incoming> get incoming;

  /// Peers turning up and going away.
  Stream<PeerEvent> get presence;

  /// Hands one string to one peer.
  ///
  /// Returns nothing and takes no callback. Not a `Future`, deliberately: a
  /// data channel send is a datagram handed over, and the way a real transport
  /// reports that a peer is gone is [presence] rather than a failure here. A
  /// `Future<void>` would invite the mesh to wait for a delivery nobody
  /// promised and would put an await in the middle of handling an event.
  void send(String peerId, String body);

  /// Lets everything go. The mesh calls this and never anything under it.
  Future<void> close();
}

/// One string that arrived from one peer.
@immutable
class Incoming {
  const Incoming({required this.from, required this.body});

  /// Which peer sent it, according to the transport.
  final String from;

  final String body;

  @override
  String toString() => 'Incoming(from: $from, body: $body)';
}

/// Whether a peer just turned up or just went away.
enum Presence { arrived, left }

/// A peer turning up or going away.
@immutable
class PeerEvent {
  const PeerEvent(this.peerId, this.presence);

  final String peerId;
  final Presence presence;

  @override
  String toString() => 'PeerEvent($peerId, ${presence.name})';
}
