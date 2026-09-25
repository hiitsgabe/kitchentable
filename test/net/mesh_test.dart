import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/table/actions/table_action.dart';
import 'package:kitchentable/table/model/card_instance.dart';
import 'package:kitchentable/table/model/seat.dart';
import 'package:kitchentable/table/model/seat_owner.dart';
import 'package:kitchentable/table/model/table_state.dart';
import 'package:kitchentable/table/model/zone.dart';
import 'package:kitchentable/table/net/mesh.dart';
import 'package:kitchentable/table/wire/wire.dart';

import 'fake_transport.dart';

/// A small table with something in every kind of pile, so a verb has a card to
/// move and a failure is short enough to read.
TableState _aTable() => const TableState(
      seats: [
        Seat(
          id: 's1',
          name: 'you',
          life: 40,
          owner: SeatOwner.here(),
          zones: [
            Zone(
              id: 'library-s1',
              seatId: 's1',
              label: 'Library',
              visibility: ZoneVisibility.hidden,
              ordered: true,
              cards: [
                CardInstance(id: 'l1', oracleId: 'sol ring'),
                CardInstance(id: 'l2', oracleId: 'mountain'),
              ],
            ),
            Zone(
              id: 'hand-s1',
              seatId: 's1',
              label: 'Hand',
              visibility: ZoneVisibility.owner,
              ordered: false,
              cards: [CardInstance(id: 'h1', oracleId: 'brainstorm')],
            ),
            Zone(
              id: 'battlefield-s1',
              seatId: 's1',
              label: 'Battlefield',
              visibility: ZoneVisibility.public,
              ordered: false,
              cards: [CardInstance(id: 'b1', oracleId: 'llanowar elves')],
            ),
          ],
        ),
        Seat(
          id: 's2',
          name: 'kit',
          life: 40,
          owner: SeatOwner.peer('a'),
          zones: [
            Zone(
              id: 'hand-s2',
              seatId: 's2',
              label: 'Hand',
              visibility: ZoneVisibility.owner,
              ordered: false,
            ),
            Zone(
              id: 'battlefield-s2',
              seatId: 's2',
              label: 'Battlefield',
              visibility: ZoneVisibility.public,
              ordered: false,
            ),
          ],
        ),
      ],
      turnSeatId: 's1',
    );

/// The people at the table, their transports, and everything any of their
/// meshes refused.
class _Seats {
  final net = FakeNetwork();
  final _meshes = <String, Mesh>{};
  final _lines = <String, FakeTransport>{};

  /// Why each peer would not act on something. Collected from the moment the
  /// mesh is built, because a case that subscribes later misses the refusal it
  /// is about.
  final refused = <String, List<String>>{};

  /// Who each peer was told is hosting, in order, and how many times it was told
  /// the table had changed. Both streams exist for a screen to rebuild off, so
  /// both are read here rather than only the getters, which a mesh that never
  /// said anything would still answer correctly.
  final toldTheHostIs = <String, List<String?>>{};
  final toldTheTableChanged = <String, int>{};

  Mesh mesh(String id) => _meshes[id]!;
  FakeTransport line(String id) => _lines[id]!;

  /// Somebody sits down and their mesh starts. The first one made the room, so
  /// it is the only one holding a table.
  ///
  /// Their transport knows nobody yet, because the news of who is here has not
  /// been delivered: the mesh is built and then finds out. That is one of the
  /// two orders this can happen in and [sitLate] is the other.
  Mesh sit(String id, {TableState? table, bool creator = false}) =>
      _start(net.join(id), table: table, creator: creator);

  /// Somebody whose transport already knows who is here before their mesh is
  /// built.
  ///
  /// The other order, and not a contrivance: a real transport can have its
  /// channels open before anything above it exists, and the code that asks for
  /// the table on the way up is never reached by a peer that finds out
  /// afterwards.
  Future<Mesh> sitLate(String id) async {
    final line = net.join(id);
    await net.settle();
    return _start(line);
  }

  Mesh _start(
    FakeTransport line, {
    TableState? table,
    bool creator = false,
  }) {
    final mesh = Mesh(transport: line, table: table, creator: creator);
    refused[line.me] = [];
    toldTheHostIs[line.me] = [];
    toldTheTableChanged[line.me] = 0;
    mesh.refusals.listen(refused[line.me]!.add);
    mesh.hosts.listen(toldTheHostIs[line.me]!.add);
    mesh.tables.listen((_) => toldTheTableChanged[line.me] =
        toldTheTableChanged[line.me]! + 1);
    mesh.start();
    addTearDown(mesh.close);
    addTearDown(line.close);
    _lines[line.me] = line;
    _meshes[line.me] = mesh;
    return mesh;
  }

