import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/look_at_top.dart';
import 'package:kitchentable/features/play/widgets/deck_sheet.dart';
import 'package:kitchentable/table/model/card_instance.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

List<CardInstance> _top(int n) => [
      for (var i = 0; i < n; i++)
        CardInstance(id: 'c$i', oracleId: 'card$i'),
    ];

const _named = {
  'card0': CatalogCard(oracleId: 'card0', name: 'Sol Ring', typeLine: 'A', cmc: 1),
  'card1': CatalogCard(oracleId: 'card1', name: 'Demonic Tutor', typeLine: 'S', cmc: 2),
  'card2': CatalogCard(oracleId: 'card2', name: 'Sol Talisman', typeLine: 'A', cmc: 2),
};

Widget _host({
  int count = 53,
  Map<String, CatalogCard> printings = const {},
  VoidCallback? onShuffle,
  void Function(List<Placement>)? onArrange,
  Future<List<CardInstance>> Function(int)? peek,
}) =>
    MaterialApp(
      home: Scaffold(
        body: DeckSheet(
          metrics: Metrics.of(DeviceClass.handheld),
          count: count,
          printings: printings,
          peek: peek ?? (n) async => _top(n),
          onShuffle: onShuffle ?? () {},
          onArrange: onArrange ?? (_) {},
        ),
      ),
    );

void main() {
  testWidgets('it opens on the choices, not on the cards', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    // A library is hidden from everybody, its owner included. Opening this
    // sheet must not itself reveal anything: looking is a deliberate second
    // act.
    expect(find.byKey(const Key('deck-shuffle')), findsOneWidget);
    expect(find.byKey(const Key('deck-look')), findsOneWidget);
    expect(find.byKey(const Key('peeked-c0')), findsNothing);
  });

  testWidgets('shuffling asks first', (tester) async {
    var shuffled = 0;
    await tester.pumpWidget(_host(onShuffle: () => shuffled++));
    await tester.pump();

    await tester.tap(find.byKey(const Key('deck-shuffle')));
    await tester.pumpAndSettle();

    // Nothing has happened yet. Shuffling is the one act at a table that
    // cannot be undone by looking, so it gets a question.
    expect(shuffled, 0);
    expect(find.byKey(const Key('confirm-shuffle')), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm-shuffle')));
    await tester.pumpAndSettle();

    expect(shuffled, 1);
  });

  testWidgets('backing out of a shuffle shuffles nothing', (tester) async {
    var shuffled = 0;
    await tester.pumpWidget(_host(onShuffle: () => shuffled++));
    await tester.pump();

    await tester.tap(find.byKey(const Key('deck-shuffle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cancel-shuffle')));
    await tester.pumpAndSettle();

    expect(shuffled, 0);
  });

  testWidgets('looking shows the top cards', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    await tester.tap(find.byKey(const Key('deck-look')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peeked-c0')), findsOneWidget);
    expect(find.byKey(const Key('peeked-c1')), findsOneWidget);
  });

  testWidgets('each card gets a destination and the choices come back',
      (tester) async {
    List<Placement>? arranged;
    await tester.pumpWidget(_host(onArrange: (p) => arranged = p));
    await tester.pump();

    await tester.tap(find.byKey(const Key('deck-look')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('bottom-c0')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('deck-done')));
    await tester.pumpAndSettle();

    // Everything looked at comes back, not only the ones that were touched:
    // a card left alone is a card going back on top, and `arrange` needs it
    // in the list to know its order.
    expect(arranged, hasLength(2));
    expect(arranged!.first, (cardId: 'c0', to: Landing.bottom));
    expect(arranged!.last, (cardId: 'c1', to: Landing.top));
  });

  testWidgets('looking at a deck with fewer cards than asked for',
      (tester) async {
    await tester.pumpWidget(_host(count: 1, peek: (n) async => _top(1)));
    await tester.pump();

    await tester.tap(find.byKey(const Key('deck-look')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peeked-c0')), findsOneWidget);
    expect(find.byKey(const Key('peeked-c1')), findsNothing);
  });

  testWidgets('an empty deck offers nothing to look at', (tester) async {
    await tester.pumpWidget(_host(count: 0, peek: (n) async => const []));
    await tester.pump();

    expect(find.byKey(const Key('deck-look')), findsNothing);
    expect(find.byKey(const Key('deck-shuffle')), findsNothing);
  });

  testWidgets('the deck can be searched for a card by name', (tester) async {
    final arranged = <List<Placement>>[];
    var shuffled = 0;
    await tester.pumpWidget(_host(
      count: 3,
      printings: _named,
      onArrange: arranged.add,
      onShuffle: () => shuffled++,
    ));
    await tester.pump();

    // "Search your library for a card" is on hundreds of cards and there was
    // no way to do it: the deck offered shuffling and looking at the top few,
    // so a tutor meant looking at all of it in order.
    await tester.tap(find.byKey(const Key('deck-search')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peeked-c0')), findsOneWidget);
    expect(find.byKey(const Key('peeked-c1')), findsOneWidget);
    expect(find.byKey(const Key('peeked-c2')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('deck-filter')), 'tutor');
    await tester.pumpAndSettle();

    // By name and not by position: Demonic Tutor is the second card down and
    // the two Sol cards are the ones that share a prefix with each other.
    expect(find.byKey(const Key('peeked-c1')), findsOneWidget);
    expect(find.byKey(const Key('peeked-c0')), findsNothing);
    expect(find.byKey(const Key('peeked-c2')), findsNothing);

    await tester.tap(find.byKey(const Key('deck-done')));
    await tester.pumpAndSettle();

    // Every card is still reported, filtered or not: the filter is what you
    // can see, not what you are holding, and a card hidden by it is a card
    // going back where it was.
    expect(arranged.single, hasLength(3));

    // And a tutor shuffles. It is the rule on every card that says "search
    // your library", and it is the only thing that stops a search being a free
    // look at the whole deck in order.
    expect(shuffled, 1);
  });

  testWidgets('looking at the top few is not a search', (tester) async {
    var shuffled = 0;
    await tester.pumpWidget(
      _host(count: 3, printings: _named, onShuffle: () => shuffled++),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('deck-look')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('deck-filter')), findsNothing);

    await tester.tap(find.byKey(const Key('deck-done')));
    await tester.pumpAndSettle();

    // Looking at the top and putting it back is not a shuffle, and the sheet
    // says so out loud elsewhere: "this is the one thing here that looking
    // cannot undo".
    expect(shuffled, 0);
  });
}
