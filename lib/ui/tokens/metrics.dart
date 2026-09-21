import 'dart:ui';

enum DeviceClass { handheld, tv }

/// A television is the only thing we expect to be large and untouchable at the
/// same time. Anything you can touch is being held, however big it is.
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

  double sp(double base) => base * scale;
}
