import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../decks/model/deck_format.dart';
import '../../table/room/room.dart';
import '../../table/room/room_names.dart';
import 'room_controller.dart';
import 'room_screen.dart';

/// The host's waiting room, opened straight from a link.
///
/// For looking at the screen people wait on: a `#demoroom=N` link makes a
/// room of N chairs and shows it, with no card source, no deck and nobody
/// else, which is exactly the state a host sits in between making the room
/// and the first friend arriving. The companion of `#demo=N` for the table.
class DemoRoom extends ConsumerStatefulWidget {
  const DemoRoom({super.key, required this.seats});

  final int seats;

  @override
  ConsumerState<DemoRoom> createState() => _DemoRoomState();
}

class _DemoRoomState extends ConsumerState<DemoRoom> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(roomProvider.notifier)
          .open(
            RoomConfig(
              format: DeckFormat.commander,
              seats: roomSeatChoices.contains(widget.seats)
                  ? widget.seats
                  : roomSeatChoices.first,
              hostName: 'you',
              roomName: freshRoomName(),
            ),
          );
    });
  }

  @override
  Widget build(BuildContext context) =>
      ref.watch(roomProvider) == null ? const SizedBox() : const RoomScreen();
}
