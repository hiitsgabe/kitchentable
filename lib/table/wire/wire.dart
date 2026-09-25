import 'dart:convert';

import '../actions/table_action.dart';
import '../model/card_instance.dart';
import '../model/seat.dart';
import '../model/seat_owner.dart';
import '../model/table_state.dart';
import '../model/zone.dart';

/// What this build speaks.
///
/// Bumped when a shape changes, never when a verb is added: a new verb is
/// already an error that names itself on the other side, and a version bump
/// would refuse the whole table instead of the one thing nobody understood.
const wireVersion = 1;

/// A wire that could not be read, and why, in words that name the thing.
///
/// An exception and not a null, because every way this fails is a table about
/// to disagree with itself. A peer that drops what it does not understand goes
/// on drawing a correct looking screen of a game the others are no longer
/// playing.
class WireError implements Exception {
  const WireError(this.message);

  final String message;

  @override
  String toString() => 'WireError: $message';
}

/// Puts a verb on the wire.
///
/// Hand written rather than generated: eleven verbs is less work than a build
/// step, and the switch below is exhaustive over the sealed set, so a twelfth
/// verb does not compile until somebody writes its line. That is the check that
/// cannot be forgotten, and it is why this is a switch expression with no
/// default clause.
String toWire(TableAction action) => jsonEncode({
      'v': wireVersion,
      ..._verbToJson(action),
    });

/// Reads a verb back off the wire.
TableAction fromWire(String wire) {
  final json = _objectFrom(wire);
  _checkVersion(json);

  final type = json['type'];
  return switch (type) {
    'MoveCard' => MoveCard(
        cardId: _string(json, 'cardId'),
        toZoneId: _string(json, 'toZoneId'),
        at: _intOrNull(json, 'at'),
        faceDown: _boolOrNull(json, 'faceDown'),
        position: _positionFrom(json['position']),
      ),
    'RotateCard' => RotateCard(
        _string(json, 'cardId'),
        to: _intOrNull(json, 'to'),
      ),
    'FlipCard' => FlipCard(_string(json, 'cardId')),
    'ChangeCounter' => ChangeCounter(
        cardId: _string(json, 'cardId'),
        kind: _string(json, 'kind'),
        by: _int(json, 'by'),
      ),
    'AttachCard' => AttachCard(
        cardId: _string(json, 'cardId'),
        toCardId: _stringOrNull(json, 'toCardId'),
      ),
    'ShuffleZone' => ShuffleZone(
        zoneId: _string(json, 'zoneId'),
        seed: _string(json, 'seed'),
      ),
    'DrawCards' => DrawCards(
        fromZoneId: _string(json, 'fromZoneId'),
        toZoneId: _string(json, 'toZoneId'),
        count: _int(json, 'count'),
      ),
    'CreateToken' => CreateToken(
        zoneId: _string(json, 'zoneId'),
        oracleId: _string(json, 'oracleId'),
        cardId: _string(json, 'cardId'),
      ),
    'ChangeLife' => ChangeLife(
        seatId: _string(json, 'seatId'),
        by: _int(json, 'by'),
      ),
    'RollDice' => RollDice(_ints(json, 'results')),
    'PassTurn' => const PassTurn(),
    _ => throw WireError(
        'unknown verb "$type". This build speaks eleven and that is not one of '
        'them, so the peer that sent it is running something newer.',
      ),
  };
}

