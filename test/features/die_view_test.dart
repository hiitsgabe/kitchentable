import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/dice/die_view.dart';
import 'package:kitchentable/features/play/dice/polyhedron.dart';
// ignore: depend_on_referenced_packages
import 'package:vector_math/vector_math_64.dart';

Widget _host({Polyhedron? die, int showing = 0, Quaternion? turn}) {
  // The default cannot be written in the parameter list: the solids are
  // derived at startup, so `Polyhedron.d20` is final and not const.
  final solid = die ?? Polyhedron.d20;
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: DieView(
          die: solid,
          showing: showing,
          turn: turn ?? solid.settle(showing),
          size: 80,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('it draws something for each of the three', (tester) async {
    for (final die in [Polyhedron.d6, Polyhedron.d12, Polyhedron.d20]) {
      await tester.pumpWidget(_host(die: die));
      await tester.pump();
      expect(find.byType(DieView), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  test('only the faces turned towards you are drawn', () {
    for (final die in [Polyhedron.d6, Polyhedron.d12, Polyhedron.d20]) {
      final turn = die.settle(0);
      final seen = visibleFaces(die, turn);

      // Never all of them and never none: a solid shows about half its
      // faces, and a die that drew all of them would paint its own far side
      // over its near one.
      expect(seen, isNotEmpty);
      expect(seen.length, lessThan(die.faces.length));
      expect(seen, contains(0), reason: 'the face that was rolled is hidden');
    }
  });

  test('the rolled face is the one nearest the middle', () {
    for (final die in [Polyhedron.d6, Polyhedron.d12, Polyhedron.d20]) {
      final turn = die.settle(3 % die.faces.length);
      final rolled = 3 % die.faces.length;
      final centre = Offset.zero;

      var nearest = -1;
      var best = double.infinity;
      for (final f in visibleFaces(die, turn)) {
        final at = project(die, f, turn, 80);
        final d = (at - centre).distance;
        if (d < best) {
          best = d;
          nearest = f;
        }
      }
      expect(nearest, rolled,
          reason: 'a ${die.sides} sided die showing $rolled points elsewhere');
    }
  });

  test('a face turned edge on is not drawn', () {
    final die = Polyhedron.d6;
    // A quarter turn puts two faces exactly edge on. Drawn, they are a line
    // of pixels that flickers; culled, they are nothing, which is what a real
    // die does.
    final turn = Quaternion.axisAngle(Vector3(0, 1, 0), math.pi / 2);
    final seen = visibleFaces(die, turn);
    expect(seen.length, lessThanOrEqualTo(4));
  });
}
