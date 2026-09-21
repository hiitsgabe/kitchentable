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

  @override
  Set<Column> get primaryKey => {oracleId};
}

class Decks extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get format => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A card in a deck. Three piles live here, told apart by two flags rather than
/// three tables, because they are the same row with a different home.
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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          // A catalog is 36000 rows that took minutes to fetch and index, so a
          // schema bump adds tables and never drops one.
          if (from < 2) {
            await m.createTable(decks);
            await m.createTable(deckCards);
          }
        },
      );

  Future<int> cardCount() async {
    final count = countAll();
    final query = selectOnly(cards)..addColumns([count]);
    return await query.map((row) => row.read(count)!).getSingle();
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
      );
}
