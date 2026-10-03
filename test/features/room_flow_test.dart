import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/decks/deck_repository.dart';
import 'package:kitchentable/decks/model/deck.dart';
import 'package:kitchentable/decks/model/deck_format.dart';
import 'package:kitchentable/features/decks/decks_controller.dart';
import 'package:kitchentable/features/decks/play_decks_screen.dart';
import 'package:kitchentable/features/lobby/lobby.dart';
import 'package:kitchentable/features/menu/menu_controller.dart';
import 'package:kitchentable/features/menu/menu_screen.dart';
import 'package:kitchentable/features/setup/setup_controller.dart';
import 'package:kitchentable/features/setup/setup_screen.dart';
import 'package:kitchentable/features/play/play_controller.dart';
import 'package:kitchentable/features/play/play_screen.dart';
import 'package:kitchentable/features/play/widgets/hand_sheet.dart';
import 'package:kitchentable/features/play/widgets/table_card.dart';
import 'package:kitchentable/features/room/entry.dart';
import 'package:kitchentable/features/room/join_screen.dart';
import 'package:kitchentable/features/room/room_controller.dart';
import 'package:kitchentable/features/room/room_screen.dart';
import 'package:kitchentable/features/room/start_screen.dart';
import 'package:kitchentable/features/settings/player_name.dart';
import 'package:kitchentable/net/link.dart';
import 'package:kitchentable/net/signaling.dart';
import 'package:kitchentable/net/connection_report.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';
import 'package:kitchentable/table/actions/table_action.dart';
import 'package:kitchentable/table/model/seat_owner.dart';
import 'package:kitchentable/table/room/room.dart';
import 'package:kitchentable/table/setup.dart';
import 'package:kitchentable/ui/atoms/menu_row.dart';
import 'package:kitchentable/ui/organisms/screen_frame.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../net/fake_transport.dart';

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
  FakeNetwork? net,
}) {
  // This device is `me` on a network in memory, so a room here reaches
  // nobody unless a case puts somebody on the other end with [_friend].
  final network = net ?? FakeNetwork();
  final container = ProviderContainer(
    overrides: [
      roomOriginProvider.overrideWithValue(origin),
      launchRoomCodeProvider.overrideWithValue(launchCode),
      transportFactoryProvider.overrideWithValue((_) => network.join('me')),
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

/// A friend on the other side of the network, running the same lobby a
/// phone would. They knock on arrival; [_settle] carries it.
Lobby _friend(FakeNetwork net, String id) {
  final lobby = Lobby.guest(transport: net.join(id));
  addTearDown(lobby.close);
  return lobby;
}

/// Delivers everything in flight and draws the result. Under the widget
/// tester's fake clock the network's own turn of the event loop never comes,
/// so it runs for real and the screen is pumped after.
Future<void> _settle(WidgetTester tester, FakeNetwork net) async {
  await tester.runAsync(net.settle);
  await tester.pump();
}

/// A room with a host in it, from this device's side.
ProviderContainer _hosting(FakeNetwork net, {int seats = 3, int? life}) {
  final container = _container(net: net, shelf: [_deck('d1')]);
  container.read(roomProvider.notifier).open(_config(seats: seats, life: life));
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

/// What the frame says under the title, before it is set in capitals.
String _label(WidgetTester tester) =>
    tester.widget<ScreenFrame>(find.byType(ScreenFrame)).label;

/// The text under a key, and a named failure when there is none.
///
/// Read through the finder deliberately: `tester.widget` on an empty finder
/// throws Bad state: No element, which is a red case that never says which
/// assertion it was. A probe that emptied the screen read exactly like that.
/// Every line of text inside a keyed row, joined. The chairs are a row of
/// number, name and status rather than one string.
String _rowAt(WidgetTester tester, String key) {
  final finder = find.byKey(Key(key));
  expect(finder, findsOneWidget, reason: 'no row at $key');
  return tester
      .widgetList<Text>(find.descendant(of: finder, matching: find.byType(Text)))
      .map((t) => t.data ?? '')
      .join(' ')
      .trim();
}

String _textAt(WidgetTester tester, String key) {
  final finder = find.byKey(Key(key));
  expect(finder, findsOneWidget, reason: 'no text at $key');
  return tester.widget<Text>(finder).data!;
}

void main() {
  // The name lives on the device now, so any screen reading it reads a store.
  // A configured app, which is what every case below but the first run ones
  // is about. Left out, the wizard stands in front of the screen under test,
  // which is the wizard working rather than the case failing.
  setUp(() => SharedPreferences.setMockInitialValues({'setupDone': true}));

  group('the menu', () {
    test('offers playing and joining rather than dealing', () {
      const state = MenuState(cardCount: 36079, enabledSources: 1);
      final ids = state.entries.map((e) => e.id).toList();

      expect(ids, contains(MenuEntryId.play));
      expect(ids, contains(MenuEntryId.join));
      expect(state.initialFocus, MenuEntryId.play,
          reason: 'the first thing to do is make a place to play in');

      final play = state.entries.firstWhere((e) => e.id == MenuEntryId.play);
      final join = state.entries.firstWhere((e) => e.id == MenuEntryId.join);
      expect(play.subtitle, contains('invite'));
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

      await tester.tap(find.byKey(const Key('menu-play')));
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
    testWidgets('confirming the settings opens a room with a QR of the link '
        'and a way to send it', (tester) async {
      final container = _container();
      await _pump(tester, container, const StartScreen());

      await tester.tap(find.byKey(const Key('make-room')));
      await tester.pumpAndSettle();

      expect(find.byType(RoomScreen), findsOneWidget);

      final code = container.read(roomProvider)!.code;
      expect(code, matches(roomCodePattern));
      expect(container.read(roomProvider)!.hosting, isTrue);
      expect(find.byKey(const Key('room-code')), findsNothing,
          reason: 'a room is a link; the code is noise beside it');

      // The link and the QR are asserted apart on purpose. They are built from
      // the same code and a QR is not readable by eye, so a room screen that
      // put the wrong code in the link would still show a QR somebody could
      // scan, and a case that only looked at the QR would let it through.
      expect(find.byKey(const Key('room-copy')), findsOneWidget);
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

      // A select and not an open list: the choices exist only while you are
      // choosing. Five rows laid open on the screen read as a list to browse
      // rather than a setting with a value.
      for (final format in DeckFormat.values) {
        expect(find.byKey(Key('format-${format.name}')), findsNothing,
            reason: '${format.name} is laid open before anybody asked');
      }

      await tester.tap(find.byKey(const Key('format-select')));
      await tester.pumpAndSettle();

      // Derived from the enum, not from a list typed in here. A case holding
      // its own five names could only ever look for the formats somebody
      // remembered, and a sixth added to the app would leave it green.
      for (final format in DeckFormat.values) {
        expect(find.byKey(Key('format-${format.name}')), findsOneWidget,
            reason: 'no way to pick ${format.name}');
      }

      MenuRow select() =>
          tester.widget<MenuRow>(find.byKey(const Key('format-select')));

      final wanted = DeckFormat.values.last;
      expect(select().title, isNot(wanted.label),
          reason: 'the tap below has to be a change, and this is the guard '
              'against pressing the one the screen opened on');

      await tester.tap(find.byKey(Key('format-${wanted.name}')));
      await tester.pumpAndSettle();

      expect(select().title, wanted.label,
          reason: 'the select says which one is chosen');
      expect(find.byKey(Key('format-${wanted.name}')), findsNothing,
          reason: 'choosing closes the choices');

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
      expect(find.byKey(const Key('room-copy')), findsNothing);
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

    test('no line on the room says nobody can arrive', () {
      // The line came down when people could. Read off the source rather than
      // off one pumped screen, because the screen has states and the line
      // could hide in one a case never draws; the second line is the positive
      // control, because a file that failed to read satisfies the first.
      final source = File('lib/features/room/room_screen.dart');
      expect(source.existsSync(), isTrue,
          reason: 'this reads the source, so it has to run from the package '
              'root. cwd is ${Directory.current.path}');
      final text = source.readAsStringSync();

      expect(text, isNot(contains('room-reach')));
      expect(text, isNot(contains('cannot actually arrive')));
      expect(text, contains('room-start'));
    });

    testWidgets('the chairs count down as people arrive', (tester) async {
      final net = FakeNetwork();
      final container = _hosting(net, seats: 3);
      await _pump(tester, container, const RoomScreen());

      expect(_rowAt(tester, 'room-chair-1'), contains('pick a deck'));
      expect(_textAt(tester, 'room-chairs-count'), '0 of 3');
      expect(_rowAt(tester, 'room-chair-2'), contains('Empty'));
      expect(_rowAt(tester, 'room-chair-3'), contains('Empty'));
      expect(_label(tester), contains('3 of 3 chairs empty'));

      final ana = _friend(net, 'ana');
      await _settle(tester, net);
      // Connected is not seated: a chair is a person with a deck.
      expect(_rowAt(tester, 'room-chair-2'), contains('Empty'));

      ana.bring(deck: _deck('anas'), name: 'ana');
      await _settle(tester, net);

      expect(_rowAt(tester, 'room-chair-2'), contains('ana'));
      expect(_rowAt(tester, 'room-chair-2'), contains('ready'));
      expect(_textAt(tester, 'room-chairs-count'), '1 of 3');
      expect(_rowAt(tester, 'room-chair-3'), contains('Empty'));
      expect(_label(tester), contains('2 of 3 chairs empty'));

      net.drop('ana');
      await _settle(tester, net);
      expect(_rowAt(tester, 'room-chair-2'), contains('Empty'),
          reason: 'a friend who leaves gives the chair back');
    });

    testWidgets('the connection is one line while it works, and says more '
        'only when it does not', (tester) async {
      final net = FakeNetwork();
      final container = _hosting(net);
      await _pump(tester, container, const RoomScreen());

      // Reaching it is worth a line; nobody puts a STUN line in a lobby.
      expect(_textAt(tester, 'room-relay').toLowerCase(), contains('findable'));
      expect(find.byKey(const Key('room-stun')), findsNothing);
      expect(find.byKey(const Key('room-peer-ana')), findsNothing);

      final reach = container.read(reachProvider.notifier);
      reach.note(const RendezvousStep(SignalingStatus(SignalingStep.announced)));
      await tester.pump();

      // A relay that took the room is not news, so the line goes away.
      expect(find.byKey(const Key('room-relay')), findsNothing);

      // Somebody connected, with no deck yet: a chair-less row in the chairs
      // card, which is where a host looks for who has arrived.
      reach.note(const LinkStep(LinkStatus(LinkStage.opened, peer: 'ana')));
      await tester.pump();
      expect(_rowAt(tester, 'room-peer-ana').toLowerCase(),
          contains('picking a deck'));
      expect(_rowAt(tester, 'room-peer-ana'), isNot(contains('ana')),
          reason: 'the name is not known until the deck arrives');

      // Once the deck lands they have a chair, and the chair-less row goes.
      _friend(net, 'ana').bring(deck: _deck('anas'), name: 'ana');
      await _settle(tester, net);
      expect(find.byKey(const Key('room-peer-ana')), findsNothing);
      expect(_rowAt(tester, 'room-chair-2'), contains('ana'));

      // A relay that cannot be reached at all is news again.
      reach.note(const RendezvousStep(
        SignalingStatus(SignalingStep.relayUnreachable),
      ));
      await tester.pump();
      expect(_textAt(tester, 'room-relay').toLowerCase(),
          contains('no relay could be reached'));
    });

    testWidgets('a peer that was heard shows before it connects, and a failure '
        'shows its reason', (tester) async {
      final net = FakeNetwork();
      final container = _hosting(net);
      await _pump(tester, container, const RoomScreen());
      final reach = container.read(reachProvider.notifier);

      // On the first two-phone check the host heard the phone, gathered its
      // own address for it, and the link never opened; the screen read
      // "chair 2: empty" with no hint anybody had been seen. Heard is a fact
      // worth a line before it becomes a chair.
      expect(find.byKey(const Key('room-seen-ana')), findsNothing);
      reach.note(const RendezvousStep(
        SignalingStatus(SignalingStep.peerHere, peer: 'ana'),
      ));
      await tester.pump();
      expect(_textAt(tester, 'room-seen-ana').toLowerCase(),
          contains('connecting'));

      // And carries the link's last word about itself, so a screenshot of
      // this line says where it stopped.
      reach.note(const LinkStep(LinkStatus(
        LinkStage.progress,
        peer: 'ana',
        detail: 'ice checking',
      )));
      await tester.pump();
      expect(_textAt(tester, 'room-seen-ana'), contains('ice checking'));

      // Opened: the seen line gives way to the peer line.
      reach.note(const LinkStep(LinkStatus(LinkStage.opened, peer: 'ana')));
      await tester.pump();
      expect(find.byKey(const Key('room-seen-ana')), findsNothing);
      expect(find.byKey(const Key('room-peer-ana')), findsOneWidget);
      expect(_rowAt(tester, 'room-peer-ana').toLowerCase(),
          contains('picking a deck'));

      // A failure that a TURN server would not fix used to be invisible: no
      // turn line, no peer line, nothing. Now it says why.
      reach.note(LinkStep(LinkStatus(
        LinkStage.failed,
        peer: 'ana',
        failure: const LinkFailure(
          peer: 'ana',
          reason: 'the other side closed before the channel opened',
          needsTurn: false,
        ),
      )));
      await tester.pump();
      expect(find.byKey(const Key('room-peer-ana')), findsNothing);
      expect(find.byKey(const Key('room-turn')), findsNothing,
          reason: 'this is not the TURN case');
      expect(_textAt(tester, 'room-failed-ana'),
          contains('closed before the channel opened'));
    });

    testWidgets('a link that needs a relay is said in words, and where to '
        'put one', (tester) async {
      final net = FakeNetwork();
      final container = _hosting(net);
      await _pump(tester, container, const RoomScreen());

      expect(find.byKey(const Key('room-turn')), findsNothing);

      final reach = container.read(reachProvider.notifier);
      // A failure that a relay would not fix says nothing about relays.
      reach.note(const LinkStep(LinkStatus(
        LinkStage.failed,
        peer: 'bo',
        failure: LinkFailure(peer: 'bo', reason: 'their offer was garbage'),
      )));
      await tester.pump();
      expect(find.byKey(const Key('room-turn')), findsNothing);

      reach.note(const LinkStep(LinkStatus(
        LinkStage.failed,
        peer: 'ana',
        failure: LinkFailure(
          peer: 'ana',
          reason: 'ICE completed with no candidate pair',
          needsTurn: true,
        ),
      )));
      await tester.pump();

      final line = _textAt(tester, 'room-turn');
      expect(line, contains('TURN'));
      expect(line, contains('Settings'));
      expect(line.toLowerCase(), contains('could not be reached directly'));
      expect(line, isNot(contains('ICE')),
          reason: 'in words, not in the words of the protocol');
    });

    testWidgets('the fill row hides once a real person is seated',
        (tester) async {
      final net = FakeNetwork();
      final container = _hosting(net, seats: 3);
      await _pump(tester, container, const RoomScreen());

      expect(find.byKey(const Key('room-fill')), findsOneWidget);

      final ana = _friend(net, 'ana');
      await _settle(tester, net);
      expect(find.byKey(const Key('room-fill')), findsOneWidget,
          reason: 'connected and not seated is not a person in a chair');

      ana.bring(deck: _deck('anas'), name: 'ana');
      await _settle(tester, net);
      expect(find.byKey(const Key('room-fill')), findsNothing);
      expect(find.byKey(const Key('room-deck')), findsOneWidget,
          reason: 'the positive control: the host still picks its own deck');
    });

    testWidgets('the host starts only with every chair full, and the button '
        'says which are empty', (tester) async {
      final net = FakeNetwork();
      final container = _hosting(net, seats: 3);
      await _pump(tester, container, const RoomScreen());

      MenuRow start() =>
          tester.widget<MenuRow>(find.byKey(const Key('room-start')));

      expect(start().enabled, isFalse);
      expect(start().subtitle, contains('chairs 1, 2 and 3'));

      // The host sits through the picker, which closes on the room.
      await tester.tap(find.byKey(const Key('room-deck')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('deck-row-0')));
      await tester.pumpAndSettle();
      expect(find.byType(PlayDecksScreen), findsNothing);
      expect(find.byType(PlayScreen), findsNothing,
          reason: 'sitting down is not dealing');
      expect(start().enabled, isFalse);
      expect(start().subtitle, contains('chairs 2 and 3'));

      final ana = _friend(net, 'ana');
      ana.bring(deck: _deck('anas'), name: 'ana');
      await _settle(tester, net);
      expect(start().enabled, isFalse);
      expect(start().subtitle, contains('chair 3'));
      expect(start().subtitle, isNot(contains('2')));

      // Pressed anyway: a dimmed row does nothing.
      await tester.tap(find.byKey(const Key('room-start')));
      await tester.pumpAndSettle();
      expect(container.read(playProvider), isNull);

      _friend(net, 'bo').bring(deck: _deck('bos'), name: 'bo');
      await _settle(tester, net);
      expect(start().enabled, isTrue);
      expect(start().subtitle, isNot(contains('waiting')));

      await tester.tap(find.byKey(const Key('room-start')));
      await tester.pumpAndSettle();

      final table = container.read(playProvider)!;
      expect(table.seats.map((s) => s.name), ['kit', 'ana', 'bo']);
      expect(table.seats.map((s) => s.owner), [
        const SeatOwner.peer('me'),
        const SeatOwner.peer('ana'),
        const SeatOwner.peer('bo'),
      ]);
      expect(find.byType(PlayScreen), findsOneWidget);
      // And the host looks out of its own seat, found by its key on the
      // transport: every seat is keyed now, so a controller that never asked
      // the transport who it is would open this table as a spectator.
      expect(container.read(viewerSeatProvider), table.seats.first.id,
          reason: "the host's seat is the one under its own key");
      final viewer = container.read(viewerSeatProvider.notifier);
      expect(viewer.look(table.seats[1].id), isFalse,
          reason: "ana's seat is ana's, on the host's phone too");
      expect(viewer.look(table.seats.first.id), isTrue);
      // And the lobby's last word went to both guests. Read off the wire and
      // not settled through to them: settling runs for real, and the table
      // behind this screen starts fetching card backs the moment it can.
      final sent = (container.read(transportProvider)! as FakeTransport).sent;
      expect(
        sent.where((s) => s.body.contains('"dealt"')).map((s) => s.to).toSet(),
        {'ana', 'bo'},
      );
    });

    testWidgets("a guest sees the host's room, its chairs, and that the table "
        'was dealt', (tester) async {
      // The other way round: this device is the guest, and the host is a
      // lobby on the far side of the network.
      final net = FakeNetwork();
      final host = Lobby.host(
        transport: net.join('kit'),
        config: _config(seats: 2, life: 30),
      );
      addTearDown(host.close);
      final container = _container(net: net, shelf: [_deck('d1')]);
      container.read(roomProvider.notifier).arrive(freshRoomCode());
      await _pump(tester, container, const RoomScreen());

      expect(_textAt(tester, 'room-answer').toLowerCase(),
          contains('waiting for the host'));
      expect(find.byKey(const Key('room-chairs')), findsNothing,
          reason: 'a guest cannot count chairs it has not been told about');
      expect(find.byKey(const Key('room-start')), findsNothing);

      await _settle(tester, net);
      expect(find.byKey(const Key('room-answer')), findsNothing,
          reason: 'the host answered, so there is nothing to wait for');
      expect(_rowAt(tester, 'room-chair-1'), contains('host'));
      expect(_rowAt(tester, 'room-chair-2'), contains('Empty'));
      expect(find.byKey(const Key('room-fill')), findsNothing,
          reason: 'the other chairs are other people\'s');

      await tester.tap(find.byKey(const Key('room-deck')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('deck-row-0')));
      await tester.pumpAndSettle();
      await _settle(tester, net);
      expect(_rowAt(tester, 'room-chair-2'), contains('You'));
      expect(host.seated.map((s) => s.name), [namelessPlayer]);

      host.sit(deck: _deck('hosts'), name: 'kit');
      await _settle(tester, net);
      expect(_rowAt(tester, 'room-chair-1'), contains('kit'));
      expect(find.byKey(const Key('room-dealt')), findsNothing);
      expect(find.byType(PlayScreen), findsNothing);

      final mesh = host.start(
        (players) => sitDownTogether(players: players, seed: 'seed'),
      );
      await _settle(tester, net);

      // The table arrived and the guest is in front of it, looking out of the
      // seat under its own key. The host's phone deals and this one is handed
      // the result, so the controller here was seeded from the mesh and never
      // dealt anything.
      expect(container.read(lobbyProvider)!.dealt, isTrue);
      // The route is pushed from a listener, so it is on screen a frame
      // after the table arrived and not in the same one.
      await tester.pumpAndSettle();
      expect(find.byType(PlayScreen), findsOneWidget,
          reason: 'the guest reaches the table the moment it is dealt');
      final table = container.read(playProvider)!;
      expect(table.seats.map((s) => s.owner), [
        const SeatOwner.peer('kit'),
        const SeatOwner.peer('me'),
      ]);
      expect(container.read(viewerSeatProvider), 's2',
          reason: "the guest's seat is the one under its own key");
      // Its own hand, face up: seven cards in the sheet. The host's is a
      // count on a band and never a card.
      expect(tester.widget<HandSheet>(find.byType(HandSheet)).cards,
          hasLength(7));

      // A card the host moves lands here, at the same spot.
      final card = mesh.table!.zone('hand-s1')!.cards.first;
      mesh.run(MoveCard(
        cardId: card.id,
        toZoneId: 'battlefield-s1',
        position: (x: 0.25, y: 0.75),
      ));
      await _settle(tester, net);
      await tester.pumpAndSettle();
      final landed = container.read(playProvider)!.locate(card.id)!;
      expect(landed.zone.id, 'battlefield-s1');
      expect(landed.card.position, (x: 0.25, y: 0.75));
      // And drawn, by name: the host's battlefield is public, and the guest's
      // own deck carries the same printing. Found by the card rather than by
      // a band, because at this window the screen picks the canvas.
      final drawn = find.byWidgetPredicate(
        (w) => w is TableCard && w.instance.id == card.id,
      );
      expect(drawn, findsOneWidget,
          reason: "the host's card is on this screen once it moved");
      expect(tester.widget<TableCard>(drawn).printing?.name, 'Mountain');
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

      // A line and not a row. It answers "nobody is coming", which is not
      // what the room is for, and as a row with an icon it stood level with
      // Start and read as an equal way to play.
      final words = _textAt(tester, 'room-fill').toLowerCase();

      expect(words, contains('hands'));
      expect(words, contains('4'), reason: 'and how many it is filling');
      expect(words, isNot(contains('more than one seat')));
      expect(
        tester.widgetList<MenuRow>(find.byType(MenuRow)).map((r) => r.key),
        isNot(contains(const Key('room-fill'))),
        reason: 'it is a line now, not a row',
      );
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
      expect(table.seats.every((s) => s.owner.actableHere(me: 'me')), isTrue,
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
      final net = FakeNetwork();
      final container = _hosting(net, seats: 2, life: 30);
      await _pump(tester, container, const RoomScreen());

      await tester.tap(find.byKey(const Key('room-deck')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('deck-row-0')));
      await tester.pumpAndSettle();
      _friend(net, 'ana').bring(deck: _deck('anas'), name: 'ana');
      await _settle(tester, net);
      await tester.tap(find.byKey(const Key('room-start')));
      await tester.pumpAndSettle();

      // Commander starts on 40 and this room said 30. A starting life you can
      // edit and the table ignores is a setting that looks like it works.
      expect(container.read(playProvider)!.seats.map((s) => s.life), [30, 30]);
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
      expect(container.read(roomProvider)!.code, code);
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
      expect(container.read(roomProvider)!.code, 'aaaa-aaa');
      expect(_textAt(tester, 'room-answer').toLowerCase(),
          contains('waiting for the host'));
    });

    testWidgets('the first run is a wizard, not the menu', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await _pump(tester, _container(), const Entry());

      expect(find.byType(SetupScreen), findsOneWidget);
      expect(find.byType(MenuScreen), findsNothing);
      expect(find.byKey(const Key('setup-name')), findsOneWidget);
    });

    testWidgets('a room link on the first run runs the wizard and then lands '
        'in the room', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final code = freshRoomCode();
      final container = _container(launchCode: code);

      await _pump(tester, container, const Entry());

      // The link is the intent, so the wizard comes first and the room is
      // parked rather than dropped: a link that opens the menu after five
      // minutes of setup is worse than one that opens the menu.
      expect(find.byType(SetupScreen), findsOneWidget);
      expect(find.byType(RoomScreen), findsNothing);

      await tester.tap(find.byKey(const Key('setup-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('setup-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('setup-done')));
      await tester.pumpAndSettle();

      expect(find.byType(RoomScreen), findsOneWidget);
      expect(container.read(roomProvider)!.code, code);
    });

    testWidgets('the wizard is run once, and the menu after that',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final container = _container();
      await _pump(tester, container, const Entry());

      await tester.tap(find.byKey(const Key('setup-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('setup-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('setup-done')));
      await tester.pumpAndSettle();

      expect(find.byType(MenuScreen), findsOneWidget);
      expect(container.read(setupDoneProvider), isTrue);
    });

    testWidgets('and an ordinary launch still opens the menu', (tester) async {
      await _pump(tester, _container(), const Entry());

      expect(find.byType(MenuScreen), findsOneWidget);
      expect(find.byType(RoomScreen), findsNothing);
    });
  });
}
