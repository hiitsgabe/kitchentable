import 'package:flutter/foundation.dart';

import 'link.dart';
import 'signaling.dart';

/// A transport that can say how its connection is getting on, for a screen
/// to show as facts.
///
/// Apart from [Transport] on purpose: the mesh speaks to the transport and
/// must not learn what a relay or a link is, which is the seam the mesh
/// tests defend. This is the other half, the one the room screen reads and
/// the mesh never does, and it is free to know the vocabulary of both
/// mechanisms because showing a connection is exactly that job. Both the
/// WebRTC transport and the relay transport report the same steps, so the
/// screen does not know or care which one it is watching.
abstract class ReportsConnection {
  Stream<ConnectionStep> get steps;
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
