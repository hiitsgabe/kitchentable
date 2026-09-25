import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../decks/model/deck_format.dart';

/// What a room code is spelled out of.
///
/// Twenty three letters and eight digits: no `o` or `0`, no `i`, `l` or `1`.
/// Somebody is going to read a code out loud across a kitchen table rather than
/// send it, and a pair that sounds or looks alike costs a rejoin attempt every
/// time. Dropping five characters costs a little under a bit per character and
/// buys a code you can say.
const roomCodeAlphabet = 'abcdefghjkmnpqrstuvwxyz23456789';

/// Four, a dash, three. Derived from the alphabet rather than typed out again,
/// so a character added there cannot be a character this refuses.
final roomCodePattern =
    RegExp('^[$roomCodeAlphabet]{4}-[$roomCodeAlphabet]{3}\$');

/// How many chairs a room may have. The screen reads this rather than typing
/// out 2 and 4, and a fifth chair is a decision about the layout and not a
/// number to raise here.
const roomSeatChoices = [2, 3, 4];

/// What a link puts in front of the code.
const _roomMarker = '#room=';

/// Not seeded, and secure rather than merely random.
///
/// The code is the whole of the invitation: there is no password behind it, so
/// a generator somebody can predict is a room somebody can walk into. It is
/// seven characters out of thirty one, which is about thirty five bits, and
/// that is a room nobody guesses without being told rather than a secret.
final _random = Random.secure();

/// A code for a room nobody has made yet.
String freshRoomCode() {
  String run(int length) => [
        for (var i = 0; i < length; i++)
          roomCodeAlphabet[_random.nextInt(roomCodeAlphabet.length)],
      ].join();

  return '${run(4)}-${run(3)}';
}

/// The link you send, or hold up as a QR code.
///
/// A name and not an address, which the design settled: it says which room,
/// never which machine, so it needs no DNS of ours, no tunnel, no open port and
/// no server, and it works in both directions and more than once.
///
/// The code goes in the fragment on purpose. A fragment is never sent to the
/// server that hands over the page, so the only copy of it is in the hands of
/// the people at the table.
String linkFor(String code, {required String origin}) {
  final base =
      origin.endsWith('/') ? origin.substring(0, origin.length - 1) : origin;
  return '$base/$_roomMarker${code.toLowerCase()}';
}

/// The code out of a link, a pasted line, or the browser's own hash. Null when
/// there is no code in there.
///
/// Case insensitive, because a code that was read out loud and typed back in
/// has a case and the person typing it did not choose one.
String? codeFrom(String link) {
  final at = link.indexOf(_roomMarker);
  if (at < 0) return null;

  final code = link.substring(at + _roomMarker.length).toLowerCase();

  // Shaped like a code or nothing. A code holding an `o` or a `1` was misheard
  // rather than minted, and there is nothing to repair it to: no character in
  // the alphabet is confusable with another, which is the point of the
  // alphabet. Better to say this is not a room link than to carry a typo as
  // far as the mesh and come back with no such room.
  return roomCodePattern.hasMatch(code) ? code : null;
}

/// What the host set up before anybody arrived.
///
/// A value, because Task 3 holds one in provider state and rebuilds a screen
/// off it while somebody types into it.
@immutable
class RoomConfig {
  RoomConfig({
    required this.format,
    required this.seats,
    required this.hostName,
    required this.roomName,
    int? life,
  })  : life = life ?? format.startingLife,
        assert(
          roomSeatChoices.contains(seats),
          'a room seats one of $roomSeatChoices, not $seats',
        );

  final DeckFormat format;

  /// How many chairs, including the host's.
  final int seats;

  /// Where everybody starts.
  ///
  /// Defaulted from the format at construction and editable afterwards, because
  /// forty is where Commander starts and not a rule: people play thirty. The
  /// default lives here rather than in [copyWith] so that changing the format
  /// later leaves a number somebody typed alone.
  final int life;

  final String hostName;

  /// What the room is called, which is what the people joining see before they
  /// see anything else.
  final String roomName;

  RoomConfig copyWith({
    DeckFormat? format,
    int? seats,
    int? life,
    String? hostName,
    String? roomName,
  }) =>
      RoomConfig(
        format: format ?? this.format,
        seats: seats ?? this.seats,
        life: life ?? this.life,
        hostName: hostName ?? this.hostName,
        roomName: roomName ?? this.roomName,
      );

  @override
  bool operator ==(Object other) =>
      other is RoomConfig &&
      other.format == format &&
      other.seats == seats &&
      other.life == life &&
      other.hostName == hostName &&
      other.roomName == roomName;

  @override
  int get hashCode => Object.hash(format, seats, life, hostName, roomName);
}
