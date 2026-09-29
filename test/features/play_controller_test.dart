import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/decks/model/deck.dart';
import 'package:kitchentable/decks/model/deck_format.dart';
import 'package:kitchentable/features/lobby/lobby.dart';
import 'package:kitchentable/features/play/play_controller.dart';
import 'package:kitchentable/net/mesh.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';
import 'package:kitchentable/table/actions/table_action.dart';
import 'package:kitchentable/table/model/seat_owner.dart';
import 'package:kitchentable/table/model/table_state.dart';
import 'package:kitchentable/table/referee/referee.dart';
import 'package:kitchentable/table/view/seat_view.dart';

import '../net/fake_transport.dart';

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

  group('with a mesh', () {
    late FakeNetwork net;
    late ProviderContainer host;
    late ProviderContainer ana;
    late Mesh hostMesh;
    late FakeTransport hostLine;

    PlayController playOn(ProviderContainer phone) =>
        phone.read(playProvider.notifier);
    TableState tableOn(ProviderContainer phone) => phone.read(playProvider)!;

    /// Two phones, each with a controller looking through its own transport,
    /// dealt the way the room does it: the host deals and hands its table to
    /// a mesh, the guest's mesh asks and is handed the table, and the guest's
    /// controller is seeded from what arrived rather than from a deal.
    setUp(() async {
      net = FakeNetwork();
      hostLine = net.join('host');
      final anaLine = net.join('ana');
      host = ProviderContainer(
        overrides: [transportProvider.overrideWithValue(hostLine)],
      );
      ana = ProviderContainer(
        overrides: [transportProvider.overrideWithValue(anaLine)],
      );

      playOn(host).startPod(
        players: [
          (deck: _deck(), name: 'kit', owner: const SeatOwner.peer('host')),
          (deck: _deck(), name: 'ana', owner: const SeatOwner.peer('ana')),
        ],
        seed: 'abc',
      );
      hostMesh = Mesh(
        transport: hostLine,
        table: tableOn(host),
        creator: true,
      )..start();
      playOn(host).follow(hostMesh);

      final anaMesh = Mesh(transport: anaLine)..start();
      await net.settle();
      expect(anaMesh.table, isNotNull, reason: 'the mesh handed ana the table');
      playOn(ana).join(anaMesh, decks: {'ana': _deck()});
    });

    tearDown(() async {
      host.dispose();
      ana.dispose();
    });

    test('a card moved on the host lands at the same spot on the guest',
        () async {
      final card = tableOn(host).zone('hand-s1')!.cards.first;

      playOn(host).run(MoveCard(
        cardId: card.id,
        toZoneId: 'battlefield-s1',
        position: (x: 0.25, y: 0.75),
      ));
      await net.settle();

      // The host first, then the guest, so a failure says which phone the
      // card never reached.
      final onHost = tableOn(host).locate(card.id)!;
      expect(onHost.zone.id, 'battlefield-s1', reason: "on the host's phone");
      expect(onHost.card.position, (x: 0.25, y: 0.75),
          reason: "on the host's phone");
      final onAna = tableOn(ana).locate(card.id)!;
      expect(onAna.zone.id, 'battlefield-s1', reason: "on ana's phone");
      expect(onAna.card.position, (x: 0.25, y: 0.75),
          reason: "on ana's phone");
    });

    test('and one moved on the guest lands on the host', () async {
      final card = tableOn(ana).zone('hand-s2')!.cards.first;

      playOn(ana).run(MoveCard(
        cardId: card.id,
        toZoneId: 'battlefield-s2',
        position: (x: 0.5, y: 0.5),
      ));
      await net.settle();

      final onAna = tableOn(ana).locate(card.id)!;
      expect(onAna.zone.id, 'battlefield-s2', reason: "on ana's phone");
      final onHost = tableOn(host).locate(card.id)!;
      expect(onHost.zone.id, 'battlefield-s2', reason: "on the host's phone");
      expect(onHost.card.position, (x: 0.5, y: 0.5),
          reason: "on the host's phone");
    });

    test("the guest's hand is face up on the guest's phone and face down on "
        "the host's", () {
      // Each phone looks out of the seat under its own key, which is what
      // makes the hand readable on one and not the other.
      expect(ana.read(viewerSeatProvider), 's2');
      expect(host.read(viewerSeatProvider), 's1');

      final onAna = SeatView.of(tableOn(ana).seat('s2')!, viewer: 's2');
      expect(onAna.pile('hand')!.readable, isTrue);
      expect(onAna.pile('hand')!.cards, hasLength(7));

      final onHost = SeatView.of(tableOn(host).seat('s2')!, viewer: 's1');
      expect(onHost.pile('hand')!.readable, isFalse);
      expect(onHost.pile('hand')!.cards, isEmpty);
      expect(onHost.pile('hand')!.count, 7,
          reason: 'how many she holds is public, what they are is not');
    });

    test('undo is refused in words while the mesh is up, and the table stays',
        () async {
      playOn(host).run(const ChangeLife(seatId: 's1', by: -5));
      await net.settle();
      expect(tableOn(host).seat('s1')!.life, 35);
      expect(tableOn(ana).seat('s1')!.life, 35);

      expect(playOn(host).canUndo, isFalse);
      playOn(host).undo();

      expect(tableOn(host).seat('s1')!.life, 35,
          reason: 'undo did not move the table');
      expect(playOn(host).lastRefusal, isNotNull,
          reason: 'refused out loud, not silently ignored');
      expect(playOn(host).lastRefusal!.reason.toLowerCase(), contains('undo'));
    });

    test('a referee still reviews a verb before it travels', () async {
      playOn(host).useReferee(const _GrumpyReferee());
      final sentBefore = hostLine.sent.length;

      playOn(host).run(const ChangeLife(seatId: 's1', by: -5));
      await net.settle();

      expect(tableOn(host).seat('s1')!.life, 40);
      expect(tableOn(ana).seat('s1')!.life, 40);
      expect(hostLine.sent.length, sentBefore,
          reason: 'a refused verb never reaches the wire');
      expect(playOn(host).lastRefusal?.reason, 'no');
    });
  });
}

class _GrumpyReferee implements Referee {
  const _GrumpyReferee();

  @override
  Refusal? review(TableState table, TableAction action) => const Refusal('no');

  @override
  List<String>? legalTargets(TableState table, String cardId) => null;
}
