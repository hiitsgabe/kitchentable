import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/menu/menu_controller.dart';
import 'package:kitchentable/features/menu/menu_screen.dart';
import 'package:kitchentable/ui/atoms/menu_row.dart';

Widget _host(MenuState state) => ProviderScope(
  overrides: [menuStateProvider.overrideWith((ref) async => state)],
  child: const MaterialApp(home: MenuScreen()),
);

void main() {
  testWidgets('an empty app still offers the way in', (tester) async {
    await tester.pumpWidget(
      _host(const MenuState(cardCount: 0, enabledSources: 0)),
    );
    await tester.pumpAndSettle();

    // Shouted, because it is a slab and slabs carry one word in capitals.
    expect(find.text('PLAY'), findsOneWidget);
    // One shut door, not three. Decks is the only row that cannot do its job
    // without cards; a room can be made and joined whatever is on the device.
    expect(find.text('needs a source'), findsOneWidget);
  });

  testWidgets('a loaded catalog is not announced on the first screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const MenuState(cardCount: 36079, enabledSources: 1)),
    );
    await tester.pumpAndSettle();

    // The count was the brightest line on the first screen and it told a
    // player nothing they could act on. Four words, the way the reference
    // title screen has them.
    expect(find.textContaining('CARDS'), findsNothing);
    expect(find.text('PLAY'), findsOneWidget);
  });

  MenuRow rowFor(WidgetTester tester, String title) => tester.widget<MenuRow>(
    find.ancestor(of: find.text(title), matching: find.byType(MenuRow)),
  );

  testWidgets('the menu hands each row its own enabled flag', (tester) async {
    await tester.pumpWidget(
      _host(const MenuState(cardCount: 0, enabledSources: 0)),
    );
    await tester.pumpAndSettle();

    expect(rowFor(tester, 'Decks').enabled, isFalse);
    expect(rowFor(tester, 'Join').enabled, isTrue);
    expect(rowFor(tester, 'Settings').enabled, isTrue);
  });

  testWidgets('Play is not one of the rows, it is the way in', (tester) async {
    await tester.pumpWidget(
      _host(const MenuState(cardCount: 36079, enabledSources: 1)),
    );
    await tester.pumpAndSettle();

    // Drawn apart from the list and bigger than it: one dominant action is
    // what every menu in the benchmark has and this one did not.
    expect(find.byKey(const Key('menu-play')), findsOneWidget);
    expect(
      find.ancestor(of: find.text('PLAY'), matching: find.byType(MenuRow)),
      findsNothing,
    );
    final play = tester.getSize(find.byKey(const Key('menu-play')));
    final join = tester.getSize(find.byKey(const Key('menu-join')));
    expect(play.height, greaterThan(join.height));
  });
}
