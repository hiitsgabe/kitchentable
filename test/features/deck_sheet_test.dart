import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/look_at_top.dart';
import 'package:kitchentable/features/play/widgets/deck_sheet.dart';
import 'package:kitchentable/features/play/widgets/sheet_parts.dart';
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

    // Nothing is lit until you choose. Looking at the top few opens with
    // `top` on every row, because a card you leave alone there is going back
    // on top; searching, the other ninety two cards are not going anywhere and
    // saying they were is how the whole deck got rearranged by a tutor.
    //
    // Reading the row's own state and not the placements it ends up sending:
    // sending the right thing while showing every card lit up as going to the
    // top is exactly what this looked like, and no case here could tell.
    expect(tester.widget<CardRow>(find.byKey(const Key('peeked-c1'))).chosen,
        isNull);

    await tester.tap(find.byKey(const Key('hand-c1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('deck-done')));
    await tester.pumpAndSettle();

    // Only the card you chose. The two the filter hid are not in here either,
    // and neither is the one it showed and you left alone.
    expect(arranged.single, [(cardId: 'c1', to: Landing.hand)]);

    // And a tutor shuffles. It is the rule on every card that says "search
    // your library", and it is the only thing that stops a search being a free
    // look at the whole deck in order.
    expect(shuffled, 1);
  });

  testWidgets('a search moves nothing you did not choose', (tester) async {
    final arranged = <List<Placement>>[];
    await tester.pumpWidget(
      _host(count: 3, printings: _named, onArrange: arranged.add),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('deck-search')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('deck-done')));
    await tester.pumpAndSettle();

    // Opening the search and closing it again is not a move. It used to report
    // all three as going to the top, which is a rearrangement of the whole
    // deck dressed up as a no-op.
    expect(arranged.single, isEmpty);
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

    // And the other way round: looking does open with the top lit, which is
    // the behaviour the search case above is the exception to.
    expect(tester.widget<CardRow>(find.byKey(const Key('peeked-c0'))).chosen,
        Landing.top);

    await tester.tap(find.byKey(const Key('deck-done')));
    await tester.pumpAndSettle();

    // Looking at the top and putting it back is not a shuffle, and the sheet
    // says so out loud elsewhere: "this is the one thing here that looking
    // cannot undo".
    expect(shuffled, 0);
  });
}
