import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/look_at_top.dart';
import 'package:kitchentable/features/play/widgets/deck_sheet.dart';
import 'package:kitchentable/table/model/card_instance.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

List<CardInstance> _top(int n) => [
      for (var i = 0; i < n; i++)
        CardInstance(id: 'c$i', oracleId: 'card$i'),
    ];

Widget _host({
  int count = 53,
  VoidCallback? onShuffle,
  void Function(List<Placement>)? onArrange,
  Future<List<CardInstance>> Function(int)? peek,
}) =>
    MaterialApp(
      home: Scaffold(
        body: DeckSheet(
          metrics: Metrics.of(DeviceClass.handheld),
          count: count,
          printings: const {},
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
}
