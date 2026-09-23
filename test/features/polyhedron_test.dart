import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/dice/polyhedron.dart';
// ignore: depend_on_referenced_packages
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('a d6 is a cube', () {
    final die = Polyhedron.d6;
    expect(die.faces, hasLength(6));
    expect(die.faces.every((f) => f.length == 4), isTrue);
    expect(die.vertices, hasLength(8));
  });

  test('a d20 has twenty triangles on twelve corners', () {
    final die = Polyhedron.d20;
    expect(die.vertices, hasLength(12));
    expect(die.faces, hasLength(20));
    expect(die.faces.every((f) => f.length == 3), isTrue);
  });

  test('a d12 has twelve pentagons on twenty corners', () {
    final die = Polyhedron.d12;
    expect(die.vertices, hasLength(20));
    expect(die.faces, hasLength(12));
    expect(die.faces.every((f) => f.length == 5), isTrue);
  });

  test('every face is flat', () {
    for (final die in [Polyhedron.d6, Polyhedron.d12, Polyhedron.d20]) {
      for (final face in die.faces) {
        final points = [for (final i in face) die.vertices[i]];
        final centre =
            points.reduce((a, b) => a + b) / points.length.toDouble();
        final normal = die.normalOf(face);
        for (final p in points) {
          expect((p - centre).dot(normal).abs(), lessThan(1e-9),
              reason: 'a face of a ${die.sides} sided die is not flat');
        }
      }
    }
  });

  test('every face looks outwards', () {
    for (final die in [Polyhedron.d6, Polyhedron.d12, Polyhedron.d20]) {
      for (final face in die.faces) {
        final points = [for (final i in face) die.vertices[i]];
        final centre =
            points.reduce((a, b) => a + b) / points.length.toDouble();
        // A normal pointing inwards makes the culling draw the far side of
        // the die and hide the near one, which looks like a hole.
        expect(die.normalOf(face).dot(centre), greaterThan(0));
      }
    }
  });

  test('every face is wound the same way round', () {
    for (final die in [Polyhedron.d12, Polyhedron.d20]) {
      for (final face in die.faces) {
        final points = [for (final i in face) die.vertices[i]];
        final normal = die.normalOf(face);
        for (var i = 0; i < points.length; i++) {
          final a = points[i];
          final b = points[(i + 1) % points.length];
          final c = points[(i + 2) % points.length];
          expect((b - a).cross(c - b).dot(normal), greaterThan(0),
              reason: 'a face of a ${die.sides} sided die turns back '
                  'on itself');
        }
      }
    }
  });

  test('every corner is the same distance out', () {
    for (final die in [Polyhedron.d6, Polyhedron.d12, Polyhedron.d20]) {
      final radius = die.vertices.first.length;
      for (final v in die.vertices) {
        expect(v.length, closeTo(radius, 1e-9));
      }
    }
  });

  test('a rolled face is turned to face you, exactly', () {
    for (final die in [Polyhedron.d6, Polyhedron.d12, Polyhedron.d20]) {
      for (var i = 0; i < die.faces.length; i++) {
        final landed = die.settle(i).rotated(die.normalOf(die.faces[i]));
        expect(landed.x.abs(), lessThan(1e-9));
        expect(landed.y.abs(), lessThan(1e-9));
        expect(landed.z, closeTo(1, 1e-9),
            reason: 'face $i of a ${die.sides} sided die landed away '
                'from you');
      }
    }
  });

  test('the face already facing you needs no turning', () {
    final die = Polyhedron.d6;
    final facing = die.faces.indexWhere(
      (f) => (die.normalOf(f) - Vector3(0, 0, 1)).length < 1e-9,
    );
    expect(facing, isNot(-1), reason: 'a cube has a face pointing at you');

    // The axis is the cross product of two parallel vectors, which is zero
    // and cannot be normalized. The identity is the answer, not a crash.
    final landed = die.settle(facing).rotated(die.normalOf(die.faces[facing]));
    expect(landed.z, closeTo(1, 1e-9));
  });

  test('the face pointing away turns all the way round', () {
    final die = Polyhedron.d6;
    final away = die.faces.indexWhere(
      (f) => (die.normalOf(f) - Vector3(0, 0, -1)).length < 1e-9,
    );
    expect(away, isNot(-1));

    // The other degenerate axis: opposite vectors also cross to zero, and
    // this one needs half a turn about any perpendicular rather than none.
    final landed = die.settle(away).rotated(die.normalOf(die.faces[away]));
    expect(landed.z, closeTo(1, 1e-9),
        reason: 'the far face never came round');
  });

  test('a die has as many faces as it has sides', () {
    expect(Polyhedron.d6.sides, 6);
    expect(Polyhedron.d12.sides, 12);
    expect(Polyhedron.d20.sides, 20);
    for (final die in [Polyhedron.d6, Polyhedron.d12, Polyhedron.d20]) {
      expect(die.faces.length, die.sides);
    }
  });
}
