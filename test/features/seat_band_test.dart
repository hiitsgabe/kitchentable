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

void main() {
  testWidgets('an opponent shows how many cards, never which', (tester) async {
    final them = SeatView.of(_seat('s2', hand: 3), viewer: 's1');
    await tester.pumpWidget(_host(them));

    expect(find.text('hand 3'), findsOneWidget);
    // Their battlefield is empty, so every card in the tree would have to have
    // come out of their hand. There are none, because the view never carried
    // them this far.
    expect(find.byType(TableCard), findsNothing);
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
