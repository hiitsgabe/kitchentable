import 'dart:convert';

import 'package:drift/drift.dart';

import '../model/catalog_card.dart';
import 'catalog_opener.dart';

part 'catalog_db.g.dart';

class Cards extends Table {
  TextColumn get oracleId => text()();
  TextColumn get name => text()();
  TextColumn get nameFolded => text()();
  TextColumn get typeLine => text()();
  RealColumn get cmc => real()();
  TextColumn get manaCost => text().nullable()();
  TextColumn get oracleText => text().nullable()();
  TextColumn get power => text().nullable()();
  TextColumn get toughness => text().nullable()();
  TextColumn get colorIdentity => text()();
  TextColumn get rarity => text().nullable()();
  TextColumn get setCode => text().nullable()();
  TextColumn get legalities => text()();
  TextColumn get imageSmall => text().nullable()();
  TextColumn get imageNormal => text().nullable()();
  TextColumn get imageLarge => text().nullable()();
  TextColumn get imageBack => text().nullable()();

  @override
  Set<Column> get primaryKey => {oracleId};
}

/// Named so the generated row class does not collide with the Deck model.
/// drift names a row after the table in the singular, and `Deck` is taken.
@DataClassName('DeckRow')
class Decks extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get format => text()();
  TextColumn get game => text().withDefault(const Constant('magic'))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A card in a deck. Three piles live here, told apart by two flags rather than
/// three tables, because they are the same row with a different home.
@DataClassName('DeckCardRow')
class DeckCards extends Table {
  TextColumn get deckId => text()();
  TextColumn get oracleId => text()();
  IntColumn get quantity => integer()();
  BoolColumn get sideboard => boolean().withDefault(const Constant(false))();
  BoolColumn get commander => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {deckId, oracleId, sideboard};
}

@DriftDatabase(tables: [Cards, Decks, DeckCards])
class CatalogDb extends _$CatalogDb {
  CatalogDb() : super(openCatalog());

  CatalogDb.forTesting(super.executor);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          // A catalog is 36000 rows that took minutes to fetch and index, so a
          // schema bump adds tables and never drops one.
          //
          // Every step here is idempotent, and that is not belt and braces.
          // A browser reported `duplicate column name: image_large` on a
          // database that had already been through this: the column was
          // written and the version was not, so the next open replayed the
          // whole upgrade onto a schema that already had it. Whatever lost
          // the version, a migration that cannot be run twice turns that into
          // a database nobody can open, and on the web the storage is the
          // least reliable part of the stack. Skipping what is already there
          // is the repair as well as the guard: the next open gets through
          // and records the version.
          if (from < 2) {
            // No guard needed: drift 2.35.0 writes CREATE TABLE IF NOT EXISTS
            // (migration.dart:319). SQLite has no ADD COLUMN IF NOT EXISTS,
            // which is why the columns below do need one.
            await m.createTable(decks);
            await m.createTable(deckCards);
          }
          if (from < 3) {
            // Every deck that existed before this column was a Magic deck,
            // which is what the default says, so nothing needs rewriting.
            await _addColumnOnce(m, decks, decks.game);
          }
          if (from < 4) {
            // Null on every existing row. Those cards turn over onto the
            // generic back, which is what they did before this column existed.
            // A reimport fills it in.
            await _addColumnOnce(m, cards, cards.imageBack);
          }
          if (from < 5) {
            // Null on every existing row, which falls back to the normal file
            // the way those cards already drew. A reimport fills it in.
            await _addColumnOnce(m, cards, cards.imageLarge);
          }
        },
      );

  /// Adds a column unless the table already has it.
  Future<void> _addColumnOnce(
    Migrator m,
    TableInfo<Table, dynamic> table,
    GeneratedColumn<Object> column,
  ) async {
    final rows = await customSelect(
      'PRAGMA table_info(${table.actualTableName})',
    ).get();
    final already =
        rows.any((row) => row.read<String>('name') == column.name);
    if (!already) await m.addColumn(table, column);
  }

  Future<int> cardCount() async {
    final count = countAll();
    final query = selectOnly(cards)..addColumns([count]);
    return await query.map((row) => row.read(count)!).getSingle();
  }

  /// True when anything in the catalog predates the large image column.
  Future<bool> needsBetterPictures() async {
    final query = select(cards)
      ..where((c) => c.imageLarge.isNull())
      ..limit(1);
    return await query.getSingleOrNull() != null;
  }

  /// One transaction for the whole batch. Inserting 36000 rows one statement at
  /// a time takes minutes, batched it takes seconds.
  Future<void> insertAll(List<CatalogCard> incoming) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(
        cards,
        incoming.map(_toRow).toList(),
      );
    });
  }

  Future<List<CatalogCard>> searchByName(String term) async {
    final needle = '%${term.toLowerCase()}%';
    final rows = await (select(cards)
          ..where((c) => c.nameFolded.like(needle))
          ..orderBy([(c) => OrderingTerm(expression: c.name)])
          ..limit(100))
        .get();
    return rows.map(_fromRow).toList();
  }

  Future<void> clear() => delete(cards).go();

  Future<List<CatalogCard>> cardsByOracleIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows =
        await (select(cards)..where((c) => c.oracleId.isIn(ids))).get();
    return rows.map(_fromRow).toList();
  }

  /// Exact name match, case insensitive. This is what a pasted decklist needs:
  /// it has a name and nothing else, and a fuzzy match there would quietly
  /// swap a card for one that merely looks similar.
  Future<Map<String, CatalogCard>> cardsByExactNames(
    Iterable<String> names,
  ) async {
    final wanted = names.map((n) => n.toLowerCase()).toSet();
    if (wanted.isEmpty) return const {};

    final rows = await (select(cards)
          ..where((c) => c.nameFolded.isIn(wanted.toList())))
        .get();

    return {
      for (final row in rows) row.nameFolded: _fromRow(row),
    };
  }

  CardsCompanion _toRow(CatalogCard c) => CardsCompanion.insert(
        oracleId: c.oracleId,
        name: c.name,
        nameFolded: c.name.toLowerCase(),
        typeLine: c.typeLine,
        cmc: c.cmc,
        manaCost: Value(c.manaCost),
        oracleText: Value(c.oracleText),
        power: Value(c.power),
        toughness: Value(c.toughness),
        colorIdentity: c.colorIdentity.join(''),
        rarity: Value(c.rarity),
        setCode: Value(c.setCode),
        legalities: jsonEncode(c.legalities),
        imageSmall: Value(c.imageSmall),
        imageNormal: Value(c.imageNormal),
        imageLarge: Value(c.imageLarge),
        imageBack: Value(c.imageBack),
      );

  CatalogCard _fromRow(Card row) => CatalogCard(
        oracleId: row.oracleId,
        name: row.name,
        typeLine: row.typeLine,
        cmc: row.cmc,
        manaCost: row.manaCost,
        oracleText: row.oracleText,
        power: row.power,
        toughness: row.toughness,
        colorIdentity: row.colorIdentity.split('').where((s) => s.isNotEmpty).toList(),
        rarity: row.rarity,
        setCode: row.setCode,
        legalities: (jsonDecode(row.legalities) as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v as String)),
        imageSmall: row.imageSmall,
        imageNormal: row.imageNormal,
        imageLarge: row.imageLarge,
        imageBack: row.imageBack,
      );
}
