import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/table/actions/table_action.dart';
import 'package:kitchentable/table/model/card_instance.dart';
import 'package:kitchentable/table/model/seat.dart';
import 'package:kitchentable/table/model/table_state.dart';
import 'package:kitchentable/table/model/zone.dart';
import 'package:kitchentable/table/table_session.dart';

TableState _table() => TableState(
      seats: [
        Seat(
          id: 's1',
          name: 'you',
          life: 40,
          zones: [
            Zone(
              id: 'library',
              seatId: 's1',
              label: 'Library',
              visibility: ZoneVisibility.hidden,
              ordered: true,
              cards: [
                for (var i = 0; i < 5; i++)
                  CardInstance(id: 'c$i', oracleId: 'x'),
              ],
            ),
            const Zone(
              id: 'hand',
              seatId: 's1',
              label: 'Hand',
              visibility: ZoneVisibility.owner,
              ordered: false,
            ),
          ],
        ),
      ],
    );

void main() {
  test('a fresh session has nothing to undo', () {
    final session = TableSession(_table());
    expect(session.canUndo, isFalse);
  });

  test('undo puts the table back exactly as it was', () {
    final session = TableSession(_table());
    session.run(const DrawCards(
      fromZoneId: 'library',
      toZoneId: 'hand',
      count: 3,
    ));

    expect(session.state.zone('hand')!.size, 3);

    session.undo();

    expect(session.state.zone('hand')!.size, 0);
    expect(session.state.zone('library')!.size, 5);
  });

  test('undo goes back more than one step', () {
    final session = TableSession(_table());
    session.run(const ChangeLife(seatId: 's1', by: -1));
    session.run(const ChangeLife(seatId: 's1', by: -1));
    session.run(const ChangeLife(seatId: 's1', by: -1));

    expect(session.state.seat('s1')!.life, 37);

    session.undo();
    session.undo();

    expect(session.state.seat('s1')!.life, 39);
  });

  test('undoing past the beginning stops at the beginning', () {
    final session = TableSession(_table());
    session.run(const ChangeLife(seatId: 's1', by: -1));

    session.undo();
    session.undo();
    session.undo();

    expect(session.state.seat('s1')!.life, 40);
    expect(session.canUndo, isFalse);
  });

  test('history does not grow without bound', () {
    final session = TableSession(_table(), historyLimit: 10);

    for (var i = 0; i < 50; i++) {
      session.run(const ChangeLife(seatId: 's1', by: -1));
    }

    // A table left running all evening would otherwise keep every state it
    // ever had, and each one holds every card.
    expect(session.historyLength, 10);
  });

  test('undo only reaches as far back as the history kept', () {
    final session = TableSession(_table(), historyLimit: 3);

    for (var i = 0; i < 10; i++) {
      session.run(const ChangeLife(seatId: 's1', by: -1));
    }
    for (var i = 0; i < 10; i++) {
      session.undo();
    }

    expect(session.state.seat('s1')!.life, 33,
        reason: 'three steps back from thirty, and no further');
  });
}
