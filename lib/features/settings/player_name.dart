import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'player_names.dart';

const _key = 'playerName';

/// The last resort, for a seat whose name never arrived.
///
/// It used to be what everybody was called, which on four chairs reads "you",
/// "you", "you", "you". A device is given a name of its own the first time it
/// is opened now, so this shows for a peer whose name has not crossed yet.
const namelessPlayer = 'you';

/// The name the player put in settings, kept on the device.
///
/// A name belongs to the person and not to the room: it is the same in every
/// room they ever join, so asking again each time is asking somebody to repeat
/// themselves, and it makes two places where it can disagree.
///
/// A device that has never been given one mints itself a name rather than
/// opening an empty box: nobody should have to think of a name before they
/// can play, and "you" on every chair is what the alternative looked like.
/// Minted once and stored, so it is the same name tomorrow.
class PlayerName extends Notifier<String> {
  @override
  String build() {
    _restore();
    return '';
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null && saved.isNotEmpty) {
      state = saved;
      return;
    }
    // Never named, so it names itself. Stored straight away: a name that
    // changed on every launch would be a different person each evening.
    final fresh = freshPlayerName();
    state = fresh;
    await prefs.setString(_key, fresh);
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
