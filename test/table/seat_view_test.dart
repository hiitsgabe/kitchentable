import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/table/model/card_instance.dart';
import 'package:kitchentable/table/model/seat.dart';
import 'package:kitchentable/table/model/zone.dart';
import 'package:kitchentable/table/view/seat_view.dart';

Zone _zone(String id, String seatId, ZoneVisibility v, int n) => Zone(
      id: '$id-$seatId',
      seatId: seatId,
      label: id,
      visibility: v,
      ordered: true,
      cards: [
        for (var i = 0; i < n; i++)
          CardInstance(id: '$seatId-$id-$i', oracleId: 'card$i'),
      ],
    );

Seat _seat(String id) => Seat(
      id: id,
      name: id,
      life: 40,
      zones: [
        _zone('library', id, ZoneVisibility.hidden, 53),
        _zone('hand', id, ZoneVisibility.owner, 7),
        _zone('battlefield', id, ZoneVisibility.public, 3),
      ],
    );

void main() {
  test('you see the cards in your own hand', () {
    final view = SeatView.of(_seat('s1'), viewer: 's1');
    final hand = view.zone('hand-s1')!;

    expect(hand.count, 7);
    expect(hand.cards, hasLength(7));
    expect(hand.readable, isTrue);
  });

  test('you see how many cards are in somebody else s hand, and no more', () {
    final view = SeatView.of(_seat('s2'), viewer: 's1');
    final hand = view.zone('hand-s2')!;

    // The count is public at a real table: everybody can see how many cards
    // somebody is holding. What is in them is not.
    expect(hand.count, 7);
    expect(hand.cards, isEmpty);
    expect(hand.readable, isFalse);
  });

  test('nobody reads a library, not even its owner', () {
    final mine = SeatView.of(_seat('s1'), viewer: 's1');
    final theirs = SeatView.of(_seat('s2'), viewer: 's1');

    expect(mine.zone('library-s1')!.readable, isFalse);
    expect(mine.zone('library-s1')!.count, 53);
    expect(theirs.zone('library-s2')!.readable, isFalse);
  });

  test('a battlefield is everybody s', () {
    final theirs = SeatView.of(_seat('s2'), viewer: 's1');
    final board = theirs.zone('battlefield-s2')!;

    expect(board.readable, isTrue);
    expect(board.cards, hasLength(3));
  });

  test('a view never carries a card it will not show', () {
    final theirs = SeatView.of(_seat('s2'), viewer: 's1');

    // The point of building a view rather than filtering in the widget: a card
    // that reached the screen could be read off the widget tree, and plan 3
    // sends these over a wire.
    final everything = theirs.zones.expand((z) => z.cards).map((c) => c.id);
    expect(everything.any((id) => id.contains('hand')), isFalse);
    expect(everything.any((id) => id.contains('library')), isFalse);
  });

  test('it is the same seat either way round', () {
    final view = SeatView.of(_seat('s1'), viewer: 's1');
    expect(view.seatId, 's1');
    expect(view.life, 40);
    expect(view.name, 's1');
  });
}
