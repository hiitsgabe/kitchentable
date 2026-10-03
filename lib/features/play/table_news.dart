import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../table/actions/table_action.dart';
import '../../table/model/table_state.dart';

/// Something somebody did, with a name on it.
///
/// The table is a state rather than a log, which is what makes undo a list
/// and a late arrival a snapshot. A state cannot say what just happened,
/// though: somebody at the other end of a call rolls a die and the number on
/// this phone changes with nothing to watch and nobody named. This is the
/// other half, and it is deliberately not kept: it is the last thing said,
/// and it goes quiet again.
///
/// [turn] rises with every announcement, so two identical rolls in a row are
/// two pieces of news. Without it a die that lands twice on the same number
/// would be announced once.
typedef TableNews = ({String by, String name, TableAction action, int turn});

/// The last thing anybody did, or null before anybody has.
class TableNewsDesk extends Notifier<TableNews?> {
  var _turn = 0;

  @override
  TableNews? build() => null;

  /// Says what a peer did. [table] is read for the name, because a key is
  /// what travels and a name is what a person reads.
  void say({
    required String by,
    required TableAction action,
    required TableState? table,
  }) {
    state = (by: by, name: _nameOf(by, table), action: action, turn: ++_turn);
  }

  /// Whoever is sitting in the chair that key holds.
  ///
  /// The key itself is never shown: it is sixty four characters of hex and
  /// means nothing to anybody at the table. A key with no chair is somebody
  /// who has not sat down, which is still worth naming as somebody.
  static String _nameOf(String by, TableState? table) {
    final seat = table?.seats.where((s) => s.owner.peerId == by).firstOrNull;
    final name = seat?.name.trim() ?? '';
    return name.isEmpty ? 'Somebody' : name;
  }
}

final tableNewsProvider = NotifierProvider<TableNewsDesk, TableNews?>(
  TableNewsDesk.new,
);
