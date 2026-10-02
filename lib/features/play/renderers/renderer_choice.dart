import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';


enum TableRenderer {
  /// The table divided equally among the seats, each board filling its share.
  /// The default: no board floats in an empty margin.
  grid,

  /// Bands down the screen, one seat each, yours pinned at the bottom.
  stackedSeats,

  /// Every seat on a surface you pan and pinch.
  freeCanvas,
}

/// What to draw, given the room and whatever the player picked.
///
/// Both directions and not the width alone. A phone held sideways is 844 wide
/// and clears the cut above, and what the canvas would hand it is a seat's
/// station: two strips of [matAside] either side of the mat, 28 percent of the
/// width before a card is drawn, and a 380 unit mat to stand in 390 points less
/// the chrome. The question the width asks on its own is "is this wide", and
/// the question it means is "is there room".
///
/// The choice wins in both directions. Somebody on a phone who wants the whole
/// table zoomed out is not wrong, and neither is somebody on a desktop who
/// prefers the bands.
TableRenderer rendererFor({TableRenderer? chosen}) =>
    // The divided view fills the screen on any size and is the one the table
    // opens on; the others are there for a player who switches to them.
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
    if (raw == null) return;
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

final rendererChoiceProvider =
    NotifierProvider<RendererChoice, TableRenderer?>(RendererChoice.new);
