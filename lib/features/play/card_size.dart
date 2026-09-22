import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How much bigger or smaller than the layout's own choice.
///
/// A multiplier and not a size, because the two renderers draw at different
/// sizes already and the player is adjusting both at once. One is what the
/// layout picked.
const cardScaleMin = 0.6;
const cardScaleMax = 2.0;
const _step = 0.1;
const _key = 'cardScale';

class CardScale extends Notifier<double> {
  @override
  double build() {
    _restore();
    return 1;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getDouble(_key);
    if (saved != null) state = saved.clamp(cardScaleMin, cardScaleMax);
  }

  /// One notch bigger or smaller. Notches rather than a slider because this is
  /// reachable from a D-pad, where there is nothing to drag.
  Future<void> nudge(int by) async {
    final next = (state + by * _step).clamp(cardScaleMin, cardScaleMax);
    // Floating point: ten notches of 0.1 do not land on 2.0 exactly, and the
    // test asserts the bound.
    state = double.parse(next.toStringAsFixed(2));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, state);
  }
}

final cardScaleProvider = NotifierProvider<CardScale, double>(CardScale.new);
