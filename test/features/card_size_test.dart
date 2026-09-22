import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/card_size.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a table starts at the size the layout chose', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(cardScaleProvider), 1.0);
  });

  test('the player can make them bigger and smaller', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(cardScaleProvider.notifier).nudge(1);
    expect(container.read(cardScaleProvider), greaterThan(1.0));

    await container.read(cardScaleProvider.notifier).nudge(-1);
    expect(container.read(cardScaleProvider), 1.0);
  });

  test('it stops before a card is a dot or fills the screen', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final size = container.read(cardScaleProvider.notifier);

    for (var i = 0; i < 40; i++) {
      await size.nudge(1);
    }
    expect(container.read(cardScaleProvider), cardScaleMax);

    for (var i = 0; i < 80; i++) {
      await size.nudge(-1);
    }
    expect(container.read(cardScaleProvider), cardScaleMin);
  });

  test('it is remembered', () async {
    final first = ProviderContainer();
    await first.read(cardScaleProvider.notifier).nudge(1);
    final chosen = first.read(cardScaleProvider);
    first.dispose();

    final second = ProviderContainer();
    addTearDown(second.dispose);
    // Riverpod builds lazily and the read is async, so the provider has to be
    // touched and then given a turn before it can have restored anything.
    second.read(cardScaleProvider);
    await Future<void>.delayed(Duration.zero);

    expect(second.read(cardScaleProvider), chosen);
  });
}
