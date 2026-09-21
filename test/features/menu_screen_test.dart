import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/menu/menu_controller.dart';
import 'package:kitchentable/features/menu/menu_screen.dart';

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
}
