import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/widgets/token_sheet.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';
import 'package:kitchentable/ui/tokens/metrics.dart';

CatalogCard _card(String name, {String type = 'Token'}) =>
    CatalogCard(oracleId: name, name: name, typeLine: type, cmc: 0);

Widget _host({
  Future<List<CatalogCard>> Function(String)? search,
  void Function(CatalogCard)? onPick,
}) =>
    MaterialApp(
      home: Scaffold(
        body: TokenSheet(
          metrics: Metrics.of(DeviceClass.handheld),
          search: search ??
              (term) async => [_card('Goblin'), _card('Goblin Chieftain')],
          onPick: onPick ?? (_) {},
        ),
      ),
    );

void main() {
  testWidgets('it opens empty, with nothing searched for yet', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    expect(find.byKey(const Key('token-Goblin')), findsNothing);
  });

  testWidgets('typing finds cards', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'gob');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('token-Goblin')), findsOneWidget);
    expect(find.byKey(const Key('token-Goblin Chieftain')), findsOneWidget);
  });

  testWidgets('picking one reports it', (tester) async {
    CatalogCard? picked;
    await tester.pumpWidget(_host(onPick: (c) => picked = c));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'gob');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('token-Goblin')));
    await tester.pumpAndSettle();

    expect(picked?.name, 'Goblin');
  });

  testWidgets('a catalog with nothing in it says so rather than nothing',
      (tester) async {
    await tester.pumpWidget(_host(search: (term) async => []));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'gob');
    await tester.pumpAndSettle();

    // A token whose face is not in the catalog would draw as a blank back
    // with no name, which is worse than no token. Saying so is the honest
    // answer, and the fix is on the sources screen.
    expect(find.textContaining('Nothing'), findsOneWidget);
  });

  testWidgets('it offers tokens first', (tester) async {
    await tester.pumpWidget(_host(search: (term) async => [
          _card('Goblin Chieftain', type: 'Creature - Goblin'),
          _card('Goblin', type: 'Token Creature - Goblin'),
        ]));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'gob');
    await tester.pumpAndSettle();

    final rows = tester.widgetList(find.byType(TokenRow)).toList();
    expect(rows, hasLength(2));

    // A token is what this sheet is for. A real card of the same name is
    // still there, because plenty of tokens are copies of one, but it is not
    // what you are offered first.
    expect(
      tester.getRect(find.byKey(const Key('token-Goblin'))).top,
      lessThan(
        tester.getRect(find.byKey(const Key('token-Goblin Chieftain'))).top,
      ),
    );

    // And quiet about it, because there is one. Without this the message
    // could be shown over every search and the case below would still pass:
    // it only ever asks whether the words are there.
    expect(find.textContaining('No tokens'), findsNothing);
  });

  testWidgets('a catalog with no tokens in it says why', (tester) async {
    await tester.pumpWidget(_host(search: (term) async => [
          _card('Goblin Chieftain', type: 'Creature - Goblin'),
        ]));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'gob');
    await tester.pumpAndSettle();

    // Scryfall's bulk data carries token cards, so a catalog with none of
    // them was imported from a source that does not, and saying so beats a
    // list that silently has no tokens in it.
    expect(find.textContaining('No tokens'), findsOneWidget);
  });
}
