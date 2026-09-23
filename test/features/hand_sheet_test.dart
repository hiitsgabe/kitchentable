import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/decks/model/game.dart';
import 'package:kitchentable/features/play/widgets/hand_sheet.dart';
import 'package:kitchentable/features/play/widgets/table_card.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';
import 'package:kitchentable/table/model/card_instance.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

List<CardInstance> _hand(int n) => [
      for (var i = 0; i < n; i++)
        CardInstance(id: 'h$i', oracleId: 'card$i'),
    ];

/// A printing for the first card in hand, because a preview is only ever
/// drawn for a card the catalog has heard of. Without one the hover case
/// below would find nothing whatever the code did.
const _printing = CatalogCard(
  oracleId: 'card0',
  name: 'Sol Ring',
  typeLine: 'Artifact',
  cmc: 1,
  imageSmall: 'small.jpg',
);

Widget _host({
  int cards = 3,
  Map<String, CatalogCard> printings = const {},
  void Function(String cardId, int to)? onReorder,
  Game? game,
}) =>
    MaterialApp(
      home: Scaffold(
        body: HandSheet(
          metrics: Metrics.of(DeviceClass.handheld),
          cards: _hand(cards),
          printings: printings,
          onPlay: (_) {},
          onInspect: (_) {},
          onReorder: onReorder ?? (_, _) {},
          game: game,
        ),
      ),
    );

