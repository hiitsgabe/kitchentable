import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/look_at_top.dart';
import 'package:kitchentable/table/actions/apply.dart';
import 'package:kitchentable/table/actions/table_action.dart';
import 'package:kitchentable/table/model/card_instance.dart';
import 'package:kitchentable/table/model/seat.dart';
import 'package:kitchentable/table/model/table_state.dart';
import 'package:kitchentable/table/model/zone.dart';

TableState _table() => TableState(
      seats: [
        Seat(
          id: 's1',
          name: 'you',
          life: 40,
          zones: [
            Zone(
              id: 'library-s1',
              seatId: 's1',
              label: 'Library',
              visibility: ZoneVisibility.hidden,
              ordered: true,
              cards: const [
                CardInstance(id: 'a', oracleId: 'A'),
                CardInstance(id: 'b', oracleId: 'B'),
                CardInstance(id: 'c', oracleId: 'C'),
                CardInstance(id: 'd', oracleId: 'D'),
              ],
            ),
            const Zone(
              id: 'graveyard-s1',
              seatId: 's1',
              label: 'Graveyard',
              visibility: ZoneVisibility.public,
              ordered: true,
            ),
            const Zone(
              id: 'hand-s1',
              seatId: 's1',
              label: 'Hand',
              visibility: ZoneVisibility.owner,
              ordered: false,
            ),
          ],
        ),
      ],
    );

/// The same table with one card already in the graveyard, which is where the
/// pile sheet's cards come from.
TableState _withOneDead() {
  final table = _table();
  final pile = table.zone('graveyard-s1')!;
  return table.withZone(
    pile.add(const CardInstance(id: 'g', oracleId: 'G')),
  );
}

List<String> _library(TableState t) =>
    t.zone('library-s1')!.cards.map((c) => c.id).toList();

TableState _run(TableState table, List<TableAction> actions) =>
    actions.fold(table, apply);

void main() {
  test('putting everything back on top in the order you chose', () {
    // Scry 2, keeping both, swapped.
    final next = _run(
      _table(),
      arrange(
        libraryId: 'library-s1',
        placements: const [
          (cardId: 'b', to: Landing.top),
          (cardId: 'a', to: Landing.top),
        ],
        librarySize: 4,
      ),
    );

    expect(_library(next), ['b', 'a', 'c', 'd']);
  });

  test('sending one to the bottom', () {
    // Scry 1, bottoming it.
    final next = _run(
      _table(),
      arrange(
        libraryId: 'library-s1',
        placements: const [(cardId: 'a', to: Landing.bottom)],
        librarySize: 4,
      ),
    );

    expect(_library(next), ['b', 'c', 'd', 'a']);
  });

  test('top and bottom at once, which is what scry two really is', () {
    final next = _run(
      _table(),
      arrange(
        libraryId: 'library-s1',
        placements: const [
          (cardId: 'b', to: Landing.top),
          (cardId: 'a', to: Landing.bottom),
        ],
        librarySize: 4,
      ),
    );

    expect(_library(next), ['b', 'c', 'd', 'a']);
  });

  test('surveil sends them to the graveyard instead', () {
    final next = _run(
      _table(),
      arrange(
        libraryId: 'library-s1',
        graveyardId: 'graveyard-s1',
        placements: const [
          (cardId: 'a', to: Landing.graveyard),
          (cardId: 'b', to: Landing.top),
        ],
        librarySize: 4,
      ),
    );

    expect(_library(next), ['b', 'c', 'd']);
    expect(next.zone('graveyard-s1')!.cards.map((c) => c.id), ['a']);
  });

  test('an impulse effect takes one and bottoms the rest', () {
    final next = _run(
      _table(),
      arrange(
        libraryId: 'library-s1',
        handId: 'hand-s1',
        placements: const [
          (cardId: 'a', to: Landing.hand),
          (cardId: 'b', to: Landing.bottom),
          (cardId: 'c', to: Landing.bottom),
        ],
        librarySize: 4,
      ),
    );

    expect(_library(next), ['d', 'b', 'c']);
    expect(next.zone('hand-s1')!.cards.map((c) => c.id), ['a']);
  });

  test('a card put underneath from outside the library lands last', () {
    // Regrowth's opposite: a card going from the graveyard to the bottom of
    // the deck. It was never in the library, so the pile it is inserted into
    // is one longer than the size handed over and not one shorter, and the
    // scry arithmetic would leave it second from the bottom, where nothing on
    // screen would ever show it.
    final next = _run(
      _withOneDead(),
      arrange(
        libraryId: 'library-s1',
        placements: const [(cardId: 'g', to: Landing.bottom)],
        librarySize: 4,
        fromLibrary: false,
      ),
    );

    expect(_library(next), ['a', 'b', 'c', 'd', 'g']);
    expect(next.zone('graveyard-s1')!.cards, isEmpty);
  });

  test('nothing chosen changes nothing', () {
    final next = _run(
      _table(),
      arrange(
        libraryId: 'library-s1',
        placements: const [],
        librarySize: 4,
      ),
    );

    expect(_library(next), ['a', 'b', 'c', 'd']);
  });

  test('a destination with no zone for it is skipped, not crashed', () {
    // No graveyardId was given, so a card sent there has nowhere to go. At a
    // real table you do not get an exception for reaching for a pile that is
    // not there, which is the rule apply already follows.
    final next = _run(
      _table(),
      arrange(
        libraryId: 'library-s1',
        placements: const [(cardId: 'a', to: Landing.graveyard)],
        librarySize: 4,
      ),
    );

    expect(_library(next), ['a', 'b', 'c', 'd']);
  });
}