  /// What one peer put on the wire for another, by kind, from a mark taken
  /// earlier. What is not in here is the point of several of these cases.
  List<String> kindsSent(String from, {required String to, int since = 0}) => [
        for (final message in line(from).sent.skip(since))
          if (message.to == to)
            jsonDecode(message.body)['kind']! as String,
      ];
}

/// Three phones, the first one having made the room, settled into a table.
Future<_Seats> _threeSeats() async {
  final seats = _Seats()
    ..sit('host', table: _aTable(), creator: true)
    ..sit('a')
    ..sit('b');
  await seats.net.settle();
  return seats;
}

void main() {
  test('a verb run on one seat lands on the other two', () async {
    final seats = await _threeSeats();

    seats.mesh('host').run(const ChangeLife(seatId: 's1', by: -3));
    await seats.net.settle();

    for (final id in ['host', 'a', 'b']) {
      expect(seats.mesh(id).table, isNotNull, reason: id);
      expect(seats.mesh(id).table!.seat('s1')!.life, 37, reason: id);
    }

    // And back the other way. A mesh is not a host broadcasting: a guest's verb
    // has to reach the host as well as the other guest, and a transport wired
    // in one direction would pass the case above and fail this one.
    seats.mesh('a').run(const RollDice([6, 6]));
    await seats.net.settle();

    for (final id in ['host', 'a', 'b']) {
      expect(seats.mesh(id).table!.dice, [6, 6], reason: id);
    }

    // And each of them was told, rather than quietly holding a new table that
    // nothing on screen would know to draw. Twice for the two verbs, and once
    // more for the guests, who were handed the table before either of them.
    expect(seats.toldTheTableChanged['host'], 2);
    expect(seats.toldTheTableChanged['a'], 3);
    expect(seats.toldTheTableChanged['b'], 3);
  });

  test('a verb naming a card nobody has changes nothing and says nothing',
      () async {
    // `apply` makes a verb naming something that is not there a no op, on the
    // grounds that at a real table you do not get an exception for reaching for
    // a card somebody already moved. It still travels, because the peer that
    // sent it may be right and this one may be the one missing the card, and it
    // still has to arrive as nothing rather than as a change: a screen told the
    // table changed rebuilds, and a mesh that said so on every stray verb would
    // make a peer with an out of date idea of the table redraw everybody's.
    final seats = await _threeSeats();
    final told = {
      for (final id in ['host', 'a', 'b']) id: seats.toldTheTableChanged[id]!,
    };

    seats.mesh('host').run(const FlipCard('no-such-card'));
    await seats.net.settle();

    expect(seats.kindsSent('host', to: 'b').last, 'action');
    for (final id in ['host', 'a', 'b']) {
      expect(seats.toldTheTableChanged[id], told[id], reason: id);
    }
  });

  test('a peer arriving late is handed the game so far, not the verbs', () async {
    final seats = _Seats()
      ..sit('host', table: _aTable(), creator: true)
      ..sit('a');
    await seats.net.settle();

    seats.mesh('host').run(const ChangeLife(seatId: 's1', by: -8));
    seats.mesh('host').run(const FlipCard('b1'));
    seats.mesh('host').run(
          const DrawCards(
            fromZoneId: 'library-s1',
            toZoneId: 'hand-s1',
            count: 1,
          ),
        );
    await seats.net.settle();

    seats.sit('b');
    await seats.net.settle();

    // `isNotNull` first and on its own line, so a mesh that hands a late peer
    // nothing fails here saying the table is missing rather than throwing a
    // null check out of the comparison below and reading like a crash.
    expect(seats.mesh('b').table, isNotNull);
    expect(seats.mesh('b').table!.seat('s1')!.life, 32);
    expect(seats.mesh('b').table!.zone('hand-s1')!.cards.length, 2);
    expect(seats.mesh('b').table!.zone('battlefield-s1')!.cards.single.faceDown,
        isTrue);

    // The whole table and not the three fields above, through the wire, which
    // is the only deep comparison of a `TableState` there is.
    expect(
      stateToWire(seats.mesh('b').table!),
      stateToWire(seats.mesh('host').table!),
    );

    // A snapshot and not a replay. Nobody sent b the three verbs it missed: a
    // replay would have to be bounded by something, and `apply` is a no op for
    // a verb naming a card that is not there, so a replay that fell short would
    // leave b with a table that looks perfectly correct and is wrong.
    expect(seats.kindsSent('host', to: 'b'), ['welcome']);
    expect(seats.kindsSent('a', to: 'b'), isEmpty);
  });

  test('the host stamps each peer as it joins, and the peer sends no number',
      () async {
    final seats = await _threeSeats();

    const asJoined = {'host': 0, 'a': 1, 'b': 2};
    for (final id in ['host', 'a', 'b']) {
      expect(seats.mesh(id).stamps, asJoined, reason: id);
    }
    expect(seats.mesh('a').myStamp, 1);
    expect(seats.mesh('b').myStamp, 2);

    // A fourth, whose transport knew the other three before its mesh started,
    // because that is the other way round and it asks along a different line.
    await seats.sitLate('d');
    await seats.net.settle();

    expect(seats.mesh('d').myStamp, 3);
    expect(seats.mesh('host').stamps, {'host': 0, 'a': 1, 'b': 2, 'd': 3});

    // And the ask carries nothing a peer could lie in. Not a comment about it:
    // the fields are read off what was actually sent, so a field added to the
    // hello has to come back here and be argued for. Both peers, because they
    // ask from different places.
    for (final id in ['a', 'd']) {
      final asks = seats
          .line(id)
          .sent
          .map((m) => jsonDecode(m.body) as Map<String, Object?>)
          .where((m) => m['kind'] == 'hello');

      expect(asks, isNotEmpty, reason: '$id never asked for the table at all');
      for (final ask in asks) {
        expect(ask.keys.toSet(), {'v', 'kind'}, reason: '$id sent $ask');
      }
    }
  });

  test('when the host goes, the lowest stamp takes over and the others agree',
      () async {
    final seats = await _threeSeats();
    expect(seats.mesh('a').hostId, 'host');

    seats.net.drop('host');
    await seats.net.settle();

    expect(seats.mesh('a').hostId, 'a');
    expect(seats.mesh('b').hostId, 'a');
    expect(seats.mesh('a').hosting, isTrue);
    expect(seats.mesh('b').hosting, isFalse);

    // Succession sends no messages, so the only way a screen hears about it is
    // this stream, and a role that moved in silence is a room whose title bar
    // still names somebody who left.
    expect(seats.toldTheHostIs['a'], ['host', 'a']);
    expect(seats.toldTheHostIs['b'], ['host', 'a']);

    // And the table goes on. The whole reason the design paid for a mesh is
    // that one person going through a tunnel is not the end of the game.
    seats.mesh('b').run(const ChangeLife(seatId: 's2', by: -1));
    await seats.net.settle();

    expect(seats.mesh('a').table!.seat('s2')!.life, 39);
  });

  test('when the peer that made the room comes back, it takes the role again',
      () async {
    final seats = await _threeSeats();

    seats.net.drop('host');
    await seats.net.settle();

    seats.mesh('a').run(const ChangeLife(seatId: 's1', by: -11));
    await seats.net.settle();

    seats.net.rejoin('host');
    await seats.net.settle();

    for (final id in ['host', 'a', 'b']) {
      expect(seats.mesh(id).hostId, 'host', reason: id);
    }

    expect(seats.toldTheHostIs['b'], ['host', 'a', 'host']);

    // Its stamp came back with it, which is the whole mechanism: the number
    // lives in everybody's roster rather than in the peer, so the peer does not
    // have to be believed about it.
    expect(seats.mesh('a').stamps['host'], 0);

    // And it came back to the table as it is now, not as it left it.
    expect(seats.mesh('host').table!.seat('s1')!.life, 29);
    expect(
      stateToWire(seats.mesh('host').table!),
      stateToWire(seats.mesh('a').table!),
    );
  });

  test('a peer cannot promote itself by claiming to be senior', () async {
    // The attack the design names. Succession that reads what a peer says about
    // when it joined lets a modified client claim to be first, win every
    // succession, and push whatever state it likes the moment it takes over.
    // The host stamps the number instead.
    //
    // It has to be forged rather than run, because a `Mesh` only ever sends
    // what this file's build sends and the attacker is somebody else's build.
    final seats = await _threeSeats();
    const claimingToBeFirst = '{"v":1,"kind":"hello","stamp":-1,"joinedAt":0}';

    seats.net.forge(from: 'b', to: 'host', body: claimingToBeFirst);
    seats.net.forge(from: 'b', to: 'a', body: claimingToBeFirst);
    await seats.net.settle();

    expect(seats.mesh('host').stamps['b'], 2, reason: 'the host stamped it');
    expect(seats.mesh('a').stamps['b'], 2);

    seats.net.drop('host');
    await seats.net.settle();

    expect(seats.mesh('a').hostId, 'a', reason: 'b claimed to have joined first');
    expect(seats.mesh('b').hostId, 'a', reason: 'and the others have to agree');
    expect(seats.mesh('b').hosting, isFalse);
  });

  test('a roster from anybody but the host is refused', () async {
    // The same attack from the other end: rather than lying about itself in a
    // handshake, a modified client tells everybody what the numbers are. A peer
    // takes a roster only from the peer it already believes is hosting, which
    // it worked out itself out of the last roster the host sent.
    final seats = await _threeSeats();

    seats.net.forge(
      from: 'b',
      to: 'a',
      body: jsonEncode({
        'v': wireVersion,
        'kind': 'roster',
        'stamps': {'b': -1, 'host': 0, 'a': 1},
      }),
    );
    await seats.net.settle();

    expect(seats.mesh('a').stamps['b'], 2);
    expect(
      seats.refused['a'],
      anyElement(allOf(contains('b'), contains('roster'))),
      reason: 'refused out loud: this is somebody trying, not a glitch',
    );

    seats.net.drop('host');
    await seats.net.settle();

    expect(seats.mesh('a').hostId, 'a');
  });

  test('a table nobody asked for is refused, even from the peer taking over',
      () async {
    // The second half of the same attack, in the design's own words: pushing
    // whatever state it likes the moment it takes over. So the attacker here is
    // the peer that has just legitimately become the host, which is the only
    // peer b would take a table from at all. State travels only where it was
    // asked for, so a peer that is playing cannot be handed a different game.
    final seats = await _threeSeats();

    seats.net.drop('host');
    await seats.net.settle();
    expect(seats.mesh('b').hostId, 'a', reason: 'a has taken the role over');

    seats.net.forge(
      from: 'a',
      to: 'b',
      body: jsonEncode({
        'v': wireVersion,
        'kind': 'welcome',
        'stamps': {'a': -1, 'host': 0, 'b': 2},
        'state': stateToWire(_aTable().withLife('s1', -37)),
      }),
    );
    await seats.net.settle();

    expect(seats.mesh('b').table!.seat('s1')!.life, 40);
    expect(seats.mesh('b').stamps['a'], 1);
    expect(
      seats.refused['b'],
      anyElement(allOf(contains('a'), contains('nobody asked'))),
    );
  });

  test('a peer that missed ten verbs is handed the table, not the ten verbs',
      () async {
    final seats = await _threeSeats();

    seats.net.drop('b');
    await seats.net.settle();

    for (var i = 0; i < 10; i++) {
      seats.mesh('host').run(const ChangeLife(seatId: 's1', by: -1));
    }
    await seats.net.settle();

    expect(seats.mesh('b').table, isNotNull, reason: 'b sat down before the drop');
    expect(seats.mesh('b').table!.seat('s1')!.life, 40,
        reason: 'b was in a tunnel for all ten');
    expect(seats.mesh('host').table!.seat('s1')!.life, 30);

    final mark = seats.line('host').sent.length;
    seats.net.rejoin('b');
    await seats.net.settle();

    expect(seats.mesh('b').table, isNotNull);
    expect(seats.mesh('b').table!.seat('s1')!.life, 30);
    expect(
      stateToWire(seats.mesh('b').table!),
      stateToWire(seats.mesh('host').table!),
    );

    // One table, and none of the ten. A replay would need a log bounded by
    // something, and a peer away for an hour would outrun the bound and need a
    // snapshot anyway, which makes replay a second mechanism that is only
    // sometimes enough.
    expect(seats.kindsSent('host', to: 'b', since: mark), ['welcome']);
  });

  test('two verbs at the same instant can leave two peers disagreeing',
      () async {
    // Nothing orders the mesh. This case is here to say so in numbers rather
    // than in a comment, because the alternative is one peer ordering
    // everything, which is the star the design rejected, and the cost of not
    // doing it has to be visible somewhere.
    //
    // Each peer applies verbs as they arrive, so its own comes first and the
    // other one lands after it. For a verb that sets rather than adds, that
    // decides the value, and the two of them disagree. `ChangeLife` carries a
    // delta and commutes; `RollDice` and `RotateCard(to:)` do not.
    final seats = await _threeSeats();

    seats.mesh('a').run(const RollDice([6]));
    seats.mesh('b').run(const RollDice([1]));
    await seats.net.settle();

    expect(seats.mesh('a').table!.dice, [1], reason: 'its own, then b\'s');
    expect(seats.mesh('b').table!.dice, [6], reason: 'its own, then a\'s');
    expect(seats.mesh('host').table!.dice, [1], reason: 'a\'s, then b\'s');
    expect(
      seats.mesh('a').table!.dice,
      isNot(seats.mesh('b').table!.dice),
      reason: 'and this is the cost, until a verb carries an order',
    );

    // A delta is the case that does not care, which is why this is a property
    // of the verb and not of the mesh.
    seats.mesh('a').run(const ChangeLife(seatId: 's1', by: -1));
    seats.mesh('b').run(const ChangeLife(seatId: 's1', by: -2));
    await seats.net.settle();

    for (final id in ['host', 'a', 'b']) {
      expect(seats.mesh(id).table!.seat('s1')!.life, 37, reason: id);
    }
  });

  test('a verb is applied where it lands and never passed on', () async {
    final seats = await _threeSeats();
    final mark = {
      for (final id in ['host', 'a', 'b']) id: seats.line(id).sent.length,
    };

    seats.mesh('host').run(const RotateCard('b1', to: 90));
    await seats.net.settle();

    expect(seats.mesh('a').table!.zone('battlefield-s1')!.cards.single.rotation,
        90);

    // Two sends and no more, and nothing sent on by the two that received it.
    // In a full mesh the sender already reached everybody, so a peer that
    // relayed a verb would deliver every verb once per peer and the copies
    // would move the card again.
    expect(seats.kindsSent('host', to: 'a', since: mark['host']!), ['action']);
    expect(seats.kindsSent('host', to: 'b', since: mark['host']!), ['action']);
    for (final id in ['a', 'b']) {
      expect(
        seats.line(id).sent.skip(mark[id]!).map((m) => m.body),
        isEmpty,
        reason: '$id received a verb and answered with something',
      );
    }
  });

  test('a message this build cannot read is refused in words that name it',
      () async {
    final seats = await _threeSeats();

    seats.net.forge(
      from: 'b',
      to: 'a',
      body: jsonEncode({'v': wireVersion, 'kind': 'coup'}),
    );
    seats.net.forge(
      from: 'b',
      to: 'a',
      body: jsonEncode({
        'v': wireVersion + 1,
        'kind': 'action',
        'body': toWire(const PassTurn()),
      }),
    );
    seats.net.forge(from: 'b', to: 'a', body: 'this is not json');
    await seats.net.settle();

    expect(seats.refused['a'], hasLength(3));
    expect(seats.refused['a'], anyElement(contains('coup')));
    expect(
      seats.refused['a'],
      anyElement(allOf(contains('version'), contains('${wireVersion + 1}'))),
    );
    expect(seats.refused['a'], anyElement(contains('JSON')));

    // And none of it moved the table.
    expect(seats.mesh('a').table!.turnSeatId, 's1');
  });

  test('nothing under table/net knows what a relay is', () async {
    // The seam. The next slice writes a real transport over Nostr and WebRTC
    // and these two files do not change, which is only true while they import
    // nothing that could tell them: coupling to a library needs an import, so
    // reading the imports off the files proves the absence rather than
    // sampling for words somebody thought of.
    const allowed = {
      'dart:async',
      'dart:convert',
      'package:flutter/foundation.dart',
      '../actions/apply.dart',
      '../actions/table_action.dart',
      '../model/table_state.dart',
      '../wire/wire.dart',
      'transport.dart',
    };

    for (final path in [
      'lib/table/net/transport.dart',
      'lib/table/net/mesh.dart',
    ]) {
      final file = File(path);
      expect(
        file.existsSync(),
        isTrue,
        reason: 'this reads the source, so it has to run from the package '
            'root. cwd is ${Directory.current.path}',
      );

      final imports = RegExp(r"^import '([^']+)'", multiLine: true)
          .allMatches(file.readAsStringSync())
          .map((m) => m.group(1)!)
          .toSet();

      // A broken regex reads as a clean file, so the population has to be
      // non empty before the difference below means anything.
      expect(imports, isNotEmpty, reason: path);
      expect(imports.difference(allowed), isEmpty, reason: path);
    }

    // And the mesh mints nothing. Every id and every roll is minted by whoever
    // built the verb, which is what lets three phones exchange verbs instead of
    // screens: `apply` is pure, so the same verb on the same table gives the
    // same table everywhere. This covers the two ways anything in this
    // repository invents a number and no more; the imports above are the part
    // that proves an absence.
    final mesh = File('lib/table/net/mesh.dart').readAsStringSync();
    expect(mesh, isNot(contains('Random')));
    expect(mesh, isNot(contains('DateTime')));
  });
}
