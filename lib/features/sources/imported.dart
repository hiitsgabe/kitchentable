import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'importedSources';

/// Which sources have been imported onto this device, by id.
///
/// The app used to know only how many cards it had, not where they came
/// from. That was enough for a menu and not enough for a list of sources:
/// after an import finished, the list drew Scryfall exactly as it had
/// before, which read as the import not having happened. A record of what
/// came in is what lets the list say "imported" on the right row.
///
/// Empty while it is being read off the disk, which is a frame or two, and
/// a row that is not yet marked for that frame is a far smaller lie than a
/// wizard that waits.
class ImportedSources extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    _restore();
    return const {};
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    state = {...?prefs.getStringList(_key)};
  }

  /// An import finished. Said here by the import itself, the moment it
  /// reaches done, so a screen anywhere in the app can show it.
  Future<void> mark(String sourceId) async {
    state = {...state, sourceId};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, state.toList()..sort());
  }
}

final importedSourcesProvider = NotifierProvider<ImportedSources, Set<String>>(
  ImportedSources.new,
);
