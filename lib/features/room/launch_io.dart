/// Nowhere to read a launch URL from.
///
/// A phone is not opened by following a link in this slice: there is no app
/// link or universal link registered, so the way in on a phone is the code,
/// typed or read off a QR. Both answers are null rather than guessed, and the
/// room screen is what tells the player there is no link to hand out.
String? launchRoomCode() => null;

/// Null and not a URL of our own invention. The link says which room and never
/// which machine, so its front half is wherever the web build is served, and a
/// build that is not served anywhere has no front half to offer.
String? launchOrigin() => null;
