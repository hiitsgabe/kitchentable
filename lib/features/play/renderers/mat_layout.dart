import 'dart:math' as math;
import 'dart:ui';

/// One seat's mat, in surface units. The canvas zooms, so these are not
/// pixels and do not scale with the device.
const matSize = Size(640, 380);

/// How big a card is in surface units, for both renderers.
///
/// The canvas zooms, so this is fixed and `Metrics` is deliberately not
/// consulted for it: a card must be the same size relative to the mat on a
/// phone and on a television.
///
/// One copy and not one per renderer. It was two, and the size of a card is
/// exactly the kind of number that drifts apart when it is written twice.
const cardOnMat = Size(90, 90 * 88 / 63);

/// The smallest a card on a mat may be drawn, as a share of the printed one.
///
/// A fit is not a floor, and the fit on a phone is a 50.3 point card. What that
/// costs is not the rules text, which is gone at any size a phone's mat can
/// give and is what the long press is for: it is the picture. A Magic card's
/// art box is about 86 percent of its width and 42 percent of its height, so a
/// card of 50.3 carries a picture 43 by 30 points and a card of 72 carries one
/// 62 by 42, which is twice as much of the only thing on a card you recognise
/// from across a table.
///
/// 72 and not more, and that bound is the suite's rather than the eye's. At 76
/// the floor would also win on a 700 point window, where the fit comes to 75.6,
/// and `the board is budgeted for both columns, not one` measures the row's own
/// width arithmetic at exactly that window: a floor reaching up there takes
/// that case's subject away without failing it. So the readable end of the band
/// those two leave, which is four fifths of the card the mat prints.
///
/// Final and not const, for the reason [matAside] is.
final matScaleFloor = 72 / cardOnMat.width;

/// How much bigger or smaller than a mat unit, for a box this size.
///
/// Whichever of width and height runs out first, so the whole mat fits, and
/// never below [matScaleFloor], where the mat stops fitting and the board
/// scrolls instead. An unbounded height is not a number that can run out, and
/// the smaller of anything and infinity is the anything, so a box that scrolls
/// is scaled by its width alone, which is what scrolling is for.
double matScaleFor(Size box) => math.max(
      matScaleFloor,
      math.min(
        box.width / matSize.width,
        box.height / matSize.height,
      ),
    );

/// The smallest a card on a board is drawn, in points.
///
/// What it costs to go below this is not the rules text, which is gone at any
/// size a phone can give and is what the long press is for: it is the picture.
/// A Magic card's art box is about 86 percent of its width and 42 percent of
/// its height, so a card of 50 carries a picture 43 by 30 points and a card of
/// 72 carries one 62 by 42, which is twice as much of the only thing on a card
/// you recognise from across a table.
const readableCard = 72.0;

/// How many cards across a board wide enough to afford them shows.
///
/// A phone shows five and a desktop shows nine, and the rule below is what
/// gets from one to the other without a breakpoint.
const _acrossWhenRoomy = 9;

/// How wide a card is drawn on a board this wide.
///
/// [readableCard], or a ninth of the board, whichever is bigger.
///
/// **Not a fraction of a fixed mat.** The board used to be a 640 by 380 mat
/// scaled to fit, with the card's size falling out of that scale, and the two
/// could not both be satisfied on a phone: fitting the mat gave a 50 point
/// card, and a readable card made the mat 512 points wide inside a 358 point
/// board, so the battlefield was permanently cut off and had to be panned.
/// Sizing the card on its own leaves the board free to be exactly the shape of
/// the screen, which is what a table is.
double cardWidthFor(double boardWidth) {
  final roomy = boardWidth / _acrossWhenRoomy;
  return roomy > readableCard ? roomy : readableCard;
}

/// Between mats, so two battlefields never read as one.
const matGap = 40.0;

/// Space kept clear inside a mat, and between cards laid out by flow.
const matPadding = 16.0;

/// How wide the strip beside a mat is.
///
/// A card, plus the room a pile's own count row and label need around it. The
/// corner, the deck, the graveyard and the token button all stand in one of
/// these rather than on the mat, because drawn on the mat they sit over the
/// battlefield at every zoom.
///
/// Final and not const: `Size.width` is a getter, so `cardOnMat.width` is not
/// a constant expression, and writing 90 again here is exactly the drift the
/// one copy of a card's size above is there to stop.
final matAside = cardOnMat.width + matPadding * 2;

/// A seat's whole share of the surface: the mat, and a strip on each side.
///
/// A grid and not a ring. A ring was the first idea and it is wrong for a
/// rectangle: seats land at angles where a card is either tiny or off the
/// edge, and a phone rotated into landscape makes it worse. Two across, then
/// down, and three seats leave the fourth place empty rather than squeezing.
Rect stationFor(int index, int count) {
  final columns = count <= 1 ? 1 : 2;
  final column = index % columns;
  final row = index ~/ columns;
  final width = matSize.width + matAside * 2;

  return Rect.fromLTWH(
    column * (width + matGap),
    row * (matSize.height + matGap),
    width,
    matSize.height,
  );
}

/// Where a seat's mat sits on the shared surface.
///
/// The mat inside the station, so a drop position is still normalized against
/// the same box it always was: the mat is `matSize` exactly and the strips are
/// beside it rather than taken out of it.
Rect matFor(int index, int count) {
  final station = stationFor(index, count);

  return Rect.fromLTWH(
    station.left + matAside,
    station.top,
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
    columns * (matSize.width + matAside * 2) + (columns - 1) * matGap,
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
  Size mat = matSize,
}) {
  if (position == null) return _flowSpot(index, card, mat);

  return Offset(
    clampDouble(
      position.x * mat.width - card.width / 2,
      0,
      mat.width - card.width,
    ),
    clampDouble(
      position.y * mat.height - card.height / 2,
      0,
      mat.height - card.height,
    ),
  );
}

Offset _flowSpot(int index, Size card, Size mat) {
  final perRow = math.max(
    1,
    ((mat.width - matPadding) / (card.width + matPadding)).floor(),
  );

  return Offset(
    matPadding + (index % perRow) * (card.width + matPadding),
    matPadding + (index ~/ perRow) * (card.height + matPadding),
  );
}
