import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/renderers/free_canvas.dart';
import 'package:kitchentable/features/play/widgets/table_card.dart';
import 'package:kitchentable/table/model/card_instance.dart';
import 'package:kitchentable/table/model/seat.dart';
import 'package:kitchentable/table/model/zone.dart';
import 'package:kitchentable/table/view/seat_view.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

Zone _zone(String kind, String seatId, ZoneVisibility v, List<CardInstance> c) =>
    Zone(
      id: '$kind-$seatId',
      seatId: seatId,
      label: kind,
      visibility: v,
      ordered: false,
      cards: c,
    );

Seat _seat(String id, {int board = 1, int hand = 2}) => Seat(
      id: id,
      name: 'seat $id',
      life: 40,
      zones: [
        _zone('battlefield', id, ZoneVisibility.public, [
          for (var i = 0; i < board; i++)
            CardInstance(id: '$id-b$i', oracleId: 'c$i'),
        ]),
        _zone('hand', id, ZoneVisibility.owner, [
          for (var i = 0; i < hand; i++)
            CardInstance(id: '$id-h$i', oracleId: 'c$i'),
        ]),
      ],
    );

Widget _host(
  List<Seat> seats, {
  String viewer = 's1',
  void Function(CardInstance)? onTapCard,
  void Function(String cardId, double x, double y)? onPlace,
}) =>
    MaterialApp(
      home: Scaffold(
        body: FreeCanvas(
          metrics: Metrics.of(DeviceClass.handheld),
          seats: [for (final s in seats) SeatView.of(s, viewer: viewer)],
          viewerSeatId: viewer,
          printings: const {},
          onTapCard: onTapCard ?? (_) {},
          onInspectCard: (_) {},
          onPlace: onPlace ?? (_, _, _) {},
        ),
      ),
    );

void main() {
  testWidgets('every seat gets a mat with its name on it', (tester) async {
    await tester.pumpWidget(_host([_seat('s1'), _seat('s2'), _seat('s3')]));

    expect(find.byKey(const Key('mat-s1')), findsOneWidget);
    expect(find.byKey(const Key('mat-s2')), findsOneWidget);
    expect(find.byKey(const Key('mat-s3')), findsOneWidget);
    expect(find.text('seat s2 · 40'), findsOneWidget);
  });

  testWidgets('a battlefield is drawn for everybody', (tester) async {
    await tester.pumpWidget(_host([_seat('s1', board: 2), _seat('s2', board: 3)]));

    expect(find.byType(TableCard), findsNWidgets(5));
  });

  testWidgets('no hand is on the canvas, not even your own', (tester) async {
    await tester.pumpWidget(_host([_seat('s1', board: 1, hand: 2)]));

    // The hand lives in its own sheet below the board, and a hand on the mat
    // is the Arena mistake the spec rules out by geometry.
    expect(find.byKey(const Key('card-s1-h0')), findsNothing);
    expect(find.byKey(const Key('card-s1-b0')), findsOneWidget);
  });

  testWidgets('tapping a card reports it', (tester) async {
    CardInstance? tapped;
    await tester.pumpWidget(
      _host([_seat('s1', board: 1)], onTapCard: (c) => tapped = c),
    );

    await tester.tap(find.byKey(const Key('card-s1-b0')));
    await tester.pump();

    expect(tapped?.id, 's1-b0');
  });

  testWidgets('a card that says where it is goes there', (tester) async {
    final placed = Seat(
      id: 's1',
      name: 'seat s1',
      life: 40,
      zones: [
        _zone('battlefield', 's1', ZoneVisibility.public, [
          const CardInstance(
            id: 's1-b0',
            oracleId: 'c0',
            position: (x: 0.9, y: 0.1),
          ),
          const CardInstance(id: 's1-b1', oracleId: 'c1'),
        ]),
      ],
    );
    await tester.pumpWidget(_host([placed]));

    final positioned = tester.getRect(find.byKey(const Key('card-s1-b0')));
    final flowed = tester.getRect(find.byKey(const Key('card-s1-b1')));

    // Nothing writes position yet. This is the first thing that would show it
    // if something did, which is the only reason the field is not dead code.
    expect(positioned.left, greaterThan(flowed.left));
  });

  testWidgets('you can move your own cards here too', (tester) async {
    ({String id, double x, double y})? dropped;
    await tester.pumpWidget(_host(
      [_seat('s1', board: 1)],
      onPlace: (id, x, y) => dropped = (id: id, x: x, y: y),
    ));
    await tester.pump();

    await tester.drag(find.byKey(const Key('card-s1-b0')),
        const Offset(120, 60));
    await tester.pump();

    expect(dropped?.id, 's1-b0');
    expect(dropped!.x, inExclusiveRange(0, 1));
  });

  testWidgets('somebody else s cards are not yours to move', (tester) async {
    ({String id, double x, double y})? dropped;
    await tester.pumpWidget(_host(
      [_seat('s1', board: 1), _seat('s2', board: 1)],
      onPlace: (id, x, y) => dropped = (id: id, x: x, y: y),
    ));
    await tester.pump();

    await tester.drag(find.byKey(const Key('card-s2-b0')),
        const Offset(120, 60));
    await tester.pump();

    expect(dropped, isNull);
  });

  testWidgets('your mat is the last one, nearest your hand', (tester) async {
    await tester.pumpWidget(_host(
      [_seat('s1'), _seat('s2'), _seat('s3')],
      viewer: 's2',
    ));
    await tester.pump();

    final mine = tester.getRect(find.byKey(const Key('mat-s2')));
    for (final id in ['s1', 's3']) {
      expect(mine.top, greaterThanOrEqualTo(
        tester.getRect(find.byKey(Key('mat-$id'))).top,
      ), reason: 'mat $id should not be below yours');
    }
  });
}
