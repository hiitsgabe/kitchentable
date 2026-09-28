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

  test('a seat with no transport under it may be acted for by anybody here',
      () {
    const here = SeatOwner.here();
    const nobody = SeatOwner.empty();

    // Solo and the pod on one tablet: there is no key to compare with, and
    // every chair is this device's, so the question has one answer whatever
    // key is asked about, a null included.
    expect(here.actableHere(me: null), isTrue);
    expect(here.actableHere(me: 'abc'), isTrue);
    expect(nobody.actableHere(me: null), isFalse);
    expect(nobody.actableHere(me: 'abc'), isFalse);
  });

  test('a keyed seat may be acted for by its own key and nobody else', () {
    const theirs = SeatOwner.peer('abc');

    // The seat is the same object on every phone. Whose it is to play is a
    // question each phone asks with its own key, which is what keeps a
    // guest's hand a guest's on the host's phone and the host's on the
    // guest's.
    expect(theirs.actableHere(me: 'abc'), isTrue);
    expect(theirs.actableHere(me: 'xyz'), isFalse);
    expect(theirs.actableHere(me: null), isFalse,
        reason: 'a phone with no key is not the phone that holds this seat');
  });
}