void main() {
  testWidgets('a few cards sit in the middle, not against the left edge',
      (tester) async {
    await tester.pumpWidget(_host(cards: 3));
    await tester.pump();

    final sheet = tester.getRect(find.byType(HandSheet));
    final first = tester.getRect(find.byType(TableCard).first);
    final last = tester.getRect(find.byType(TableCard).last);

    final leftGap = first.left - sheet.left;
    final rightGap = sheet.right - last.right;

    expect(leftGap, greaterThan(1), reason: 'it was pinned to the left edge');
    expect(leftGap, closeTo(rightGap, 1));
  });

  testWidgets('a full hand still fills the width', (tester) async {
    await tester.pumpWidget(_host(cards: 30));
    await tester.pump();

    final sheet = tester.getRect(find.byType(HandSheet));
    final first = tester.getRect(find.byType(TableCard).first);

    // Thirty cards used to scroll and now they wrap, and either way a hand
    // that does not fit across must not be drawn short of the sheet it is in:
    // the cards shrink until the line spans the width there is.
    expect(first.left, closeTo(sheet.left, 12));
  });

  testWidgets('an empty hand says so', (tester) async {
    await tester.pumpWidget(_host(cards: 0));

    expect(find.textContaining('No cards'), findsOneWidget);
  });

  testWidgets('a card dragged sideways reports where it was put',
      (tester) async {
    ({String id, int to})? moved;
    await tester.pumpWidget(_host(
      cards: 4,
      onReorder: (id, to) => moved = (id: id, to: to),
    ));
    await tester.pump();

    final third = tester.getCenter(find.byType(TableCard).at(2));
    final gesture = await tester.startGesture(third);
    await tester.pump(const Duration(milliseconds: 40));
    await gesture.moveTo(tester.getCenter(find.byType(TableCard).first));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(moved?.id, 'h2');
    expect(moved?.to, 0);
  });

  testWidgets('a tap still plays the card', (tester) async {
    CardInstance? played;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HandSheet(
          metrics: Metrics.of(DeviceClass.handheld),
          cards: _hand(3),
          printings: const {},
          onPlay: (c) => played = c,
          onInspect: (_) {},
          onReorder: (_, _) {},
        ),
      ),
    ));
    await tester.pump();

    // Adding a drag to a widget that already had a tap is how a tap stops
    // working. It did, once, on the board.
    await tester.tap(find.byType(TableCard).first);
    await tester.pump();

    expect(played?.id, 'h0');
  });

  testWidgets('a card in hand does grow under the pointer', (tester) async {
    await tester.pumpWidget(_host(printings: const {'card0': _printing}));
    await tester.pump();

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await tester.pump();

    await mouse.moveTo(tester.getCenter(find.byType(TableCard).first));
    await tester.pumpAndSettle();

    // The hand draws at 64 points, where you cannot read a word.
    expect(find.byKey(const Key('hover-preview')), findsOneWidget);
  });

  testWidgets('a hand too wide to fit wraps instead of scrolling',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(cards: 16));
    await tester.pump();

    final sheet = tester.getRect(find.byType(HandSheet));
    final first = tester.getRect(find.byType(TableCard).first);
    final last = tester.getRect(find.byType(TableCard).last);

    // Every card on screen, on more than one line. Scrolling was never
    // reachable: a card's own drag wins the gesture arena over the list's,
    // so dragging rearranged the hand instead of moving it, and there was no
    // other way to reach the far end.
    expect(last.right, lessThanOrEqualTo(sheet.right + 1));
    expect(last.top, greaterThan(first.top),
        reason: 'sixteen cards are still on one line');
  });

  testWidgets('a hand that fits stays on one line', (tester) async {
    await tester.pumpWidget(_host(cards: 3));
    await tester.pump();

    final first = tester.getRect(find.byType(TableCard).first);
    final last = tester.getRect(find.byType(TableCard).last);

    expect(last.top, first.top);
  });

  testWidgets('the sheet grows for a second line but not without end',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(cards: 3));
    await tester.pump();
    final one = tester.getSize(find.byType(HandSheet)).height;

    await tester.pumpWidget(_host(cards: 16));
    await tester.pump();
    final two = tester.getSize(find.byType(HandSheet)).height;

    await tester.pumpWidget(_host(cards: 60));
    await tester.pump();
    final many = tester.getSize(find.byType(HandSheet)).height;

    expect(two, greaterThan(one));
    // A hand of sixty is a Battle of Wits deck and it still cannot be allowed
    // to eat the battlefield. Past the cap the cards get smaller instead.
    expect(many, two);
  });

  testWidgets('a short last line sits under the middle of the one above',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(cards: 7));
    await tester.pump();

    // Five across and two under them. Nothing above pins this: a Wrap sizes
    // itself to its widest line, so its own `alignment` has no room to spend
    // and left aligning it leaves every case here green. What centres the
    // whole hand is the Center around it, and what centres the short line
    // inside it is the Wrap, and the drop arithmetic below counts on it.
    final top = tester.getRect(find.byType(TableCard).at(4));
    final firstBelow = tester.getRect(find.byType(TableCard).at(5));
    final lastBelow = tester.getRect(find.byType(TableCard).at(6));
    final leftOfAll = tester.getRect(find.byType(TableCard).first).left;

    expect(firstBelow.left - leftOfAll, greaterThan(1),
        reason: 'the short line was flushed to the left');
    expect(firstBelow.left - leftOfAll, closeTo(top.right - lastBelow.right, 1));
  });

  testWidgets('a card dropped on the short line lands on that line',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    ({String id, int to})? moved;
    await tester.pumpWidget(_host(
      cards: 7,
      onReorder: (id, to) => moved = (id: id, to: to),
    ));
    await tester.pump();

    // The first card of the second line, which is where a wrapped hand stops
    // being x over a pitch. Counting the column from the left of the widest
    // line instead of from where this short one starts reads this drop as the
    // sixth place rather than the fifth, and both are in range, so the clamp
    // at either end does not save it.
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(TableCard).first));
    await tester.pump(const Duration(milliseconds: 40));
    await gesture.moveTo(tester.getCenter(find.byType(TableCard).at(5)));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(moved?.id, 'h0');
    expect(moved?.to, 5);
  });

  testWidgets('a card in hand is drawn on the game s own back',
      (tester) async {
    await tester.pumpWidget(_host(cards: 1, game: Game.magic));
    await tester.pump();

    // Nothing in this hand has a printing, so the back is what is drawn, and
    // whose back it is only reaches the card if the sheet passes the game on.
    // Dropping that one argument leaves every other case here green.
    expect(find.byKey(const Key('card-back-art')), findsOneWidget);
  });
}
