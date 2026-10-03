// Picking a picture off the device, which only the platform can do.
//
// The same conditional export the catalog, the gunzip and the launch URL use.
// A browser has a file input and no file system; a phone build has a file
// system and no file input, and needs a plugin this app does not carry yet,
// so it says so rather than offering a button that does nothing.
export 'pick_image_web.dart' if (dart.library.io) 'pick_image_io.dart';
