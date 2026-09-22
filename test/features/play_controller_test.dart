import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/decks/model/deck.dart';
import 'package:kitchentable/decks/model/deck_format.dart';
import 'package:kitchentable/features/play/play_controller.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';
import 'package:kitchentable/table/actions/table_action.dart';
import 'package:kitchentable/table/model/table_state.dart';
import 'package:kitchentable/table/referee/referee.dart';

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

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  PlayController controller() => container.read(playProvider.notifier);

  test('nothing is on the table until a deck is brought to it', () {
    expect(container.read(playProvider), isNull);
  });

  test('starting seats you with a hand', () {
    controller().start(_deck(), seed: 'abc');

    final table = container.read(playProvider)!;
    expect(table.zone('hand-s1')!.size, 7);
    expect(table.zone('library-s1')!.size, 53);
  });

  test('an action moves the table on', () {
    controller().start(_deck(), seed: 'abc');
    final card = container.read(playProvider)!.zone('hand-s1')!.cards.first;

    controller().run(MoveCard(cardId: card.id, toZoneId: 'battlefield-s1'));

    expect(container.read(playProvider)!.zone('battlefield-s1')!.size, 1);
    expect(container.read(playProvider)!.zone('hand-s1')!.size, 6);
  });

  test('undo puts it back', () {
    controller().start(_deck(), seed: 'abc');
    controller().run(const ChangeLife(seatId: 's1', by: -5));

    expect(container.read(playProvider)!.seat('s1')!.life, 35);

    controller().undo();

    expect(container.read(playProvider)!.seat('s1')!.life, 40);
  });

  test('a refused action does not move the table, and says why', () {
    controller().start(_deck(), seed: 'abc');
    controller().useReferee(const _GrumpyReferee());

    controller().run(const ChangeLife(seatId: 's1', by: -5));

    expect(container.read(playProvider)!.seat('s1')!.life, 40);
    expect(controller().lastRefusal?.reason, 'no');
  });

  test('leaving the table clears it', () {
    controller().start(_deck(), seed: 'abc');
    controller().leave();

    expect(container.read(playProvider), isNull);
  });
}

class _GrumpyReferee implements Referee {
  const _GrumpyReferee();

  @override
  Refusal? review(TableState table, TableAction action) => const Refusal('no');

  @override
  List<String>? legalTargets(TableState table, String cardId) => null;
}
