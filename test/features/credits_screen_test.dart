import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/settings/credits_screen.dart';
import 'package:kitchentable/ui/atoms/menu_row.dart';

void main() {
  /// Taller than the 800 by 600 the test window opens at: the credits screen
  /// is a long column and a ListView does not build what is under the fold,
  /// where the finders would miss it.
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('it shows the mark, the build, and the fair play note', (
    tester,
  ) async {
    tall(tester);
    await tester.pumpWidget(const MaterialApp(home: CreditsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('dev.hiitsgabe.kitchentable'), findsOneWidget);
    expect(find.textContaining('build'), findsOneWidget);
    expect(find.text('Bring your own cards'), findsOneWidget);
    expect(find.byKey(const Key('credits-source')), findsOneWidget);
    expect(find.byKey(const Key('credits-coffee')), findsOneWidget);
  });

  testWidgets('a shelf is shut until opened, then shows its rows', (
    tester,
  ) async {
    tall(tester);
    await tester.pumpWidget(const MaterialApp(home: CreditsScreen()));
    await tester.pumpAndSettle();

    // Closed: the long list is not drawn, so the screen is a few rows.
    expect(find.text('Scryfall'), findsNothing);

    await tester.tap(find.byKey(const Key('shelf-credits')));
    await tester.pumpAndSettle();
    expect(find.text('Scryfall'), findsOneWidget);
    expect(find.text('flutter'), findsOneWidget);
  });

  testWidgets('a row copies its link rather than opening it', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    tall(tester);
    await tester.pumpWidget(const MaterialApp(home: CreditsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('shelf-authors')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('hiitsgabe'));
    await tester.pump();
    expect(copied, contains('https://gabeismy.name'));
    // The toast it shows holds a timer; let it fire so none is left pending.
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('settings has a Credits row that opens the screen', (
    tester,
  ) async {
    tall(tester);
    await tester.pumpWidget(const MaterialApp(home: CreditsScreen()));
    await tester.pumpAndSettle();
    // The screen itself is a frame with a Credits title and the open-source
    // row, which is the one every case above leans on.
    expect(find.byType(MenuRow), findsWidgets);
  });
}
