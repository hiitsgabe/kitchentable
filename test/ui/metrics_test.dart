import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

void main() {
  test('a wide screen with no touch is a television', () {
    expect(
      classifyDevice(size: const Size(1920, 1080), hasTouch: false),
      DeviceClass.tv,
    );
  });

  test('a wide screen you can touch is still a handheld', () {
    expect(
      classifyDevice(size: const Size(1920, 1080), hasTouch: true),
      DeviceClass.handheld,
    );
  });

  test('a small screen is a handheld whatever it claims about touch', () {
    expect(
      classifyDevice(size: const Size(640, 480), hasTouch: false),
      DeviceClass.handheld,
    );
  });

  test('television metrics are bigger than handheld metrics', () {
    expect(Metrics.of(DeviceClass.tv).scale,
        greaterThan(Metrics.of(DeviceClass.handheld).scale));
    expect(Metrics.of(DeviceClass.tv).safeInset,
        greaterThan(Metrics.of(DeviceClass.handheld).safeInset));
  });
}
