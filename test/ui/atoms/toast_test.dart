import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/ui/atoms/toast.dart';

Future<BuildContext> _screen(WidgetTester tester) async {
  late BuildContext context;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    ),
  );
  return context;
}

void main() {
  testWidgets('a line with something in front of it shows both, for as long '
      'as it was asked to', (tester) async {
    final context = await _screen(tester);

    Toast.announce(
      context,
      'kit rolled 4',
      leading: const SizedBox(key: Key('die'), width: 10, height: 10),
      lasts: const Duration(seconds: 2),
    );
    await tester.pump();
    expect(find.text('kit rolled 4'), findsOneWidget);
    expect(find.byKey(const Key('die')), findsOneWidget);

    // A thing that moves needs longer than a line read at a glance, so the
    // default would have taken this away already.
    await tester.pump(const Duration(milliseconds: 1900));
    expect(find.byKey(const Key('die')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('kit rolled 4'), findsNothing);
    expect(find.byKey(const Key('die')), findsNothing);
  });

  testWidgets('a line with an icon still draws the icon', (tester) async {
    final context = await _screen(tester);

    Toast.show(context, 'Shuffled', icon: Icons.casino_rounded);
    await tester.pump();
    expect(find.text('Shuffled'), findsOneWidget);
    expect(find.byIcon(Icons.casino_rounded), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Shuffled'), findsNothing);
  });
}
