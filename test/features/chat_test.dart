import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/chat.dart';
import 'package:kitchentable/table/model/seat.dart';
import 'package:kitchentable/table/model/seat_owner.dart';
import 'package:kitchentable/table/model/table_state.dart';

const _table = TableState(
  seats: [
    Seat(
      id: 's1',
      name: 'Thistle',
      life: 40,
      owner: SeatOwner.peer('me'),
      zones: [],
    ),
    Seat(
      id: 's2',
      name: 'Carla',
      life: 40,
      owner: SeatOwner.peer('carla'),
      zones: [],
    ),
  ],
);

ChatDesk _desk() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container.read(chatProvider);
  return container.read(chatProvider.notifier);
}

void main() {
  test('a line carries the name on the chair, never the key', () {
    // A key is sixty four characters of hex and means nothing to anybody at
    // the table.
    final desk = _desk();
    desk.heard(by: 'carla', text: 'your turn', table: _table, me: 'me');

    expect(desk.state.latest!.name, 'Carla');
    expect(desk.state.latest!.text, 'your turn');
    expect(desk.state.latest!.mine, isFalse);
  });

  test('somebody with no chair is still somebody', () {
    final desk = _desk();
    desk.heard(by: 'astranger', text: 'hello', table: _table, me: 'me');

    expect(desk.state.latest!.name, 'Somebody');
  });

  test('your own line is not news to you', () {
    final desk = _desk();
    desk.heard(by: 'me', text: 'mine', table: _table, me: 'me');

    expect(desk.state.lines, hasLength(1));
    expect(desk.state.latest!.mine, isTrue);
    expect(desk.state.unread, 0, reason: 'you watched yourself type it');
  });

  test('everybody else s lines count up until the chat is opened', () {
    final desk = _desk();
    desk.heard(by: 'carla', text: 'one', table: _table, me: 'me');
    desk.heard(by: 'carla', text: 'two', table: _table, me: 'me');

    expect(desk.state.unread, 2);

    desk.seen();
    expect(desk.state.unread, 0);

    desk.heard(by: 'carla', text: 'three', table: _table, me: 'me');
    expect(desk.state.unread, 1);
  });

  test('an empty line is not a line', () {
    final desk = _desk();
    desk.heard(by: 'carla', text: '   ', table: _table, me: 'me');

    expect(desk.state.lines, isEmpty);
  });

  test('it keeps an evening and not for ever', () {
    // A table left open overnight must not grow without end.
    final desk = _desk();
    for (var i = 0; i < ChatDesk.keep + 40; i++) {
      desk.heard(by: 'carla', text: 'line $i', table: _table, me: 'me');
    }

    expect(desk.state.lines, hasLength(ChatDesk.keep));
    // The newest is kept and the oldest is dropped, which is the way round
    // that matters.
    expect(desk.state.lines.last.text, 'line ${ChatDesk.keep + 39}');
  });

  test('the newest is last, because that is where a chat puts it', () {
    final desk = _desk();
    desk.heard(by: 'carla', text: 'first', table: _table, me: 'me');
    desk.heard(by: 'me', text: 'second', table: _table, me: 'me');

    expect([for (final l in desk.state.lines) l.text], ['first', 'second']);
  });
}
