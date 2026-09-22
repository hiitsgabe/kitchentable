import 'package:flutter/material.dart';

import '../../../sources/model/catalog_card.dart';
import '../../../table/model/card_instance.dart';
import '../../../ui/atoms/card_art.dart';
import '../../../ui/tokens/metrics.dart';

/// How much bigger the card under the pointer gets.
const _hoverGrowth = 3.2;

/// A card that grows under a mouse.
///
/// A finger has no hover, so this is inert on a phone: `MouseRegion` only
/// fires for a pointer that can be somewhere without pressing, which a touch
/// never is. The preview is in an `Overlay` so it is not clipped by whatever
/// the card is sitting inside, which on the board is a mat with its own
/// bounds.
class HoverCard extends StatefulWidget {
  const HoverCard({
    super.key,
    required this.metrics,
    required this.instance,
    required this.printing,
    required this.width,
    this.child,
  });

  final Metrics metrics;
  final CardInstance instance;
  final CatalogCard? printing;
  final double width;

  /// What to draw normally. The card itself, when there is one to wrap.
  final Widget? child;

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  OverlayEntry? _entry;

  @override
  void dispose() {
    _remove();
    super.dispose();
  }

  void _remove() {
    _entry?.remove();
    _entry = null;
  }

  void _show() {
    final printing = widget.printing;
    if (printing == null || _entry != null) return;
    // A card lying face down keeps its face. Every card on the table is
    // wrapped in one of these, so without this a pointer would read the back
    // of somebody's card off the screen.
    if (widget.instance.faceDown) return;

    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final at = box.localToGlobal(Offset.zero);
    final big = widget.width * _hoverGrowth;

    _entry = OverlayEntry(
      builder: (context) {
        final screen = MediaQuery.sizeOf(context);
        // Beside the card if there is room on the right, otherwise on its
        // left, and never off the bottom.
        final left = at.dx + widget.width + big > screen.width
            ? at.dx - big - 12
            : at.dx + widget.width + 12;
        final top = (at.dy - big * 0.3)
            .clamp(12.0, (screen.height - big * 88 / 63 - 12).clamp(12.0, 1e5));

        return Positioned(
          key: const Key('hover-preview'),
          left: left.clamp(12.0, screen.width - big - 12),
          top: top,
          child: IgnorePointer(
            child: Material(
              color: Colors.transparent,
              child: CardArt(
                metrics: widget.metrics,
                card: printing,
                width: big,
              ),
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(_entry!);
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => _show(),
        onExit: (_) => _remove(),
        child: widget.child ?? const SizedBox.shrink(),
      );
}
