// How the app was opened, which only a browser can answer.
//
// The same conditional export the catalog and the gunzip use. A phone build has
// no launch URL to read and says so by answering null to both, rather than by
// having the io file import a browser library that does not exist there.
//
// Ordinary comments and not doc comments: a doc comment above an export belongs
// to a library that is not declared here, which analyze calls dangling and is
// right to.
export 'launch_web.dart' if (dart.library.io) 'launch_io.dart';
