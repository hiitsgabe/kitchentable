import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../table/model/card_instance.dart';
import '../../../ui/tokens/app_palette.dart';
import '../dragging.dart';

/// A card you can pick up and drop somewhere else.
///
/// This replaces an earlier pan based drag, which reported deltas to whatever
/// widget contained it and so could never move a card from a hand onto a mat
/// or from a mat into a corner. That design also had to hand back the
/// `kTouchSlop` the recogniser swallows before it reports anything; here the
/// drop position comes from the pointer, so there is nothing to hand back.
///
/// The feedback is the card itself at full size and what is left behind is a
/// faint outline, so it still looks like the card is moving rather than like
/// a ghost being spawned. That was the part worth keeping.
class DraggableCard extends ConsumerWidget {
  const DraggableCard({
    super.key,
    required this.card,
    required this.child,
    this.canDrag = true,
  });

  final CardInstance card;
  final Widget child;

  /// False for a card on somebody else's mat. It is theirs to move.
  final bool canDrag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!canDrag) return child;

    final dragging = ref.read(draggingProvider.notifier);

    return Draggable<CardInstance>(
      data: card,
      // Said out loud, once, rather than handed to each thing a card can land
      // on. Every zone on the screen watches this and grows into a target
      // while it is true, and a parameter instead would be a hand off site per
      // widget between here and each of them.
      onDragStarted: dragging.started,
      // These two and not `onDragEnd`, which is the obvious one and is the
      // one that does not always arrive. A card can leave the tree while it is
      // in the air: somebody else moves it, or it lands somewhere that redraws
      // the row it came from. `Draggable` keeps the drag alive across that on
      // purpose, and then guards `onDragEnd` on the widget still being
      // mounted, so the end of that drag is never reported to it. These two
      // are not guarded and exactly one of them fires for every end there is,
      // accepted or not, so between them nothing is left in the air.
      onDragCompleted: dragging.ended,
      onDraggableCanceled: (_, _) => dragging.ended(),
      // The whole rectangle is the grab area, corners and gaps included. A
      // card reads as one solid object, and deferring to the child means the
      // transparent parts of it are not pickable.
      hitTestBehavior: HitTestBehavior.opaque,
      // The card rides centred on the finger rather than keeping the exact
      // point it was grabbed by. That is what makes the drop honest: the
      // position reported below is the pointer, and the pointer is where the
      // middle of the card has been sitting the whole way across.
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: Material(
          color: Colors.transparent,
          child: Opacity(opacity: 0.92, child: child),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: child),
      child: child,
    );
  }
}

/// Somewhere a card can land.
///
/// Reports where the pointer was when it was released, in this widget's own
/// coordinates, so a mat can normalise against itself without knowing where
/// on the screen it is. The position comes from the pointer rather than from
/// a sum of deltas, which is why the `kTouchSlop` that the old pan based drag
/// had to compensate for cannot come back here.
///
/// **It says when it is the one.** The card being dragged is drawn centred on
/// the finger at full size, so it covers whatever it is over: the player is
/// aiming at something they cannot see, from memory of where it was before
/// the drag started, at zones that move and grow the moment one does. The
/// graveyard and the command zone stand one above the other in the same
/// narrow rail, and dropping into the wrong one of those was reported from a
/// real table. A ring around the target under the pointer is the answer to
/// all of that at once, and it belongs here rather than in each zone,
/// because every target in the app has the same problem.
class CardDropTarget extends StatelessWidget {
  const CardDropTarget({super.key, required this.onDrop, required this.child});

  final void Function(CardInstance card, Offset at) onDrop;
  final Widget child;

  @override
  Widget build(BuildContext context) => DragTarget<CardInstance>(
    onAcceptWithDetails: (details) {
      final box = context.findRenderObject() as RenderBox?;
      if (box == null) return;
      // `details.offset` is the top left of the feedback, not the
      // pointer. They are the same point here only because the drag is
      // anchored at the pointer above; with the default anchor this
      // arrives half a card up and to the left of the finger.
      onDrop(details.data, box.globalToLocal(details.offset));
    },
    // Built only while it is the one, so its presence in the tree is the
    // claim. A widget that is always there and draws nothing is a thing a
    // test can find and be wrong about.
    builder: (context, candidate, _) =>
        candidate.isEmpty ? child : AimedAt(child: child),
  );
}

/// The ring that says a card let go now lands here.
///
/// Painted over the target rather than around it, so nothing moves when it
/// appears: a target that grew by two points the moment the pointer crossed
/// it would shift everything under it in a column, which is the thing that
/// makes a drop land somewhere the player did not aim.
class AimedAt extends StatelessWidget {
  const AimedAt({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.palette.accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.palette.accent, width: 2.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
