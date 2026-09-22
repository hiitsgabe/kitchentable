import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/table/actions/table_action.dart';
import 'package:kitchentable/table/model/seat.dart';
import 'package:kitchentable/table/model/table_state.dart';
import 'package:kitchentable/table/referee/referee.dart';

final _table = const TableState(
  seats: [Seat(id: 's1', name: 'you', life: 40, zones: [])],
);

void main() {
  test('the permissive referee permits everything', () {
    const referee = PermissiveReferee();

    expect(
      referee.review(_table, const MoveCard(cardId: 'x', toZoneId: 'y')),
      isNull,
    );
    expect(referee.review(_table, const PassTurn()), isNull);
    expect(referee.review(_table, const RollDice([6])), isNull);
  });

  test('it knows no legal targets, and says so rather than guessing', () {
    const referee = PermissiveReferee();

    expect(referee.legalTargets(_table, 'c1'), isNull,
        reason: 'null is I do not know, an empty list would be there are none');
  });

  test('a refusal carries a reason a player can act on', () {
    const refusal = Refusal('It is not your turn');
    expect(refusal.reason, 'It is not your turn');
  });
}
