import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/widgets/seat_band.dart';
import 'package:kitchentable/features/play/widgets/table_card.dart';
import 'package:kitchentable/table/model/card_instance.dart';
import 'package:kitchentable/table/model/seat.dart';
import 'package:kitchentable/table/model/zone.dart';
import 'package:kitchentable/table/view/seat_view.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

Zone _zone(String kind, String seatId, ZoneVisibility v, int n) => Zone(
      id: '$kind-$seatId',
      seatId: seatId,
      label: kind,
      visibility: v,
      ordered: false,
      cards: [
        for (var i = 0; i < n; i++)
          CardInstance(id: '$seatId-$kind-$i', oracleId: 'card$i'),
      ],
    );

Seat _seat(String id, {int life = 40, int hand = 3, int board = 0}) => Seat(
      id: id,
      name: 'seat $id',
      life: life,
      zones: [
        _zone('hand', id, ZoneVisibility.owner, hand),
        _zone('battlefield', id, ZoneVisibility.public, board),
      ],
    );

Widget _host(SeatView seat, {void Function()? onTap}) => MaterialApp(
      home: Scaffold(
        body: SeatBand(
          metrics: Metrics.of(DeviceClass.handheld),
          seat: seat,
          printings: const {},
          onTap: onTap ?? () {},
        ),
      ),
    );

/// A view that leaks on purpose: the hand arrives full and readable.
///
/// [SeatView] would never build this, and that is the point. Handing the band
/// a correct view proves nothing about the band, because a band that read the
/// hand would find it empty and draw nothing either way. The band is what is
/// under test here, so it is given a view that would let it misbehave.
SeatView _leaking({int hand = 7, int board = 1}) => SeatView(
      seatId: 's2',
      name: 'seat s2',
      life: 40,
      isViewer: false,
      zones: [
        ZoneView(
          id: 'battlefield-s2',
          label: 'battlefield',
          count: board,
          readable: true,
          cards: [
            for (var i = 0; i < board; i++)
              CardInstance(id: 's2-b$i', oracleId: 'card$i'),
          ],
        ),
        ZoneView(
          id: 'hand-s2',
          label: 'hand',
          count: hand,
          readable: true,
          cards: [
            for (var i = 0; i < hand; i++)
              CardInstance(id: 's2-h$i', oracleId: 'card$i'),
          ],
        ),
      ],
    );

void main() {
  testWidgets('an opponent shows how many cards, never which', (tester) async {
    await tester.pumpWidget(_host(_leaking(hand: 7, board: 1)));

    expect(find.text('hand 7'), findsOneWidget);
    // One card drawn, and it is the one on the battlefield. The seven in the
    // hand are right there in the view and the band must still not reach for
    // them: a pile other than the battlefield is not the band's to draw.
    expect(find.byType(TableCard), findsNWidgets(1));
  });

  testWidgets('a battlefield is drawn, because everybody can see it',
      (tester) async {
    final them = SeatView.of(_seat('s2', board: 2), viewer: 's1');
    await tester.pumpWidget(_host(them));

    expect(find.byType(TableCard), findsNWidgets(2));
  });

  testWidgets('an empty battlefield says so', (tester) async {
    final them = SeatView.of(_seat('s2'), viewer: 's1');
    await tester.pumpWidget(_host(them));

    expect(find.text('nothing out'), findsOneWidget);
  });

  testWidgets('life shows, and a dead seat still shows it', (tester) async {
    final them = SeatView.of(_seat('s2', life: -2), viewer: 's1');
    await tester.pumpWidget(_host(them));

    expect(find.text('-2'), findsOneWidget);
  });

  testWidgets('tapping the band reports it', (tester) async {
    var tapped = false;
    final them = SeatView.of(_seat('s2'), viewer: 's1');
    await tester.pumpWidget(_host(them, onTap: () => tapped = true));

    await tester.tap(find.byKey(const Key('band-s2')));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
