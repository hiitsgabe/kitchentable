import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../table/actions/table_action.dart';
import '../../table/model/table_state.dart';
import 'chat.dart';

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
    state = (by: by, name: nameOf(by, table), action: action, turn: ++_turn);
  }
}

final tableNewsProvider = NotifierProvider<TableNewsDesk, TableNews?>(
  TableNewsDesk.new,
);
