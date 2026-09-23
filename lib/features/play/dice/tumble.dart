import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:vector_math/vector_math_64.dart';

import 'polyhedron.dart';

/// The axis a die turns about while it is still in the air.
///
/// One axis, in the world's frame rather than the die's, and deliberately not
/// one of any of the three solids' own: about a face normal or a vertex a die
/// comes round to the same silhouette several times a turn, which reads as a
/// spinning top rather than as something that has been thrown. It leans away
/// from the camera as well as across it, so the tumble shows the far faces on
/// the way past instead of turning the same three at you.
final Vector3 tumbleAxis = Vector3(0.42, 0.78, 0.31).normalized();

/// Where the die is pointing, part way through a roll.
///
/// Composed so the settle wins outright at the end: the spin decays to
/// nothing as [at] reaches one, so the last frame is the settle exactly and
/// not the settle plus a rounding error. A die that stops a degree off reads
/// as one resting on an edge.
///
/// The settle is the left factor because the left factor is the one that
/// applies first, which was measured and not assumed: `(z * x).rotated(x)` is
/// the same vector as `x.rotated(z.rotated(x))`. So the spin lands on a die
/// already facing the right way, about an axis fixed in the world, and every
/// die in the tray turns about the same one whatever number it is coming up
/// on. Written the other way round the spin would be in the die's own frame
/// and each face would swing about somewhere else.
///
/// Nothing random in here. The number is rolled by the caller, because
/// `apply` has to be a function or replaying a game gives a different game,
/// which is the same reason `CreateToken` takes its id from outside.
Quaternion tumble({
  required Polyhedron die,
  required int face,
  required double spin,
  required double at,
}) {
  // Decelerating, because a die thrown across a table slows into its answer
  // rather than stopping dead. `Curves.easeOutCubic` transforms a double
  // without a widget anywhere near it, and it returns 1 exactly at 1, which
  // is what leaves no residue in the last frame.
  final eased = Curves.easeOutCubic.transform(at);

  return die.settle(face) *
      Quaternion.axisAngle(tumbleAxis, 2 * math.pi * spin * (1 - eased));
}

/// One roll of [die]: a number from one to its number of sides.
///
/// The generator comes from outside for the same reason the result is handed
/// to `RollDice` rather than made inside it. Somebody has to own the
/// randomness, and it cannot be the reducer.
int rollOne(Polyhedron die, math.Random random) =>
    1 + random.nextInt(die.sides);
