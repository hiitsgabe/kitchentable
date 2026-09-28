import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/decks/model/deck.dart';
import 'package:kitchentable/decks/model/deck_format.dart';
import 'package:kitchentable/decks/model/game.dart';
import 'package:kitchentable/features/lobby/lobby.dart';
import 'package:kitchentable/net/mesh.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';
import 'package:kitchentable/table/model/seat_owner.dart';
import 'package:kitchentable/table/model/table_state.dart';
import 'package:kitchentable/table/room/room.dart';
import 'package:kitchentable/table/setup.dart';
import 'package:kitchentable/table/wire/deck_wire.dart';
import 'package:kitchentable/table/wire/wire.dart';

import '../net/fake_transport.dart';

/// A printing with every field filled and none at its default, so a wire that
/// dropped one cannot round trip by accident.
const _bolt = CatalogCard(
  oracleId: 'bolt',
  name: 'Lightning Bolt',
  typeLine: 'Instant',
  cmc: 1,
  manaCost: '{R}',
  oracleText: 'Lightning Bolt deals 3 damage to any target.',
  power: null,
  toughness: null,
  colorIdentity: ['R'],
  rarity: 'common',
  setCode: 'lea',
  legalities: {'commander': 'legal', 'standard': 'not_legal'},
  imageSmall: 'https://img.test/bolt/small.jpg',
  imageNormal: 'https://img.test/bolt/normal.jpg',
  imageLarge: 'https://img.test/bolt/large.jpg',
  imageBack: null,
);

const _bear = CatalogCard(
  oracleId: 'bear',
  name: 'Grizzly Bears',
  typeLine: 'Creature - Bear',
  cmc: 2,
  manaCost: '{1}{G}',
  power: '2',
  toughness: '2',
  colorIdentity: ['G'],
  rarity: 'common',
  setCode: 'lea',
  imageNormal: 'https://img.test/bear/normal.jpg',
  imageBack: 'https://img.test/bear/back.jpg',
);

Deck _deck(String id, {List<DeckSlot>? slots}) => Deck(
      id: id,
      name: 'deck $id',
      format: DeckFormat.commander,
      game: Game.magic,
      slots: slots ??
          const [
            DeckSlot(card: _bear, quantity: 1, commander: true),
            DeckSlot(card: _bolt, quantity: 40),
          ],
    );

RoomConfig _config({int seats = 3, int? life}) => RoomConfig(
      format: DeckFormat.commander,
      seats: seats,
      life: life,
      hostName: 'kit',
      roomName: 'the kitchen',
    );

/// The printing fields, in one place, so a case that compares two cards
/// compares all of them and a field added to [CatalogCard] shows up here as
/// a missing line rather than silently not compared.
Map<String, Object?> _fields(CatalogCard c) => {
      'oracleId': c.oracleId,
      'name': c.name,
      'typeLine': c.typeLine,
      'cmc': c.cmc,
      'manaCost': c.manaCost,
      'oracleText': c.oracleText,
      'power': c.power,
      'toughness': c.toughness,
      'colorIdentity': c.colorIdentity,
      'rarity': c.rarity,
      'setCode': c.setCode,
      'legalities': c.legalities,
      'imageSmall': c.imageSmall,
      'imageNormal': c.imageNormal,
      'imageLarge': c.imageLarge,
      'imageBack': c.imageBack,
    };

TableState _deal(List<Player> players) =>
    sitDownTogether(players: players, seed: 'seed');

/// A host and its guests on one fake network, each a real [Lobby].
class _Room {
  _Room({int seats = 3}) : config = _config(seats: seats) {
    host = Lobby.host(transport: net.join('host'), config: config);
    addTearDown(host.close);
  }

  final net = FakeNetwork();
  final RoomConfig config;
  late final Lobby host;
  final Map<String, Lobby> guests = {};

  /// Somebody opens the link. Their lobby speaks up on the network, and
  /// [settle] is what carries it.
  Lobby arrive(String id) {
    final lobby = Lobby.guest(transport: net.join(id));
    addTearDown(lobby.close);
    return guests[id] = lobby;
  }

  Future<void> settle() => net.settle();
}

