import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sources/catalog/catalog_db.dart';

enum MenuEntryId { play, decks, sources, settings }

class MenuEntry {
  const MenuEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.enabled,
  });

  final MenuEntryId id;
  final String title;
  final String subtitle;
  final bool enabled;
}

/// The menu is not a fixed list with a tutorial bolted on. It reads the real
/// state and shows what is actually possible, which is why there is no welcome
/// screen anywhere in this app.
class MenuState {
  const MenuState({required this.cardCount, required this.enabledSources});

  final int cardCount;
  final int enabledSources;

  bool get hasCatalog => cardCount > 0;

  String get headline =>
      hasCatalog ? '$cardCount CARDS' : 'NO SOURCES CONFIGURED';

  MenuEntryId get initialFocus =>
      hasCatalog ? MenuEntryId.play : MenuEntryId.sources;

  List<MenuEntry> get entries => [
        MenuEntry(
          id: MenuEntryId.play,
          title: 'Play',
          subtitle: hasCatalog ? 'host a table or join by code' : 'needs a source',
          enabled: hasCatalog,
        ),
        MenuEntry(
          id: MenuEntryId.decks,
          title: 'Decks',
          subtitle: hasCatalog ? 'no decks yet' : 'needs a source',
          enabled: hasCatalog,
        ),
        MenuEntry(
          id: MenuEntryId.sources,
          title: 'Sources',
          subtitle: enabledSources == 0
              ? 'start here'
              : '$enabledSources on',
          enabled: true,
        ),
        const MenuEntry(
          id: MenuEntryId.settings,
          title: 'Settings',
          subtitle: 'appearance, network, D-pad',
          enabled: true,
        ),
      ];
}

final catalogDbProvider = Provider<CatalogDb>((ref) {
  final db = CatalogDb();
  ref.onDispose(db.close);
  return db;
});

final menuStateProvider = FutureProvider<MenuState>((ref) async {
  final db = ref.watch(catalogDbProvider);
  final count = await db.cardCount();

  // enabledSources is inferred rather than looked up, because nothing records
  // which sources are on yet. A non empty catalog is today's evidence that
  // Scryfall was imported, and that only holds while Scryfall is the one
  // catalog source. The second one makes this line lie, and the Sources
  // subtitle is what will show the lie first.
  return MenuState(cardCount: count, enabledSources: count > 0 ? 1 : 0);
});
