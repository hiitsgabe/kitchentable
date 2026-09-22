import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TableRenderer {
  /// Bands down the screen, one seat each, yours pinned at the bottom.
  stackedSeats,

  /// Every seat on a surface you pan and pinch.
  freeCanvas,
}

/// Wide enough for four seats side by side without a card becoming a smudge.
const _wideEnough = 720.0;

/// What to draw, given the room and whatever the player picked.
///
/// The choice wins in both directions. Somebody on a phone who wants the whole
/// table zoomed out is not wrong, and neither is somebody on a desktop who
/// prefers the bands.
TableRenderer rendererFor({required double width, TableRenderer? chosen}) {
  if (chosen != null) return chosen;
  return width >= _wideEnough
      ? TableRenderer.freeCanvas
      : TableRenderer.stackedSeats;
}

const _key = 'tableRenderer';

/// Null until the player picks one, which means the width decides.
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
