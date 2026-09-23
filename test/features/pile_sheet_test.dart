import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/look_at_top.dart';
import 'package:kitchentable/features/play/widgets/pile_sheet.dart';
import 'package:kitchentable/table/model/card_instance.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

List<CardInstance> _cards(int n) => [
      for (var i = 0; i < n; i++)
        CardInstance(id: 'c$i', oracleId: 'card$i'),
    ];

Widget _host({
  List<CardInstance> cards = const [],
  void Function(List<Placement>)? onArrange,
}) =>
    MaterialApp(
      home: Scaffold(
        body: PileSheet(
          metrics: Metrics.of(DeviceClass.handheld),
          label: 'Graveyard',
          cards: cards,
          printings: const {},
          onArrange: onArrange ?? (_) {},
        ),
      ),
    );

void main() {
  testWidgets('everything in the pile is there to read', (tester) async {
    await tester.pumpWidget(_host(cards: _cards(4)));
    await tester.pump();

    // A graveyard is public and always has been: unlike the deck, opening
    // this reveals nothing that was hidden, so there is no first step asking
    // whether you are sure.
    for (var i = 0; i < 4; i++) {
      expect(find.byKey(Key('pile-card-c$i')), findsOneWidget);
    }
  });

  testWidgets('an empty pile says so', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    expect(find.textContaining('Nothing'), findsOneWidget);
  });

  testWidgets('a card can be taken back out', (tester) async {
    List<Placement>? arranged;
    await tester.pumpWidget(
      _host(cards: _cards(3), onArrange: (p) => arranged = p),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('hand-c1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('pile-done')));
    await tester.pumpAndSettle();

    // Only what was moved. A graveyard is not ordered in any way anybody
    // cares about, so a card nobody touched has nowhere to be put back to.
    expect(arranged, [(cardId: 'c1', to: Landing.hand)]);
  });

  testWidgets('nothing chosen reports nothing', (tester) async {
    List<Placement>? arranged;
    await tester.pumpWidget(
      _host(cards: _cards(3), onArrange: (p) => arranged = p),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('pile-done')));
    await tester.pumpAndSettle();

    expect(arranged, isEmpty);
  });

  testWidgets('a card can go to the top of the deck or to the bottom',
      (tester) async {
    List<Placement>? arranged;
    await tester.pumpWidget(
      _host(cards: _cards(2), onArrange: (p) => arranged = p),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('top-c0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('bottom-c1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('pile-done')));
    await tester.pumpAndSettle();

    expect(arranged, hasLength(2));
    expect(arranged, contains((cardId: 'c0', to: Landing.top)));
    expect(arranged, contains((cardId: 'c1', to: Landing.bottom)));
  });

  testWidgets('a big pile comes a page at a time', (tester) async {
    await tester.pumpWidget(_host(cards: _cards(30)));
    await tester.pump();

    // Thirty rows in one scroll is a list you get lost in, and a graveyard in
    // a long game is a hundred.
    expect(find.byKey(const Key('pile-card-c0')), findsOneWidget);
    expect(find.byKey(const Key('pile-card-c29')), findsNothing);
    expect(find.textContaining('1'), findsWidgets);
  });

  testWidgets('the next page has the next cards', (tester) async {
    await tester.pumpWidget(_host(cards: _cards(30)));
    await tester.pump();

    await tester.tap(find.byKey(const Key('pile-next')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pile-card-c0')), findsNothing);
    expect(find.byKey(const Key('pile-card-c29')), findsWidgets);
  });

  testWidgets('a small pile has no pages to turn', (tester) async {
    await tester.pumpWidget(_host(cards: _cards(4)));
    await tester.pump();

    expect(find.byKey(const Key('pile-next')), findsNothing);
    expect(find.byKey(const Key('pile-back')), findsNothing);
  });

  testWidgets('a choice made on one page survives turning to another',
      (tester) async {
    List<Placement>? arranged;
    await tester.pumpWidget(
      _host(cards: _cards(30), onArrange: (p) => arranged = p),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('hand-c1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('pile-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pile-done')));
    await tester.pumpAndSettle();

    // The page is a window on the pile, not a form that resets.
    expect(arranged, [(cardId: 'c1', to: Landing.hand)]);
  });
}
