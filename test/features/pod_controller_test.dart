import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/decks/model/deck.dart';
import 'package:kitchentable/decks/model/deck_format.dart';
import 'package:kitchentable/features/play/play_controller.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';
import 'package:kitchentable/table/model/seat_owner.dart';
import 'package:kitchentable/table/setup.dart';

CatalogCard _card(String name) =>
    CatalogCard(oracleId: name, name: name, typeLine: 'Instant', cmc: 1);

Deck _deck(String name) => Deck(
      id: name,
      name: name,
      format: DeckFormat.commander,
      slots: [DeckSlot(card: _card('$name-card'), quantity: 60)],
    );

Player _here(String name) =>
    (deck: _deck(name), name: name, owner: const SeatOwner.here());

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  PlayController controller() => container.read(playProvider.notifier);
  ViewerSeat viewer() => container.read(viewerSeatProvider.notifier);

  test('nobody is looking before a table opens', () {
    expect(container.read(viewerSeatProvider), isNull);
  });

  test('a pod seats everybody and you are looking first', () {
    controller().startPod(
      players: [_here('you'), _here('Carla'), _here('Diego')],
      seed: 'abc',
    );

    expect(container.read(playProvider)!.seats, hasLength(3));
    expect(container.read(viewerSeatProvider), 's1');
  });

  test('one deck goes through the same door', () {
    controller().start(_deck('solo'), seed: 'abc');

    final table = container.read(playProvider)!;
    expect(table.seats, hasLength(1));
    expect(table.zone('hand-s1')!.size, 7);
    // Solo is not a mode. It is the case where nobody else has joined, so the
    // one seat is held here exactly like the other three would be.
    expect(table.seats.single.owner.actableHere, isTrue);
    expect(container.read(viewerSeatProvider), 's1');
  });

  test('looking through another local seat moves the viewer', () {
    controller().startPod(players: [_here('you'), _here('Carla')], seed: 'abc');

    expect(viewer().look('s2'), isTrue);
    expect(container.read(viewerSeatProvider), 's2');
  });

  test('looking through a seat this device does not hold is refused', () {
    controller().startPod(
      players: [
        _here('you'),
        (deck: _deck('far'), name: 'Bruno', owner: const SeatOwner.peer('p1')),
      ],
      seed: 'abc',
    );

    // The one rule that makes hidden information mean anything on a device
    // holding several seats: you may only look out of a chair you are in.
    expect(viewer().look('s2'), isFalse);
    expect(container.read(viewerSeatProvider), 's1');
  });

  test('looking at a seat that is not there is refused', () {
    controller().startPod(players: [_here('you')], seed: 'abc');

    expect(viewer().look('s9'), isFalse);
    expect(container.read(viewerSeatProvider), 's1');
  });

  test('leaving puts nobody in the chair', () {
    controller().startPod(players: [_here('you'), _here('Carla')], seed: 'abc');
    viewer().look('s2');
    controller().leave();

    expect(container.read(playProvider), isNull);
    // A stale viewer outlives its table and points at a seat that no longer
    // exists, which the next table then inherits.
    expect(container.read(viewerSeatProvider), isNull);
  });

  test('a new table reseats the viewer at its own first seat', () {
    controller().startPod(players: [_here('you'), _here('Carla')], seed: 'abc');
    viewer().look('s2');
    controller().startPod(players: [_here('you')], seed: 'def');

    expect(container.read(viewerSeatProvider), 's1');
  });

  test('a pod of peers only leaves nobody looking', () {
    controller().startPod(
      players: [
        (deck: _deck('a'), name: 'Carla', owner: const SeatOwner.peer('p1')),
        (deck: _deck('b'), name: 'Diego', owner: const SeatOwner.peer('p2')),
      ],
      seed: 'abc',
    );

    // A spectator: the table is open and this device holds no chair. Plan 3
    // arrives here, and it must not land on somebody else's hand by default.
    expect(container.read(viewerSeatProvider), isNull);
  });
}
