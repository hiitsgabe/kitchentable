import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The three ways of putting the table on the screen. Each one fills it.
enum TableRenderer {
  /// Everyone at once, each board filling its share. The default.
  grid,

  /// One board at a time, the whole area; swipe or pick to change.
  focus,

  /// Two boards: yours and one other.
  split;

  TableRenderer get next => switch (this) {
    TableRenderer.grid => TableRenderer.focus,
    TableRenderer.focus => TableRenderer.split,
    TableRenderer.split => TableRenderer.grid,
  };
}

/// What to draw: the player's pick, or the grid, which fills the screen on
/// any size and is what a table opens on.
TableRenderer rendererFor({TableRenderer? chosen}) =>
    chosen ?? TableRenderer.grid;

const _key = 'tableRenderer';

/// Null until the player picks one, which means the room decides.
class RendererChoice extends Notifier<TableRenderer?> {
  @override
  TableRenderer? build() {
    _restore();
    return null;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    // Only if nobody has chosen in the meantime. A choice made in the same
    // frame as the first read used to be overwritten by what the disk said
    // a moment later, which turned every view a demo link asked for back
    // into the previous one.
    if (raw == null || state != null) return;
    state = TableRenderer.values.where((r) => r.name == raw).firstOrNull;
  }

  Future<void> choose(TableRenderer? renderer) async {
    state = renderer;
    final prefs = await SharedPreferences.getInstance();
    if (renderer == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, renderer.name);
    }
  }
}

final rendererChoiceProvider = NotifierProvider<RendererChoice, TableRenderer?>(
  RendererChoice.new,
);

/// Which other seat the player is looking at: the page Focus is on, or the
/// second board of a Split. Null means the view's own default (yours in
/// Focus, the first other in Split). Not the viewer seat, which is the one
/// this device acts for and does not change by looking.
class WatchedSeat extends Notifier<String?> {
  @override
  String? build() => null;

  @override
  set state(String? seatId) => super.state = seatId;
}

final watchedSeatProvider = NotifierProvider<WatchedSeat, String?>(
  WatchedSeat.new,
);
