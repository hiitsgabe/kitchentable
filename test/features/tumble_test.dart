import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/dice/polyhedron.dart';
import 'package:kitchentable/features/play/dice/tumble.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('which side of a product applies first', () {
    // Measured rather than assumed, because axisAngle already turned out to
    // run against the right hand rule. A quarter turn about z followed by a
    // quarter turn about x, applied to the x axis.
    final aboutZ = Quaternion.axisAngle(Vector3(0, 0, 1), math.pi / 2);
    final aboutX = Quaternion.axisAngle(Vector3(1, 0, 0), math.pi / 2);
    final v = Vector3(1, 0, 0);

    // The left factor applies first. Asserting that both products come out
    // one unit long would have proved nothing: a unit quaternion cannot
    // change a vector's length whichever way round it is written, so that
    // pair of expectations passes on either convention and on a `tumble`
    // that composes backwards.
    //
    // z first sends x to (0, -1, 0) and then x sends that to (0, 0, 1).
    expect((aboutZ * aboutX).rotated(v).z, closeTo(1, 1e-9));
    expect((aboutZ * aboutX).rotated(v).y, closeTo(0, 1e-9));

    // x first leaves x alone, and then z sends it to (0, -1, 0).
    expect((aboutX * aboutZ).rotated(v).y, closeTo(-1, 1e-9));
    expect((aboutX * aboutZ).rotated(v).z, closeTo(0, 1e-9));

    // Which is the same thing said without a product, so the two readings
    // cannot both be true.
    expect(
        ((aboutZ * aboutX).rotated(v) - aboutX.rotated(aboutZ.rotated(v)))
            .length,
        lessThan(1e-12));

    // So `tumble` has to put the settle on the left, and that is observable
    // rather than a matter of taste. With the settle first the spin is a turn
    // about a world axis applied afterwards, so the one body direction the
    // roll never moves is whatever the settle sends to that axis: every
    // frame sends it to `tumbleAxis` and stays there. Composed the other way
    // round the spin acts on the die's own frame and this walks off.
    final die = Polyhedron.d20;
    for (final face in [0, 7, 19]) {
      final held = die.settle(face).inverted().rotated(tumbleAxis);
      for (final at in [0.0, 0.2, 0.5, 0.9, 1.0]) {
        expect(
            (tumble(die: die, face: face, spin: 3, at: at).rotated(held) -
                    tumbleAxis)
                .length,
            lessThan(1e-9),
            reason: 'face $face at $at turns about somewhere else');
      }
    }
  });

  test('a tumble ends exactly where the die settles', () {
    for (final die in [Polyhedron.d6, Polyhedron.d12, Polyhedron.d20]) {
      for (var face = 0; face < die.faces.length; face++) {
        final landed =
            tumble(die: die, face: face, spin: 3, at: 1).rotated(
          die.normalOf(die.faces[face]),
        );

        // Not close to the camera. On it. A die that settles a degree out
        // reads as a die resting on an edge.
        expect(landed.z, closeTo(1, 1e-9),
            reason: 'face $face of a ${die.sides} sided die did not land');
      }
    }
  });

  test('a tumble actually moves', () {
    final die = Polyhedron.d20;
    final settled = tumble(die: die, face: 0, spin: 3, at: 1);
    final middle = tumble(die: die, face: 0, spin: 3, at: 0.5);

    // A "tumble" that is the settle all the way through is a die that
    // teleports to its answer, which is what a still picture looks like.
    expect((middle.rotated(Vector3(0, 0, 1)) -
                settled.rotated(Vector3(0, 0, 1)))
            .length,
        greaterThan(0.1));
  });

  test('more spin is more turning', () {
    final die = Polyhedron.d20;
    final along = Vector3(1, 0, 0);
    Vector3 pointing(double spin, double at) =>
        tumble(die: die, face: 0, spin: spin, at: at).rotated(along);

    var far = 0.0;
    var near = 0.0;
    for (var i = 1; i < 20; i++) {
      final t = i / 20;
      far += (pointing(6, t) - pointing(6, t - 0.05)).length;
      near += (pointing(1, t) - pointing(1, t - 0.05)).length;
    }
    // Sampled at twenty steps a fast enough spin would alias: a whole turn
    // between two samples is a chord of nothing, and the fast die could come
    // out the still one. Measured here, six turns walks 18.69 and one walks
    // 5.74, so the sampling is nowhere near that cliff.
    expect(far, greaterThan(near));
  });

  test('the same roll tumbles the same way twice', () {
    final die = Polyhedron.d12;
    final once = tumble(die: die, face: 4, spin: 3, at: 0.37);
    final twice = tumble(die: die, face: 4, spin: 3, at: 0.37);

    // No randomness inside. What is random is the number, which is rolled by
    // the caller, because `apply` has to be a function or replaying a game
    // gives a different game.
    expect((once.rotated(Vector3(1, 2, 3)) - twice.rotated(Vector3(1, 2, 3)))
        .length, lessThan(1e-12));
  });

  test('a roll is a number on the die', () {
    final rolled = <int>{};
    for (var i = 0; i < 400; i++) {
      final n = rollOne(Polyhedron.d20, math.Random(i));
      expect(n, greaterThanOrEqualTo(1));
      expect(n, lessThanOrEqualTo(20));
      rolled.add(n);
    }
    // Four hundred rolls of a d20 that never show a twenty is a d19.
    expect(rolled, hasLength(20));
  });
}
