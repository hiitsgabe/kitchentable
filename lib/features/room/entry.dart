import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../menu/menu_screen.dart';
import '../setup/setup_controller.dart';
import '../setup/setup_screen.dart';
import 'demo_room.dart';
import 'demo_table.dart';
import 'launch.dart';
import 'room_controller.dart';
import 'room_screen.dart';

/// What the app opens on.
///
/// A link that opens the menu is a link that did not work, so a launch carrying
/// a room code goes to that room and nowhere else. Everything else opens on the
/// menu, which is every phone launch and every plain visit to the web build.
///
/// A widget of its own rather than a conditional inside [MaterialApp.home],
/// because home is under the whole navigation stack: deciding it from something
/// that changes would swap the screen out from under whatever has been pushed
/// on top of it. What this reads never changes after startup.
class Entry extends ConsumerWidget {
  const Entry({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = launchDemoSeats();
    if (demo != null) {
      return DemoTable(
        seats: demo,
        view: launchDemoView(),
        fresh: launchDemoFresh(),
        chat: launchDemoChat(),
      );
    }
    final waiting = launchDemoRoomSeats();
    if (waiting != null) return DemoRoom(seats: waiting);

    final arriving = ref.watch(launchRoomCodeProvider);
    final done = ref.watch(setupDoneProvider);
    // Null while the flag is being read off the disk, which is a frame or
    // two. Nothing, rather than the menu: opening the menu and replacing it a
    // frame later is a flash of the wrong screen, and on a room link it is a
    // flash of the wrong screen in front of somebody who followed an
    // invitation.
    if (done == null) return const SizedBox.shrink();

    // The link is the intent and the first run is a detour, so the
    // destination is parked here and handed to the wizard to replay when it
    // ends. A link that opens the menu is a link that did not work, and a
    // link that opens the menu after five minutes of setup is worse.
    if (!done) {
      return SetupScreen(
        then: (_) => arriving == null ? const MenuScreen() : const RoomScreen(),
      );
    }

    return arriving == null ? const MenuScreen() : const RoomScreen();
  }
}
