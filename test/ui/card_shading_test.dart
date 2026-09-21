import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/ui/organisms/card_shading.dart';

void main() {
  test('square on, the card is fully open and unshaded', () {
    final s = CardShading(yaw: 0, pitch: 0);
    expect(s.openness, closeTo(1, 0.001));
    expect(s.shadeAlpha, closeTo(0, 0.001));
    expect(s.showingBack, isFalse);
  });

  test('side on, the card is closed', () {
    final s = CardShading(yaw: math.pi / 2, pitch: 0);
    expect(s.openness, closeTo(0, 0.001));
    expect(s.shadeAlpha, closeTo(0.55, 0.001));
  });

  test('half a turn shows the back, and shows it fully open', () {
    final s = CardShading(yaw: math.pi, pitch: 0);
    expect(s.showingBack, isTrue);
    expect(s.openness, closeTo(1, 0.001),
        reason: 'the back is as square to you as the front was');
  });

  test('a full turn is the same as no turn', () {
    final a = CardShading(yaw: 0, pitch: 0);
    final b = CardShading(yaw: 2 * math.pi, pitch: 0);

    expect(b.showingBack, a.showingBack);
    expect(b.openness, closeTo(a.openness, 0.001));
    expect(b.shadeOnRight, a.shadeOnRight);
    expect(b.glossOffset, closeTo(a.glossOffset, 0.001));
  });

  test('three and a half turns is the same as half a turn', () {
    final a = CardShading(yaw: math.pi, pitch: 0);
    final b = CardShading(yaw: math.pi + 6 * math.pi, pitch: 0);

    expect(b.showingBack, a.showingBack);
    expect(b.glossOffset, closeTo(a.glossOffset, 0.001));
    expect(b.groundDx, closeTo(a.groundDx, 0.001));
  });

  test('nothing goes out of range however far it is spun', () {
    // Twenty turns each way, the region a person reaches in a few seconds of
    // dragging and nobody checks by hand.
    for (var i = -2000; i <= 2000; i++) {
      final yaw = i * math.pi / 50;
      for (final pitch in [-0.45, 0.0, 0.45]) {
        final s = CardShading(yaw: yaw, pitch: pitch);

        for (final (name, v) in [
          ('openness', s.openness),
          ('shadeAlpha', s.shadeAlpha),
          ('glossAlpha', s.glossAlpha),
          ('groundAlpha', s.groundAlpha),
        ]) {
          expect(v.isNaN, isFalse, reason: '$name was NaN at yaw $yaw');
          expect(v, inInclusiveRange(0.0, 1.0),
              reason: '$name was $v at yaw $yaw');
        }
      }
    }
  });

  test('the turn never drifts outside one revolution', () {
    for (var i = -500; i <= 500; i++) {
      final s = CardShading(yaw: i.toDouble(), pitch: 0);
      expect(s.yaw.abs(), lessThanOrEqualTo(math.pi + 0.0001),
          reason: 'yaw ${i.toDouble()} wrapped to ${s.yaw}');
    }
  });
}
