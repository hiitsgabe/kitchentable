import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/said_out_loud.dart';
import 'package:kitchentable/features/play/table_news.dart';
import 'package:kitchentable/table/actions/table_action.dart';

TableNews _news(TableAction action, {String by = 'carla', int turn = 1}) =>
    (by: by, name: 'Carla', action: action, turn: turn);

void main() {
  test('a roll somebody else made is said out loud, with the die named', () {
    final line = saidOutLoud(
      _news(const RollDice([17, 12, 6], die: 0)),
      me: 'me',
    );

    expect(line, 'Carla rolled 17 on the d20');
  });

  test('your own roll is not announced back at you', () {
    // You watched it leave your own hand. A toast saying what you just did is
    // the app talking to itself.
    final line = saidOutLoud(
      _news(const RollDice([17, 12, 6], die: 0), by: 'me'),
      me: 'me',
    );

    expect(line, isNull);
  });

  test('a roll from a build that did not say which die still says who', () {
    // The numbers are agreed either way. There is just nothing to name.
    final line = saidOutLoud(_news(const RollDice([17, 12, 6])), me: 'me');

    expect(line, 'Carla rolled');
  });

  test('moving a card says nothing, because you can see it move', () {
    final line = saidOutLoud(
      _news(const MoveCard(cardId: 'c', toZoneId: 'z')),
      me: 'me',
    );

    expect(line, isNull);
  });

  test('a tray acts out only what somebody else threw', () {
    expect(
      announcedRoll(_news(const RollDice([17, 12, 6], die: 1)), me: 'me'),
      (die: 1, value: 12, turn: 1),
    );
    expect(
      announcedRoll(
        _news(const RollDice([17, 12, 6], die: 1), by: 'me'),
        me: 'me',
      ),
      isNull,
    );
    expect(announcedRoll(null, me: 'me'), isNull);
  });

  test('a die index nobody has is not acted out', () {
    // A peer running something newer with four dice in its tray. The numbers
    // are still agreed; the animation is the part this build cannot do.
    expect(
      announcedRoll(_news(const RollDice([17, 12, 6], die: 9)), me: 'me'),
      isNull,
    );
  });
}
