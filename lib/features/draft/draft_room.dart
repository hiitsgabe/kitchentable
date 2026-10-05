import 'dart:async';
import 'dart:convert';

import '../../decks/model/deck.dart';
import '../../net/transport.dart';
import '../../table/wire/deck_wire.dart';
import 'booster_roller.dart';
import 'draft_state.dart';
import 'draft_table.dart';

/// The real-time draft, over a [Transport], host-authoritative.
///
/// The host holds the one [DraftTable] and pushes each seat only its own
/// [DraftView], so a modified client can never learn another seat's pack: it
/// is simply never sent one. A seat picks by sending its card's uuid to the
/// host, which moves the pack and pushes the seats that changed. This sits
/// beside the mesh rather than inside it, because the mesh replicates the
/// whole table to everyone and a draft is the opposite: everyone sees a
/// different, private thing.
///
/// A seat announces itself with a hello on arrival and the host answers with
/// that seat's first view, so a guest that built its room a moment after the
/// host still gets dealt in.
class DraftRoom {
  /// The host: rolls every pack from [roller] (seeded, so the pod is
  /// reproducible), builds the table, and deals the first views.
  DraftRoom._(this._transport, this._hostId, this._isHost);

  factory DraftRoom.host({
    required Transport transport,
    required List<String> seatIds,
    required bool sealed,
    required int packCount,
    required BoosterRoller roller,
  }) {
    final packs = [
      for (final _ in seatIds)
        [
          for (var r = 0; r < packCount; r++)
            [
              for (final p in roller.rollPack())
                DraftCard(uuid: p.uuid, oracleId: p.oracleId, rarity: p.rarity),
            ],
        ],
    ];
    return DraftRoom.fromPacks(
      transport: transport,
      seatIds: seatIds,
      sealed: sealed,
      packsPerSeat: packs,
    );
  }

  /// The host, over packs already rolled. [DraftRoom.host] is this with the
  /// roller run for you; a demo or a test that wants a known pod passes its own
  /// packs here instead.
  factory DraftRoom.fromPacks({
    required Transport transport,
    required List<String> seatIds,
    required bool sealed,
    required List<List<List<DraftCard>>> packsPerSeat,
  }) {
    final room = DraftRoom._(transport, transport.me, true);
    room._table = DraftTable(
      seatIds: seatIds,
      sealed: sealed,
      packsPerSeat: packsPerSeat,
    );
    room._listen();
    room._pushAll();
    return room;
  }

  /// A seat that is not the host: a thin client that sends picks and renders
  /// whatever view the host sends it.
  factory DraftRoom.guest({
    required Transport transport,
    required String hostId,
  }) {
    final room = DraftRoom._(transport, hostId, false);
    room._listen();
    transport.send(hostId, room._wrap('draft-hello'));
    return room;
  }

  final Transport _transport;
  final String _hostId;
  final bool _isHost;
  DraftTable? _table;

  final _views = StreamController<DraftView>.broadcast();
  Stream<DraftView> get views => _views.stream;

  DraftView? _view;

  /// The latest view of this seat, or null before the first one arrives.
  DraftView? get view => _view;

  /// The decks players have built from their pools, by seat. On the host that
  /// is everyone's, as they come in; on a guest it is only its own.
  final _built = <String, Deck>{};

  /// Everyone's built deck, by seat. The host hands these to the deal.
  Map<String, Deck> get builtDecks => Map.unmodifiable(_built);

  /// Whether every seat has turned its pool into a deck, so the host can deal.
  bool get allBuilt {
    final table = _table;
    if (table == null) return false;
    return table.seatIds.every(_built.containsKey);
  }

  /// Called on the host whenever a built deck arrives, so a lobby watching can
  /// see [allBuilt] turn true. Called on a guest when the host says the table
  /// is dealt, so it can leave the draft for the mesh.
  void Function()? onBuiltChanged;
  void Function()? onDealt;

  StreamSubscription<Incoming>? _sub;

  void _listen() {
    _sub = _transport.incoming.listen(_heard);
  }

  void _heard(Incoming message) {
    final Map<String, Object?> json;
    try {
      json = (jsonDecode(message.body) as Map).cast<String, Object?>();
    } catch (_) {
      return;
    }
    switch (json['kind']) {
      case 'draft-hello' when _isHost:
        _pushTo(message.from);
      case 'draft-pick' when _isHost:
        final uuid = json['uuid'];
        if (uuid is String) {
          _table!.pick(message.from, uuid);
          _pushAll();
        }
      case 'draft-state' when !_isHost && message.from == _hostId:
        final view = json['view'];
        if (view is Map) {
          _emit(DraftView.fromJson(view.cast<String, Object?>()));
        }
      case 'draft-built' when _isHost:
        final wire = json['deck'];
        if (wire is String) {
          _built[message.from] = deckFromWire(wire);
          onBuiltChanged?.call();
        }
      case 'dealt' when !_isHost && message.from == _hostId:
        // The host turned the finished draft into a table. The draft is over;
        // the lobby takes it from here and joins the mesh.
        onDealt?.call();
    }
  }

  /// Hands this seat's finished deck in. The host records it; a guest sends it
  /// to the host and keeps its own copy, which the lobby reads for its seat.
  void submit(Deck deck) {
    _built[_transport.me] = deck;
    if (_isHost) {
      onBuiltChanged?.call();
    } else {
      _transport.send(
        _hostId,
        _wrap('draft-built', {'deck': deckToWire(deck)}),
      );
    }
  }

  /// Takes a card. On the host it moves the pack straight away; on a guest it
  /// asks the host to.
  void pick(String uuid) {
    if (_isHost) {
      _table!.pick(_transport.me, uuid);
      _pushAll();
    } else {
      _transport.send(_hostId, _wrap('draft-pick', {'uuid': uuid}));
    }
  }

  void _pushAll() {
    final table = _table!;
    for (final seat in table.seatIds) {
      if (seat == _transport.me) {
        _emit(table.viewFor(seat));
      } else {
        _transport.send(
          seat,
          _wrap('draft-state', {'view': table.viewFor(seat).toJson()}),
        );
      }
    }
  }

  void _pushTo(String seat) {
    final table = _table;
    if (table == null || !table.seatIds.contains(seat)) return;
    if (seat == _transport.me) {
      _emit(table.viewFor(seat));
    } else {
      _transport.send(
        seat,
        _wrap('draft-state', {'view': table.viewFor(seat).toJson()}),
      );
    }
  }

  void _emit(DraftView view) {
    _view = view;
    if (!_views.isClosed) _views.add(view);
  }

  String _wrap(String kind, [Map<String, Object?> more = const {}]) =>
      jsonEncode({'kind': kind, ...more});

  Future<void> close() async {
    await _sub?.cancel();
    await _views.close();
  }
}
