import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/widgets/library_stack.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

Widget _host({
  int count = 60,
  double width = 70,
  VoidCallback? onDraw,
  VoidCallback? onWork,
}) =>
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: LibraryStack(
            metrics: Metrics.of(DeviceClass.handheld),
            count: count,
            width: width,
            onDraw: onDraw ?? () {},
            onWork: onWork ?? () {},
          ),
        ),
      ),
    );

void main() {
  testWidgets('it says how many are left', (tester) async {
    await tester.pumpWidget(_host(count: 53));

    expect(find.text('53'), findsOneWidget);
  });

  testWidgets('tapping it draws', (tester) async {
    var drew = 0;
    await tester.pumpWidget(_host(onDraw: () => drew++));

    await tester.tap(find.byKey(const Key('library-draw')));
    await tester.pump();

    expect(drew, 1);
  });

  testWidgets('a fat deck is taller than a thin one', (tester) async {
    await tester.pumpWidget(_host(count: 99));
    final fat = tester.getSize(find.byKey(const Key('library-stack'))).height;

    await tester.pumpWidget(_host(count: 4));
    await tester.pump();
    final thin = tester.getSize(find.byKey(const Key('library-stack'))).height;

    // The whole point the player asked for: the pile shrinks as it is drawn,
    // so the table looks like a table.
    expect(fat, greaterThan(thin));
  });

  testWidgets('an empty library is drawn as nothing, not as one card',
      (tester) async {
    await tester.pumpWidget(_host(count: 0));

    expect(find.text('0'), findsOneWidget);
    expect(find.byKey(const Key('library-draw')), findsNothing,
        reason: 'there is nothing to draw, so nothing offers to');
  });

  testWidgets('the stack stops growing long before a hundred', (tester) async {
    await tester.pumpWidget(_host(count: 100));
    final hundred =
        tester.getSize(find.byKey(const Key('library-stack'))).height;

    await tester.pumpWidget(_host(count: 250));
    await tester.pump();
    final many = tester.getSize(find.byKey(const Key('library-stack'))).height;

    // A Commander deck is a hundred and a real pile is about two centimetres.
    // Letting the height track the count linearly would put a two hundred and
    // fifty card pile off the screen.
    expect(many, hundred);
  });

  testWidgets('there is a way into the deck that is not drawing',
      (tester) async {
    var worked = 0;
    await tester.pumpWidget(_host(onWork: () => worked++));

    await tester.tap(find.byKey(const Key('library-work')));
    await tester.pump();

    expect(worked, 1);
  });
}
