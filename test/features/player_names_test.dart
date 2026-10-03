import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/settings/player_name.dart';
import 'package:kitchentable/features/settings/player_names.dart';
import 'package:kitchentable/ui/background/backdrop_style.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a device that has never been named names itself', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(playerNameProvider);
    await Future<void>.delayed(Duration.zero);

    // Not "you". Four chairs all reading "you" is what this removes.
    final name = container.read(playerNameProvider);
    expect(name, isNotEmpty);
    expect(name, isNot(namelessPlayer));
    expect(playerNames, contains(name));
    expect(container.read(yourNameProvider), name);
  });

  test('the name it picked is the name it keeps', () async {
    final first = ProviderContainer();
    first.read(playerNameProvider);
    await Future<void>.delayed(Duration.zero);
    final name = first.read(playerNameProvider);
    first.dispose();

    final second = ProviderContainer();
    addTearDown(second.dispose);
    second.read(playerNameProvider);
    await Future<void>.delayed(Duration.zero);

    expect(second.read(playerNameProvider), name,
        reason: 'a name that changed every launch is a different person '
            'every evening');
  });

  test('a name somebody typed is never replaced', () async {
    SharedPreferences.setMockInitialValues({'playerName': 'kit'});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(playerNameProvider);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(playerNameProvider), 'kit');
  });

  test('the names are short enough for a chair, and all different', () {
    expect(playerNames, hasLength(playerNames.toSet().length));
    for (final name in playerNames) {
      expect(name.length, lessThanOrEqualTo(9), reason: name);
      expect(name.trim(), name, reason: name);
    }
  });

  test('a table opens on the swirling paint', () {
    // The default, and the one the app is drawn over unless somebody says
    // otherwise.
    expect(const BackdropStyle().kind, BackdropKind.paint);
    expect(BackdropKind.paint.animated, isTrue);
  });
}
