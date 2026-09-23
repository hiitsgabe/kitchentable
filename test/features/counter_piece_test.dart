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
  testWidgets('it says its value twice, the way the plastic does',
      (tester) async {
    await tester.pumpWidget(_host('+1/+1'));
    await tester.pump();

    // Printed at both ends so it reads from the other side of the table,
    // which is what the real ones do and why they are shaped the way they
    // are.
    expect(find.text('+1/+1'), findsNWidgets(2));
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

  testWidgets('a keyword piece says the word', (tester) async {
    await tester.pumpWidget(_host('flying'));
    await tester.pump();

    expect(find.text('FLYING'), findsNWidgets(2));
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
