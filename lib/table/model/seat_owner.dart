import 'package:flutter/foundation.dart';

/// Who is holding a seat.
///
/// One of the three cases is unreachable until plan 3 puts somebody on the
/// other end of a connection. It is here anyway, because a seat that cannot
/// say who holds it would have to be rewritten rather than extended, and the
/// screen has to ask the question from the day it draws a second seat.
@immutable
class SeatOwner {
  const SeatOwner._(this._peerId, this._here);

  /// Somebody at this device. Several seats can be held here at once, which is
  /// a pod around one tablet.
  const SeatOwner.here() : this._(null, true);

  /// Somebody on the other end of a connection.
  const SeatOwner.peer(String peerId) : this._(peerId, false);

  /// A chair nobody has sat in.
  const SeatOwner.empty() : this._(null, false);

  final String? _peerId;
  final bool _here;

  bool get isHere => _here;
  bool get isEmpty => !_here && _peerId == null;
  String? get peerId => _peerId;

  /// Whether this device may act for this seat. The screen reads it before
  /// offering a control: a seat somebody else holds is watched, not played.
  bool get actableHere => _here;

  @override
  bool operator ==(Object other) =>
      other is SeatOwner && other._peerId == _peerId && other._here == _here;

  @override
  int get hashCode => Object.hash(_peerId, _here);
}
