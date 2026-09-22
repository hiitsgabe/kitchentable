import 'actions/apply.dart';
import 'actions/table_action.dart';
import 'model/table_state.dart';

/// A table being played, and the last few states it was in.
///
/// Undo is a list of whole states rather than a stack of inverse actions. It
/// costs memory and it is right: an inverse has to be derived for every verb
/// and gets subtly wrong for the ones that lose information, like shuffling a
/// pile or clearing a counter to zero.
class TableSession {
  TableSession(this._state, {this.historyLimit = 40});

  TableState _state;
  final List<TableState> _history = [];

  /// How far back undo reaches. A table left running all evening would
  /// otherwise keep every state it ever had, and each one holds every card.
  final int historyLimit;

  TableState get state => _state;
  bool get canUndo => _history.isNotEmpty;
  int get historyLength => _history.length;

  void run(TableAction action) {
    final next = apply(_state, action);
    if (identical(next, _state)) return;

    _history.add(_state);
    if (_history.length > historyLimit) _history.removeAt(0);
    _state = next;
  }

  void undo() {
    if (_history.isEmpty) return;
    _state = _history.removeLast();
  }
}
