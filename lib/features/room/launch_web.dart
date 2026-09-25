import 'package:web/web.dart' as web;

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
String? launchRoomCode() => codeFrom(web.window.location.href);

/// Where this build is being served from, which is the front half of every link
/// it hands out.
///
/// Origin and path, without the fragment and without the query, so a folder
/// deploy links back to the folder and not to the root of the domain.
String? launchOrigin() =>
    '${web.window.location.origin}${web.window.location.pathname}';
