import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/decks/model/deck_format.dart';
import 'package:kitchentable/table/room/room.dart';

/// What each format starts you on, written out rather than read off
/// `DeckFormat` so this is an expectation and not a mirror of the code it is
/// checking. Keyed over `DeckFormat.values`, so a sixth format has to come back
/// here and say what a room of it starts on.
const _startsOn = {
  DeckFormat.commander: 40,
  DeckFormat.standard: 20,
  DeckFormat.pauper: 20,
  DeckFormat.draft: 20,

  // Not 20. Pokemon is won by taking prize cards and has no life total at all,
  // which `DeckFormat.startingLife` already says, and a room that invented its
  // own 20 would be a second opinion about it.
  DeckFormat.pokemonStandard: 0,
};

RoomConfig _config({
  DeckFormat format = DeckFormat.commander,
  int seats = 4,
  int? life,
}) =>
    RoomConfig(
      format: format,
      seats: seats,
      life: life,
      hostName: 'kit',
      roomName: 'the kitchen',
    );

void main() {
  test('a code is typable out loud', () {
    final codes = {for (var i = 0; i < 500; i++) freshRoomCode()};

    // Somebody is going to read this across a kitchen table rather than send
    // it, so the alphabet has nothing in it that can be misheard or misread:
    // no O against 0, no I or l against 1.
    for (final code in codes) {
      expect(code, matches(RegExp(r'^[a-hjkmnp-z2-9]{4}-[a-hjkmnp-z2-9]{3}$')));
    }

    // And 500 of them are 500, which is the cheapest thing that notices a
    // generator seeded once.
    expect(codes, hasLength(500));
  });

  test('the generator is not seeded, which the case above cannot see', () {
    // A `Random(7)` made once at the top of the file keeps advancing, so the
    // 500 above are still 500 and that case passes with a fixed seed in place.
    // Measured: it survives. What a fixed seed actually breaks is distinctness
    // between two devices, where every phone that starts the app mints the same
    // first code, two people host the same room and a link opens the wrong one.
    // No test inside one process can watch a second process, so this reads the
    // source instead, which is the only place that property is visible.
    final source = File('lib/table/room/room.dart');
    expect(
      source.existsSync(),
      isTrue,
      reason: 'this reads the source, so it has to run from the package root. '
          'cwd is ${Directory.current.path}',
    );

    expect(
      RegExp(r'Random[.(]\w*')
          .allMatches(source.readAsStringSync())
          .map((m) => m.group(0))
          .toSet(),
      {'Random.secure'},
      reason: 'the code is the whole of the invitation: there is nothing '
          'behind it, so a generator somebody can predict is a room somebody '
          'can walk into',
    );
  });

  test('a link carries the code and comes back out of it', () {
    final code = freshRoomCode();
    final link = linkFor(code, origin: 'https://example.test/app');

    expect(link, 'https://example.test/app/#room=$code');
    expect(codeFrom(link), code);
    expect(codeFrom('https://example.test/app/#room=${code.toUpperCase()}'),
        code, reason: 'a code read out and typed back in has a case');
    expect(codeFrom('https://example.test/app/'), isNull);
    expect(codeFrom('nonsense'), isNull);
  });

  test('a link is the same link however the origin was spelled', () {
    // The web hands over an origin with no path and a deploy under a folder
    // hands one with a trailing slash, and both have to make the same link or
    // the same room has two.
    expect(
      linkFor('abcd-efg', origin: 'https://example.test/app/'),
      'https://example.test/app/#room=abcd-efg',
    );
    expect(
      linkFor('ABCD-EFG', origin: 'https://example.test/app'),
      'https://example.test/app/#room=abcd-efg',
    );
    expect(
      linkFor('abcd-efg', origin: 'https://example.test'),
      'https://example.test/#room=abcd-efg',
    );
  });

  test('a fragment on its own is enough to find the code', () {
    // Which is what the browser hands over: the hash, not the whole location.
    expect(codeFrom('#room=abcd-efg'), 'abcd-efg');
  });

  test('something code shaped, or nothing', () {
    // A link whose code could never have been minted here is not a link to a
    // room, and saying so beats carrying a typo as far as the mesh and coming
    // back with no such room.
    expect(codeFrom('https://example.test/#room=hello'), isNull);
    expect(codeFrom('https://example.test/#room='), isNull);
    expect(codeFrom('https://example.test/#room=abcdefg'), isNull);
    expect(codeFrom('https://example.test/#room=abcd-efgh'), isNull);

    // o, i, l, 0 and 1 are not in the alphabet, so a code holding one was
    // misheard rather than minted, and there is nothing to repair it to: no
    // character in the alphabet is confusable with another.
    expect(codeFrom('https://example.test/#room=oooo-ooo'), isNull);
    expect(codeFrom('https://example.test/#room=1ll1-i00'), isNull);
  });

  test('life starts where the format says and is editable after', () {
    for (final format in DeckFormat.values) {
      expect(
        _config(format: format).life,
        _startsOn[format],
        reason: format.name,
      );
    }

    // A starting point and not a rule: people play 30 life Commander, and a
    // room that snapped it back to 40 would be arguing with them.
    expect(_config(format: DeckFormat.commander, life: 25).life, 25);
    expect(_config(format: DeckFormat.commander).copyWith(life: 30).life, 30);

    // And changing the format leaves a life somebody typed alone, which is the
    // reason the default lives in the constructor and not in `copyWith`.
    expect(
      _config(format: DeckFormat.standard, life: 15)
          .copyWith(format: DeckFormat.commander)
          .life,
      15,
    );
  });

  test('a room seats two to four', () {
    for (final seats in roomSeatChoices) {
      expect(_config(seats: seats).seats, seats);
    }
    expect(roomSeatChoices, [2, 3, 4]);

    // One is not a room, it is the table you already had, and the fifth chair
    // is a decision about the screen nobody has taken.
    expect(() => _config(seats: 1), throwsA(isA<AssertionError>()));
    expect(() => _config(seats: 5), throwsA(isA<AssertionError>()));
  });

  test('a config is a value', () {
    // Task 3 holds one in provider state and rebuilds a screen off it, which
    // is a thing identity equality does on every keystroke and never stops.
    expect(_config(), _config());
    expect(_config(life: 30), isNot(_config(life: 31)));
    expect(_config(seats: 2), isNot(_config(seats: 3)));
    expect(
      _config(),
      isNot(_config().copyWith(roomName: 'the shed')),
    );
  });
}
