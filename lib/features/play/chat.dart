import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../net/talk.dart';
import '../../table/model/table_state.dart';
import '../lobby/lobby.dart';
import 'play_controller.dart';
import 'talk_here.dart';

/// One line somebody said.
@immutable
class ChatLine {
  const ChatLine({
    required this.by,
    required this.name,
    required this.text,
    required this.at,
    required this.mine,
  });

  /// The key that said it, and the name on the chair that key is holding.
  final String by;
  final String name;

  final String text;
  final DateTime at;

  /// Whether this phone said it. Yours go on the right, everybody else's on
  /// the left, which is what every chat anybody has used does.
  final bool mine;
}

/// What has been said at this table, and how much of it you have not seen.
@immutable
class ChatRoom {
  const ChatRoom({this.lines = const [], this.unread = 0});

  /// Oldest first, so the newest is at the bottom where a chat puts it.
  final List<ChatLine> lines;

  /// How many have arrived since the chat was last open. Drawn as a number
  /// on the button, which is where every app puts it.
  final int unread;

  ChatLine? get latest => lines.isEmpty ? null : lines.last;

  ChatRoom copyWith({List<ChatLine>? lines, int? unread}) =>
      ChatRoom(lines: lines ?? this.lines, unread: unread ?? this.unread);
}

/// Everything said at this table.
///
/// Not on [TableState] on purpose. A line of chat is not a thing that
/// happened to the cards: undo must not take it back, the snapshot handed to
/// a late guest must not carry it, and the referee has no opinion about it.
/// It arrives on its own stream and lives here.
class ChatDesk extends Notifier<ChatRoom> {
  /// How much is kept. Enough to scroll back through an evening, bounded so
  /// a table left open overnight does not grow without end.
  static const keep = 200;

  StreamSubscription<Said>? _hearing;

  @override
  ChatRoom build() {
    // Follows whatever the phone talks over, which changes as a room is
    // joined or a demo table opened, and nothing else has to remember to
    // point the chat at it.
    ref.listen(talkProvider, (_, talk) => _follow(talk), fireImmediately: true);
    ref.onDispose(() => _hearing?.cancel());
    return const ChatRoom();
  }

  void _follow(Talk? talk) {
    _hearing?.cancel();
    _hearing = talk?.chatter.listen((said) {
      // The name on their chair: the lobby's where there is a lobby, the
      // table's otherwise.
      final lobby = ref.read(lobbyProvider);
      heard(
        by: said.by,
        text: said.text,
        table: ref.read(playProvider),
        me: talk.me,
        name: lobby?.nameOf(said.by),
      );
    });
  }

  /// Somebody said something. [table] is read for the name, because a key is
  /// what travels and a name is what a person reads; [name] says it outright
  /// where the caller knows better.
  void heard({
    required String by,
    required String text,
    required TableState? table,
    required String? me,
    String? name,
  }) {
    final said = text.trim();
    if (said.isEmpty) return;

    final mine = by == me;
    final line = ChatLine(
      by: by,
      name: name ?? nameOf(by, table),
      text: said,
      at: DateTime.now(),
      mine: mine,
    );

    final lines = [...state.lines, line];
    state = state.copyWith(
      lines: lines.length > keep ? lines.sublist(lines.length - keep) : lines,
      // Your own line is not news to you.
      unread: mine ? state.unread : state.unread + 1,
    );
  }

  /// The chat was opened, so none of it is unread any more.
  void seen() {
    if (state.unread != 0) state = state.copyWith(unread: 0);
  }
}

final chatProvider = NotifierProvider<ChatDesk, ChatRoom>(ChatDesk.new);

/// Whoever is sitting in the chair that key holds.
///
/// The key itself is never shown: it is sixty four characters of hex and
/// means nothing to anybody at the table. A key with no chair is somebody
/// who has not sat down, which is still worth naming as somebody.
String nameOf(String by, TableState? table) {
  final seat = table?.seats.where((s) => s.owner.peerId == by).firstOrNull;
  final name = seat?.name.trim() ?? '';
  return name.isEmpty ? 'Somebody' : name;
}
