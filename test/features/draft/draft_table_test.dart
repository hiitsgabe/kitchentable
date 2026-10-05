import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/draft/draft_state.dart';
import 'package:kitchentable/features/draft/draft_table.dart';

/// A pack of [names] cards, each its own card.
List<DraftCard> _pack(List<String> names) => [
  for (final n in names) DraftCard(uuid: n, oracleId: 'o-$n', rarity: 'common'),
];

List<String> _packIds(DraftView v) => [for (final c in v.pack!) c.uuid];
List<String> _poolIds(DraftView v) => [for (final c in v.pool) c.uuid];

void main() {
  test('sealed opens every pack into its owner pool and goes to building', () {
    final table = DraftTable(
      seatIds: ['a', 'b'],
      sealed: true,
      packsPerSeat: [
        [
          _pack(['a1', 'a2']),
          _pack(['a3']),
        ],
        [
          _pack(['b1']),
          _pack(['b2']),
        ],
      ],
    );
    expect(table.building, isTrue);
    expect(_poolIds(table.viewFor('a')), ['a1', 'a2', 'a3']);
    expect(_poolIds(table.viewFor('b')), ['b1', 'b2']);
    expect(table.viewFor('a').phase, DraftPhase.building);
  });

  group('a two seat draft', () {
    late DraftTable table;
    setUp(() {
      // One round, two cards per pack, so it is easy to follow the pass.
      table = DraftTable(
        seatIds: ['a', 'b'],
        sealed: false,
        packsPerSeat: [
          [
            _pack(['a1', 'a2']),
          ],
          [
            _pack(['b1', 'b2']),
          ],
        ],
      );
    });

    test('each seat opens its own pack, and only its own', () {
      final a = table.viewFor('a');
      expect(a.phase, DraftPhase.picking);
      expect(_packIds(a), ['a1', 'a2'], reason: 'a sees a pack, not b pack');
      expect(a.fresh, isTrue, reason: 'the pack it cracked open');
      expect(a.packNumber, 1);
      expect(a.pickNumber, 1);
      expect(_packIds(table.viewFor('b')), ['b1', 'b2']);
    });

    test(
      'a pick is taken into the pool and the rest passes to the neighbour',
      () {
        expect(table.pick('a', 'a1'), isTrue);
        expect(_poolIds(table.viewFor('a')), ['a1']);
        // a has nothing until b passes; a is waiting.
        expect(table.viewFor('a').phase, DraftPhase.waiting);
        // b now holds its own pack still (hasn't picked), queue depth shows the
        // passed pack waiting behind it.
        expect(table.pick('b', 'b1'), isTrue);
        // Now a has b's remaining pack (b2), passed; not fresh.
        final a = table.viewFor('a');
        expect(a.phase, DraftPhase.picking);
        expect(_packIds(a), ['b2'], reason: 'a now holds what b passed on');
        expect(
          a.fresh,
          isFalse,
          reason: 'a passed-along pack does not animate',
        );
      },
    );

    test('picking a card not in your front pack is refused', () {
      expect(table.pick('a', 'b1'), isFalse, reason: 'not in a front pack');
      expect(table.pick('a', 'nope'), isFalse);
    });

    test(
      'when both packs are emptied the draft is done and everyone builds',
      () {
        // 4 cards total, 4 picks, then done.
        table.pick('a', 'a1');
        table.pick('b', 'b1');
        // a now has b2 (passed), b has a2 (passed).
        table.pick('a', 'b2');
        table.pick('b', 'a2');
        expect(table.done, isTrue);
        expect(table.viewFor('a').phase, DraftPhase.building);
        expect(_poolIds(table.viewFor('a')).toSet(), {'a1', 'b2'});
        expect(_poolIds(table.viewFor('b')).toSet(), {'b1', 'a2'});
      },
    );
  });

  test('round two passes the other way', () {
    // Three seats, two rounds, one card per pack so a round is one pick each.
    final table = DraftTable(
      seatIds: ['a', 'b', 'c'],
      sealed: false,
      packsPerSeat: [
        [
          _pack(['a1']),
          _pack(['a2']),
        ],
        [
          _pack(['b1']),
          _pack(['b2']),
        ],
        [
          _pack(['c1']),
          _pack(['c2']),
        ],
      ],
    );
    // Round 1: each picks its single-card pack, which empties it, so no pass.
    table.pick('a', 'a1');
    table.pick('b', 'b1');
    table.pick('c', 'c1');
    // Round 2 opened: each seat cracked its second pack.
    expect(table.viewFor('a').packNumber, 2);
    expect(_packIds(table.viewFor('a')), ['a2']);
    expect(table.viewFor('a').fresh, isTrue);
  });
}
