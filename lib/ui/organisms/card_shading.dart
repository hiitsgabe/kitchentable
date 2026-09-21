import 'dart:math' as math;

/// Everything the card viewer needs to know about how a card is lit, worked
/// out from how it is turned.
///
/// Pulled out of the widget so it can be tested at angles a person would need
/// a minute of dragging to reach. The bug that prompted it only showed after
/// more than one full turn, which is exactly the region nobody checks by hand.
class CardShading {
  CardShading({required double yaw, required this.pitch})
      : yaw = _wrap(yaw),
        _facing = math.cos(_wrap(yaw));

  final double yaw;
  final double pitch;
  final double _facing;

  /// Turn kept inside one revolution. Without this the angle grows without
  /// bound as somebody keeps spinning, and every value below that depends on
  /// the sign of the turn starts disagreeing with the face actually showing.
  static double _wrap(double a) {
    const twoPi = 2 * math.pi;
    final r = a % twoPi;
    return r > math.pi ? r - twoPi : (r < -math.pi ? r + twoPi : r);
  }

  /// True when the far side is the one you are looking at.
  bool get showingBack => _facing < 0;

  /// Zero side on, one square to you.
  double get openness => _facing.abs().clamp(0.0, 1.0);

  /// How dark the side swinging away gets.
  double get shadeAlpha => (0.55 * (1 - openness)).clamp(0.0, 1.0);

  /// How bright the gloss band is.
  double get glossAlpha => (0.26 * (1 - openness * 0.5)).clamp(0.0, 1.0);

  /// How solid the shadow on the ground is.
  double get groundAlpha => (0.6 * openness).clamp(0.0, 1.0);

  /// How visible the card's edge is. Cubed so it is gone well before the face
  /// becomes readable.
  double get edgeAlpha =>
      math.pow(1 - openness, 3).toDouble().clamp(0.0, 1.0);

  /// Which way the dark side sits. Reads the face that is showing rather than
  /// the raw angle, so it stays correct after the card has been turned round
  /// more than once.
  bool get shadeOnRight => math.sin(yaw) > 0;

  /// How far along the gloss band has slid.
  double get glossOffset => math.sin(yaw) * 2;

  double get groundDx => -math.sin(yaw);
  double get groundDy => math.sin(pitch);
}
