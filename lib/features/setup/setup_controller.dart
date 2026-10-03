import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'setupDone';

/// Whether the first run has been got through.
///
/// A flag and not a guess at the state. "No name and no cards" looks like a
/// first run and is also what somebody who skipped every step looks like, and
/// walking them through it again every launch is the way to be hated.
///
/// Null while it is being read off the disk, which is a frame or two: the
/// screen that decides what to open waits rather than opening the menu and
/// replacing it.
class SetupDone extends Notifier<bool?> {
  @override
  bool? build() {
    _restore();
    return null;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> finish() async {
    state = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }

  /// For somebody who wants to be walked through it again, from Settings.
  Future<void> again() async {
    state = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, false);
  }
}

final setupDoneProvider = NotifierProvider<SetupDone, bool?>(SetupDone.new);
