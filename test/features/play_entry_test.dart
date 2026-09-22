import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/decks/deck_repository.dart';
import 'package:kitchentable/decks/model/deck.dart';
import 'package:kitchentable/decks/model/deck_format.dart';
import 'package:kitchentable/features/decks/decks_controller.dart';
import 'package:kitchentable/features/decks/play_decks_screen.dart';
import 'package:kitchentable/features/menu/menu_controller.dart';
import 'package:kitchentable/features/play/play_controller.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';

Deck _deck(String id) => Deck(
      id: id,
      name: 'deck $id',
      format: DeckFormat.commander,
      slots: [
        DeckSlot(
          card: const CatalogCard(
            oracleId: 'mountain',
            name: 'Mountain',
            typeLine: 'Basic Land - Mountain',
            cmc: 0,
          ),
          quantity: 60,
        ),
      ],
    );

/// The Play list with decks in it and no database underneath.
///
/// The screen reads the list without cards and loads a deck's cards only when
/// it deals, so the stand in has to answer both, and the rows it lists carry a
/// count rather than slots for exactly that reason.
class _Shelf implements DeckRepository {
  _Shelf(this.full);

  final List<Deck> full;

  @override
  Future<List<Deck>> list() async => [
        for (final deck in full)
          Deck(
            id: deck.id,
            name: deck.name,
            format: deck.format,
            knownCardCount: deck.cardCount,
          ),
      ];

  @override
  Future<Deck?> load(String id) async =>
      full.where((d) => d.id == id).firstOrNull;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<ProviderContainer> _listed(WidgetTester tester) async {
  final container = ProviderContainer(
    overrides: [
      // Null keeps the play screen this pushes from going to disk for its
      // printings. The deck list never reads the database directly.
      catalogDbProvider.overrideWithValue(null),
      deckRepositoryProvider.overrideWithValue(_Shelf([_deck('d1')])),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: PlayDecksScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  test('Play says it deals, which is what it does', () {
    const state = MenuState(cardCount: 36079, enabledSources: 1);
    final play = state.entries.firstWhere((e) => e.id == MenuEntryId.play);

    expect(play.subtitle, contains('deals'));
    expect(play.enabled, isTrue,
        reason: 'a table starts from a deck, and this is the door that deals');
  });

  test('it waits for a source first', () {
    const state = MenuState(cardCount: 0, enabledSources: 0);
    final play = state.entries.firstWhere((e) => e.id == MenuEntryId.play);

    expect(play.enabled, isFalse);
    expect(play.subtitle, 'needs a source');
  });

  testWidgets('tapping a deck still deals straight away', (tester) async {
    final container = await _listed(tester);

    await tester.tap(find.byKey(const Key('deck-row-0')));
    await tester.pumpAndSettle();

    // Plan 1 asked for a deck row that deals on a single press, and the seat
    // toggle is not allowed to put a step in front of that.
    expect(container.read(playProvider)!.seats, hasLength(1));
  });

  testWidgets('dealing several decks seats several people', (tester) async {
    final container = await _listed(tester);

    await tester.tap(find.byKey(const Key('add-seat')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('deck-row-0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('deck-row-0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('deal')));
    await tester.pumpAndSettle();

    final table = container.read(playProvider);
    expect(table!.seats, hasLength(2));
    expect(table.seats.every((s) => s.owner.actableHere), isTrue,
        reason: 'a pod on one device holds every chair itself');
  });
}
