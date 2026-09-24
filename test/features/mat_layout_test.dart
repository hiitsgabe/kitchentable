import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/renderers/mat_layout.dart';

void main() {
  test('two seats sit side by side', () {
    final a = matFor(0, 2);
    final b = matFor(1, 2);

    expect(a.top, b.top);
    expect(b.left, greaterThan(a.right));
  });

  test('four seats make a square and no two mats touch', () {
    final mats = [for (var i = 0; i < 4; i++) matFor(i, 4)];

    for (var i = 0; i < mats.length; i++) {
      for (var j = i + 1; j < mats.length; j++) {
        expect(mats[i].overlaps(mats[j]), isFalse,
            reason: 'mat $i overlaps mat $j');
      }
    }
    expect(mats[2].top, greaterThan(mats[0].bottom));
  });

  test('three seats leave the fourth place empty', () {
    // Squeezing three into a row makes a card a smudge on a tablet. The gap
    // where the fourth would be is the cheaper answer.
    expect(matFor(2, 3).top, greaterThan(matFor(0, 3).bottom));
    expect(matFor(2, 3).left, matFor(0, 3).left);
  });

  test('one seat gets the whole surface', () {
    // The strips beside the mat are the seat's too, so one seat's surface is a
    // mat plus a strip on each side rather than a mat exactly. It was
    // `matSize` on the nose until the furniture came off the mat.
    expect(matFor(0, 1),
        Rect.fromLTWH(matAside, 0, matSize.width, matSize.height));
    expect(surfaceFor(1), Size(matSize.width + matAside * 2, matSize.height));
  });

  test('the surface is big enough for every mat', () {
    for (final count in [1, 2, 3, 4, 5, 6]) {
      final surface = surfaceFor(count);
      for (var i = 0; i < count; i++) {
        final mat = matFor(i, count);
        expect(mat.right, lessThanOrEqualTo(surface.width),
            reason: 'mat $i of $count runs off the right');
        expect(mat.bottom, lessThanOrEqualTo(surface.height),
            reason: 'mat $i of $count runs off the bottom');
      }
    }
  });

  const card = Size(90, 126);

  test('a small box does not shrink the card past telling it apart', () {
    // A phone's board is 358 points wide and 485 tall, where the fit alone is
    // 0.559 and the card on the mat comes out 50.3 points across.
    expect(matScaleFor(const Size(358, 485)), matScaleFloor);
    expect(matScaleFloor * cardOnMat.width, greaterThanOrEqualTo(72));
  });

  test('a big box still fits the whole mat', () {
    // Whichever of the two runs out first, which above the floor is what it
    // always was: the height on a wide window, the width on a tall one.
    expect(matScaleFor(const Size(1900, 800)), closeTo(800 / 380, 1e-9));
    expect(matScaleFor(const Size(1280, 3800)), closeTo(1280 / 640, 1e-9));
  });

  test('a card with a position is centred on it', () {
    final spot = spotFor(position: (x: 0.5, y: 0.5), index: 0, card: card);

    expect(spot.dx, closeTo(matSize.width / 2 - card.width / 2, 0.01));
    expect(spot.dy, closeTo(matSize.height / 2 - card.height / 2, 0.01));
  });

  test('a card at the very edge stays on the mat', () {
    final spot = spotFor(position: (x: 1, y: 1), index: 0, card: card);

    expect(spot.dx, closeTo(matSize.width - card.width, 0.01));
    expect(spot.dy, closeTo(matSize.height - card.height, 0.01));
    expect(spot.dx, greaterThanOrEqualTo(0));
  });

  test('a card without a position gets a slot, and keeps it', () {
    final first = spotFor(position: null, index: 0, card: card);
    final again = spotFor(position: null, index: 0, card: card);
    final second = spotFor(position: null, index: 1, card: card);

    // Cards must not jump around when one of them is turned, so the slot is a
    // function of the index and nothing else.
    expect(first, again);
    expect(second.dx, greaterThan(first.dx));
    expect(second.dy, first.dy);
  });

  test('the flow wraps rather than running off the mat', () {
    final spots = [
      for (var i = 0; i < 20; i++) spotFor(position: null, index: i, card: card),
    ];

    expect(spots.last.dy, greaterThan(spots.first.dy));
    for (final spot in spots) {
      expect(spot.dx + card.width, lessThanOrEqualTo(matSize.width));
    }
  });

  test('your own seat is the one nearest your hand', () {
    // Four seats, you are second in table order. The hand sits under the
    // canvas, so nearest means bottom, and bottom means last.
    final order = seatOrder(count: 4, viewerAt: 1);

    expect(order.last, 1);
    expect(order.toSet(), {0, 1, 2, 3});
  });

  test('the others keep going round the table in order', () {
    final order = seatOrder(count: 4, viewerAt: 1);

    // Turn order still reads round the table from the seat after yours, which
    // is the order you will be passing priority in.
    expect(order, [2, 3, 0, 1]);
  });

  test('a spectator changes nothing', () {
    expect(seatOrder(count: 3, viewerAt: null), [0, 1, 2]);
    expect(seatOrder(count: 3, viewerAt: 9), [0, 1, 2]);
  });

  test('a table of one is a table of one', () {
    expect(seatOrder(count: 1, viewerAt: 0), [0]);
  });

  test('a seat takes more room than its mat', () {
    // The corner, the deck, the graveyard and the token button stand beside
    // the mat and not on it, so a seat's share of the surface is wider than
    // the mat by a strip on each side.
    final station = stationFor(0, 1);
    final mat = matFor(0, 1);

    expect(station.width, greaterThan(mat.width));
    expect(station.height, mat.height);
  });

  test('the mat sits between the two strips', () {
    final station = stationFor(0, 1);
    final mat = matFor(0, 1);

    expect(mat.left, greaterThan(station.left));
    expect(mat.right, lessThan(station.right));
    // Even on both sides, so a table of four does not lean.
    expect(mat.left - station.left, closeTo(station.right - mat.right, 0.01));
  });

  test('the strips are a card wide, with room to breathe', () {
    final station = stationFor(0, 1);
    final mat = matFor(0, 1);

    expect(mat.left - station.left, greaterThan(cardOnMat.width));
  });

  test('the surface holds every station', () {
    for (final count in [1, 2, 3, 4]) {
      final surface = surfaceFor(count);
      for (var i = 0; i < count; i++) {
        final station = stationFor(i, count);
        expect(station.right, lessThanOrEqualTo(surface.width),
            reason: 'station $i of $count runs off the right');
        expect(station.bottom, lessThanOrEqualTo(surface.height),
            reason: 'station $i of $count runs off the bottom');
      }
    }
  });

  test('two stations never overlap', () {
    final stations = [for (var i = 0; i < 4; i++) stationFor(i, 4)];
    for (var i = 0; i < stations.length; i++) {
      for (var j = i + 1; j < stations.length; j++) {
        expect(stations[i].overlaps(stations[j]), isFalse,
            reason: 'station $i overlaps station $j');
      }
    }
  });
}
