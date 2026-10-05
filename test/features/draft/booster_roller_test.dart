import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/draft/booster_roller.dart';
import 'package:kitchentable/sources/model/draft_set.dart';

/// A tiny set: ten commons, four uncommons, two rares, each its own uuid.
List<DraftPrinting> _printings() => [
  for (var i = 0; i < 10; i++) _p('c$i', 'common'),
  for (var i = 0; i < 4; i++) _p('u$i', 'uncommon'),
  for (var i = 0; i < 2; i++) _p('r$i', 'rare'),
];

DraftPrinting _p(String uuid, String rarity) => DraftPrinting(
  setCode: 'TST',
  uuid: uuid,
  oracleId: 'o-$uuid',
  rarity: rarity,
  number: uuid,
);

Map<String, dynamic> _booster() => {
  'play': {
    'boostersTotalWeight': 1,
    'boosters': [
      {
        'weight': 1,
        'contents': {'common': 6, 'uncommon': 3, 'rare': 1},
      },
    ],
    'sheets': {
      'common': {
        'totalWeight': 10,
        'foil': false,
        'cards': {for (var i = 0; i < 10; i++) 'c$i': 1},
      },
      'uncommon': {
        'totalWeight': 4,
        'foil': false,
        'cards': {for (var i = 0; i < 4; i++) 'u$i': 1},
      },
      'rare': {
        'totalWeight': 2,
        'foil': false,
        'cards': {for (var i = 0; i < 2; i++) 'r$i': 1},
      },
    },
  },
};

void main() {
  test('a pack has the sheet counts the layout asks for', () {
    final roller = BoosterRoller(
      booster: _booster(),
      printings: {for (final p in _printings()) p.uuid: p},
      random: Random(1),
    );
    final pack = roller.rollPack();
    expect(pack, hasLength(10), reason: '6 + 3 + 1');
    expect(pack.where((p) => p.rarity == 'common'), hasLength(6));
    expect(pack.where((p) => p.rarity == 'uncommon'), hasLength(3));
    expect(pack.where((p) => p.rarity == 'rare'), hasLength(1));
  });

  test('no printing repeats inside a pack: a slot does not give two of one '
      'common', () {
    final roller = BoosterRoller(
      booster: _booster(),
      printings: {for (final p in _printings()) p.uuid: p},
      random: Random(7),
    );
    for (var i = 0; i < 50; i++) {
      final pack = roller.rollPack();
      final ids = pack.map((p) => p.uuid).toList();
      expect(ids.toSet(), hasLength(ids.length), reason: 'roll $i had a dup');
    }
  });

  test('the same seed rolls the same pack', () {
    List<String> roll(int seed) => BoosterRoller(
      booster: _booster(),
      printings: {for (final p in _printings()) p.uuid: p},
      random: Random(seed),
    ).rollPack().map((p) => p.uuid).toList();
    expect(roll(42), roll(42));
    expect(roll(1), isNot(roll(2)));
  });

  test('it prefers the draft product, then play, and skips collector', () {
    expect(
      BoosterRoller(booster: {'collector': {}, 'play': {}}, printings: {}).kind,
      'play',
      reason: 'collector is never drafted',
    );
    expect(
      BoosterRoller(booster: {'draft': {}, 'play': {}}, printings: {}).kind,
      'draft',
      reason: 'the draft booster wins when a set has both',
    );
    expect(BoosterRoller(booster: const {}, printings: {}).canRoll, isFalse);
  });
}
