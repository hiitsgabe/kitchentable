import 'dart:math' as math;
import 'dart:ui';

/// One seat's mat, in surface units. The canvas zooms, so these are not
/// pixels and do not scale with the device.
const matSize = Size(640, 380);

/// Between mats, so two battlefields never read as one.
const matGap = 40.0;

/// Space kept clear inside a mat, and between cards laid out by flow.
const matPadding = 16.0;

/// Where a seat's mat sits on the shared surface.
///
/// A grid and not a ring. A ring was the first idea and it is wrong for a
/// rectangle: seats land at angles where a card is either tiny or off the
/// edge, and a phone rotated into landscape makes it worse. Two across, then
/// down, and three seats leave the fourth place empty rather than squeezing.
Rect matFor(int index, int count) {
  final columns = count <= 1 ? 1 : 2;
  final column = index % columns;
  final row = index ~/ columns;

  return Rect.fromLTWH(
    column * (matSize.width + matGap),
    row * (matSize.height + matGap),
    matSize.width,
    matSize.height,
  );
}

/// Which seat goes in which mat, so yours is the one nearest your hand.
///
/// The hand sits under the canvas, so nearest is last. The rest keep going
/// round the table from the seat after yours, which is the order priority
/// passes in, so the arrangement on screen matches the one people say out
/// loud.
///
/// Returns positions into the seat list, not seat ids.
List<int> seatOrder({required int count, required int? viewerAt}) {
  if (viewerAt == null || viewerAt < 0 || viewerAt >= count) {
    return [for (var i = 0; i < count; i++) i];
  }
  return [
    for (var i = 1; i <= count; i++) (viewerAt + i) % count,
  ];
}

/// How big the whole surface is, so the viewer knows what it is panning over.
Size surfaceFor(int count) {
  final seats = math.max(1, count);
  final columns = seats <= 1 ? 1 : 2;
  final rows = (seats / columns).ceil();

  return Size(
    columns * matSize.width + (columns - 1) * matGap,
    rows * matSize.height + (rows - 1) * matGap,
  );
}

/// Where a card sits inside its own mat.
///
/// A card carrying an `x,y` is centred on it, normalized against the mat and
/// not against the screen, which is what lets both renderers show the same
/// arrangement. A card without one falls into a slot that depends on the index
/// and on nothing else, because cards must not jump around when one of them
/// is turned.
Offset spotFor({
  required ({double x, double y})? position,
  required int index,
  required Size card,
}) {
  if (position == null) return _flowSpot(index, card);

  return Offset(
    clampDouble(
      position.x * matSize.width - card.width / 2,
      0,
      matSize.width - card.width,
    ),
    clampDouble(
      position.y * matSize.height - card.height / 2,
      0,
      matSize.height - card.height,
    ),
  );
}

Offset _flowSpot(int index, Size card) {
  final perRow = math.max(
    1,
    ((matSize.width - matPadding) / (card.width + matPadding)).floor(),
  );

  return Offset(
    matPadding + (index % perRow) * (card.width + matPadding),
    matPadding + (index ~/ perRow) * (card.height + matPadding),
  );
}