Map<String, Object?> _verbToJson(TableAction action) => switch (action) {
      MoveCard() => {
          'type': 'MoveCard',
          'cardId': action.cardId,
          'toZoneId': action.toZoneId,
          'at': action.at,
          'faceDown': action.faceDown,
          'position': _positionToJson(action.position),
        },
      RotateCard() => {
          'type': 'RotateCard',
          'cardId': action.cardId,
          'to': action.to,
        },
      FlipCard() => {
          'type': 'FlipCard',
          'cardId': action.cardId,
        },
      ChangeCounter() => {
          'type': 'ChangeCounter',
          'cardId': action.cardId,
          'kind': action.kind,
          'by': action.by,
        },
      AttachCard() => {
          'type': 'AttachCard',
          'cardId': action.cardId,
          'toCardId': action.toCardId,
        },
      ShuffleZone() => {
          'type': 'ShuffleZone',
          'zoneId': action.zoneId,
          'seed': action.seed,
        },
      DrawCards() => {
          'type': 'DrawCards',
          'fromZoneId': action.fromZoneId,
          'toZoneId': action.toZoneId,
          'count': action.count,
        },
      CreateToken() => {
          'type': 'CreateToken',
          'zoneId': action.zoneId,
          'oracleId': action.oracleId,
          'cardId': action.cardId,
        },
      ChangeLife() => {
          'type': 'ChangeLife',
          'seatId': action.seatId,
          'by': action.by,
        },
      RollDice() => {
          'type': 'RollDice',
          'results': action.results,
        },
      PassTurn() => {'type': 'PassTurn'},
    };

/// The whole table, for a peer arriving late.
///
/// Everything, in the clear, including hands and libraries: what stops a peer
/// drawing somebody else's hand is `ZoneVisibility` and the software reading it,
/// which is a promise about the client and not about the wire. The room screen
/// says so out loud rather than leaving it to be assumed.
String stateToWire(TableState table) => jsonEncode({
      'v': wireVersion,
      'turnSeatId': table.turnSeatId,
      'dice': table.dice,
      'seats': [for (final seat in table.seats) _seatToJson(seat)],
    });

TableState stateFromWire(String wire) {
  final json = _objectFrom(wire);
  _checkVersion(json);

  return TableState(
    seats: [
      for (final seat in _list(json, 'seats')) _seatFrom(_object(seat, 'seat')),
    ],
    turnSeatId: _stringOrNull(json, 'turnSeatId'),
    dice: _ints(json, 'dice'),
  );
}

Map<String, Object?> _seatToJson(Seat seat) => {
      'id': seat.id,
      'name': seat.name,
      'life': seat.life,
      'owner': _ownerToJson(seat.owner),
      'zones': [for (final zone in seat.zones) _zoneToJson(zone)],
    };

Seat _seatFrom(Map<String, Object?> json) => Seat(
      id: _string(json, 'id'),
      name: _string(json, 'name'),
      life: _int(json, 'life'),
      owner: _ownerFrom(_string(json, 'owner')),
      zones: [
        for (final zone in _list(json, 'zones')) _zoneFrom(_object(zone, 'zone')),
      ],
    );

/// `SeatOwner` holds its two fields privately and is built through three named
/// constructors, so this reads the getters and picks the constructor back.
String _ownerToJson(SeatOwner owner) {
  if (owner.isHere) return 'here';
  final peerId = owner.peerId;
  return peerId == null ? 'empty' : 'peer:$peerId';
}

SeatOwner _ownerFrom(String owner) {
  if (owner == 'here') return const SeatOwner.here();
  if (owner == 'empty') return const SeatOwner.empty();
  if (owner.startsWith('peer:')) {
    return SeatOwner.peer(owner.substring('peer:'.length));
  }
  throw WireError('a seat is held by "$owner", which is nobody this build knows');
}

Map<String, Object?> _zoneToJson(Zone zone) => {
      'id': zone.id,
      'seatId': zone.seatId,
      'label': zone.label,
      'visibility': zone.visibility.name,
      'ordered': zone.ordered,
      'cards': [for (final card in zone.cards) _cardToJson(card)],
    };

Zone _zoneFrom(Map<String, Object?> json) => Zone(
      id: _string(json, 'id'),
      seatId: _string(json, 'seatId'),
      label: _string(json, 'label'),
      visibility: _visibilityFrom(_string(json, 'visibility')),
      ordered: _bool(json, 'ordered'),
      cards: [
        for (final card in _list(json, 'cards')) _cardFrom(_object(card, 'card')),
      ],
    );

