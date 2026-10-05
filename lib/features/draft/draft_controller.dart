import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../decks/model/basic_lands.dart';
import '../../decks/model/deck.dart';
import '../../sources/catalog/catalog_db.dart';
import '../../sources/import/mtgjson_importer.dart';
import '../../sources/model/catalog_card.dart';
import '../../sources/model/draft_set.dart';
import '../../sources/source_registry.dart';
import '../menu/menu_controller.dart';
import 'booster_roller.dart';
import 'draft_room.dart';
import 'draft_state.dart';

/// The seat's live view of the draft, or null before one is adopted.
///
/// The [DraftRoom] is built where the transport lives (the lobby, or a demo),
/// then handed here with [DraftController.adopt]. This notifier only watches
/// the one view the host sends this seat and relays picks back; it never holds
/// the table. That keeps the hidden-information guarantee the room enforces:
/// the UI cannot show what it was never given.
class DraftController extends Notifier<DraftView?> {
  DraftRoom? _room;
  StreamSubscription<DraftView>? _sub;

  @override
  DraftView? build() {
    ref.onDispose(_detach);
    return _room?.view;
  }

  /// Takes over a room: starts relaying its views into this notifier's state.
  /// Closing the previous subscription first, so adopting twice is safe.
  void adopt(DraftRoom room) {
    _sub?.cancel();
    _room = room;
    _sub = room.views.listen((view) => state = view);
    state = room.view;
  }

  void pick(String uuid) => _room?.pick(uuid);

  /// Hands the built deck to the draft, which carries it to the host to deal.
  void submit(Deck deck) => _room?.submit(deck);

  DraftRoom? get room => _room;

  void _detach() {
    _sub?.cancel();
    _sub = null;
  }
}

final draftProvider = NotifierProvider<DraftController, DraftView?>(
  DraftController.new,
);

/// The catalog cards for everything in this seat's current view, keyed by
/// oracle id. A draft card whose oracle id the catalog never heard of is
/// simply absent from the map, and the screens draw it as a nameless back.
final draftCardsProvider = FutureProvider<Map<String, CatalogCard>>((
  ref,
) async {
  final view = ref.watch(draftProvider);
  final db = ref.watch(catalogDbProvider);
  if (view == null || db == null) return const {};

  final ids = <String>{
    for (final c in view.pool)
      if (c.oracleId.isNotEmpty) c.oracleId,
    for (final c in (view.pack ?? const <DraftCard>[]))
      if (c.oracleId.isNotEmpty) c.oracleId,
  };
  if (ids.isEmpty) return const {};

  final cards = await db.cardsByOracleIds(ids.toList());
  return {for (final c in cards) c.oracleId: c};
});

/// The MTGJSON sets imported on this device, newest first, for the host to
/// pick a draft set from. Empty with no catalog or before MTGJSON is imported.
final draftSetsProvider = FutureProvider<List<DraftSet>>((ref) async {
  final db = ref.watch(catalogDbProvider);
  if (db == null) return const [];
  return db.draftSetList();
});

/// Builds the roller for a set the host chose, fetching the set's packs the
/// first time it is drafted (the set list carries only metadata until then).
/// Null where the catalog, the set or its MTGJSON endpoint is missing.
Future<BoosterRoller?> rollerForSet(CatalogDb db, String setCode) async {
  var set = await db.draftSet(setCode);
  if (set == null) return null;
  if (!set.fetched) {
    Uri? endpoint;
    for (final source in knownSources) {
      if (source.id == 'mtgjson_sets') endpoint = source.endpoint;
    }
    if (endpoint == null) return null;
    await MtgjsonImporter(db: db).fetchSet(endpoint, setCode);
    set = await db.draftSet(setCode);
    if (set == null) return null;
  }
  final printings = await db.draftPrintingsOf(setCode);
  return BoosterRoller.forSet(set, printings);
}

/// The five basic lands, by name, for the only cards the deck builder lets a
/// player add from outside the pool. Empty where the catalog does not have
/// them.
final draftBasicsProvider = FutureProvider<Map<String, CatalogCard>>((
  ref,
) async {
  final db = ref.watch(catalogDbProvider);
  if (db == null) return const {};
  return loadBasicLands(db);
});
