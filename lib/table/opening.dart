import 'model/table_state.dart';
import 'setup.dart';

/// Whether this seat is still deciding which hand to keep.
///
/// A mulligan is only a mulligan before the game starts, and nothing at this
/// table says when that is: there are no turns and no phases, on purpose. So
/// it is read off the cards, by the rule a person would use. You have started
/// playing when something is on the battlefield, when something has been
/// discarded, or when you have drawn a card you were not dealt. Until one of
/// those is true the hand in front of you is still the opening hand, whatever
/// you have done to it.
///
/// [deckSize] is how many cards the library held before the opening hand came
/// off it. Without it there is no way to tell a draw from a deal: both move a
/// card from the library to the hand and leave the two of them adding up to
/// the same number.
bool stillChoosingAHand(
  TableState table,
  String seatId, {
  required int? deckSize,
}) {
  final seat = table.seat(seatId);
  if (seat == null || deckSize == null) return false;

  // Anything out of the hand that is not back in the library means the game
  // is on. Exile is here because a card exiled from hand is a real opening
  // play in both games this app is for.
  for (final name in ['battlefield', 'graveyard', 'exile']) {
    if (table.zone('$name-$seatId')?.cards.isNotEmpty ?? false) return false;
  }

  final library = table.zone('library-$seatId');
  if (library == null) return false;

  // A mulligan puts the hand back and takes the same number out again, so the
  // library returns to exactly this. Cards put on the bottom under the London
  // rule leave it larger. Only a draw makes it smaller.
  return library.cards.length >= deckSize - openingHandSize;
}

/// How many cards have to go to the bottom before this hand is kept.
///
/// The London rule: draw seven every time and put back as many as you have
/// taken. Zero on a first hand, which is what makes the first one free.
int cardsToPutBack(TableState table, String seatId) =>
    table.seat(seatId)?.mulligans ?? 0;
