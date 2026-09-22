import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/widgets/radar_strip.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

Widget _host({
  required List<({String seatId, String name, int life})> seats,
  String? focused,
  void Function(String)? onJump,
}) =>
    MaterialApp(
      home: Scaffold(
        body: RadarStrip(
          metrics: Metrics.of(DeviceClass.handheld),
          seats: seats,
          focusedSeatId: focused,
          onJump: onJump ?? (_) {},
        ),
      ),
    );

void main() {
  testWidgets('every life total is on screen at once', (tester) async {
    await tester.pumpWidget(_host(seats: const [
      (seatId: 's1', name: 'you', life: 40),
      (seatId: 's2', name: 'Carla', life: 28),
      (seatId: 's3', name: 'Diego', life: 19),
      (seatId: 's4', name: 'Bruno', life: 34),
    ]));

    // The whole argument for bands over tabs: a threat you are not looking at
    // is a threat you forget.
    expect(find.text('40'), findsOneWidget);
    expect(find.text('28'), findsOneWidget);
    expect(find.text('19'), findsOneWidget);
    expect(find.text('34'), findsOneWidget);
  });

  testWidgets('tapping one asks to jump to it', (tester) async {
    String? jumped;
    await tester.pumpWidget(_host(
      seats: const [
        (seatId: 's1', name: 'you', life: 40),
        (seatId: 's2', name: 'Carla', life: 28),
      ],
      onJump: (id) => jumped = id,
    ));

    await tester.tap(find.text('Carla'));
    await tester.pump();

    expect(jumped, 's2');
  });

  testWidgets('a dead seat is still counted, at zero or below',
      (tester) async {
    await tester.pumpWidget(_host(seats: const [
      (seatId: 's1', name: 'you', life: 40),
      (seatId: 's2', name: 'Carla', life: -3),
    ]));

    expect(find.text('-3'), findsOneWidget);
  });

  testWidgets('one seat still draws a strip', (tester) async {
    await tester.pumpWidget(_host(seats: const [
      (seatId: 's1', name: 'you', life: 40),
    ]));

    expect(find.text('40'), findsOneWidget);
  });
}
