import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/features/play/widgets/card_drag.dart';
import 'package:kitchentable/table/model/card_instance.dart';

const _card = CardInstance(id: 'a', oracleId: 'o');

Widget _host({
  void Function(CardInstance, Offset)? onDrop,
  bool canDrag = true,
}) =>
    // Every card here is a `DraggableCard`, which says a drag is on through a
    // provider rather than through a parameter of its own, so it needs a scope
    // to say it into. In the app that scope is the one the whole screen is
    // under.
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(
                height: 120,
                child: Center(
                  child: DraggableCard(
                    card: _card,
                    canDrag: canDrag,
                    child: const SizedBox(
                      key: Key('the-card'),
                      width: 60,
                      height: 84,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: CardDropTarget(
                  onDrop: onDrop ?? (_, _) {},
                  child: const SizedBox.expand(
                    key: Key('the-target'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

void main() {
  testWidgets('a card dropped on a target arrives there', (tester) async {
    CardInstance? dropped;
    await tester.pumpWidget(_host(onDrop: (c, _) => dropped = c));
    await tester.pump();

    await tester.drag(
      find.byKey(const Key('the-card')),
      tester.getCenter(find.byKey(const Key('the-target'))) -
          tester.getCenter(find.byKey(const Key('the-card'))),
      // The key is on a bare SizedBox, and a bare SizedBox is never itself in
      // a hit test path. What is hit is the pickup above it, which is the
      // point: the whole rectangle is the grab area, painted or not.
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(dropped?.id, 'a');
  });

  testWidgets('where it was let go is reported in the target s own space',
      (tester) async {
    Offset? at;
    await tester.pumpWidget(_host(onDrop: (_, where) => at = where));
    await tester.pump();

    final target = tester.getRect(find.byKey(const Key('the-target')));
    final from = tester.getCenter(find.byKey(const Key('the-card')));
    final to = target.topLeft + const Offset(40, 30);

    await tester.drag(find.byKey(const Key('the-card')), to - from,
        warnIfMissed: false);
    await tester.pumpAndSettle();

    // Local to the target, so a mat can normalise it without knowing where on
    // the screen it happens to be. The pointer's real position, not a sum of
    // deltas, which is why the touch slop the old pan based drag had to
    // compensate for cannot come back here.
    //
    // Exactly, and not within a pixel or two. A sum of deltas has to be
    // approximate because the first kTouchSlop of travel is never reported;
    // a position taken straight off the pointer has nothing to lose, so a
    // tolerance here would be room for the old bug to hide in.
    expect(at!.dx, 40.0);
    expect(at!.dy, 30.0);
  });

  testWidgets('a card nobody may move does not move', (tester) async {
    CardInstance? dropped;
    await tester.pumpWidget(
        _host(canDrag: false, onDrop: (c, _) => dropped = c));
    await tester.pump();

    await tester.drag(find.byKey(const Key('the-card')), const Offset(0, 200),
        warnIfMissed: false);
    await tester.pumpAndSettle();

    // Somebody else's card on somebody else's mat.
    expect(dropped, isNull);
  });

  testWidgets('a drop outside every target reports nothing', (tester) async {
    CardInstance? dropped;
    await tester.pumpWidget(_host(onDrop: (c, _) => dropped = c));
    await tester.pump();

    await tester.drag(
      find.byKey(const Key('the-card')),
      const Offset(0, -60),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(dropped, isNull);
  });
}
