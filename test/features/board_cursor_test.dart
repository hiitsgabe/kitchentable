import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/board_cursor.dart';

const _board = [
  (id: 'battlefield-s1', size: 3),
  (id: 'graveyard-s1', size: 0),
  (id: 'hand-s1', size: 2),
];

void main() {
  test('it starts on the first pile with something in it', () {
    final cursor = BoardCursor.start(_board)!;

    expect(cursor.zoneId, 'battlefield-s1');
    expect(cursor.index, 0);
  });

  test('it starts nowhere when there is nothing anywhere', () {
    expect(BoardCursor.start(const [(id: 'battlefield-s1', size: 0)]), isNull);
    expect(BoardCursor.start(const []), isNull);
  });

  test('stepping walks along the pile', () {
    final cursor = BoardCursor.start(_board)!.step(1, zones: _board);

    expect(cursor.index, 1);
    expect(cursor.zoneId, 'battlefield-s1');
  });

  test('stepping past the end stays at the end', () {
    var cursor = BoardCursor.start(_board)!;
    for (var i = 0; i < 9; i++) {
      cursor = cursor.step(1, zones: _board);
    }

    // Clamped and not wrapped. A player pressing right twice on a board of one
    // card should see nothing happen rather than see the ring teleport, and a
    // wrap on a pile of one is indistinguishable from a dead button.
    expect(cursor.index, 2);
  });

  test('stepping back past the front stays at the front', () {
    final cursor = BoardCursor.start(_board)!.step(-1, zones: _board);

    expect(cursor.index, 0);
  });

  test('changing pile skips the empty ones', () {
    final cursor = BoardCursor.start(_board)!.changeZone(1, zones: _board);

    expect(cursor.zoneId, 'hand-s1');
    expect(cursor.index, 0);
  });

  test('changing pile wraps round the table', () {
    final cursor = BoardCursor.start(_board)!
        .changeZone(1, zones: _board)
        .changeZone(1, zones: _board);

    expect(cursor.zoneId, 'battlefield-s1');
  });

  test('changing pile backwards works too', () {
    final cursor = BoardCursor.start(_board)!.changeZone(-1, zones: _board);

    expect(cursor.zoneId, 'hand-s1');
  });

  test('it stays put when every other pile is empty', () {
    const only = [
      (id: 'battlefield-s1', size: 2),
      (id: 'graveyard-s1', size: 0),
    ];
    final cursor = BoardCursor.start(only)!.step(1, zones: only);

    expect(cursor.changeZone(1, zones: only).zoneId, 'battlefield-s1');
    expect(cursor.changeZone(1, zones: only).index, 1,
        reason: 'a pile change that changes nothing must not move the ring');
  });

  test('a pile that shrank under the cursor pulls it back', () {
    const before = [(id: 'battlefield-s1', size: 5)];
    const after = [(id: 'battlefield-s1', size: 2)];
    var cursor = BoardCursor.start(before)!;
    for (var i = 0; i < 4; i++) {
      cursor = cursor.step(1, zones: before);
    }

    // Playing the card the ring was on is the common case, and the index it
    // was holding no longer exists.
    expect(cursor.step(0, zones: after).index, 1);
  });
}
