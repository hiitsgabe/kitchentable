import 'dart:ui' show PlatformDispatcher;

/// The `kitchentable://join?room=...` link Android opened the app on.
///
/// The web build at /play/ opens that link when a room link is followed on a
/// phone with the app installed, and Android hands it to Flutter as the
/// initial route, `/?room=abcd-efg&game=magic`; `codeFrom` finds the room in
/// it the way it does in a web link. Any other launch has the route `/`. iOS
/// hands its links over once the app is running instead; see
/// `RoomLinks` in app.dart.
String? launchLink() => PlatformDispatcher.instance.defaultRouteName;

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
