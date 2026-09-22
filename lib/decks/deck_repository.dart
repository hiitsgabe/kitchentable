import 'package:drift/drift.dart';

import '../sources/catalog/catalog_db.dart';
import 'model/deck.dart';
import 'model/deck_format.dart';
import 'model/game.dart';

/// Reads and writes decks. The catalog and the decks share one database file,
/// because a deck is mostly a list of oracle ids pointing into the catalog and
/// splitting them would mean joining across two files by hand.
class DeckRepository {
  DeckRepository(this.db);

  final CatalogDb db;

  Future<List<Deck>> list() async {
    // Newest first, and the id breaks the tie. Two decks saved inside the same
    // millisecond carry the same timestamp, and without a tie break their order
    // is whatever sqlite felt like, which changes between runs.
    final rows = await (db.select(db.decks)
          ..orderBy([
            (d) => OrderingTerm.desc(d.updatedAt),
            (d) => OrderingTerm.desc(d.id),
          ]))
        .get();

    // Deliberately without slots. The list screen shows a name, a format and a
    // count, and loading every card of every deck to draw that would be silly.
    // The count comes from one grouped query instead.
    final counts = await _cardCounts();

    return rows
        .map((r) => Deck(
              id: r.id,
              name: r.name,
              format: _formatFrom(r.format),
              game: _gameFrom(r.game),
              slots: const [],
              knownCardCount: counts[r.id] ?? 0,
            ))
        .toList();
  }

  /// How many cards each deck holds, counting the sideboard out, in one query
  /// rather than one per deck.
  Future<Map<String, int>> _cardCounts() async {
    final total = db.deckCards.quantity.sum();
    final query = db.selectOnly(db.deckCards)
      ..addColumns([db.deckCards.deckId, total])
      ..where(db.deckCards.sideboard.equals(false))
      ..groupBy([db.deckCards.deckId]);

    final rows = await query.get();
    return {
      for (final row in rows)
        row.read(db.deckCards.deckId)!: row.read(total) ?? 0,
    };
  }

  Future<Deck?> load(String id) async {
    final row = await (db.select(db.decks)..where((d) => d.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;

    final entries =
        await (db.select(db.deckCards)..where((c) => c.deckId.equals(id))).get();
    final cards = await db.cardsByOracleIds(
      entries.map((e) => e.oracleId).toList(),
    );
    final byId = {for (final c in cards) c.oracleId: c};

    final slots = <DeckSlot>[];
    for (final entry in entries) {
      final card = byId[entry.oracleId];
      // A card can go missing if the catalog was cleared and reimported from a
      // different source. Dropping the slot silently would shrink the deck
      // without saying so, but there is nowhere to say it from here, so the
      // deck screen counts what it has and the number speaks.
      if (card == null) continue;
      slots.add(DeckSlot(
        card: card,
        quantity: entry.quantity,
        sideboard: entry.sideboard,
        commander: entry.commander,
      ));
    }

    return Deck(
      id: row.id,
      name: row.name,
      format: _formatFrom(row.format),
      game: _gameFrom(row.game),
      slots: slots,
    );
  }

  Future<void> save(Deck deck) async {
    await db.transaction(() async {
      await db.into(db.decks).insertOnConflictUpdate(
            DecksCompanion.insert(
              id: deck.id,
              name: deck.name,
              format: deck.format.name,
              game: Value(deck.game.name),
              updatedAt: DateTime.now(),
            ),
          );

      await (db.delete(db.deckCards)..where((c) => c.deckId.equals(deck.id)))
          .go();

      await db.batch((b) {
        b.insertAll(
          db.deckCards,
          deck.slots.map(
            (s) => DeckCardsCompanion.insert(
              deckId: deck.id,
              oracleId: s.card.oracleId,
              quantity: s.quantity,
              sideboard: Value(s.sideboard),
              commander: Value(s.commander),
            ),
          ),
        );
      });
    });
  }

  Future<void> delete(String id) async {
    await db.transaction(() async {
      await (db.delete(db.deckCards)..where((c) => c.deckId.equals(id))).go();
      await (db.delete(db.decks)..where((d) => d.id.equals(id))).go();
    });
  }

  static Game _gameFrom(String stored) => Game.values.firstWhere(
        (g) => g.name == stored,
        orElse: () => Game.magic,
      );

  static DeckFormat _formatFrom(String stored) => DeckFormat.values.firstWhere(
        (f) => f.name == stored,
        orElse: () => DeckFormat.commander,
      );
}
