import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/counters.dart';
import 'package:kitchentable/features/play/widgets/counter_piece.dart';

Widget _host(String kind, {int count = 1}) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: CounterPieceView(
            piece: pieceNamed(kind) ?? unknownPiece(kind),
            count: count,
            width: 40,
          ),
        ),
      ),
    );

void main() {
  testWidgets('it says its value once', (tester) async {
    await tester.pumpWidget(_host('+1/+1'));
    await tester.pump();

    // The plastic prints it twice so it reads from either side of a physical
    // table. On a screen one person is looking and the upside down copy is
    // noise.
    expect(find.text('+1/+1'), findsOneWidget);
  });

  testWidgets('more than one of a kind says how many', (tester) async {
    await tester.pumpWidget(_host('+1/+1', count: 3));
    await tester.pump();

    // Three pieces drawn three times would cover the card. One piece and a
    // number is what a stack of three looks like from above anyway.
    expect(find.textContaining('3'), findsWidgets);
  });

  testWidgets('a single one does not count itself', (tester) async {
    await tester.pumpWidget(_host('+2/+2'));
    await tester.pump();

    expect(find.text('1'), findsNothing);
    expect(find.textContaining('x'), findsNothing);
  });

  testWidgets('a keyword piece says the word once', (tester) async {
    await tester.pumpWidget(_host('flying'));
    await tester.pump();

    expect(find.text('FLYING'), findsOneWidget);
  });

  testWidgets('it has a side, not just a face', (tester) async {
    await tester.pumpWidget(_host('+4/+4'));
    await tester.pump();

    // The deck reads as solid because it draws leaves behind its top card.
    // A counter gets its thickness the same way: the shape again, darker,
    // offset down and right, so there is an edge to catch the light.
    expect(find.byKey(const Key('counter-side')), findsOneWidget);
    final side = tester.getRect(find.byKey(const Key('counter-side')));
    final face = tester.getRect(find.byKey(const Key('counter-face')));
    expect(side.left, greaterThan(face.left));
    expect(side.top, greaterThan(face.top));

    // And both of them inside the piece's own box, which is what says the side
    // found room rather than took it: the two shapes are each a lift smaller
    // than the box they share, so a card wearing one is the size of a card
    // wearing none. Drawn at 1.4 times their box instead, the face covers the
    // side completely and every other assertion in this file still passed.
    final piece = tester.getRect(find.byType(CounterPieceView));
    expect(face.width, lessThan(piece.width));
    // To a hundredth of a point and not exactly: the side's bottom edge is a
    // lift plus a box less a lift, which comes out 3e-14 past the box it is
    // the same edge as.
    expect(side.bottom, moreOrLessEquals(piece.bottom, epsilon: 0.01));
  });

  testWidgets('the side is darker than the face', (tester) async {
    await tester.pumpWidget(_host('+2/+2'));
    await tester.pump();

    double lightness(Key k) {
      final box = tester.widget<DecoratedBox>(find.descendant(
        of: find.byKey(k),
        matching: find.byType(DecoratedBox),
      ).first);
      return HSLColor.fromColor(
        (box.decoration as BoxDecoration).color!,
      ).lightness;
    }

    // Lit from above, which is what says the face is on top rather than the
    // two being two shapes next to each other.
    expect(lightness(const Key('counter-side')),
        lessThan(lightness(const Key('counter-face'))));
  });

  testWidgets('it stands off the card', (tester) async {
    await tester.pumpWidget(_host('+4/+4'));
    await tester.pump();

    // "a little 3d, like a popup illusion". A shadow under it and a light
    // edge along its top is what makes a printed shape read as an object
    // lying on the card rather than as ink on it.
    final decorated = tester.widgetList<DecoratedBox>(
      find.byType(DecoratedBox),
    );
    expect(
      decorated.any((d) => (d.decoration as BoxDecoration).boxShadow != null),
      isTrue,
      reason: 'nothing here casts a shadow, so nothing is on top of anything',
    );
  });
}
