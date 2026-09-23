import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/decks/model/game.dart';
import 'package:kitchentable/features/play/renderers/stacked_seats.dart';
import 'package:kitchentable/features/play/widgets/seat_band.dart';
import 'package:kitchentable/table/model/card_instance.dart';
import 'package:kitchentable/table/model/seat.dart';
import 'package:kitchentable/table/model/zone.dart';
import 'package:kitchentable/table/view/seat_view.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

Seat _seat(String id, {int board = 0}) => Seat(
      id: id,
      name: 'seat $id',
      life: 40,
      zones: [
        Zone(
          id: 'hand-$id',
          seatId: id,
          label: 'hand',
          visibility: ZoneVisibility.owner,
          ordered: false,
          cards: [CardInstance(id: '$id-h0', oracleId: 'c0')],
        ),
        Zone(
          id: 'battlefield-$id',
          seatId: id,
          label: 'battlefield',
          visibility: ZoneVisibility.public,
          ordered: false,
          cards: [
            for (var i = 0; i < board; i++)
              CardInstance(id: '$id-b$i', oracleId: 'c$i'),
          ],
        ),
      ],
    );

Widget _host(
  List<String> seatIds, {
  String viewer = 's1',
  void Function(String)? onFocusSeat,
  Game? Function(String seatId)? gameFor,
  int board = 0,
}) =>
    MaterialApp(
      home: Scaffold(
        body: StackedSeats(
          metrics: Metrics.of(DeviceClass.handheld),
          seats: [
            for (final id in seatIds)
              SeatView.of(_seat(id, board: board), viewer: viewer),
          ],
          viewerSeatId: viewer,
          printings: const {},
          onFocusSeat: onFocusSeat ?? (_) {},
          gameFor: gameFor,
          yours: const ColoredBox(
            key: Key('your-seat'),
            color: Color(0xFF000000),
            child: SizedBox.expand(),
          ),
        ),
      ),
    );


/// The default 800x600 surface leaves the band column 240 logical pixels,
/// which is two of a 122 pixel band: the rest scrolls, and a band in the cache
/// region is offstage, where the default finders will not look. These cases
/// are about where a band goes, not about scrolling, so give the surface room
/// for every band to be on screen at once.
void _roomForBands(WidgetTester tester) {
  tester.view.physicalSize = const Size(2400, 3000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('everybody but you gets a band', (tester) async {
    _roomForBands(tester);
    await tester.pumpWidget(_host(['s1', 's2', 's3', 's4']));

    expect(find.byType(SeatBand), findsNWidgets(3));
    expect(find.byKey(const Key('band-s1')), findsNothing);
    expect(find.byKey(const Key('band-s4')), findsOneWidget);
  });

  testWidgets('your seat sits below every band', (tester) async {
    _roomForBands(tester);
    await tester.pumpWidget(_host(['s1', 's2', 's3']));

    final yours = tester.getRect(find.byKey(const Key('your-seat')));
    for (final id in ['s2', 's3']) {
      final band = tester.getRect(find.byKey(Key('band-$id')));
      expect(yours.top, greaterThanOrEqualTo(band.bottom - 1),
          reason: 'your seat must start at or below where $id ends');
    }
  });

  testWidgets('a table of one is your seat and nothing else', (tester) async {
    _roomForBands(tester);
    await tester.pumpWidget(_host(['s1']));

    expect(find.byType(SeatBand), findsNothing);
    expect(find.byKey(const Key('your-seat')), findsOneWidget);
  });

  testWidgets('tapping a band asks to look out of that seat', (tester) async {
    _roomForBands(tester);
    String? asked;
    await tester.pumpWidget(_host(['s1', 's2'], onFocusSeat: (id) => asked = id));

    await tester.tap(find.byKey(const Key('band-s2')));
    await tester.pump();

    expect(asked, 's2');
  });

  testWidgets('a spectator gets a band for everybody', (tester) async {
    _roomForBands(tester);
    // Nobody is looking, which is plan 3 arriving as a spectator. Every seat
    // is somebody else, so every seat is a band.
    await tester.pumpWidget(_host(['s1', 's2'], viewer: ''));

    expect(find.byType(SeatBand), findsNWidgets(2));
  });

  testWidgets('each band is handed its own seat s game', (tester) async {
    _roomForBands(tester);
    await tester.pumpWidget(_host(
      ['s1', 's2', 's3'],
      board: 1,
      gameFor: (seatId) => seatId == 's2' ? Game.magic : null,
    ));
    await tester.pump();

    // Asked per seat and not taken once for the table. Two bands are drawn and
    // only s2 is playing Magic, so taking one game for the lot would draw two
    // backs or none depending on whose it was, and reading the viewer's would
    // draw none.
    expect(
      find.descendant(
        of: find.byKey(const Key('band-s2')),
        matching: find.byKey(const Key('card-back-art')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('band-s3')),
        matching: find.byKey(const Key('card-back-art')),
      ),
      findsNothing,
    );
  });
}
