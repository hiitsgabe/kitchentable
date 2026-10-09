import '../../decks/model/game.dart';

/// Nowhere to read a launch URL from.
///
/// A phone is not opened by following a link in this slice: there is no app
/// link or universal link registered, so the way in on a phone is the code,
/// typed or read off a QR. Null rather than guessed.
String? launchRoomCode() => null;

Game? launchRoomGame() => null;

/// No address bar, no demo.
int? launchDemoSeats() => null;

String? launchDemoView() => null;

bool launchDemoFresh() => false;

bool launchDemoChat() => false;

bool launchDemoVoice() => false;

bool launchDemoDraft() => false;

bool launchDemoSealed() => false;

/// No address bar, no demo.
int? launchDemoRoomSeats() => null;
