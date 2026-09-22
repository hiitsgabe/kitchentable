import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/table/model/card_instance.dart';

void main() {
  test('a card starts upright, face up and uncounted', () {
    const card = CardInstance(id: 'i1', oracleId: 'sol ring');

    expect(card.rotation, 0);
    expect(card.faceDown, isFalse);
    expect(card.counters, isEmpty);
    expect(card.attachedTo, isNull);
    expect(card.position, isNull);
  });

  test('two cards of the same printing are still two cards', () {
    const a = CardInstance(id: 'i1', oracleId: 'mountain');
    const b = CardInstance(id: 'i2', oracleId: 'mountain');

    expect(a == b, isFalse,
        reason: 'thirty seven Mountains are thirty seven things on a table');
  });

  test('counters add up and clear away', () {
    const card = CardInstance(id: 'i1', oracleId: 'x');

    final loaded = card.withCounter('+1/+1', 2).withCounter('+1/+1', 1);
    expect(loaded.counters['+1/+1'], 3);

    final cleared = loaded.withCounter('+1/+1', -3);
    expect(cleared.counters.containsKey('+1/+1'), isFalse,
        reason: 'a counter at zero is not a counter');
  });

  test('a counter can go negative, because some of them do', () {
    const card = CardInstance(id: 'i1', oracleId: 'x');
    final drained = card.withCounter('-1/-1', 2);

    expect(drained.counters['-1/-1'], 2);
  });

  test('a tap turns a card, and a second tap turns it back', () {
    const card = CardInstance(id: 'c', oracleId: 'o');

    // At a table a card is straight or it is turned. Ninety per tap walked it
    // through upside down on the way back, which is what the player hit.
    expect(card.turned().rotation, 90);
    expect(card.turned().turned().rotation, 0);
  });

  test('a card turned any other way comes back straight on a tap', () {
    const card = CardInstance(id: 'c', oracleId: 'o', rotation: 180);

    expect(card.turned().rotation, 0);
  });

  test('an angle can be set outright', () {
    const card = CardInstance(id: 'c', oracleId: 'o');

    expect(card.turnedTo(180).rotation, 180);
    expect(card.turnedTo(180).turnedTo(180).rotation, 180,
        reason: 'setting an angle is not a toggle');
  });
}
