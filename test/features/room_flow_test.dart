import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/decks/deck_repository.dart';
import 'package:kitchentable/decks/model/deck.dart';
import 'package:kitchentable/decks/model/deck_format.dart';
import 'package:kitchentable/features/decks/decks_controller.dart';
import 'package:kitchentable/features/decks/play_decks_screen.dart';
import 'package:kitchentable/features/menu/menu_controller.dart';
import 'package:kitchentable/features/menu/menu_screen.dart';
import 'package:kitchentable/features/play/play_controller.dart';
import 'package:kitchentable/features/room/entry.dart';
import 'package:kitchentable/features/room/join_screen.dart';
import 'package:kitchentable/features/room/room_controller.dart';
import 'package:kitchentable/features/room/room_screen.dart';
import 'package:kitchentable/features/room/start_screen.dart';
import 'package:kitchentable/features/settings/player_name.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';
import 'package:kitchentable/table/room/room.dart';
import 'package:kitchentable/ui/atoms/menu_row.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the web build is served from, for the tests that want a link. Off the
/// web there is no origin at all and the room has only a code, which is its
/// own case below.
const _origin = 'https://example.test/app';

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

/// The Play list with decks in it and no database underneath, the same stand in
/// the deck picker's own tests use: the list is read without cards and the
/// cards are loaded only when it deals.
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

RoomConfig _config({int seats = 4, int? life}) => RoomConfig(
      format: DeckFormat.commander,
      seats: seats,
      life: life,
      hostName: 'kit',
      roomName: 'the kitchen',
    );

ProviderContainer _container({
  String? origin = _origin,
  String? launchCode,
  List<Deck> shelf = const [],
  String? yourName = namelessPlayer,
  MenuState menu = const MenuState(cardCount: 36079, enabledSources: 1),
}) {
  final container = ProviderContainer(
    overrides: [
      roomOriginProvider.overrideWithValue(origin),
      launchRoomCodeProvider.overrideWithValue(launchCode),
      // Your name comes off the device rather than out of this screen now, and
      // overriding the resolved one keeps these cases off the disk. Null means
      // no override: the real chain, from an empty store to the fallback.
      if (yourName != null) yourNameProvider.overrideWithValue(yourName),
      // Null keeps every screen this pushes off the disk, and stands in for
      // the web build, which has no local catalog.
      catalogDbProvider.overrideWithValue(null),
      deckRepositoryProvider.overrideWithValue(_Shelf(shelf)),
      menuStateProvider.overrideWith((ref) async => menu),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Taller than the 800 by 600 the test window opens at.
///
/// The room screen is a column of things a player has to read, and the default
/// window puts the last of them under the fold, where the finders skip it. The
/// real screen scrolls. This is about what is on the screen, not where.
void _tallWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _pump(
  WidgetTester tester,
  ProviderContainer container,
  Widget home,
) async {
  _tallWindow(tester);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: home),
    ),
  );
  await tester.pumpAndSettle();
}

/// The text under a key, and a named failure when there is none.
///
/// Read through the finder deliberately: `tester.widget` on an empty finder
/// throws Bad state: No element, which is a red case that never says which
/// assertion it was. A probe that emptied the screen read exactly like that.
String _textAt(WidgetTester tester, String key) {
  final finder = find.byKey(Key(key));
  expect(finder, findsOneWidget, reason: 'no text at $key');
  return tester.widget<Text>(finder).data!;
}

