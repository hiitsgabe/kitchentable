import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/widgets/hover_card.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';
import 'package:kitchentable/table/model/card_instance.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

const _printing = CatalogCard(
  oracleId: 'o',
  name: 'Sol Ring',
  typeLine: 'Artifact',
  cmc: 1,
  imageSmall: 'small.jpg',
);

Widget _host({bool faceDown = false}) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: HoverCard(
            metrics: Metrics.of(DeviceClass.handheld),
            instance: CardInstance(
              id: 'a',
              oracleId: 'o',
              faceDown: faceDown,
            ),
            printing: _printing,
            width: 60,
            // Without a child the widget has no size at all, so there is
            // nothing for a pointer to be over and every case below would
            // pass for the wrong reason.
            child: const SizedBox(width: 60, height: 84),
          ),
        ),
      ),
    );

/// The same app without the card, so pumping this over [_host] takes the
/// card out of the tree while the overlay it drew into stays.
Widget _empty() => const MaterialApp(home: Scaffold(body: SizedBox()));

void main() {
  testWidgets('nothing is shown until a pointer is over it', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    expect(find.byKey(const Key('hover-preview')), findsNothing);
  });

  testWidgets('a pointer over the card brings up a bigger one',
      (tester) async {
    await tester.pumpWidget(_host());

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await tester.pump();

    await mouse.moveTo(tester.getCenter(find.byType(HoverCard)));
    await tester.pump();

    expect(find.byKey(const Key('hover-preview')), findsOneWidget);
  });

  testWidgets('moving away puts it back', (tester) async {
    await tester.pumpWidget(_host());

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await tester.pump();

    await mouse.moveTo(tester.getCenter(find.byType(HoverCard)));
    await tester.pump();
    await mouse.moveTo(const Offset(5, 5));
    await tester.pump();

    expect(find.byKey(const Key('hover-preview')), findsNothing);
  });

  testWidgets('a card lying face down keeps its face', (tester) async {
    await tester.pumpWidget(_host(faceDown: true));

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await tester.pump();

    await mouse.moveTo(tester.getCenter(find.byType(HoverCard)));
    await tester.pump();

    // Every card on the table is wrapped in one of these, so a hover that
    // ignored this would read the back of a card off the screen.
    expect(find.byKey(const Key('hover-preview')), findsNothing);
  });

  testWidgets('a preview leaves with the card that raised it',
      (tester) async {
    await tester.pumpWidget(_host());

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await tester.pump();

    await mouse.moveTo(tester.getCenter(find.byType(HoverCard)));
    await tester.pump();
    expect(find.byKey(const Key('hover-preview')), findsOneWidget);

    // A card is played out of the zone it was sitting in while the pointer is
    // still on it. There is no exit for a widget that is simply gone, so the
    // preview has to come down on dispose or it outlives the card.
    await tester.pumpWidget(_empty());
    await tester.pump();

    expect(find.byKey(const Key('hover-preview')), findsNothing);
  });

  testWidgets('a touch does not raise it', (tester) async {
    await tester.pumpWidget(_host());

    // A finger has no hover. On a phone this widget must be inert, or every
    // tap would flash a preview.
    await tester.tap(find.byType(HoverCard));
    await tester.pump();

    expect(find.byKey(const Key('hover-preview')), findsNothing);
  });
}
