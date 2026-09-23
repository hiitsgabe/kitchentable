import 'package:flutter/material.dart';
// vector_math ships inside the Flutter SDK, so it is here without a
// pubspec entry, and the lint that wants one has to be told so.
import 'package:vector_math/vector_math_64.dart';

import '../../../ui/tokens/palette.dart';
import 'polyhedron.dart';

/// The faces of [die] turned towards you once [turn] has been applied.
///
/// A face is towards you when its turned normal leans at the camera, which is
/// a positive z, and that one line is the whole of the culling. Edge on does
/// not count: it would paint as a line of pixels that flickers as the die
/// rolls, and a real die shows nothing there.
List<int> visibleFaces(Polyhedron die, Quaternion turn) => [
      for (var i = 0; i < die.faces.length; i++)
        if (turn.rotated(die.normalOf(die.faces[i])).z > 0) i,
    ];

/// Where the number on [face] sits, measured out from the middle of a die
/// drawn [size] across.
///
/// There is no vanishing point. A die this small is very nearly orthographic,
/// and a projection with one needs a camera depth tuned against the die's
/// radius: it would buy a couple of pixels of taper and have to be tuned
/// again every time the die changes size. Screen y runs down, so y is
/// negated.
Offset project(Polyhedron die, int face, Quaternion turn, double size) {
  final at = turn.rotated(die.centreOf(die.faces[face]));
  return Offset(at.x * size / 2, -at.y * size / 2);
}

/// How square on [face] is: 1 when it looks straight at you, 0 edge on.
///
/// This is the shading and the foreshortening both. A face at a glancing
/// angle gets a small dim number, which is what foreshortening looks like
/// without skewing the text into the face's own plane.
double squareOn(Polyhedron die, int face, Quaternion turn) =>
    turn.rotated(die.normalOf(die.faces[face])).z.clamp(0.0, 1.0);

/// A die drawn as the solid it is, rather than as a picture of one.
class DieView extends StatelessWidget {
  const DieView({
    required this.die,
    required this.showing,
    required this.turn,
    required this.size,
    super.key,
  });

  final Polyhedron die;

  /// The face the die has landed on, which is the one in the accent colour.
  final int showing;

  /// Where the die has got to in its tumble.
  final Quaternion turn;

  /// The width and the height of the die, in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _Solid(die: die, showing: showing, turn: turn, size: size),
        ),
      );
}

class _Solid extends CustomPainter {
  _Solid({
    required this.die,
    required this.showing,
    required this.turn,
    required this.size,
  });

  final Polyhedron die;
  final int showing;
  final Quaternion turn;
  final double size;

  @override
  void paint(Canvas canvas, Size box) {
    final middle = box.center(Offset.zero);
    final corners = [for (final v in die.vertices) turn.rotated(v)];
    Offset flat(Vector3 at) =>
        middle + Offset(at.x * size / 2, -at.y * size / 2);
    double depth(int face) =>
        die.faces[face].map((i) => corners[i].z).reduce((a, b) => a + b) /
        die.faces[face].length;

    // Far to near, so the near faces land on top of the far ones. Painter's
    // algorithm, which is exact for a convex solid, and all three are convex.
    final seen = visibleFaces(die, turn)
      ..sort((a, b) => depth(a).compareTo(depth(b)));

    for (final face in seen) {
      final lit = squareOn(die, face, turn);
      final outline = Path();
      final corner = die.faces[face];
      for (var i = 0; i < corner.length; i++) {
        final to = flat(corners[corner[i]]);
        i == 0 ? outline.moveTo(to.dx, to.dy) : outline.lineTo(to.dx, to.dy);
      }
      outline.close();

      final base = face == showing ? Palette.accent : Palette.tile;
      canvas.drawPath(
        outline,
        Paint()..color = Color.lerp(Palette.felt, base, 0.25 + 0.75 * lit)!,
      );
      canvas.drawPath(
        outline,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Palette.tileEdge,
      );

      final number = TextPainter(
        text: TextSpan(
          text: '${face + 1}',
          style: TextStyle(
            color: Palette.ink,
            fontSize: size * 0.3 * lit,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final at = middle + project(die, face, turn, size);
      number.paint(canvas, at - number.size.center(Offset.zero));
    }
  }

  @override
  bool shouldRepaint(covariant _Solid old) =>
      old.die != die ||
      old.showing != showing ||
      old.turn != turn ||
      old.size != size;
}
