import 'dart:async';

import 'transport.dart';

/// A mesh of [Transport]s living in one isolate, delivering on the microtask
/// queue. The same seam the real net presents, with nothing behind it: for a
/// demo of a networked flow, and for solo play where the only other seats are
/// bots on this device.
///
/// Delivery is asynchronous, a microtask per hop, so the ordering matches a
/// real transport closely enough that code which works here works there. It is
/// deliberately not instant: a handler that sent a reply and expected to see it
/// before returning would be wrong on the wire, and would be wrong here too.
class LoopbackNetwork {
  final _seats = <String, LoopbackTransport>{};

  /// Adds a seat and wires it to everyone already present, both ways.
  LoopbackTransport join(String id) {
    final here = LoopbackTransport._(id, this);
    for (final other in _seats.values) {
      other._arrive(id);
      here._arrive(other.me);
    }
    _seats[id] = here;
    return here;
  }

  /// Removes a seat and tells the rest it is gone.
  void drop(String id) {
    final gone = _seats.remove(id);
    if (gone == null) return;
    for (final other in _seats.values) {
      other._depart(id);
    }
  }

  void _send(String from, String to, String body) {
    final seat = _seats[to];
    if (seat == null) return;
    scheduleMicrotask(() => seat._receive(Incoming(from: from, body: body)));
  }

  Set<String> _othersOf(String id) =>
      {for (final k in _seats.keys) if (k != id) k};
}

class LoopbackTransport implements Transport {
  LoopbackTransport._(this.me, this._net);

  @override
  final String me;

  final LoopbackNetwork _net;

  final _incoming = StreamController<Incoming>.broadcast();
  final _presence = StreamController<PeerEvent>.broadcast();

  @override
  Set<String> get peers => _net._othersOf(me);

  @override
  Stream<Incoming> get incoming => _incoming.stream;

  @override
  Stream<PeerEvent> get presence => _presence.stream;

  @override
  void send(String peerId, String body) => _net._send(me, peerId, body);

  void _receive(Incoming message) {
    if (!_incoming.isClosed) _incoming.add(message);
  }

  void _arrive(String id) {
    if (!_presence.isClosed) _presence.add(PeerEvent(id, Presence.arrived));
  }

  void _depart(String id) {
    if (!_presence.isClosed) _presence.add(PeerEvent(id, Presence.left));
  }

  @override
  Future<void> close() async {
    _net.drop(me);
    await _incoming.close();
    await _presence.close();
  }
}
