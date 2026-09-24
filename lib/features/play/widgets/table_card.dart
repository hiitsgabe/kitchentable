import 'package:flutter/material.dart';

import '../../../decks/model/game.dart';
import '../../../sources/model/catalog_card.dart';
import '../../../table/model/card_instance.dart';
import '../../../ui/atoms/card_art.dart';
import '../../../ui/tokens/metrics.dart';
import 'counter_piece.dart';
import 'hover_card.dart';

/// One card where it is sitting, turned however it is turned.
class TableCard extends StatelessWidget {
  const TableCard({
    super.key,
    required this.metrics,
    required this.instance,
    required this.printing,
    required this.width,
    this.onTap,
    this.onLongPress,
    this.hoverPreview = true,
    this.game,
  });

  final Metrics metrics;
  final CardInstance instance;

  /// Whose back this card is turned onto when it is face down, and whose back
  /// stands in for a printing the catalog has never heard of.
  ///
  /// Null draws the plain outlined box, which is right for a token and for a
  /// card out of a source somebody cleared, and is what a harness that draws
  /// a card with no table behind it should still get.
  final Game? game;

  /// Null when the catalog has never heard of it, which happens to a token and
  /// to a card from a source that was cleared.
  final CatalogCard? printing;

  final double width;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Whether a pointer resting on this card brings up a bigger one.
  ///
  /// True by default, and that is the real decision rather than a shrug: a
  /// new caller is far more likely to be drawing cards small, which is where
  /// the preview earns its place, and a caller drawing them big has to say so
  /// and say why. The two that do are the board and the canvas.
  final bool hoverPreview;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final card = printing;

    final face = instance.faceDown || card == null
        ? CardBack(width: width, game: game)
        : CardArt(metrics: m, card: card, width: width);

    // Wrapped here and not by each caller, so a card in a hand, in a seat's
    // band and in a deck sheet all grow under a pointer from one place, and
    // the two that draw cards big turn it off rather than each of the rest
    // turning it on.
    return _maybeHover(
      m,
      card,
      GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        // The same door a hold opens, on the button a mouse already has. Two
        // gestures onto one callback, not two menus to keep in step.
        onSecondaryTap: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: AnimatedRotation(
          turns: instance.rotation / 360,
          duration: const Duration(milliseconds: 160),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              face,
              if (instance.counters.isNotEmpty)
                CountersOnCard(counters: instance.counters, width: width),
            ],
          ),
        ),
      ),
    );
  }

  /// The pieces the card is wearing, in a row along its bottom edge.
  ///
  /// One marker for the net of everything numeric, one per keyword, and one
  /// for any kind nobody printed. The pills this replaces were one per kind
  /// and read `+2 +3` down the corner, which is three numbers with no units:
  /// the numbers now say what they do to power and toughness and the words
  /// say the word.
  ///
  /// Sized off the card and not off the metrics, and positioned rather than
  /// laid out, so a card wearing counters is exactly as big as a card wearing
  /// none. Two earlier things added to a card each cost the board nine and a
  /// half percent by having a size of their own.

  /// The card, under a preview or not.
  Widget _maybeHover(Metrics m, CatalogCard? card, Widget child) =>
      hoverPreview
          ? HoverCard(
              metrics: m,
              instance: instance,
              printing: card,
              width: width,
              child: child,
            )
          : child;
}
