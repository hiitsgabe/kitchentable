import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mat_layout.dart';

enum TableRenderer {
  /// Bands down the screen, one seat each, yours pinned at the bottom.
  stackedSeats,

  /// Every seat on a surface you pan and pinch.
  freeCanvas,
}

/// Wide enough for four seats side by side without a card becoming a smudge.
const _wideEnough = 720.0;

/// Tall enough to stand a seat's mat in, once the screen has taken what it
/// keeps whichever renderer is drawing.
///
/// Derived and not chosen. `FreeCanvas` fits the whole surface into its
/// viewport with a [matGap] of room off each axis, so a viewport shorter than
/// [matSize] plus that gap is already drawing a seat's mat below the size
/// `mat_layout` prints it at, and the strips beside it and the cards on it are
/// all fractions of the mat: 420 points.
///
/// The window is not the viewport. The screen keeps its top bar, its hand and
/// its hints whichever renderer draws the table, and on a 390 by 844 phone
/// those are 88, 117 and 51 points of the 844, measured. 256 of chrome and 420
/// of mat is 676, which a phone held either way round is under and a tablet
/// held either way round is over.
///
/// Final and not const: `Size.height` is a getter, so `matSize.height` is not a
/// constant expression, which is the same reason `matAside` is final beside the
/// mat it is measured off.
final _tallEnough = matSize.height + matGap + 256;

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
TableRenderer rendererFor({
  required double width,
  required double height,
  TableRenderer? chosen,
}) {
  if (chosen != null) return chosen;
  return width >= _wideEnough && height >= _tallEnough
      ? TableRenderer.freeCanvas
      : TableRenderer.stackedSeats;
}

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
