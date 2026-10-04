import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/sources/imported.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a source marked as imported is still marked after a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final first = ProviderContainer();
    addTearDown(first.dispose);
    expect(first.read(importedSourcesProvider), isEmpty);

    await first.read(importedSourcesProvider.notifier).mark('scryfall_oracle');
    expect(first.read(importedSourcesProvider), {'scryfall_oracle'});

    // A new container is the app opened again: nothing in memory, only what
    // was written down.
    final again = ProviderContainer();
    addTearDown(again.dispose);
    again.read(importedSourcesProvider);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(again.read(importedSourcesProvider), {'scryfall_oracle'});
  });

  test('marking a second source keeps the first', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final imported = container.read(importedSourcesProvider.notifier);

    await imported.mark('scryfall_oracle');
    await imported.mark('pokemon_tcg_data');

    expect(container.read(importedSourcesProvider), {
      'scryfall_oracle',
      'pokemon_tcg_data',
    });
  });
}
