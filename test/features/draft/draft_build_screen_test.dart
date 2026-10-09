import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/draft/draft_build_screen.dart';
import 'package:kitchentable/features/draft/draft_controller.dart';
import 'package:kitchentable/features/draft/draft_state.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';

/// A draft controller pinned to one view, so the build screen can be pumped
/// without a room or a transport.
class _Fixed extends DraftController {
  _Fixed(this._view);
  final DraftView _view;
  @override
  DraftView? build() => _view;
}

CatalogCard _card(String name) =>
    CatalogCard(oracleId: name, name: name, typeLine: 'Creature', cmc: 2);

DraftCard _draft(String uuid, String oracle) =>
    DraftCard(uuid: uuid, oracleId: oracle, rarity: 'common');

void main() {
  testWidgets('a pool card taps into the deck and the count follows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final view = DraftView(
      phase: DraftPhase.building,
      pool: [_draft('1', 'Alpha'), _draft('2', 'Beta'), _draft('3', 'Gamma')],
      pack: null,
      packNumber: 3,
      pickNumber: 1,
      queueDepth: 0,
      fresh: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          draftProvider.overrideWith(() => _Fixed(view)),
          draftCardsProvider.overrideWith(
            (ref) async => {
              for (final n in ['Alpha', 'Beta', 'Gamma']) n: _card(n),
            },
          ),
          draftBasicsProvider.overrideWith((ref) async => const {}),
        ],
        child: const MaterialApp(home: DraftBuildScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('IN THE DECK · 0'), findsOneWidget);
    expect(find.text('Need 40 more'), findsOneWidget);

    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();

    expect(find.text('IN THE DECK · 1'), findsOneWidget);
    expect(find.text('Need 39 more'), findsOneWidget);
    // Alpha is still on screen, now in the deck zone rather than the pool.
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('POOL · 2'), findsOneWidget);
  });
}
