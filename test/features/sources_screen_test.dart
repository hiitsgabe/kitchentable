import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/menu/menu_controller.dart';
import 'package:kitchentable/features/sources/sources_screen.dart';

void main() {
  testWidgets('it lists the known sources and says none has run', (tester) async {
    await tester.pumpWidget(ProviderScope(
      // This screen asks the catalog whether its pictures are stale. These
      // cases are about the source list, so there is nothing for a real
      // database to answer and opening one warns about a second CatalogDb.
      overrides: [catalogDbProvider.overrideWithValue(null)],
      child: MaterialApp(home: SourcesScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Scryfall'), findsOneWidget);
    expect(find.text('MTGJSON'), findsOneWidget);
    expect(find.textContaining('NOTHING HAS LEFT THIS DEVICE'), findsOneWidget);
  });

  testWidgets('a source that downloads states its size up front',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      // This screen asks the catalog whether its pictures are stale. These
      // cases are about the source list, so there is nothing for a real
      // database to answer and opening one warns about a second CatalogDb.
      overrides: [catalogDbProvider.overrideWithValue(null)],
      child: MaterialApp(home: SourcesScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('23.6 MB'), findsOneWidget);
  });

  testWidgets('a source we have not built says so instead of pretending',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      // This screen asks the catalog whether its pictures are stale. These
      // cases are about the source list, so there is nothing for a real
      // database to answer and opening one warns about a second CatalogDb.
      overrides: [catalogDbProvider.overrideWithValue(null)],
      child: MaterialApp(home: SourcesScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('not ready yet'), findsWidgets);
  });
}
