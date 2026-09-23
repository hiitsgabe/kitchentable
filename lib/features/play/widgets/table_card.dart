import 'package:flutter/material.dart';

import '../../../sources/model/catalog_card.dart';
import '../../../table/model/card_instance.dart';
import '../../../ui/atoms/card_art.dart';
import '../../../ui/tokens/metrics.dart';
import '../../../ui/tokens/palette.dart';
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
  });

  final Metrics metrics;
  final CardInstance instance;

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
        ? CardBack(width: width)
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
        behavior: HitTestBehavior.opaque,
        child: AnimatedRotation(
          turns: instance.rotation / 360,
          duration: const Duration(milliseconds: 160),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              face,
              if (instance.counters.isNotEmpty)
                Positioned(
                  right: -width * 0.06,
                  bottom: -width * 0.06,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: m.scaled(6),
                      vertical: m.scaled(2),
                    ),
                    decoration: BoxDecoration(
                      color: Palette.accent,
                      borderRadius: BorderRadius.circular(m.scaled(99)),
                    ),
                    child: Text(
                      instance.counters.values
                          .map((v) => v > 0 ? '+$v' : '$v')
                          .join(' '),
                      style: TextStyle(
                        fontSize: m.scaled(10),
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

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