void main() {
  // The name lives on the device now, so any screen reading it reads a store.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the menu', () {
    test('offers starting a table and joining one rather than playing', () {
      const state = MenuState(cardCount: 36079, enabledSources: 1);
      final ids = state.entries.map((e) => e.id).toList();

      expect(ids, contains(MenuEntryId.start));
      expect(ids, contains(MenuEntryId.join));
      expect(state.initialFocus, MenuEntryId.start,
          reason: 'the first thing to do is make a place to play in');

      final start = state.entries.firstWhere((e) => e.id == MenuEntryId.start);
      final join = state.entries.firstWhere((e) => e.id == MenuEntryId.join);
      expect(start.subtitle, contains('invite'));
      expect(join.subtitle, contains('link'));
    });

    // The whole of this task in one case. Not a hand written list of the rows
    // that used to deal, which could only find the door somebody remembered:
    // this reads the menu's own source and asserts the picker is not named
    // anywhere in it, so a second door added later fails here too. The two
    // lines under it are the positive control, because a file that failed to
    // read, or a rename, would satisfy the absence above on its own.
    test('no door on the menu opens a deck picker', () {
      final source = File('lib/features/menu/menu_screen.dart');
      expect(source.existsSync(), isTrue,
          reason: 'this reads the source, so it has to run from the package '
              'root. cwd is ${Directory.current.path}');
      final text = source.readAsStringSync();

      expect(text, isNot(contains('PlayDecksScreen')));
      expect(text, contains('StartScreen'));
      expect(text, contains('JoinScreen'));
    });

    testWidgets('starting a table opens the room settings', (tester) async {
      await _pump(tester, _container(), const MenuScreen());

      await tester.tap(find.byKey(const Key('menu-start')));
      await tester.pumpAndSettle();

      expect(find.byType(StartScreen), findsOneWidget);
    });

    testWidgets('joining opens somewhere to paste a link', (tester) async {
      await _pump(tester, _container(), const MenuScreen());

      await tester.tap(find.byKey(const Key('menu-join')));
      await tester.pumpAndSettle();

      expect(find.byType(JoinScreen), findsOneWidget);
    });
  });

  group('starting one', () {
    testWidgets('confirming the settings opens a room with a code, a link '
        'and a QR of that link', (tester) async {
      final container = _container();
      await _pump(tester, container, const StartScreen());

      await tester.tap(find.byKey(const Key('make-room')));
      await tester.pumpAndSettle();

      expect(find.byType(RoomScreen), findsOneWidget);

      final code = _textAt(tester, 'room-code');
      expect(code, matches(roomCodePattern));
      expect(container.read(roomProvider)!.code, code);
      expect(container.read(roomProvider)!.hosting, isTrue);

      // The link and the QR are asserted apart on purpose. They are built from
      // the same code and a QR is not readable by eye, so a room screen that
      // put the wrong code in the link would still show a QR somebody could
      // scan, and a case that only looked at the QR would let it through.
      expect(_textAt(tester, 'room-link'), linkFor(code, origin: _origin));
      expect(
        tester.widget<RoomQr>(find.byKey(const Key('room-qr'))).link,
        linkFor(code, origin: _origin),
      );
      expect(find.byType(QrImageView), findsOneWidget,
          reason: 'and the square is a real QR of it, not a placeholder');
    });

    testWidgets('what the host typed is what the room is', (tester) async {
      final container = _container();
      await _pump(tester, container, const StartScreen());

      await tester.enterText(find.byKey(const Key('room-name')), 'the kitchen');
      await tester.enterText(find.byKey(const Key('life-field')), '30');
      await tester.pump();
      await tester.tap(find.byKey(const Key('seats-up')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('make-room')));
      await tester.pumpAndSettle();

      final config = container.read(roomProvider)!.config!;
      expect(config.roomName, 'the kitchen');
      expect(config.life, 30);
      expect(roomSeatChoices, contains(config.seats));
      expect(config.seats, isNot(roomSeatChoices.first),
          reason: 'plus was pressed once, so it moved off the fewest');
    });

    testWidgets('the format is picked off the list rather than cycled through',
        (tester) async {
      final container = _container();
      await _pump(tester, container, const StartScreen());

      // Derived from the enum, not from a list typed in here. A case holding
      // its own five names could only ever look for the formats somebody
      // remembered, and a sixth added to the app would leave it green.
      for (final format in DeckFormat.values) {
        expect(find.byKey(Key('format-${format.name}')), findsOneWidget,
            reason: 'no way to pick ${format.name}');
      }

      MenuRow row(DeckFormat f) =>
          tester.widget<MenuRow>(find.byKey(Key('format-${f.name}')));

      final wanted = DeckFormat.values.last;
      expect(row(wanted).subtitle, isNot(contains('picked')),
          reason: 'the tap below has to be a change, and this is the guard '
              'against pressing the one the screen opened on');

      await tester.tap(find.byKey(Key('format-${wanted.name}')));
      await tester.pump();

      expect(row(wanted).subtitle, contains('picked'),
          reason: 'a select says which one is chosen');

      await tester.tap(find.byKey(const Key('make-room')));
      await tester.pumpAndSettle();

      expect(container.read(roomProvider)!.config!.format, wanted);
    });

    testWidgets('the chairs stepper stops at both ends instead of wrapping',
        (tester) async {
      // Wrapping is the failure to watch for. A row you tap to cycle wraps by
      // nature and a stepper must not: somebody pressing minus at the fewest
      // chairs and landing on the most has been lied to.
      final container = _container();
      await _pump(tester, container, const StartScreen());

      int shown() => int.parse(_textAt(tester, 'seats-count'));
      double dimming(String key) => tester
          .widget<Opacity>(find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(Opacity),
          ))
          .opacity;

      expect(shown(), roomSeatChoices.first);
      expect(dimming('seats-down'), lessThan(1),
          reason: 'minus is drawn dead at the fewest chairs');
      expect(dimming('seats-up'), 1.0);

      final atFewest = _textAt(tester, 'seats-note');
      expect(atFewest, contains('${roomSeatChoices.first}'));
      expect(atFewest, contains('as few as'));

      await tester.tap(find.byKey(const Key('seats-down')));
      await tester.pump();
      expect(shown(), roomSeatChoices.first,
          reason: 'minus at ${roomSeatChoices.first} chairs must not wrap '
              'round to ${roomSeatChoices.last}');

      // Exactly enough to land on the last and not one more, so that the press
      // past the end below is the only thing the last assertion can be about.
      // Overshooting here made a stepper that wrapped fail on the way up, which
      // left the assertion about pressing past the top never run at all.
      for (var i = 0; i < roomSeatChoices.length - 1; i++) {
        await tester.tap(find.byKey(const Key('seats-up')));
        await tester.pump();
      }

      expect(shown(), roomSeatChoices.last);
      expect(dimming('seats-up'), lessThan(1),
          reason: 'and plus is drawn dead at the most');
      expect(dimming('seats-down'), 1.0);

      final atMost = _textAt(tester, 'seats-note');
      expect(atMost, contains('${roomSeatChoices.last}'));
      expect(atMost, contains('as many as'));
      expect(atMost, isNot(atFewest),
          reason: 'both ends say when they have stopped, in their own words');

      await tester.tap(find.byKey(const Key('seats-up')));
      await tester.pump();
      expect(shown(), roomSeatChoices.last,
          reason: 'plus at ${roomSeatChoices.last} chairs must not wrap round '
              'to ${roomSeatChoices.first}');

      await tester.tap(find.byKey(const Key('make-room')));
      await tester.pumpAndSettle();
      expect(container.read(roomProvider)!.config!.seats, roomSeatChoices.last,
          reason: 'and the room is made with the number on the screen');
    });

    testWidgets('your name comes off the device and the room never asks',
        (tester) async {
      // A name is a property of the person: it is the same in every room they
      // ever join, so a room that asks again is asking somebody to repeat
      // themselves and making a second place it can disagree from.
      final container = _container(yourName: 'kit');
      await _pump(tester, container, const StartScreen());

      expect(find.byKey(const Key('host-name')), findsNothing);
      // The positive control. The room's own name is still asked for on this
      // screen, so a screen that failed to build cannot satisfy the line above
      // by being empty.
      expect(find.byKey(const Key('room-name')), findsOneWidget);

      await tester.tap(find.byKey(const Key('make-room')));
      await tester.pumpAndSettle();

      expect(container.read(roomProvider)!.config!.hostName, 'kit');
    });

    testWidgets('a room made by somebody who never said their name',
        (tester) async {
      // No override here, so this runs the real chain: an empty store, the
      // provider that puts the fallback in front of it, and the screen reading
      // it. An override handing the screen `you` would prove only the reading.
      final container = _container(yourName: null);
      await _pump(tester, container, const StartScreen());

      await tester.tap(find.byKey(const Key('make-room')));
      await tester.pumpAndSettle();

      expect(container.read(roomProvider)!.config!.hostName, namelessPlayer,
          reason: 'which is where the old empty box landed too');
    });

    testWidgets('off the web there is no link to give, only the code',
        (tester) async {
      // A phone hosting has no address of its own and never did: the link
      // points at wherever the web build is served, and a build that is not
      // served anywhere has nothing to point at. Inventing a URL here would
      // hand somebody a link that goes nowhere.
      final container = _container(origin: null);
      container.read(roomProvider.notifier).open(_config());
      await _pump(tester, container, const RoomScreen());

      expect(find.byKey(const Key('room-code')), findsOneWidget);
      expect(find.byKey(const Key('room-link')), findsNothing);
      expect(find.byType(QrImageView), findsNothing);
      expect(find.byKey(const Key('room-no-link')), findsOneWidget);
    });
  });

  group('the room', () {
    testWidgets('says plainly that nothing is hidden yet', (tester) async {
      // Everything replicates in the clear in this slice: a peer holds every
      // hand and every library, and what stops them being drawn is software
      // running on somebody else's phone. That is fine for friends and it is
      // not what a security promise sounds like, so the room says so rather
      // than leaving it to be assumed.
      final container = _container();
      container.read(roomProvider.notifier).open(_config());
      await _pump(tester, container, const RoomScreen());

      expect(find.byKey(const Key('room-openness')), findsOneWidget);

      final line = _textAt(tester, 'room-openness').toLowerCase();

      // In words a player understands. Somebody holding a hand of cards is
      // owed a sentence about their hand, not a sentence about transport
      // security, and "unencrypted" tells them nothing at all.
      for (final jargon in [
        'encrypt',
        'plaintext',
        'cleartext',
        'in the clear',
        'peer',
      ]) {
        expect(line, isNot(contains(jargon)), reason: jargon);
      }
      expect(line, contains('hand'));
      expect(line, contains('see'));
    });

    testWidgets('does not pretend anybody can reach it yet', (tester) async {
      // There is no transport in this slice at all, so a room screen counting
      // down empty chairs would be a waiting room nobody can walk into. The
      // code and the link are real and the connection is not, and the screen
      // is the only place that can say which.
      final container = _container();
      container.read(roomProvider.notifier).open(_config());
      await _pump(tester, container, const RoomScreen());

      expect(find.byKey(const Key('room-reach')), findsOneWidget);
      expect(_textAt(tester, 'room-reach'), isNotEmpty);
    });

    testWidgets('the deck is picked from inside the room', (tester) async {
      final container = _container(shelf: [_deck('d1')]);
      container.read(roomProvider.notifier).open(_config());
      await _pump(tester, container, const RoomScreen());

      expect(find.byType(PlayDecksScreen), findsNothing,
          reason: 'the room exists before anybody has a deck');

      await tester.tap(find.byKey(const Key('room-deck')));
      await tester.pumpAndSettle();

      expect(find.byType(PlayDecksScreen), findsOneWidget);
    });

    testWidgets('the picker opened from a room picks one deck and no more',
        (tester) async {
      // Collecting several decks and dealing them as one table is nonsense
      // twice over from inside a room: the room already said how many chairs,
      // and seats are meant to fill with people.
      final container = _container(shelf: [_deck('d1')]);
      container.read(roomProvider.notifier).open(_config());
      await _pump(tester, container, const RoomScreen());

      await tester.tap(find.byKey(const Key('room-deck')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('add-seat')), findsNothing);
      expect(find.byKey(const Key('deal')), findsNothing,
          reason: 'nothing to deal together, because nothing is collected');
      // The positive control: this is the deck picker with a deck on it, so an
      // empty or broken screen cannot satisfy the two lines above.
      expect(find.byKey(const Key('deck-row-0')), findsOneWidget);
    });

    testWidgets('the room offers to fill the other chairs from this device',
        (tester) async {
      final container = _container();
      container.read(roomProvider.notifier).open(_config(seats: 4));
      await _pump(tester, container, const RoomScreen());

      final row = tester.widget<MenuRow>(find.byKey(const Key('room-fill')));
      final words = '${row.title} ${row.subtitle}'.toLowerCase();

      // Named as what it does, which is the whole point of moving it. The old
      // row said "More than one seat" over "collect several decks and deal
      // them as one table", and somebody reading that had to work out that it
      // meant they would be playing everybody.
      expect(words, contains('chairs'));
      expect(words, contains('this device'));
      expect(words, contains('4'), reason: 'and how many it is filling');
      expect(words, isNot(contains('more than one seat')));
    });

    testWidgets('filling them opens a picker that takes a deck per chair',
        (tester) async {
      // Deliberately kept rather than deleted. With no transport, this is the
      // only way to see a table with more than one seat at all, and the pod
      // renderers are unreachable without it.
      final container = _container(shelf: [_deck('d1')]);
      container.read(roomProvider.notifier).open(_config(seats: 4));
      await _pump(tester, container, const RoomScreen());

      await tester.tap(find.byKey(const Key('room-fill')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('deck-row-0')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('deck-row-0')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('deal')));
      await tester.pumpAndSettle();

      final table = container.read(playProvider);
      expect(table!.seats, hasLength(2));
      expect(table.seats.every((s) => s.owner.actableHere), isTrue,
          reason: 'every chair is held by this device');
    });

    testWidgets('it will not collect more decks than the room has chairs',
        (tester) async {
      // The room said how many chairs. A picker that let somebody collect a
      // fifth deck in a four chair room would deal a table the room does not
      // describe, which is the same lie in the other direction.
      final container = _container(shelf: [_deck('d1')]);
      final seats = roomSeatChoices.first;
      container.read(roomProvider.notifier).open(_config(seats: seats));
      await _pump(tester, container, const RoomScreen());

      expect(find.byKey(const Key('room-fill')), findsOneWidget,
          reason: 'the fewest chairs a room has is $seats, and one of them is '
              'somebody else\'s, so there is something to fill');

      await tester.tap(find.byKey(const Key('room-fill')));
      await tester.pumpAndSettle();

      for (var i = 0; i < seats + 2; i++) {
        await tester.tap(find.byKey(const Key('deck-row-0')));
        await tester.pump();
      }
      await tester.tap(find.byKey(const Key('deal')));
      await tester.pumpAndSettle();

      expect(container.read(playProvider)!.seats, hasLength(seats));
    });

    testWidgets('a room that cannot say how many chairs does not offer it',
        (tester) async {
      // A guest has a code and none of the host's settings, because those
      // travel over a mesh that does not exist yet. Offering to fill chairs it
      // cannot count would be a control working off its own guess.
      final container = _container();
      container.read(roomProvider.notifier).arrive(freshRoomCode());
      await _pump(tester, container, const RoomScreen());

      expect(find.byKey(const Key('room-fill')), findsNothing);
      // The positive control again: a guest still picks a deck and sits down.
      expect(find.byKey(const Key('room-deck')), findsOneWidget);
    });

    testWidgets('the room is what the table starts on', (tester) async {
      final container = _container(shelf: [_deck('d1')]);
      container.read(roomProvider.notifier).open(_config(life: 30));
      await _pump(tester, container, const RoomScreen());

      await tester.tap(find.byKey(const Key('room-deck')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('deck-row-0')));
      await tester.pumpAndSettle();

      // Commander starts on 40 and this room said 30. A starting life you can
      // edit and the table ignores is a setting that looks like it works.
      expect(container.read(playProvider)!.seats.single.life, 30);
    });
  });

  group('joining one', () {
    testWidgets('a link pasted in lands on the room with that code',
        (tester) async {
      final container = _container();
      final code = freshRoomCode();

      await _pump(tester, container, const JoinScreen());
      await tester.enterText(
        find.byKey(const Key('join-input')),
        linkFor(code, origin: _origin),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('join-go')));
      await tester.pumpAndSettle();

      expect(find.byType(RoomScreen), findsOneWidget);
      expect(_textAt(tester, 'room-code'), code);
      expect(container.read(roomProvider)!.code, code);
      expect(container.read(roomProvider)!.hosting, isFalse);
    });

    testWidgets('a code read out loud across the table is enough',
        (tester) async {
      final container = _container();
      final code = freshRoomCode();

      await _pump(tester, container, const JoinScreen());
      await tester.enterText(
        find.byKey(const Key('join-input')),
        code.toUpperCase(),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('join-go')));
      await tester.pumpAndSettle();

      expect(container.read(roomProvider)?.code, code,
          reason: 'a code somebody said out loud has no case of its own');
    });

    testWidgets('there is nothing to join until there is a code',
        (tester) async {
      final container = _container();
      await _pump(tester, container, const JoinScreen());

      MenuRow go() =>
          tester.widget<MenuRow>(find.byKey(const Key('join-go')));

      expect(go().enabled, isFalse, reason: 'an empty box is not a room');

      await tester.enterText(find.byKey(const Key('join-input')), 'hello');
      await tester.pump();
      expect(go().enabled, isFalse, reason: 'and neither is a word');

      // An `o` and a `1` are not in the alphabet, so this was misheard rather
      // than minted and there is nothing to repair it to.
      await tester.enterText(find.byKey(const Key('join-input')), 'o1ab-cde');
      await tester.pump();
      expect(go().enabled, isFalse);

      await tester.enterText(
          find.byKey(const Key('join-input')), freshRoomCode());
      await tester.pump();
      expect(go().enabled, isTrue);

      expect(container.read(roomProvider), isNull,
          reason: 'nothing has been joined, only typed');
    });
  });

  group('a link opened on the web', () {
    testWidgets('goes straight to the room and never to the menu',
        (tester) async {
      final code = freshRoomCode();
      final container = _container(launchCode: code);

      await _pump(tester, container, const Entry());

      expect(find.byType(RoomScreen), findsOneWidget);
      expect(find.byType(MenuScreen), findsNothing,
          reason: 'a link that opens the menu is a link that did not work');
      expect(_textAt(tester, 'room-code'), code);
      expect(container.read(roomProvider)!.hosting, isFalse);
    });

    testWidgets('a room nobody is hosting opens the same way', (tester) async {
      // Nothing in this slice can tell a room that is up from a room that
      // never existed: there is no transport to ask. Saying "no such room"
      // would be a guess dressed as a fact, so the link lands where it says it
      // lands and the screen says nobody has answered.
      final container = _container(launchCode: 'aaaa-aaa');

      await _pump(tester, container, const Entry());

      expect(find.byType(RoomScreen), findsOneWidget);
      expect(_textAt(tester, 'room-code'), 'aaaa-aaa');
      expect(find.byKey(const Key('room-reach')), findsOneWidget);
    });

    testWidgets('and an ordinary launch still opens the menu', (tester) async {
      await _pump(tester, _container(), const Entry());

      expect(find.byType(MenuScreen), findsOneWidget);
      expect(find.byType(RoomScreen), findsNothing);
    });
  });
}
