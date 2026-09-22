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
  });

  final Metrics metrics;
  final CardInstance instance;

  /// Null when the catalog has never heard of it, which happens to a token and
  /// to a card from a source that was cleared.
  final CatalogCard? printing;

  final double width;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final card = printing;

    final face = instance.faceDown || card == null
        ? Container(
            width: width,
            height: width * 88 / 63,
            decoration: BoxDecoration(
              color: Palette.tile,
              borderRadius: BorderRadius.circular(width * 0.05),
              border: Border.all(color: Palette.tileEdge),
            ),
          )
        : CardArt(metrics: m, card: card, width: width);

    // Wrapped here and not by each caller, so a card on a board, in a hand
    // and in the command slot all grow under a pointer from one place.
    return HoverCard(
      metrics: m,
      instance: instance,
      printing: card,
      width: width,
      child: GestureDetector(
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
}
