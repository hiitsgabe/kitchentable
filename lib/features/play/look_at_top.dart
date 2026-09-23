import '../../table/actions/table_action.dart';

/// Where a card you have just looked at is going.
///
/// These four cover scry, surveil, fateseal and the impulse effects that take
/// one card and bottom the rest. They are one gesture with different
/// destinations, which is why this is one sheet and not four.
enum Landing { top, bottom, graveyard, hand }

/// One card and where its owner is sending it.
typedef Placement = ({String cardId, Landing to});

/// Turns a set of choices into moves.
///
/// No new verb. `MoveCard` carries an `at`, and `Zone.add` inserts there, so
/// the top is index zero and the bottom is however long the pile is when the
/// card goes back. The moves come back as a list rather than being applied
/// here, because the caller is a controller with a session and an undo stack
/// and this is arithmetic.
///
/// [fromLibrary] is what tells the bottom where the bottom is. These cards
/// came off the top of the library by default, which is scry and surveil; the
/// graveyard sheet hands the same arithmetic cards that were never in the
/// library at all.
///
/// The top pile is emitted last to first, so that the order the player put
/// them in is the order they come off. Pushing them in reading order would
/// reverse the pile, which is the bug this comment exists to stop somebody
/// tidying back in.
List<TableAction> arrange({
  required String libraryId,
  required List<Placement> placements,
  required int librarySize,
  String? graveyardId,
  String? handId,
  bool fromLibrary = true,
}) {
  final moves = <TableAction>[];

  // How many of these have left the library for good by now. A card sent to
  // the bottom goes straight back in, so it costs nothing; one sent to a hand
  // or a graveyard does not, and every bottom after it lands in a pile that is
  // one shorter than the size we were handed.
  var gone = 0;

  for (final placement in placements) {
    switch (placement.to) {
      case Landing.bottom:
        // Minus one more when these cards came off the library itself, because
        // `_move` takes the card out before putting it back and the list it
        // inserts into is shorter again than the one that was counted. A card
        // arriving from a graveyard was never in the library, so the pile is
        // one longer when it lands and the bottom is one further down.
        moves.add(MoveCard(
          cardId: placement.cardId,
          toZoneId: libraryId,
          at: librarySize - gone - (fromLibrary ? 1 : 0),
        ));
      case Landing.graveyard:
        if (graveyardId != null) {
          moves.add(
            MoveCard(cardId: placement.cardId, toZoneId: graveyardId),
          );
          gone++;
        }
      case Landing.hand:
        if (handId != null) {
          moves.add(MoveCard(cardId: placement.cardId, toZoneId: handId));
          gone++;
        }
      case Landing.top:
        break;
    }
  }

  for (final placement in placements.reversed) {
    if (placement.to != Landing.top) continue;
    moves.add(
      MoveCard(cardId: placement.cardId, toZoneId: libraryId, at: 0),
    );
  }

  return moves;
}