void main() {
  group('a deck on the wire', () {
    test('a deck comes back with every printing field it went out with', () {
      final deck = _deck('d1', slots: const [
        DeckSlot(card: _bear, quantity: 1, commander: true),
        DeckSlot(card: _bolt, quantity: 4),
        DeckSlot(card: _bolt, quantity: 3, sideboard: true),
      ]);

      final wire = deckToWire(deck);
      final json = jsonDecode(wire) as Map<String, Object?>;
      expect(json['v'], wireVersion,
          reason: 'the same number the table speaks, not a second one');

      final back = deckFromWire(wire);
      expect(back.id, 'd1');
      expect(back.name, 'deck d1');
      expect(back.format, DeckFormat.commander);
      expect(back.game, Game.magic);
      expect(back.slots, hasLength(3));

      for (var i = 0; i < 3; i++) {
        final was = deck.slots[i];
        final now = back.slots[i];
        expect(now.quantity, was.quantity, reason: 'slot $i quantity');
        expect(now.sideboard, was.sideboard, reason: 'slot $i sideboard');
        expect(now.commander, was.commander, reason: 'slot $i commander');
        expect(_fields(now.card), _fields(was.card), reason: 'slot $i card');
      }
    });

    test('a deck from another version is refused by number', () {
      final json = jsonDecode(deckToWire(_deck('d1'))) as Map<String, Object?>;
      json['v'] = wireVersion + 1;

      expect(
        () => deckFromWire(jsonEncode(json)),
        throwsA(isA<WireError>().having(
          (e) => e.message,
          'message',
          contains('${wireVersion + 1}'),
        )),
      );
    });

    test('a card missing a field it needs is refused by name', () {
      final json = jsonDecode(deckToWire(_deck('d1'))) as Map<String, Object?>;
      final slot = (json['slots'] as List).first as Map<String, Object?>;
      (slot['card'] as Map<String, Object?>).remove('typeLine');

      expect(
        () => deckFromWire(jsonEncode(json)),
        throwsA(isA<WireError>().having(
          (e) => e.message,
          'message',
          contains('typeLine'),
        )),
      );
    });

    test('a wire that is not a deck at all says so rather than crashing', () {
      expect(() => deckFromWire('not json'), throwsA(isA<WireError>()));
      expect(() => deckFromWire('[1, 2]'), throwsA(isA<WireError>()));
    });
  });

  group('the lobby', () {
    test("a guest's deck reaches the host, and the host's room reaches the "
        'guest', () async {
      final room = _Room();
      final ana = room.arrive('ana');
      await room.settle();

      // Before a deck, ana is a connection and not a person at the table.
      expect(room.host.seated, isEmpty);
      expect(ana.host, 'host', reason: 'the host answered her knock');
      expect(ana.config, room.config,
          reason: 'and told her what the room is, since she cannot guess');

      ana.bring(deck: _deck('anas'), name: 'ana');
      await room.settle();

      expect(room.host.seated, [(peer: 'ana', name: 'ana')]);
      expect(ana.seated, room.host.seated,
          reason: 'everybody sees the same chairs');
      expect(ana.seatedHere, isTrue);
    });

    test("a guest's deck arrives with its printings, so a host that never "
        'imported the card needs no catalog to draw it', () async {
      // The host holds no catalog in this case and the lobby has no way to
      // reach one, so every field below can only have come over the wire.
      final room = _Room();
      final ana = room.arrive('ana');
      await room.settle();
      ana.bring(deck: _deck('anas'), name: 'ana');
      await room.settle();

      final deck = room.host.deckOf('ana');
      expect(deck, isNotNull);
      final cards = {for (final s in deck!.slots) s.card.oracleId: s.card};
      expect(_fields(cards['bolt']!), _fields(_bolt));
      expect(_fields(cards['bear']!), _fields(_bear));
      expect(deck.commanders.single.card.oracleId, 'bear');
    });

    test('the host cannot start with an empty chair and can with all full',
        () async {
      final room = _Room(seats: 3);
      final ana = room.arrive('ana');
      await room.settle();
      room.host.sit(deck: _deck('hosts'), name: 'kit');
      ana.bring(deck: _deck('anas'), name: 'ana');
      await room.settle();

      expect(room.host.emptyChairs, [3]);
      expect(room.host.canStart, isFalse);
      expect(() => room.host.start(_deal), throwsStateError);
      await room.settle();
      expect(room.host.mesh, isNull, reason: 'nothing was handed over');
      expect(ana.dealt, isFalse, reason: 'and nobody was told otherwise');

      final bo = room.arrive('bo');
      await room.settle();
      bo.bring(deck: _deck('bos'), name: 'bo');
      await room.settle();

      expect(room.host.emptyChairs, isEmpty);
      expect(room.host.canStart, isTrue);
      expect(room.host.start(_deal), isA<Mesh>());
    });

    test("the host's own chair is the first one, and it counts", () async {
      final room = _Room(seats: 2);
      final ana = room.arrive('ana');
      await room.settle();
      ana.bring(deck: _deck('anas'), name: 'ana');
      await room.settle();

      expect(room.host.emptyChairs, [1],
          reason: 'the guest is in chair 2 and the host has not sat down');
      expect(room.host.canStart, isFalse);

      room.host.sit(deck: _deck('hosts'), name: 'kit');
      expect(room.host.seated, [
        (peer: 'host', name: 'kit'),
        (peer: 'ana', name: 'ana'),
      ]);
      expect(room.host.canStart, isTrue);
    });

    test('start deals one seat per person, each owned by that person', () async {
      final room = _Room(seats: 3);
      final ana = room.arrive('ana');
      final bo = room.arrive('bo');
      await room.settle();
      ana.bring(deck: _deck('anas'), name: 'ana');
      bo.bring(deck: _deck('bos'), name: 'bo');
      await room.settle();
      room.host.sit(deck: _deck('hosts'), name: 'kit');

      List<Player>? dealt;
      final mesh = room.host.start((players) {
        dealt = players;
        return _deal(players);
      });

      expect(dealt, isNotNull);
      expect(dealt!.map((p) => p.name), ['kit', 'ana', 'bo']);
      expect(dealt!.map((p) => p.deck.id), ['hosts', 'anas', 'bos']);
      expect(dealt![0].owner, const SeatOwner.peer('host'),
          reason: "the host's seat is keyed like everybody else's: `here` is "
              'true on one phone only and this list is read on every phone');
      expect(dealt![1].owner, const SeatOwner.peer('ana'),
          reason: "ana's hand is ana's, on ana's phone");
      expect(dealt![2].owner, const SeatOwner.peer('bo'));

      final table = mesh.table!;
      expect(table.seats.map((s) => s.name), ['kit', 'ana', 'bo']);
      expect(table.seats.map((s) => s.owner), [
        const SeatOwner.peer('host'),
        const SeatOwner.peer('ana'),
        const SeatOwner.peer('bo'),
      ]);
    });

    test('after start the lobby has stopped and the mesh has the transport',
        () async {
      final room = _Room(seats: 2);
      final ana = room.arrive('ana');
      await room.settle();
      ana.bring(deck: _deck('anas'), name: 'ana');
      await room.settle();
      room.host.sit(deck: _deck('hosts'), name: 'kit');

      final mesh = room.host.start(_deal);
      await room.settle();

      expect(ana.dealt, isTrue);
      expect(ana.mesh, isNotNull);
      expect(ana.mesh!.table, isNotNull,
          reason: 'the mesh handed her the table');
      expect(stateToWire(ana.mesh!.table!), stateToWire(mesh.table!));
      expect(ana.mesh!.hostId, 'host');

      // What the host said after handing over: nothing in the lobby's voice.
      // Counted on the transport, because a lobby left listening would answer
      // the next knock with the chairs, and that is one message too many.
      final transport = room.net.join('host');
      int chairsSaid() => transport.sent
          .where((s) => (jsonDecode(s.body) as Map)['kind'] == 'chairs')
          .length;
      final before = chairsSaid();

      final late = room.arrive('late');
      await room.settle();
      late.bring(deck: _deck('lates'), name: 'late');
      await room.settle();

      expect(chairsSaid(), before,
          reason: 'the lobby answered a knock after handing over');
      expect(room.host.seated, hasLength(2),
          reason: 'a deck brought after start finds no lobby to take it');
    });

    test('a guest who arrives after start is handed the table by the mesh and '
        'not by the lobby', () async {
      final room = _Room(seats: 2);
      final ana = room.arrive('ana');
      await room.settle();
      ana.bring(deck: _deck('anas'), name: 'ana');
      await room.settle();
      room.host.sit(deck: _deck('hosts'), name: 'kit');
      final mesh = room.host.start(_deal);
      await room.settle();

      final late = room.arrive('late');
      await room.settle();

      expect(late.mesh, isNotNull);
      expect(late.mesh!.table, isNotNull);
      expect(stateToWire(late.mesh!.table!), stateToWire(mesh.table!));
      expect(late.dealt, isTrue);
      // The lobby never spoke to them: no chairs, no host, no seat.
      expect(late.config, isNull);
      expect(late.host, isNull);
      expect(late.seated, isEmpty);
      // And the host's mesh, not its lobby, is what welcomed them.
      expect(mesh.stamps.keys, contains('late'));
    });

    test('a guest who leaves before the start gives the chair back', () async {
      final room = _Room(seats: 2);
      final ana = room.arrive('ana');
      await room.settle();
      ana.bring(deck: _deck('anas'), name: 'ana');
      await room.settle();
      expect(room.host.emptyChairs, [1]);

      room.net.drop('ana');
      await room.settle();

      expect(room.host.seated, isEmpty);
      expect(room.host.emptyChairs, [1, 2]);
    });

    test('one person more than the room has chairs is told it is full',
        () async {
      final room = _Room(seats: 2);
      final ana = room.arrive('ana');
      final bo = room.arrive('bo');
      await room.settle();
      ana.bring(deck: _deck('anas'), name: 'ana');
      await room.settle();
      bo.bring(deck: _deck('bos'), name: 'bo');
      await room.settle();

      expect(room.host.seated.map((s) => s.peer), ['ana']);
      expect(bo.seatedHere, isFalse);
      expect(bo.full, isTrue);
      expect(ana.full, isFalse, reason: 'ana has a chair, so it is not full '
          'for her');
    });

    test('a message the lobby cannot read is counted and never thrown',
        () async {
      final room = _Room();
      room.arrive('ana');
      await room.settle();

      room.net.forge(from: 'ana', to: 'host', body: 'not json');
      room.net.forge(
        from: 'ana',
        to: 'host',
        body: jsonEncode({'v': wireVersion, 'kind': 'bring', 'name': 7}),
      );
      await room.settle();

      expect(room.host.refused, 2);
      expect(room.host.seated, isEmpty);
    });
  });
}
