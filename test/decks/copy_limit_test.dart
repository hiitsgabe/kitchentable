import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/decks/model/copy_limit.dart';
import 'package:kitchentable/decks/model/deck_format.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';

CatalogCard _card({
  String name = 'Lightning Bolt',
  String typeLine = 'Instant',
  String? oracleText,
}) =>
    CatalogCard(
      oracleId: name,
      name: name,
      typeLine: typeLine,
      cmc: 1,
      oracleText: oracleText,
    );

void main() {
  group('copy limits', () {
    test('Commander allows one of a normal card, the others four', () {
      final bolt = _card();
      expect(copyLimitFor(bolt, DeckFormat.commander), 1);
      expect(copyLimitFor(bolt, DeckFormat.standard), 4);
      expect(copyLimitFor(bolt, DeckFormat.pauper), 4);
    });

    test('a basic land escapes the limit even in Commander', () {
      final mountain = _card(name: 'Mountain', typeLine: 'Basic Land - Mountain');
      expect(copyLimitFor(mountain, DeckFormat.commander), greaterThan(99));
    });

    test('a nonbasic land does not escape it', () {
      final saga = _card(name: "Urza's Saga", typeLine: 'Enchantment Land - Urza');
      expect(copyLimitFor(saga, DeckFormat.commander), 1);
    });

    test('a card that grants itself the exemption escapes too', () {
      final rats = _card(
        name: 'Relentless Rats',
        typeLine: 'Creature - Rat',
        oracleText: 'Relentless Rats gets +1/+1 for each other creature you '
            'control named Relentless Rats.\nA deck can have any number of '
            'cards named Relentless Rats.',
      );
      expect(copyLimitFor(rats, DeckFormat.commander), greaterThan(99));
      expect(copyLimitFor(rats, DeckFormat.standard), greaterThan(99));
    });

    test('a card merely mentioning rats does not', () {
      final swarm = _card(
        name: 'Pack Rat',
        typeLine: 'Creature - Rat',
        oracleText: 'Pack Rat gets +1/+1 for each other Rat you control.',
      );
      expect(copyLimitFor(swarm, DeckFormat.standard), 4);
    });
  });

  group('format shape', () {
    test('Commander is a hundred exactly, with a commander, at forty life', () {
      const f = DeckFormat.commander;
      expect(f.deckSize, 100);
      expect(f.sizeIsExact, isTrue);
      expect(f.needsCommander, isTrue);
      expect(f.startingLife, 40);
      expect(f.sideboardSize, 0);
    });

    test('Standard and Pauper are the same shape, different filter', () {
      expect(DeckFormat.standard.deckSize, DeckFormat.pauper.deckSize);
      expect(DeckFormat.standard.sideboardSize, DeckFormat.pauper.sideboardSize);
      expect(DeckFormat.standard.startingLife, DeckFormat.pauper.startingLife);
      expect(DeckFormat.standard.legalityKey, 'standard');
      expect(DeckFormat.pauper.legalityKey, 'pauper');
    });

    test('a draft pool answers to no legality list', () {
      expect(DeckFormat.draft.legalityKey, isNull);
      expect(DeckFormat.draft.deckSize, 40);
      expect(DeckFormat.draft.sizeIsExact, isFalse);
    });
  });
}
