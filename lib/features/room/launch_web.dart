import 'package:web/web.dart' as web;

import '../../decks/model/game.dart';
import '../../table/room/room.dart';

/// The code the tab was opened on, out of the address bar's fragment.
///
/// Read once, at startup, by the provider that wraps this. The fragment is
/// never sent to whoever serves the page, so this is the only copy of the code
/// there is, and it is already in the hands of the person who followed the
/// link.
///
/// Null covers both a plain visit and a fragment that is not a room: `codeFrom`
/// refuses anything that could not have been minted, so a mistyped link opens
/// the menu rather than a room that was never there.
String? launchRoomCode() => codeFrom(_launchHref);

/// The game the link said its room plays, if it said. See [gameFrom].
Game? launchRoomGame() => gameFrom(_launchHref);

/// The address the tab opened on, kept from the first time anything asks.
///
/// Flutter's router rewrites the address once the first frame is up and the
/// fragment goes with it, so a reader that comes a frame later (after a
/// flag has been read off the disk, say) would find nothing there. The two
/// readers above have to agree on one address, and this is it.
String? _href;
String get _launchHref => _href ??= web.window.location.href;

/// How many seats a `#demo=N` launch asks for, or null. A dealt table on one
/// device with sample decks, so the table can be looked at and screenshotted
/// without a room, a deck import, or a second phone. Web only: it is a
/// development door and a phone build has no address bar to open it from.
int? launchDemoSeats() {
  final match = RegExp(r'#demo=(\d)').firstMatch(web.window.location.href);
  return match == null ? null : int.tryParse(match.group(1)!);
}

/// The `view=` of a demo link: grid, focus or split. Null for the default.
String? launchDemoView() =>
    RegExp(r'view=(\w+)').firstMatch(web.window.location.href)?.group(1);

/// Whether a `#demo=N` launch should stop at the opening hand.
///
/// The demo puts four cards out on every battlefield so the boards are not
/// empty, which is right for looking at a layout and wrong for looking at
/// everything a game starts with: a card on the battlefield is exactly what
/// tells the table the opening is over.
bool launchDemoFresh() => RegExp(r'fresh=1').hasMatch(web.window.location.href);

/// Whether a `#demo=N` launch should put a few lines in the chat.
///
/// Chat only appears when there is somebody to talk to, and a demo table is
/// several seats on one device with nobody at the other end of anything.
/// This seeds a conversation so the drawer can be looked at.
bool launchDemoChat() => RegExp(r'chat=1').hasMatch(web.window.location.href);

/// Whether a `#demo=N` launch should pretend the host turned voice on.
bool launchDemoVoice() => RegExp(r'voice=1').hasMatch(web.window.location.href);

/// Whether a `#demodraft` launch should open the draft on one device: a
/// scripted pod with a bot in the other seat, so the pack crack, the picking
/// and the pool builder can be looked at without a room or a catalog.
bool launchDemoDraft() =>
    RegExp(r'#demodraft').hasMatch(web.window.location.href);

/// Whether that demo draft is a sealed pool rather than a passing draft.
bool launchDemoSealed() =>
    RegExp(r'sealed=1').hasMatch(web.window.location.href);

/// How many chairs a `#demoroom=N` launch sets up, or null. The host's
/// waiting room, opened without a card source, so the screen people wait on
/// can be looked at and screenshotted the way `#demo=N` does the table.
int? launchDemoRoomSeats() {
  final match = RegExp(r'demoroom=(\d)').firstMatch(web.window.location.href);
  return match == null ? null : int.tryParse(match.group(1)!);
}
