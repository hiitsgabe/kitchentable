import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backdrop_style.dart';

const _key = 'backdrop';

/// The backdrop the player picked, kept on the device.
///
/// It starts at the default and is replaced once the stored one has been read,
/// rather than holding the whole app on a loading spinner for a preference.
/// The first frame shows the default, which is what most people have anyway.
class BackdropController extends Notifier<BackdropStyle> {
  @override
  BackdropStyle build() {
    _restore();
    return const BackdropStyle();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      state = BackdropStyle.fromJson(
        jsonDecode(raw) as Map<String, Object?>,
      );
    } catch (_) {
      // A preference that will not parse is a preference from an older build.
      // Falling back to the default beats refusing to start.
    }
  }

  Future<void> set(BackdropStyle style) async {
    state = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(style.toJson()));
  }
}

final backdropProvider =
    NotifierProvider<BackdropController, BackdropStyle>(BackdropController.new);
