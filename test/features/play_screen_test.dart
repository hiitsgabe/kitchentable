import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/decks/model/deck.dart';
import 'package:kitchentable/decks/model/deck_format.dart';
import 'package:kitchentable/features/play/play_controller.dart';
import 'package:kitchentable/features/menu/menu_controller.dart';
import 'package:kitchentable/features/play/play_screen.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';

CatalogCard _card(String name) => CatalogCard(
      oracleId: name,
      name: name,
      typeLine: 'Instant',
      cmc: 1,
    );

Deck _deck() => Deck(
      id: 'd1',
      name: 'a deck',
      format: DeckFormat.commander,
      slots: [DeckSlot(card: _card('Mountain'), quantity: 60)],
    );

Future<ProviderContainer> _seated(WidgetTester tester) async {
  final container = ProviderContainer(
    overrides: [catalogDbProvider.overrideWithValue(null)],
  );
  addTearDown(container.dispose);
  container.read(playProvider.notifier).start(_deck(), seed: 'abc');

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: PlayScreen()),
    ),
  );
  await tester.pump();
  return container;
}

void main() {
  testWidgets('an empty table says so instead of drawing nothing',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [catalogDbProvider.overrideWithValue(null)],
        child: const MaterialApp(home: PlayScreen()),
      ),
    );
    await tester.pump();

    expect(find.textContaining('No table'), findsOneWidget);
  });

  testWidgets('a seated table shows life and the pile counts', (tester) async {
    await _seated(tester);

    expect(find.text('40'), findsOneWidget);
    expect(find.textContaining('53'), findsWidgets,
        reason: 'the library has 53 left after a hand of seven');
  });

  testWidgets('drawing takes one off the library and adds one to the hand',
      (tester) async {
    final container = await _seated(tester);

    await tester.tap(find.byKey(const Key('draw')));
    await tester.pump();

    expect(container.read(playProvider)!.zone('library-s1')!.size, 52);
    expect(container.read(playProvider)!.zone('hand-s1')!.size, 8);
  });

  testWidgets('undo is offered only once there is something to undo',
      (tester) async {
    final container = await _seated(tester);

    expect(container.read(playProvider.notifier).canUndo, isFalse);

    await tester.tap(find.byKey(const Key('draw')));
    await tester.pump();

    expect(container.read(playProvider.notifier).canUndo, isTrue);
  });

  testWidgets('life goes down and back up', (tester) async {
    final container = await _seated(tester);

    await tester.tap(find.byKey(const Key('life-down')));
    await tester.pump();

    expect(container.read(playProvider)!.seat('s1')!.life, 39);
  });
}
