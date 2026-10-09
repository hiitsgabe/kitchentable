import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../net/mesh.dart';
import '../../net/talk.dart';
import '../lobby/lobby.dart';

/// The mesh this phone's table runs on, kept here for the chat and the
/// microphones where there is no lobby to talk through: a demo table, or a
/// game on one device. Set by the play controller as it follows a mesh.
class MeshTalk extends Notifier<Mesh?> {
  @override
  Mesh? build() => null;

  void set(Mesh? mesh) => state = mesh;
}

final meshTalkProvider = NotifierProvider<MeshTalk, Mesh?>(MeshTalk.new);

/// What this phone talks over, or null alone.
///
/// The room's own channel wherever there is a room: it is there from the
/// first chair, through the draft and at the table, and it reaches the whole
/// room rather than the one game this phone is at. The mesh only where there
/// is no room at all.
final talkProvider = Provider<Talk?>(
  (ref) => ref.watch(lobbyProvider)?.talk ?? ref.watch(meshTalkProvider),
);
