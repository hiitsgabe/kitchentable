import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'playerName';

/// What somebody who has not said is called.
///
/// The room used to ask on the way in and fall back to this when the box was
/// left empty, and the fallback is the half of that worth keeping.
const namelessPlayer = 'you';

/// The name the player put in settings, kept on the device.
///
/// A name belongs to the person and not to the room: it is the same in every
/// room they ever join, so asking again each time is asking somebody to repeat
/// themselves, and it makes two places where it can disagree.
///
/// Empty until they say otherwise, which is not the same as [namelessPlayer]:
/// the box shows a hint rather than a word somebody has to delete before typing
/// their own name.
class PlayerName extends Notifier<String> {
  @override
  String build() {
    _restore();
    return '';
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null) state = saved;
  }

  Future<void> set(String name) async {
    state = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, name);
  }
}

final playerNameProvider = NotifierProvider<PlayerName, String>(PlayerName.new);

/// The name to put on a seat, which is never empty.
///
/// Apart from what the box holds so that the fallback is decided in one place
/// rather than at every screen that needs a name to show.
final yourNameProvider = Provider<String>((ref) {
  final typed = ref.watch(playerNameProvider).trim();
  return typed.isEmpty ? namelessPlayer : typed;
});
