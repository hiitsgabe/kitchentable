import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/widgets/cursor_board.dart';
import 'package:kitchentable/features/play/widgets/table_card.dart';
import 'package:kitchentable/table/model/card_instance.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

Widget _host({
  int board = 3,
  int graveyard = 0,
  void Function(CardInstance)? onActivate,
  void Function(CardInstance)? onInspect,
  Map<String, ({double x, double y})> placed = const {},
  void Function(String zoneId, String id, double x, double y)? onPlace,
}) =>
    MaterialApp(
      home: Scaffold(
        body: CursorBoard(
          metrics: Metrics.of(DeviceClass.tv),
          zones: [
            (
              id: 'battlefield-s1',
              label: 'Battlefield',
              cards: [
                for (var i = 0; i < board; i++)
                  CardInstance(
                    id: 'b$i',
                    oracleId: 'card$i',
                    position: placed['b$i'],
                  ),
              ],
            ),
            (
              id: 'graveyard-s1',
              label: 'Graveyard',
              cards: [
                for (var i = 0; i < graveyard; i++)
                  CardInstance(id: 'g$i', oracleId: 'card$i'),
              ],
            ),
          ],
          printings: const {},
          onActivate: onActivate ?? (_) {},
          onInspect: onInspect ?? (_) {},
          onPlace: onPlace ?? (_, _, _, _) {},
        ),
      ),
    );

void main() {
  testWidgets('the ring starts on the first card', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    expect(find.byKey(const Key('ring-b0')), findsOneWidget);
    expect(find.byKey(const Key('ring-b1')), findsNothing);
  });

  testWidgets('right walks the ring along', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(find.byKey(const Key('ring-b1')), findsOneWidget);
    expect(find.byKey(const Key('ring-b0')), findsNothing);
  });

  testWidgets('the shoulder button changes pile', (tester) async {
    await tester.pumpWidget(_host(graveyard: 2));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(find.byKey(const Key('ring-g0')), findsOneWidget);
  });

  testWidgets('select acts on the card under the ring', (tester) async {
    CardInstance? acted;
    await tester.pumpWidget(_host(onActivate: (c) => acted = c));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(acted?.id, 'b1');
  });

  testWidgets('a tap acts on the card touched, not the one ringed',
      (tester) async {
    CardInstance? acted;
    await tester.pumpWidget(_host(onActivate: (c) => acted = c));
    await tester.pump();

    // The ring is on b0 and the finger is on b2. This board is reached by
    // thumb far more often than by D-pad, and the two must not disagree about
    // which card the player meant.
    expect(find.byKey(const Key('ring-b0')), findsOneWidget);
    await tester.tap(find.byType(TableCard).at(2));
    await tester.pump();

    expect(acted?.id, 'b2');
  });

  testWidgets('a long press inspects rather than acts', (tester) async {
    CardInstance? acted;
    CardInstance? inspected;
    await tester.pumpWidget(_host(
      onActivate: (c) => acted = c,
      onInspect: (c) => inspected = c,
    ));
    await tester.pump();

    await tester.longPress(find.byType(TableCard).at(1));
    await tester.pump();

    expect(inspected?.id, 'b1');
    expect(acted, isNull, reason: 'a long press must not also turn the card');
  });

  testWidgets('an empty board draws no ring and does not crash',
      (tester) async {
    await tester.pumpWidget(_host(board: 0));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(find.textContaining('Nothing'), findsOneWidget);
  });

  testWidgets('a card with a position sits where it says', (tester) async {
    await tester.pumpWidget(_host(placed: {
      'b1': (x: 0.8, y: 0.2),
    }));
    await tester.pump();

    final placed = tester.getRect(find.byType(TableCard).at(1));
    final flowed = tester.getRect(find.byType(TableCard).at(0));

    expect(placed.left, greaterThan(flowed.left));
  });

  testWidgets('dragging a card reports where it was dropped', (tester) async {
    ({String id, double x, double y})? dropped;
    await tester.pumpWidget(_host(onPlace: (_, id, x, y) {
      dropped = (id: id, x: x, y: y);
    }));
    await tester.pump();

    await tester.drag(find.byType(TableCard).first, const Offset(120, 90));
    await tester.pump();

    expect(dropped?.id, 'b0');
    expect(dropped!.x, greaterThan(0));
    expect(dropped!.y, greaterThan(0));
  });

  testWidgets('a drop is reported normalized, never in pixels',
      (tester) async {
    ({String id, double x, double y})? dropped;
    await tester.pumpWidget(_host(onPlace: (_, id, x, y) {
      dropped = (id: id, x: x, y: y);
    }));
    await tester.pump();

    await tester.drag(find.byType(TableCard).first, const Offset(60, 40));
    await tester.pump();

    // 0 to 1 against this seat's mat, which is what lets a phone and a
    // television show the same arrangement.
    //
    // Strictly inside the range, not merely within it. Production clamps its
    // own output to 0 and 1, so asserting the range is asserting the clamp's
    // postcondition and cannot fail whatever the arithmetic does. A mutation
    // that reported raw pixels survived exactly that assertion, because 93
    // clamps to 1.0 and 1.0 is in range.
    expect(dropped!.x, lessThan(1));
    expect(dropped!.y, lessThan(1));
    expect(dropped!.x, greaterThan(0));
  });

  testWidgets('a longer drag lands further along than a shorter one',
      (tester) async {
    Future<double> dropAfter(double dx) async {
      double? x;
      await tester.pumpWidget(_host(onPlace: (_, _, at, _) => x = at));
      await tester.pump();
      await tester.drag(find.byType(TableCard).first, Offset(dx, 0));
      await tester.pump();
      return x!;
    }

    final short = await dropAfter(40);
    final long = await dropAfter(120);

    // Two drags of different lengths have to land in different places. In
    // pixels both would be past the mat's width and both would clamp to 1.0,
    // so this is the assertion the range check could not make.
    expect(long, greaterThan(short));
  });

  testWidgets('a card lands where the finger let go, not short of it',
      (tester) async {
    double? x;
    await tester.pumpWidget(_host(onPlace: (_, _, at, _) => x = at));
    await tester.pump();

    final card = tester.getCenter(find.byType(TableCard).first);
    await tester.drag(find.byType(TableCard).first, const Offset(200, 0));
    await tester.pumpAndSettle();

    final mat = tester.getRect(find.byKey(const Key('mat-battlefield-s1')));
    // Where the pointer actually ended, normalised against the mat it ended
    // over. A drag driven by summed deltas used to land about kTouchSlop
    // short of this, because the first stretch of travel is never reported;
    // a drop position taken from the pointer cannot.
    //
    // A billionth, and not the fiftieth of a mat a drag used to need. The
    // tolerance is here only because the two sides divide in a different
    // order and the last bit of the double disagrees: measured at
    // 0.35281250000000003 against 0.3528125. Anything looser is room for the
    // old bug to hide in, since eighteen pixels of an eight hundred pixel mat
    // is 0.0225.
    expect(x, closeTo((card.dx + 200 - mat.left) / mat.width, 1e-9));
  });

  testWidgets('a drag does not also activate the card', (tester) async {
    CardInstance? acted;
    await tester.pumpWidget(_host(
      onActivate: (c) => acted = c,
      onPlace: (_, _, _, _) {},
    ));
    await tester.pump();

    await tester.drag(find.byType(TableCard).first, const Offset(100, 60));
    await tester.pump();

    expect(acted, isNull, reason: 'dragging a card must not turn it');
  });
}
