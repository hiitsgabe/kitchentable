import 'package:flutter/material.dart';

import '../tokens/palette.dart';
import '../tokens/metrics.dart';

class Hint {
  const Hint({required this.button, required this.label});
  final String button;
  final String label;
}

class HintBar extends StatelessWidget {
  const HintBar({super.key, required this.metrics, required this.hints});

  final Metrics metrics;
  final List<Hint> hints;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return Container(
      padding: EdgeInsets.only(top: m.scaled(8)),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Palette.surfaceEdge)),
      ),
      child: Row(
        children: [
          for (final hint in hints) ...[
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: m.scaled(6),
                vertical: m.scaled(2),
              ),
              decoration: BoxDecoration(
                color: Palette.surface,
                borderRadius: BorderRadius.circular(m.scaled(4)),
                border: Border.all(color: Palette.surfaceEdge),
              ),
              child: Text(
                hint.button,
                style: TextStyle(fontSize: m.scaled(10), color: Palette.inkMuted),
              ),
            ),
            SizedBox(width: m.scaled(5)),
            Text(
              hint.label,
              style: TextStyle(fontSize: m.scaled(10), color: Palette.inkFaint),
            ),
            SizedBox(width: m.scaled(14)),
          ],
        ],
      ),
    );
  }
}
