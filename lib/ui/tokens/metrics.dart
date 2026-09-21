import 'dart:ui';

enum DeviceClass { handheld, tv }

/// A television is the only thing we expect to be large and untouchable at the
/// same time. Anything you can touch is being held, however big it is.
///
/// Width rather than shortestSide on purpose: touch already wins for anything
/// held, so width is only ever consulted for a D-pad session, where somebody
/// rotating the screen is not a case worth carrying.
DeviceClass classifyDevice({required Size size, required bool hasTouch}) {
  if (hasTouch) return DeviceClass.handheld;
  return size.width >= 960 ? DeviceClass.tv : DeviceClass.handheld;
}

class Metrics {
  const Metrics({
    required this.scale,
    required this.safeInset,
    required this.focusRing,
  });

  /// Multiplies every font size and every gap. Nothing hardcodes a size.
  ///
  /// This is not Android's sp and has nothing to do with the reader's font size
  /// preference. It is one constant per device class. If accessibility text
  /// scaling is ever honoured it has to come from MediaQuery on top of this,
  /// not instead of it.
  final double scale;

  /// Overscan. Televisions eat their own edges.
  final double safeInset;

  /// Thickness of the focus outline. Across a room a hairline is invisible.
  final double focusRing;

  static const _handheld = Metrics(scale: 1, safeInset: 16, focusRing: 2);
  static const _tv = Metrics(scale: 1.6, safeInset: 48, focusRing: 3);

  static Metrics of(DeviceClass deviceClass) =>
      switch (deviceClass) {
        DeviceClass.handheld => _handheld,
        DeviceClass.tv => _tv,
      };

  double scaled(double base) => base * scale;

  /// How wide the content column may get, for a given amount of room.
  ///
  /// A fixed cap was the first attempt and it was the opposite mistake to the
  /// one it fixed: rows no longer stretched a metre wide, they stayed a phone
  /// strip no matter how much room there was. This grows with the window and
  /// then stops, because a row of text stops being readable somewhere around
  /// eighty characters whatever the screen does.
  double contentWidthFor(double available) {
    if (available < 640 * scale) return available;
    return (available * 0.72).clamp(600 * scale, 860 * scale);
  }
}
