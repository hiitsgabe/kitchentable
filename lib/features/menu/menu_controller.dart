import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sources/catalog/catalog_db.dart';
import '../../sources/catalog/catalog_opener.dart';

enum MenuEntryId { play, join, decks, settings }

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

  /// Always Play. It was the first thing you could not press on a fresh
  /// install, which is why the first run is a wizard now and not a wall.
  MenuEntryId get initialFocus => MenuEntryId.play;

  /// Play is the way in and the rest are the furniture around it. Every
  /// client in the benchmark says the same thing: one dominant action, and
  /// a menu of five equal rows has none.
  List<MenuEntry> get entries => [
    MenuEntry(
      id: MenuEntryId.play,
      title: 'Play',
      subtitle: 'make a table and invite people',
      enabled: true,
    ),
    MenuEntry(
      id: MenuEntryId.join,
      title: 'Join',
      subtitle: 'paste a link, or type the code',
      enabled: true,
    ),
    MenuEntry(
      id: MenuEntryId.decks,
      title: 'Decks',
      subtitle: hasCatalog ? 'build one, or change one' : 'needs a source',
      enabled: hasCatalog,
    ),
    const MenuEntry(
      id: MenuEntryId.settings,
      title: 'Settings',
      subtitle: 'your name, sources, network',
      enabled: true,
    ),
  ];
}

/// Null where there is no local catalog. Both real builds have one today, so
/// only tests reach the null branch, and they use it to stand in for a
/// platform without one. See catalog_opener_web.dart, which used to refuse.
final catalogDbProvider = Provider<CatalogDb?>((ref) {
  if (!catalogIsAvailable) return null;
  final db = CatalogDb();
  ref.onDispose(db.close);
  return db;
});

final menuStateProvider = FutureProvider<MenuState>((ref) async {
  final db = ref.watch(catalogDbProvider);
  final count = db == null ? 0 : await db.cardCount();

  // enabledSources is inferred rather than looked up, because nothing records
  // which sources are on yet. A non empty catalog is today's evidence that
  // Scryfall was imported, and that only holds while Scryfall is the one
  // catalog source. The second one makes this line lie, and the Sources
  // subtitle is what will show the lie first.
  return MenuState(cardCount: count, enabledSources: count > 0 ? 1 : 0);
});
