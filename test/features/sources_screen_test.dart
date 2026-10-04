import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/menu/menu_controller.dart';
import 'package:kitchentable/features/sources/imported.dart';
import 'package:kitchentable/features/sources/sources_screen.dart';

/// A device that has already run some sources, without a disk to say so.
class _Marked extends ImportedSources {
  _Marked(this.ids);
  final Set<String> ids;
  @override
  Set<String> build() => ids;
}

void main() {
  testWidgets('a source that has been imported says so on its row', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogDbProvider.overrideWithValue(null),
          importedSourcesProvider.overrideWith(
            () => _Marked({'scryfall_oracle'}),
          ),
        ],
        child: MaterialApp(home: SourcesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // After an import finished, this list used to draw Scryfall exactly as
    // it had before, which read as the import not having happened.
    expect(find.text('imported, on this device'), findsOneWidget);
  });

  testWidgets('it lists the known sources and says none has run', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        // This screen asks the catalog whether its pictures are stale. These
        // cases are about the source list, so there is nothing for a real
        // database to answer and opening one warns about a second CatalogDb.
        overrides: [catalogDbProvider.overrideWithValue(null)],
        child: MaterialApp(home: SourcesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Scryfall'), findsOneWidget);
    expect(find.text('Pokemon'), findsOneWidget);
    expect(find.text('Local file'), findsOneWidget);
    expect(
      find.text('MTGJSON'),
      findsNothing,
      reason: 'there is no draft to feed it yet',
    );
    expect(find.textContaining('NOTHING HAS LEFT THIS DEVICE'), findsOneWidget);
    // Two screens below the menu, so Home stands beside Back.
    expect(find.byKey(const Key('home')), findsOneWidget);
  });

  testWidgets('a source that downloads states its size up front', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        // This screen asks the catalog whether its pictures are stale. These
        // cases are about the source list, so there is nothing for a real
        // database to answer and opening one warns about a second CatalogDb.
        overrides: [catalogDbProvider.overrideWithValue(null)],
        child: MaterialApp(home: SourcesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('23.6 MB'), findsOneWidget);
  });

  testWidgets('every source listed can be run', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        // This screen asks the catalog whether its pictures are stale. These
        // cases are about the source list, so there is nothing for a real
        // database to answer and opening one warns about a second CatalogDb.
        overrides: [catalogDbProvider.overrideWithValue(null)],
        child: MaterialApp(home: SourcesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // The list used to carry rows for sources the app had not built,
    // each saying so. Every row is a real road now.
    expect(find.textContaining('not ready yet'), findsNothing);
  });
}
