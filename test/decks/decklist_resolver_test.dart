import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/decks/import/decklist_parser.dart';
import 'package:kitchentable/decks/import/decklist_resolver.dart';
import 'package:kitchentable/sources/catalog/catalog_db.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';

CatalogCard _card(String name) => CatalogCard(
      oracleId: name.toLowerCase(),
      name: name,
      typeLine: 'Instant',
      cmc: 1,
    );

void main() {
  late CatalogDb db;

  setUp(() async {
    db = CatalogDb.forTesting(NativeDatabase.memory());
    await db.insertAll([
      _card('Lightning Bolt'),
      _card('Counterspell'),
      _card("Urza's Saga"),
    ]);
  });
  tearDown(() => db.close());

  test('it resolves names to catalog cards', () async {
    final r = await resolveDecklist(db, parseDecklist('4 Lightning Bolt'));
    expect(r.slots.single.card.name, 'Lightning Bolt');
    expect(r.slots.single.quantity, 4);
    expect(r.isClean, isTrue);
  });

  test('matching ignores case, because people paste lowercase', () async {
    final r = await resolveDecklist(db, parseDecklist('2 lightning bolt'));
    expect(r.slots.single.card.name, 'Lightning Bolt');
  });

  test('a name the catalog never heard of is reported, not dropped', () async {
    final r = await resolveDecklist(
      db,
      parseDecklist('4 Lightning Bolt\n2 Lightnin Bolt'),
    );
    expect(r.slots.single.card.name, 'Lightning Bolt');
    expect(r.notFound, ['Lightnin Bolt']);
    expect(r.isClean, isFalse);
  });

  test('it never guesses a near miss into a different card', () async {
    final r = await resolveDecklist(db, parseDecklist('1 Lightning Bol'));
    expect(r.slots, isEmpty);
    expect(r.notFound, ['Lightning Bol']);
  });

  test('the sideboard flag survives the lookup', () async {
    final r = await resolveDecklist(
      db,
      parseDecklist('4 Lightning Bolt\nSideboard\n2 Counterspell'),
    );
    expect(r.slots.firstWhere((s) => s.sideboard).card.name, 'Counterspell');
  });

  test('a parser complaint is carried through, not swallowed', () async {
    final r = await resolveDecklist(
      db,
      parseDecklist('4 Lightning Bolt\nTotal: 75'),
    );
    expect(r.ignoredLines, ['Total: 75']);
    expect(r.isClean, isFalse);
  });

  test('an apostrophe in a name is not a lookup problem', () async {
    final r = await resolveDecklist(db, parseDecklist("1 Urza's Saga"));
    expect(r.slots.single.card.name, "Urza's Saga");
  });
}
