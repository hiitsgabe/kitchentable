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
  testWidgets('an empty app still offers the way in', (tester) async {
    await tester.pumpWidget(_host(
      const MenuState(cardCount: 0, enabledSources: 0),
    ));
    await tester.pumpAndSettle();

    expect(find.text('NO SOURCES CONFIGURED'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
    // One shut door, not three. Decks is the only row that cannot do its job
    // without cards; a room can be made and joined whatever is on the device.
    expect(find.text('needs a source'), findsOneWidget);
  });

  testWidgets('a loaded catalog shows the real count', (tester) async {
    await tester.pumpWidget(_host(
      const MenuState(cardCount: 36079, enabledSources: 1),
    ));
    await tester.pumpAndSettle();

    expect(find.text('36079 CARDS'), findsOneWidget);
    expect(find.text('make a table and invite people'), findsOneWidget);
  });

  MenuRow rowFor(WidgetTester tester, String title) => tester.widget<MenuRow>(
        find.ancestor(of: find.text(title), matching: find.byType(MenuRow)),
      );

  testWidgets('the menu hands each row its own enabled flag', (tester) async {
    await tester.pumpWidget(_host(
      const MenuState(cardCount: 0, enabledSources: 0),
    ));
    await tester.pumpAndSettle();

    expect(rowFor(tester, 'Decks').enabled, isFalse);
    expect(rowFor(tester, 'Join').enabled, isTrue);
    expect(rowFor(tester, 'Settings').enabled, isTrue);
  });

  testWidgets('Play is not one of the rows, it is the way in', (tester) async {
    await tester.pumpWidget(_host(
      const MenuState(cardCount: 36079, enabledSources: 1),
    ));
    await tester.pumpAndSettle();

    // Drawn apart from the list and bigger than it: one dominant action is
    // what every menu in the benchmark has and this one did not.
    expect(find.byKey(const Key('menu-play')), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Play'),
        matching: find.byType(MenuRow),
      ),
      findsNothing,
    );
    final play = tester.getSize(find.byKey(const Key('menu-play')));
    final join = tester.getSize(find.byKey(const Key('menu-join')));
    expect(play.height, greaterThan(join.height));
  });
}
