import 'package:flutter/foundation.dart';

/// Who is holding a seat.
///
/// A seat at a table with people on other phones is owned by a key, the
/// host's included. The same seat is read on every phone, so whether this
/// phone may act for it is not stored here; it is asked, with this phone's
/// own key, in [actableHere].
@immutable
class SeatOwner {
  const SeatOwner._(this._peerId, this._here);

  /// Somebody at this device, at a table with no transport under it: solo, or
  /// a pod around one tablet, where several seats are held here at once.
  ///
  /// Never for a table that will travel. `here` is true on exactly one phone
  /// and the wire is read on every phone, so a `here` that arrives is the
  /// sender's own seat made actable by whoever reads it. The wire refuses it.
  const SeatOwner.here() : this._(null, true);

  /// Somebody at the table by key, this device included when it has one.
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
  ///
  /// [me] is this device's key on the transport, or null when there is none.
  /// A seat held [here] is this device's whatever the key, because there is
  /// nobody else to hold it; a keyed seat is this device's only when the key
  /// is its own, so a null key holds no keyed seat at all.
  bool actableHere({required String? me}) =>
      _here || (_peerId != null && _peerId == me);

  @override
  bool operator ==(Object other) =>
      other is SeatOwner && other._peerId == _peerId && other._here == _here;

  @override
  int get hashCode => Object.hash(_peerId, _here);
}
