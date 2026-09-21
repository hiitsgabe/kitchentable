import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/menu/menu_controller.dart';
import 'package:kitchentable/features/sources/import_controller.dart';
import 'package:kitchentable/sources/model/source_def.dart';

/// The web build has no local catalog, because drift needs sqlite3.wasm and a
/// worker shipped in web/ and this project does not carry them. Every test here
/// stands in for that platform by overriding the db to null, which is the only
/// way to reach the branch from a test runner that always has dart:io.
///
/// None of this was covered when the app first ran in a browser and died on its
/// very first screen with 53 tests green behind it.
ProviderContainer _containerWithoutCatalog() {
  final container = ProviderContainer(
    overrides: [catalogDbProvider.overrideWithValue(null)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('the menu still builds when there is no catalog', () async {
    final container = _containerWithoutCatalog();

    final state = await container.read(menuStateProvider.future);

    expect(state.cardCount, 0);
    expect(state.hasCatalog, isFalse);
    expect(state.headline, 'NO SOURCES CONFIGURED');
  });

  test('without a catalog the menu points at Sources, it does not crash',
      () async {
    final container = _containerWithoutCatalog();

    final state = await container.read(menuStateProvider.future);

    expect(state.initialFocus, MenuEntryId.sources);
    expect(
      state.entries.firstWhere((e) => e.id == MenuEntryId.play).enabled,
      isFalse,
    );
  });

  test('importing without a catalog fails with a readable reason', () async {
    final container = _containerWithoutCatalog();

    await container.read(importProvider.notifier).run(
          SourceDef(
            id: 'scryfall_oracle',
            name: 'Scryfall',
            subtitle: 'card catalog',
            kind: SourceKind.catalog,
            endpoint: Uri.parse('https://example.invalid/bulk'),
            approximateBytes: 24710557,
          ),
        );

    final state = container.read(importProvider);
    expect(state.phase, ImportPhase.failed);
    expect(state.error, contains('no local catalog'));
  });

  test('a failed import never reports progress it did not make', () async {
    final container = _containerWithoutCatalog();

    await container.read(importProvider.notifier).run(
          SourceDef(
            id: 'scryfall_oracle',
            name: 'Scryfall',
            subtitle: 'card catalog',
            kind: SourceKind.catalog,
            endpoint: Uri.parse('https://example.invalid/bulk'),
            approximateBytes: 24710557,
          ),
        );

    final state = container.read(importProvider);
    expect(state.received, 0);
    expect(state.indexed, 0);
  });
}
