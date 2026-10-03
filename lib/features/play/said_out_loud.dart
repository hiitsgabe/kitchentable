import '../../table/actions/table_action.dart';
import 'table_news.dart';

/// The dice, by their index in the tray. The tray's own order, said here so a
/// line of news can name the die that was thrown rather than its place.
const _diceNames = ['d20', 'd12', 'd6'];

/// What a line of news reads as, or null for something not worth saying.
///
/// Only what somebody else did, and only what cannot be seen happening. A
/// card moving is already a card moving on the screen; a die landing on a
/// number is a number that was already there a moment ago, which is no event
/// at all unless somebody says so.
///
/// Deliberately a function of the news and nothing else, so what the table
/// announces can be read without a widget.
String? saidOutLoud(TableNews news, {required String? me}) {
  if (news.by == me) return null;

  return switch (news.action) {
    RollDice(:final results, :final die) => _rolled(news.name, results, die),
    _ => null,
  };
}

String? _rolled(String who, List<int> results, int? die) {
  // A peer built before the throw said which die it was. The numbers are
  // still right and still agreed; there is just nothing to name.
  if (die == null || die < 0 || die >= results.length) {
    return '$who rolled';
  }
  final named = die < _diceNames.length ? _diceNames[die] : 'a die';
  return '$who rolled ${results[die]} on the $named';
}

/// A throw somebody else made, for a tray to act out, or null.
///
/// Null for this phone's own throws: the tray that was tapped has already
/// started turning, and acting the same throw out again would restart it
/// halfway through.
({int die, int value, int turn})? announcedRoll(
  TableNews? news, {
  required String? me,
}) {
  if (news == null || news.by == me) return null;
  if (news.action case RollDice(:final results, :final die?)
      when die >= 0 && die < results.length) {
    return (die: die, value: results[die], turn: news.turn);
  }
  return null;
}
