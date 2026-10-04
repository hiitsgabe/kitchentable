import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/settings/network.dart';
import 'package:kitchentable/features/settings/network_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: NetworkScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('nobody brought a TURN server, so there is none', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(turnProvider), isNull);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(turnProvider), isNull, reason: 'restored nothing');
  });

  test('a blank URL is no server, whatever the name and password say', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final turn = container.read(turnProvider.notifier);
    turn.set(url: '  ', username: 'kit', credential: 'hunter2');
    expect(container.read(turnProvider), isNull);

    turn.set(
      url: ' turn:turn.example.net:3478 ',
      username: 'kit ',
      credential: ' hunter2',
    );
    final server = container.read(turnProvider)!;
    expect(server.url, 'turn:turn.example.net:3478');
    expect(server.username, 'kit');
    expect(server.credential, 'hunter2');
  });

  testWidgets('the three boxes on the network screen set it', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await _pump(tester, container);

    await tester.enterText(
      find.byKey(const Key('turn-url')),
      'turn:turn.example.net:3478',
    );
    await tester.enterText(find.byKey(const Key('turn-username')), 'kit');
    await tester.enterText(find.byKey(const Key('turn-credential')), 'hunter2');
    await tester.pumpAndSettle();

    final server = container.read(turnProvider)!;
    expect(server.url, 'turn:turn.example.net:3478');
    expect(server.username, 'kit');
    expect(server.credential, 'hunter2');
  });

  testWidgets('the boxes open holding the server already set', (tester) async {
    SharedPreferences.setMockInitialValues({
      'turnUrl': 'turn:turn.example.net:3478',
      'turnUsername': 'kit',
      'turnCredential': 'hunter2',
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await _pump(tester, container);

    String text(String key) => tester
        .widget<TextField>(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(TextField),
          ),
        )
        .controller!
        .text;
    expect(text('turn-url'), 'turn:turn.example.net:3478');
    expect(text('turn-username'), 'kit');
    expect(text('turn-credential'), 'hunter2');
  });

  test('it is remembered', () async {
    final first = ProviderContainer();
    await first
        .read(turnProvider.notifier)
        .set(
          url: 'turn:turn.example.net:3478',
          username: 'kit',
          credential: 'hunter2',
        );
    first.dispose();

    final second = ProviderContainer();
    addTearDown(second.dispose);
    second.read(turnProvider);
    await Future<void>.delayed(Duration.zero);

    final server = second.read(turnProvider)!;
    expect(server.url, 'turn:turn.example.net:3478');
    expect(server.username, 'kit');
    expect(server.credential, 'hunter2');
  });
}
