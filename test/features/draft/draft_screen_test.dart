import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/draft/draft_controller.dart';
import 'package:kitchentable/features/draft/draft_screen.dart';
import 'package:kitchentable/features/draft/draft_state.dart';
import 'package:kitchentable/features/play/talk_here.dart';
import 'package:kitchentable/net/talk.dart';
import 'package:kitchentable/sources/model/catalog_card.dart';

import '../../net/fake_transport.dart';

/// A draft controller pinned to one view, so the screen can be pumped
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

Future<void> _pump(
  WidgetTester tester,
  DraftView view, {
  VoidCallback? onBack,
  Talk? talk,
}) async {
  tester.view.physicalSize = const Size(500, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        draftProvider.overrideWith(() => _Fixed(view)),
        talkProvider.overrideWithValue(talk),
        draftCardsProvider.overrideWith(
          (ref) async => {
            for (final n in ['Alpha', 'Beta', 'Gamma', 'Delta']) n: _card(n),
          },
        ),
      ],
      child: MaterialApp(home: DraftScreen(onBack: onBack)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('between picks it says the others are picking, and the pool '
      'opens out to be read', (tester) async {
    await _pump(
      tester,
      DraftView(
        phase: DraftPhase.waiting,
        pool: [_draft('1', 'Alpha'), _draft('2', 'Beta')],
        pack: null,
        packNumber: 1,
        pickNumber: 3,
        queueDepth: 0,
        fresh: false,
      ),
    );

    expect(find.textContaining('waiting for the others to pick'), findsOne);
    expect(find.text('YOUR POOL · 2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pool-expand')));
    await tester.pumpAndSettle();

    expect(find.text('Your pool'), findsOneWidget);
    expect(find.text('2 CARDS'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
  });

  testWidgets('a pool card lifts to read, with nothing to do to it', (
    tester,
  ) async {
    await _pump(
      tester,
      DraftView(
        phase: DraftPhase.picking,
        pool: [_draft('1', 'Alpha')],
        pack: [_draft('2', 'Beta'), _draft('3', 'Gamma')],
        packNumber: 1,
        pickNumber: 2,
        queueDepth: 0,
        fresh: false,
      ),
    );

    await tester.tap(find.text('Alpha'));
    await tester.pumpAndSettle();

    expect(find.textContaining('drag to turn it over'), findsOneWidget);
    expect(find.byKey(const Key('viewer-action')), findsNothing);
  });

  testWidgets('leaving asks first, and only a yes leaves', (tester) async {
    var left = 0;
    await _pump(
      tester,
      DraftView(
        phase: DraftPhase.picking,
        pool: const [],
        pack: [_draft('2', 'Beta')],
        packNumber: 1,
        pickNumber: 1,
        queueDepth: 0,
        fresh: false,
      ),
      onBack: () => left++,
    );

    await tester.tap(find.text('Leave draft'));
    await tester.pumpAndSettle();
    expect(find.text('Leave the draft?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('stay-in-draft')));
    await tester.pumpAndSettle();
    expect(left, 0);
    expect(find.text('Leave the draft?'), findsNothing);

    await tester.tap(find.text('Leave draft'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('leave-draft')));
    await tester.pumpAndSettle();
    expect(left, 1);
  });

  testWidgets('the room talks through the draft: a line typed here reaches '
      'the other chair', (tester) async {
    final net = FakeNetwork();
    final mine = TalkChannel(net.join('me'));
    final theirs = TalkChannel(net.join('ana'));
    addTearDown(mine.close);
    addTearDown(theirs.close);
    final heard = <Said>[];
    theirs.chatter.listen(heard.add);
    // Real time for the fake network, which yields to the event loop
    // between deliveries and a widget test's clock is not that loop.
    await tester.runAsync(net.settle);

    await _pump(
      tester,
      DraftView(
        phase: DraftPhase.picking,
        pool: const [],
        pack: [_draft('2', 'Beta')],
        packNumber: 1,
        pickNumber: 1,
        queueDepth: 0,
        fresh: false,
      ),
      talk: mine,
    );

    await tester.tap(find.byKey(const Key('draft-talk')));
    // Pumped by hand: a text box's cursor blinks forever, and settling
    // waits for it.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byKey(const Key('chat-box')), 'blue is open');
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.runAsync(net.settle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(heard, [(by: 'me', text: 'blue is open')]);
    expect(find.text('blue is open'), findsOneWidget);
  });

  testWidgets('alone, there is nobody to talk to and no button for it', (
    tester,
  ) async {
    await _pump(
      tester,
      DraftView(
        phase: DraftPhase.picking,
        pool: const [],
        pack: [_draft('2', 'Beta')],
        packNumber: 1,
        pickNumber: 1,
        queueDepth: 0,
        fresh: false,
      ),
    );
    expect(find.byKey(const Key('draft-talk')), findsNothing);
  });
}
