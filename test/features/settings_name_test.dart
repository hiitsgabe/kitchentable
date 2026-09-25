import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/settings/player_name.dart';
import 'package:kitchentable/features/settings/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SettingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('nobody has said who they are, so they are you', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Empty and not `you`. The box shows a hint rather than a word somebody
    // has to delete before typing their own name, and the fallback is what
    // anything needing a name reads instead.
    expect(container.read(playerNameProvider), isEmpty);
    expect(container.read(yourNameProvider), namelessPlayer);
  });

  test('a name of nothing but spaces is still nobody', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(playerNameProvider.notifier).set('   ');

    expect(container.read(yourNameProvider), namelessPlayer);
  });

  testWidgets('your name is in settings, where the rest of you is',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await _pump(tester, container);

    await tester.enterText(find.byKey(const Key('player-name')), 'kit');
    await tester.pumpAndSettle();

    expect(container.read(yourNameProvider), 'kit');
  });

  testWidgets('the box opens holding the name already set', (tester) async {
    // The provider restores from the disk a turn after it is first read, so a
    // screen that filled its box once in initState would show an empty box
    // over a stored name and invite somebody to type it again.
    SharedPreferences.setMockInitialValues({'playerName': 'kit'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await _pump(tester, container);

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'kit',
    );
  });

  test('it is remembered', () async {
    final first = ProviderContainer();
    await first.read(playerNameProvider.notifier).set('kit');
    first.dispose();

    final second = ProviderContainer();
    addTearDown(second.dispose);
    // Riverpod builds lazily and the read is async, so the provider has to be
    // touched and then given a turn before it can have restored anything.
    second.read(playerNameProvider);
    await Future<void>.delayed(Duration.zero);

    expect(second.read(playerNameProvider), 'kit');
    expect(second.read(yourNameProvider), 'kit');
  });
}
