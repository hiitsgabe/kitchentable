import 'dart:math' as math;

// vector_math ships inside the Flutter SDK, so it is here without a
// pubspec entry, and the lint that wants one has to be told so.
// ignore: depend_on_referenced_packages
import 'package:vector_math/vector_math_64.dart';

/// One of the three dice as a solid: corners, faces, and the turn that
/// brings a chosen face round to the camera.
///
/// Every solid here is derived from its own geometry rather than typed out.
/// Twenty triangles written by hand is twenty chances to transpose an index,
/// and the only thing that would catch it is somebody's eye on a rolling
/// die.
class Polyhedron {
  Polyhedron._(this.vertices, this.faces);

  /// The corners, every one of them one unit out from the middle.
  final List<Vector3> vertices;

  /// Each face as the indices of its corners, in order round the face and
  /// anticlockwise seen from outside.
  final List<List<int>> faces;

  /// The eight `(±1, ±1, ±1)` corners, six faces of four.
  static final Polyhedron d6 = _cube();

  /// The dual of the [d20]: one corner per icosahedron face, one pentagon
  /// per icosahedron corner.
  static final Polyhedron d12 = _dual(d20);

  /// The cyclic permutations of `(0, ±1, ±phi)`, and every triple of them
  /// that is mutually one edge apart.
  static final Polyhedron d20 = _icosahedron();

  /// How many numbers the die can show, which is how many faces it has.
  int get sides => faces.length;

  /// The outward normal of [face].
  ///
  /// Newell's method: the corner cross products sum to twice the face's area
  /// vector, which is exact for a flat polygon however many corners it has.
  /// The sign is then forced outwards rather than trusted to the winding,
  /// because an inward normal culls the near faces and draws the far ones,
  /// which reads as a hole rather than as a die.
  Vector3 normalOf(List<int> face) {
    final area = Vector3.zero();
    for (var i = 0; i < face.length; i++) {
      final a = vertices[face[i]];
      final b = vertices[face[(i + 1) % face.length]];
      area.add(a.cross(b));
    }
    final n = area.normalized();
    return n.dot(centreOf(face)) < 0 ? -n : n;
  }

  /// The middle of [face], which is where its number goes.
  Vector3 centreOf(List<int> face) =>
      _middle([for (final i in face) vertices[i]]);

  /// The turn that brings [face] round to face you.
  ///
  /// The angle is negative. `Quaternion.axisAngle` turns the opposite way to
  /// the right hand rule: measured, `axisAngle(z, pi/2).rotated(x)` is
  /// `(0, -1, 0)`. With a positive angle a face lands at
  /// `(0.667, 0.667, -0.333)`, which is the wrong face, showing almost
  /// straight, which is worse than obviously wrong.
  Quaternion settle(int face) {
    final n = normalOf(faces[face]);
    final axis = n.cross(Vector3(0, 0, 1));
    // Two degenerate cases, and they are not the same. A face already facing
    // you crosses to zero and needs no turn; a face pointing away also
    // crosses to zero and needs half a turn about any perpendicular.
    if (axis.length2 < 1e-18) {
      return n.z > 0
          ? Quaternion.identity()
          : Quaternion.axisAngle(Vector3(1, 0, 0), math.pi);
    }
    return Quaternion.axisAngle(
      axis.normalized(),
      -math.acos(n.dot(Vector3(0, 0, 1)).clamp(-1.0, 1.0)),
    );
  }
}

Vector3 _middle(List<Vector3> points) =>
    points.reduce((a, b) => a + b) / points.length.toDouble();

Polyhedron _cube() {
  final corners = <Vector3>[
    for (final x in const [1.0, -1.0])
      for (final y in const [1.0, -1.0])
        for (final z in const [1.0, -1.0]) Vector3(x, y, z),
  ];
  final faces = <List<int>>[];
  for (var axis = 0; axis < 3; axis++) {
    for (final side in const [1.0, -1.0]) {
      final on = [
        for (var i = 0; i < corners.length; i++)
          if (corners[i][axis] == side) i,
      ];
      faces.add(_round(on, corners, Vector3.zero()..[axis] = side));
    }
  }
  return Polyhedron._(_onUnitSphere(corners), faces);
}

Polyhedron _icosahedron() {
  final phi = (1 + math.sqrt(5)) / 2;
  final corners = <Vector3>[
    for (final a in const [1.0, -1.0])
      for (final b in const [1.0, -1.0]) ...[
        Vector3(0, a, b * phi),
        Vector3(a, b * phi, 0),
        Vector3(b * phi, 0, a),
      ],
  ];

  // The edge is the shortest distance between any two corners, and on these
  // coordinates it measures exactly 2.0. Every other pair is further off, so
  // a triple that is mutually one edge apart is a face and nothing else is.
  var edge = double.infinity;
  for (var i = 0; i < corners.length; i++) {
    for (var j = i + 1; j < corners.length; j++) {
      edge = math.min(edge, corners[i].distanceTo(corners[j]));
    }
  }
  bool joined(int a, int b) =>
      (corners[a].distanceTo(corners[b]) - edge).abs() < 1e-9;

  final faces = <List<int>>[];
  for (var a = 0; a < corners.length; a++) {
    for (var b = a + 1; b < corners.length; b++) {
      if (!joined(a, b)) continue;
      for (var c = b + 1; c < corners.length; c++) {
        if (joined(a, c) && joined(b, c)) {
          faces.add(_wound([a, b, c], corners));
        }
      }
    }
  }
  return Polyhedron._(_onUnitSphere(corners), faces);
}

Polyhedron _dual(Polyhedron solid) {
  final corners = [
    for (final face in solid.faces) solid.centreOf(face),
  ];
  final faces = <List<int>>[];
  for (var corner = 0; corner < solid.vertices.length; corner++) {
    final around = [
      for (var f = 0; f < solid.faces.length; f++)
        if (solid.faces[f].contains(corner)) f,
    ];
    faces.add(_round(around, corners, solid.vertices[corner]));
  }
  return Polyhedron._(_onUnitSphere(corners), faces);
}

/// The same corners pulled out onto the unit sphere.
///
/// Every solid here is corner transitive, so this is one scale applied to all
/// of them: it moves no corner off its face's plane and turns no face round.
List<Vector3> _onUnitSphere(List<Vector3> corners) =>
    [for (final c in corners) c.normalized()];

/// [ids] in order round [axis], anticlockwise seen from outside.
///
/// `(u, v, axis)` is right handed, so sorting by a rising angle in the `u`,
/// `v` plane winds the face the way the normal wants it.
List<int> _round(List<int> ids, List<Vector3> points, Vector3 axis) {
  final w = axis.normalized();
  final off = w.x.abs() < 0.5 ? Vector3(1, 0, 0) : Vector3(0, 1, 0);
  final u = w.cross(off).normalized();
  final v = w.cross(u);
  double angle(int id) =>
      math.atan2(points[id].dot(v), points[id].dot(u));
  return [...ids]..sort((a, b) => angle(a).compareTo(angle(b)));
}

/// [face] with two of its corners swapped if it was wound inwards.
List<int> _wound(List<int> face, List<Vector3> points) {
  final a = points[face[0]];
  final b = points[face[1]];
  final c = points[face[2]];
  final outwards = (b - a).cross(c - b).dot(a + b + c) > 0;
  return outwards ? face : [face[0], face[2], face[1]];
}
