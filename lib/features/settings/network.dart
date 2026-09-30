import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../net/webrtc_link.dart';

const _url = 'turnUrl';
const _username = 'turnUsername';
const _credential = 'turnCredential';

/// The TURN server the player brought, kept on the device, or null.
///
/// Empty by default on purpose. STUN is enough when the two networks let a
/// pair of addresses through, and a relay for the connection itself is the
/// one server that would be in the path of the game; the design ships none
/// and says why. When two phones each had the other's addresses and no
/// pair of them connected, which is what a phone on a carrier's network
/// against a home router looks like, the room says so and points here.
///
/// Three boxes and not a pasted line: a TURN entry is a URL, a name and a
/// password, and somebody copying them off a friend's screen copies three
/// things.
class TurnSetting extends Notifier<TurnServer?> {
  @override
  TurnServer? build() {
    _restore();
    return null;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    state = _server(
      prefs.getString(_url) ?? '',
      prefs.getString(_username) ?? '',
      prefs.getString(_credential) ?? '',
    );
  }

  /// Sets all three. A blank URL is no server, whatever the other two say.
  Future<void> set({
    required String url,
    required String username,
    required String credential,
  }) async {
    state = _server(url, username, credential);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_url, url.trim());
    await prefs.setString(_username, username.trim());
    await prefs.setString(_credential, credential.trim());
  }

  static TurnServer? _server(String url, String username, String credential) {
    final at = url.trim();
    if (at.isEmpty) return null;
    return TurnServer(
      url: at,
      username: username.trim(),
      credential: credential.trim(),
    );
  }
}

final turnProvider = NotifierProvider<TurnSetting, TurnServer?>(TurnSetting.new);
