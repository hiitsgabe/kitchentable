import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/sources/catalog/catalog_db.dart';

void main() {
  test('an upgrade onto a schema that already has everything gets through',
      () async {
    final db = CatalogDb.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    // Open it, so drift creates every table at the current schema. That is
    // the state a browser was in when it reported `duplicate column name:
    // image_large`: the columns were written and the version was not, so the
    // next open replayed the whole upgrade onto a schema that already had
    // them. A migration that cannot be run twice turns a lost version into a
    // database nobody can open.
    expect(await db.cardCount(), 0);

    await db.migration.onUpgrade(Migrator(db), 1, db.schemaVersion);

    expect(await db.cardCount(), 0,
        reason: 'the catalog has to still be readable afterwards');
  });

  test('an upgrade from empty still builds what is missing', () async {
    final db = CatalogDb.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await db.customStatement('DROP TABLE decks');
    await db.customStatement('DROP TABLE deck_cards');

    // Skipping what is there must not become skipping what is not.
    await db.migration.onUpgrade(Migrator(db), 1, db.schemaVersion);

    final tables = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    final names = tables.map((r) => r.read<String>('name')).toSet();
    expect(names, containsAll(['decks', 'deck_cards']));
  });
}
