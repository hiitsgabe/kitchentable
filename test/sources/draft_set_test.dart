import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/sources/model/draft_set.dart';

DraftSet _set({
  String type = 'expansion',
  int cards = 286,
  bool onlineOnly = false,
  String? booster,
}) => DraftSet(
  booster: booster,
  code: 'MKM',
  name: 'Murders at Karlov Manor',
  type: type,
  releaseDate: '2024-02-09',
  baseSetSize: cards,
  totalSetSize: cards,
  onlineOnly: onlineOnly,
);

void main() {
  group('draftable', () {
    test('a boostered set with cards on paper', () {
      expect(_set().draftable, isTrue);
      expect(_set(type: 'core').draftable, isTrue);
      expect(_set(type: 'masters').draftable, isTrue);
      expect(_set(type: 'draft_innovation', cards: 90).draftable, isTrue);
    });

    test('not a product without packs', () {
      expect(_set(type: 'promo', cards: 1).draftable, isFalse);
      expect(_set(type: 'commander', cards: 103).draftable, isFalse);
      expect(_set(type: 'token', cards: 400).draftable, isFalse);
      expect(_set(type: 'alchemy', cards: 300).draftable, isFalse);
    });

    test('not a set with too few cards to open a pool from', () {
      expect(_set(cards: 0).draftable, isFalse);
      expect(_set(cards: 41).draftable, isFalse);
      expect(_set(cards: 89).draftable, isFalse);
    });

    test('not a set that only exists online', () {
      expect(_set(onlineOnly: true).draftable, isFalse);
    });

    test('not a set whose file was read and had no packs', () {
      expect(_set(booster: '{}').draftable, isFalse);
      expect(_set(booster: '{"draft":{}}').draftable, isTrue);
    });
  });

  group('releasedBy', () {
    test('on the day and after, not before', () {
      final set = _set();
      expect(set.releasedBy(DateTime(2024, 2, 9)), isTrue);
      expect(set.releasedBy(DateTime(2026, 1, 1)), isTrue);
      expect(set.releasedBy(DateTime(2024, 2, 8)), isFalse);
    });
  });

  group('hasPacks', () {
    test('only once the file was read and had a recipe', () {
      expect(_set().hasPacks, isFalse, reason: 'the list row has no file');
      expect(_set(booster: '{}').hasPacks, isFalse, reason: 'read, empty');
      expect(_set(booster: '{"draft":{}}').hasPacks, isTrue);
    });
  });

  group('symbolUrlFor', () {
    test('a set code, in any case', () {
      expect(
        DraftSet.symbolUrlFor('MKM'),
        'https://svgs.scryfall.io/sets/mkm.svg',
      );
      expect(_set().symbolUrl, 'https://svgs.scryfall.io/sets/mkm.svg');
    });

    test('nothing for a label that is not a code', () {
      expect(DraftSet.symbolUrlFor(null), isNull);
      expect(DraftSet.symbolUrlFor('Demo table'), isNull);
    });
  });
}
