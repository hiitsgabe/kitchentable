import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/menu/menu_controller.dart';
import 'package:kitchentable/features/menu/menu_screen.dart';
import 'package:kitchentable/ui/atoms/menu_row.dart';

Widget _host(MenuState state) => ProviderScope(
      overrides: [
        menuStateProvider.overrideWith((ref) async => state),
      ],
      child: const MaterialApp(home: MenuScreen()),
    );

void main() {
  testWidgets('an empty app points at Sources', (tester) async {
    await tester.pumpWidget(_host(
      const MenuState(cardCount: 0, enabledSources: 0),
    ));
    await tester.pumpAndSettle();

    expect(find.text('NO SOURCES CONFIGURED'), findsOneWidget);
    expect(find.text('start here'), findsOneWidget);
    expect(find.text('needs a source'), findsNWidgets(2));
  });

  testWidgets('a loaded catalog shows the real count', (tester) async {
    await tester.pumpWidget(_host(
      const MenuState(cardCount: 36079, enabledSources: 1),
    ));
    await tester.pumpAndSettle();

    expect(find.text('36079 CARDS'), findsOneWidget);
    expect(find.text('host a table or join by code'), findsOneWidget);
  });

  // The two tests above only read text, and MenuState computes those strings
  // whether or not the screen passes anything down. So they stay green even if
  // the screen hands every row `enabled: true` and `autofocus: false`. The two
  // below pin the wiring itself, which is where the product decision lives.

  MenuRow rowFor(WidgetTester tester, String title) => tester.widget<MenuRow>(
        find.ancestor(of: find.text(title), matching: find.byType(MenuRow)),
      );

  testWidgets('the menu hands each row its own enabled flag', (tester) async {
    await tester.pumpWidget(_host(
      const MenuState(cardCount: 0, enabledSources: 0),
    ));
    await tester.pumpAndSettle();

    expect(rowFor(tester, 'Play').enabled, isFalse);
    expect(rowFor(tester, 'Decks').enabled, isFalse);
    expect(rowFor(tester, 'Sources').enabled, isTrue);
    expect(rowFor(tester, 'Settings').enabled, isTrue);
  });

  // One state per test, never two pumps in one. Swapping the override on a
  // mounted ProviderScope looks like it should work and silently does not:
  // ProviderElement.update is an empty method (riverpod 3.4.3 element.dart:610)
  // and the only class overriding it is the one behind overrideWithValue. A
  // builder override, which this provider needs because it returns a Future,
  // goes through the empty one, so the element keeps serving the first result
  // forever and pumpAndSettle has nothing to wait for.
  testWidgets('focus starts on Sources when there is nothing else to do',
      (tester) async {
    await tester.pumpWidget(_host(
      const MenuState(cardCount: 0, enabledSources: 0),
    ));
    await tester.pumpAndSettle();

    expect(rowFor(tester, 'Sources').autofocus, isTrue);
    expect(rowFor(tester, 'Play').autofocus, isFalse);
  });

  testWidgets('focus moves to Play once there are cards', (tester) async {
    await tester.pumpWidget(_host(
      const MenuState(cardCount: 36079, enabledSources: 1),
    ));
    await tester.pumpAndSettle();

    expect(rowFor(tester, 'Play').autofocus, isTrue);
    expect(rowFor(tester, 'Sources').autofocus, isFalse);
  });
}