ZoneVisibility _visibilityFrom(String name) {
  for (final visibility in ZoneVisibility.values) {
    if (visibility.name == name) return visibility;
  }
  throw WireError(
    'a zone is visible to "$name", which is not one of the three this build '
    'knows: ${ZoneVisibility.values.map((v) => v.name).join(', ')}',
  );
}

Map<String, Object?> _cardToJson(CardInstance card) => {
      'id': card.id,
      'oracleId': card.oracleId,
      'rotation': card.rotation,
      'faceDown': card.faceDown,
      'counters': card.counters,
      'attachedTo': card.attachedTo,
      'position': _positionToJson(card.position),
    };

CardInstance _cardFrom(Map<String, Object?> json) => CardInstance(
      id: _string(json, 'id'),
      oracleId: _string(json, 'oracleId'),
      rotation: _int(json, 'rotation'),
      faceDown: _bool(json, 'faceDown'),
      counters: _counters(json, 'counters'),
      attachedTo: _stringOrNull(json, 'attachedTo'),
      position: _positionFrom(json['position']),
    );

Map<String, Object?>? _positionToJson(({double x, double y})? position) =>
    position == null ? null : {'x': position.x, 'y': position.y};

({double x, double y})? _positionFrom(Object? json) {
  if (json == null) return null;
  final map = _object(json, 'position');
  return (x: _double(map, 'x'), y: _double(map, 'y'));
}

// The readers. Each one says which field was wrong and what it held, because a
// wire arrives from somebody else's build and `as` would only say the types.

Map<String, Object?> _objectFrom(String wire) {
  final Object? json;
  try {
    json = jsonDecode(wire);
  } on FormatException catch (e) {
    throw WireError('this is not JSON: ${e.message}');
  }
  return _object(json, 'wire');
}

Map<String, Object?> _object(Object? json, String what) {
  if (json is Map<String, Object?>) return json;
  throw WireError('a $what should be an object and this is ${json.runtimeType}');
}

void _checkVersion(Map<String, Object?> json) {
  final version = json['v'];
  if (version == wireVersion) return;
  throw WireError(
    'wire version $version, and this build speaks $wireVersion. Somebody at '
    'this table is running a different one.',
  );
}

Never _wrong(String key, Object? value, String wanted) => throw WireError(
      '"$key" should be $wanted and it is ${value.runtimeType} ($value)',
    );

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  return value is String ? value : _wrong(key, value, 'a string');
}

String? _stringOrNull(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  return value is String ? value : _wrong(key, value, 'a string or absent');
}

int _int(Map<String, Object?> json, String key) {
  final value = json[key];
  return value is int ? value : _wrong(key, value, 'a whole number');
}

int? _intOrNull(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  return value is int ? value : _wrong(key, value, 'a whole number or absent');
}

double _double(Map<String, Object?> json, String key) {
  final value = json[key];
  // A round number comes back off JSON as an int on one platform and a double
  // on another, and a position of exactly 1 is a corner somebody will use.
  return value is num ? value.toDouble() : _wrong(key, value, 'a number');
}

bool _bool(Map<String, Object?> json, String key) {
  final value = json[key];
  return value is bool ? value : _wrong(key, value, 'true or false');
}

bool? _boolOrNull(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  return value is bool ? value : _wrong(key, value, 'true, false or absent');
}

List<Object?> _list(Map<String, Object?> json, String key) {
  final value = json[key];
  return value is List ? value : _wrong(key, value, 'a list');
}

List<int> _ints(Map<String, Object?> json, String key) => [
      for (final value in _list(json, key))
        value is int ? value : _wrong(key, value, 'a list of whole numbers'),
    ];

Map<String, int> _counters(Map<String, Object?> json, String key) => {
      for (final entry in _object(json[key], 'counter map').entries)
        entry.key: entry.value is int
            ? entry.value as int
            : _wrong(key, entry.value, 'a map of whole numbers'),
    };
