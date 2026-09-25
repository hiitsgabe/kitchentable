import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../menu/menu_screen.dart';
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
    final arriving = ref.watch(launchRoomCodeProvider);
    return arriving == null ? const MenuScreen() : const RoomScreen();
  }
}
