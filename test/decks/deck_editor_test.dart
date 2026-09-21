import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/decks/deck_repository.dart';
import 'package:kitchentable/decks/model/deck.dart';
import 'package:kitchentable/decks/model/deck_format.dart';
import 'package:kitchentable/features/decks/decks_controller.dart';
import 'package:kitchentable/features/menu/menu_controller.dart';
import 'package:kitchentable/sources/catalog/catalog_db.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';

CatalogCard _card(String name, {String typeLine = 'Instant'}) => CatalogCard(
      oracleId: name.toLowerCase(),
      name: name,
      typeLine: typeLine,
      cmc: 1,
    );

void main() {
  late CatalogDb db;
  late ProviderContainer container;

  setUp(() async {
    db = CatalogDb.forTesting(NativeDatabase.memory());
    await db.insertAll([
      _card('Sol Ring'),
      _card('Atraxa', typeLine: 'Legendary Creature - Phyrexian Angel'),
      _card('Mountain', typeLine: 'Basic Land - Mountain'),
    ]);
    container = ProviderContainer(
      overrides: [catalogDbProvider.overrideWithValue(db)],
    );
    await DeckRepository(db).save(const Deck(
      id: 'd1',
      name: 'pod deck',
      format: DeckFormat.commander,
    ));
    await container.read(deckEditorProvider.notifier).open('d1');
  });
  tearDown(() {
    container.dispose();
    db.close();
  });

  DeckEditor editor() => container.read(deckEditorProvider.notifier);
  Deck deck() => container.read(deckEditorProvider)!;

  test('opening loads the deck', () {
    expect(deck().name, 'pod deck');
    expect(deck().format, DeckFormat.commander);
  });

  test('adding the same card twice stacks instead of duplicating', () async {
    await editor().add(DeckSlot(card: _card('Mountain'), quantity: 1));
    await editor().add(DeckSlot(card: _card('Mountain'), quantity: 1));

    expect(deck().slots.length, 1);
    expect(deck().quantityOf('mountain'), 2);
  });

  test('the same card in deck and sideboard stays two slots', () async {
    await editor().add(DeckSlot(card: _card('Sol Ring'), quantity: 1));
    await editor().add(
      DeckSlot(card: _card('Sol Ring'), quantity: 1, sideboard: true),
    );

    expect(deck().slots.length, 2);
    expect(deck().mainCount, 1);
    expect(deck().sideCount, 1);
  });

  test('setting a quantity to zero removes the card', () async {
    final slot = DeckSlot(card: _card('Sol Ring'), quantity: 3);
    await editor().add(slot);
    await editor().setQuantity(slot, 0);

    expect(deck().slots, isEmpty);
  });

  test('a deck survives being closed and opened again', () async {
    await editor().add(DeckSlot(card: _card('Sol Ring'), quantity: 1));
    editor().close();
    await editor().open('d1');

    expect(deck().quantityOf('sol ring'), 1);
  });

  test('naming a commander demotes the one that was there', () async {
    final atraxa = DeckSlot(card: _card('Atraxa'), quantity: 1);
    final sol = DeckSlot(card: _card('Sol Ring'), quantity: 1);
    await editor().add(atraxa);
    await editor().add(sol);

    await editor().makeCommander(atraxa);
    expect(deck().commanders.single.card.name, 'Atraxa');

    await editor().makeCommander(sol);
    expect(deck().commanders.single.card.name, 'Sol Ring',
        reason: 'a deck has one commander, naming a second replaces the first');
    expect(deck().commanders.length, 1);
  });

  test('the plus button cannot make two of a singleton card', () async {
    final sol = DeckSlot(card: _card('Sol Ring'), quantity: 1);
    await editor().add(sol);

    await editor().setQuantity(sol, 2);

    expect(deck().quantityOf('sol ring'), 1,
        reason: 'Commander is singleton and the button is not an exception');
  });

  test('the plus button still works on a basic land', () async {
    final mountain = DeckSlot(card: _card('Mountain', typeLine: 'Basic Land - Mountain'), quantity: 1);
    await editor().add(mountain);

    await editor().setQuantity(mountain, 37);

    expect(deck().quantityOf('mountain'), 37);
  });

  test('the limit counts the sideboard copy too', () async {
    final sol = DeckSlot(card: _card('Sol Ring'), quantity: 1);
    final solSide =
        DeckSlot(card: _card('Sol Ring'), quantity: 1, sideboard: true);
    await editor().add(sol);
    await editor().add(solSide);

    // Already two of a singleton card across the piles, so neither goes up.
    await editor().setQuantity(sol, 2);
    expect(deck().quantityOf('sol ring'), 1);
  });

  test('going down is never refused', () async {
    final mountain = DeckSlot(card: _card('Mountain', typeLine: 'Basic Land - Mountain'), quantity: 10);
    await editor().add(mountain);

    await editor().setQuantity(mountain, 4);
    expect(deck().quantityOf('mountain'), 4);
  });

  test('a pasted list is written once, not once per card', () async {
    await editor().addAll([
      DeckSlot(card: _card('Sol Ring'), quantity: 1),
      DeckSlot(card: _card('Mountain'), quantity: 37),
      DeckSlot(card: _card('Atraxa'), quantity: 1),
    ]);

    expect(deck().mainCount, 39);
    expect(deck().slots.length, 3);
  });

  test('addAll stacks onto what is already there', () async {
    await editor().add(DeckSlot(card: _card('Mountain'), quantity: 10));
    await editor().addAll([DeckSlot(card: _card('Mountain'), quantity: 5)]);

    expect(deck().slots.length, 1);
    expect(deck().quantityOf('mountain'), 15);
  });
}
