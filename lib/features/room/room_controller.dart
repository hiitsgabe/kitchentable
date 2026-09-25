import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../table/room/room.dart';
import 'launch.dart';

/// The room this device is in.
///
/// Nothing paired a code with a [RoomConfig] before this. The code is the name
/// of the place and the config is what the host set up in it, and they arrive
/// from opposite directions: the host mints the code and knows the config, and
/// somebody following a link has the code and knows nothing else yet.
@immutable
class Room {
  const Room({required this.code, required this.config, required this.hosting});

  /// Minted here, or read out of a link.
  final String code;

  /// What the host set up, and null for everybody else.
  ///
  /// Not a default standing in for it. The room's format, its chairs and what
  /// it plays to are the host's, they travel over the mesh, and there is no
  /// mesh yet: a guest that filled this in with Commander and four seats would
  /// be showing its own guess as the room's settings.
  final RoomConfig? config;

  /// Whether this device made the room.
  ///
  /// Only the host's word about the room counts, and succession in the next
  /// slice reads a stamp the host minted rather than anything a peer says about
  /// itself. This is the local half of that: what this device may claim, never
  /// what it was told.
  final bool hosting;

  /// What to call the room on screen. The host's name for it, or the code,
  /// which is all a guest has until the host says otherwise.
  String get title => config?.roomName.trim().isNotEmpty == true
      ? config!.roomName.trim()
      : code;
}

class RoomHere extends Notifier<Room?> {
  /// Already in a room when the app was opened on a link.
  ///
  /// Here and not in a screen's initState, because it is a fact about how the
  /// process started rather than a thing that happens when something is drawn,
  /// and a screen that wrote it while building would write it again on every
  /// rebuild.
  @override
  Room? build() {
    final code = ref.read(launchRoomCodeProvider);
    return code == null ? null : Room(code: code, config: null, hosting: false);
  }

  /// Makes the room. Returns the code, which is the invitation.
  String open(RoomConfig config) {
    final code = freshRoomCode();
    state = Room(code: code, config: config, hosting: true);
    return code;
  }

  /// Turns up at somebody else's room. Takes a code however it was written: a
  /// pasted link, or seven characters somebody read out.
  ///
  /// Refuses what could not have been minted rather than carrying a typo as far
  /// as the mesh and coming back with no such room.
  bool arrive(String typed) {
    final code = codeFrom(typed) ?? _bareCode(typed);
    if (code == null) return false;
    state = Room(code: code, config: null, hosting: false);
    return true;
  }

  void leave() => state = null;

  /// A code on its own, with no link around it. Lower cased first: somebody
  /// reading it out across a table does not say which case it was in.
  static String? _bareCode(String typed) {
    final code = typed.trim().toLowerCase();
    return roomCodePattern.hasMatch(code) ? code : null;
  }
}

final roomProvider = NotifierProvider<RoomHere, Room?>(RoomHere.new);

/// Whether a typed line is a room at all, for a screen that wants to dim its
/// own button before anybody presses it.
bool looksLikeRoom(String typed) =>
    codeFrom(typed) != null || RoomHere._bareCode(typed) != null;

/// The front half of the links this build hands out, or null where it has none.
///
/// A Provider and not a constant so tests can say where they are served from,
/// and so that the one place that reads the browser is the one place that is
/// replaced off the web.
final roomOriginProvider = Provider<String?>((ref) => launchOrigin());

/// The code the app was opened on, or null.
///
/// Read once and never changing: the address bar at startup is a fact about
/// this process. Watching it is therefore safe from anywhere, which matters
/// because the widget that decides the first screen has to read it while it
/// builds.
final launchRoomCodeProvider = Provider<String?>((ref) => launchRoomCode());
