import 'dart:async';

import 'package:kitchentable/table/net/transport.dart';

/// Three phones on a kitchen table, in memory.
///
/// A full mesh: everybody who is here is wired to everybody else who is here,
/// which is the shape the design settled on and the reason this is a network
/// object rather than a pair of transports.
///
/// Nothing is delivered until [settle]. That is the whole point of it. An async
/// test whose delivery happens on its own microtasks passes for reasons nobody
/// chose: a case that awaits the wrong thing, or awaits nothing, reads exactly
/// like a case that works. Here a case that does not pump the queue sees a mesh
/// that has done nothing at all, and a case that wants two peers to act at the
/// same instant enqueues both and then drains, which is the interleaving a real
/// pair of phones on different networks produces and no `await` can arrange.
class FakeNetwork {
  final Map<String, FakeTransport> _seats = {};
  final List<void Function()> _queue = [];

  /// Somebody arrives, is wired to everybody already here, and everybody finds
  /// out. Returns their transport.
  FakeTransport join(String id) {
    final arriving = _seats[id] ?? FakeTransport._(this, id);
    _seats[id] = arriving;
    arriving._live = true;

    for (final sitting in _seats.values) {
      if (sitting.me == id || !sitting._live) continue;
      _tell(sitting, PeerEvent(id, Presence.arrived));
      _tell(arriving, PeerEvent(sitting.me, Presence.arrived));
    }
    return arriving;
  }

  /// Somebody goes through a tunnel. Everybody left sees them go, they see
  /// everybody go, and anything already on its way to or from them is lost,
  /// because that is what a dropped connection does to a packet in flight.
  void drop(String id) {
    final leaving = _seats[id]!;
    leaving._live = false;

    for (final sitting in _seats.values) {
      if (sitting.me == id || !sitting._live) continue;
      _tell(sitting, PeerEvent(id, Presence.left));
      _tell(leaving, PeerEvent(sitting.me, Presence.left));
    }
  }

  /// They come out of the tunnel. The same as [join], and named differently
  /// only because the test is about the second time.
  FakeTransport rejoin(String id) => join(id);

  /// A message no honest build would send, put on the wire as if a peer sent
  /// it.
  ///
  /// A modified client is the threat the design names, so the cases about it
  /// cannot be written with a `Mesh` on the other end: a mesh only sends what
  /// this build's code sends, and the attack is code somebody else wrote. The
  /// `from` is still the transport's word, because a peer cannot forge who it
  /// is, only what it says.
  void forge({required String from, required String to, required String body}) {
    _deliver(from: from, to: to, body: body);
  }

  /// Runs the network until nothing is left in flight.
  ///
  /// One job at a time, with a real turn of the event loop after each, so a
  /// listener that reacts by sending gets its sends queued behind everything
  /// already waiting rather than jumping ahead of them.
  Future<void> settle() async {
    var guard = 0;
    while (_queue.isNotEmpty) {
      if (guard++ > 1000) {
        throw StateError(
          'the network will not settle: ${_queue.length} still in flight after '
          '1000 deliveries, which is a peer answering its own answer',
        );
      }
      _queue.removeAt(0)();
      await Future<void>.delayed(Duration.zero);
    }
  }

  void _tell(FakeTransport seat, PeerEvent event) {
    _queue.add(() {
      // Not guarded on whether this seat is live. The peer that went through the
      // tunnel is the one that most needs to hear that everybody has gone: a
      // real data channel closes at both ends, and a fake that told only the
      // people left behind would leave the dropped peer believing it could still
      // reach them, which is exactly the peer that has to notice it is behind.
      if (seat._presence.isClosed) return;

      // The reachable set changes as the news is delivered rather than when it
      // is sent, so `peers` and `presence` never disagree about who is here.
      switch (event.presence) {
        case Presence.arrived:
          seat._peers.add(event.peerId);
        case Presence.left:
          seat._peers.remove(event.peerId);
      }
      seat._presence.add(event);
    });
  }

  void _deliver({
    required String from,
    required String to,
    required String body,
  }) {
    final sender = _seats[from];
    final receiver = _seats[to];
    if (sender == null || receiver == null || !sender._live) return;

    _queue.add(() {
      if (!sender._live || !receiver._live) return;
      if (receiver._incoming.isClosed) return;
      receiver._incoming.add(Incoming(from: from, body: body));
    });
  }
}

class FakeTransport implements Transport {
  FakeTransport._(this._net, this.me);

  final FakeNetwork _net;

  @override
  final String me;

  bool _live = false;
  final Set<String> _peers = {};

  final _incoming = StreamController<Incoming>.broadcast();
  final _presence = StreamController<PeerEvent>.broadcast();

  /// Everything this peer put on the wire, in order, so a case can ask what was
  /// sent as well as what arrived. What is not here is as interesting as what
  /// is: a peer that relays an action it received would show it.
  final List<({String to, String body})> sent = [];

  @override
  Set<String> get peers => Set.unmodifiable(_peers);

  @override
  Stream<Incoming> get incoming => _incoming.stream;

  @override
  Stream<PeerEvent> get presence => _presence.stream;

  @override
  void send(String peerId, String body) {
    sent.add((to: peerId, body: body));
    _net._deliver(from: me, to: peerId, body: body);
  }

  @override
  Future<void> close() async {
    _live = false;
    await _incoming.close();
    await _presence.close();
  }
}
