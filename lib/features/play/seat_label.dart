import '../../table/view/seat_view.dart';
import '../settings/player_name.dart';

/// What to call a seat on the glass.
///
/// "You" for your own, computed and never stored: a nameless player crosses
/// the wire as the default string, and printed straight that string labels
/// every empty-named seat "you", your opponents included. Yours is the one
/// [SeatView.isViewer] marks; any other shows its player's name, or its chair
/// when that player gave none. The seat rail, the board badge and the top bar
/// all read this one function, so they cannot disagree.
String seatLabel(SeatView seat, {required int chair}) {
  if (seat.isViewer) return 'You';
  final name = seat.name.trim();
  if (name.isNotEmpty && name != namelessPlayer) return name;
  return 'Player ${chair + 1}';
}
