import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/table/model/seat.dart';
import 'package:kitchentable/table/model/seat_owner.dart';

void main() {
  test('a seat on this device is held by this device', () {
    const seat = Seat(
      id: 's1',
      name: 'you',
      life: 40,
      zones: [],
      owner: SeatOwner.here(),
    );

    expect(seat.owner.isHere, isTrue);
    expect(seat.owner.peerId, isNull);
  });

  test('a seat held by somebody else names them', () {
    const seat = Seat(
      id: 's2',
      name: 'Carla',
      life: 40,
      zones: [],
      owner: SeatOwner.peer('abc123'),
    );

    expect(seat.owner.isHere, isFalse);
    expect(seat.owner.peerId, 'abc123');
  });

  test('an empty chair is held by nobody', () {
    const seat = Seat(id: 's3', name: 'empty', life: 40, zones: []);

    expect(seat.owner.isHere, isFalse);
    expect(seat.owner.isEmpty, isTrue);
  });

  test('only a seat on this device may be acted for', () {
    const here = SeatOwner.here();
    const there = SeatOwner.peer('abc');
    const nobody = SeatOwner.empty();

    // The screen reads this before offering a control. A seat somebody else
    // holds is watched, not played, and plan 3 is where the difference starts
    // to matter.
    expect(here.actableHere, isTrue);
    expect(there.actableHere, isFalse);
    expect(nobody.actableHere, isFalse);
  });
}
