import 'package:flutter/material.dart';

import '../atoms/hint_bar.dart';
import '../tokens/metrics.dart';
import '../tokens/palette.dart';

/// Every screen in this app is the same shape: a wordmark or a title, a small
/// uppercase line under it saying what is true right now, a list, and a hint
/// bar along the bottom.
///
/// It lives in one place because the first version did not, and three screens
/// each grew their own Column with their own padding and their own idea of
/// where the bottom was. On a wide browser window that produced menu rows a
/// metre across with the chevron stranded at the far edge, and a hint bar
/// floating alone at the foot of the viewport attached to nothing.
class ScreenFrame extends StatelessWidget {
  const ScreenFrame({
    super.key,
    required this.metrics,
    required this.title,
    required this.label,
    required this.children,
    required this.hints,
    this.wordmark = false,
    this.onBack,
  });

  final Metrics metrics;

  /// Rendered as the kitchentable wordmark when [wordmark] is set, otherwise as
  /// a plain screen title.
  final String title;

  /// The small uppercase line. It says what is true at this moment, not what
  /// the screen is called.
  final String label;

  final List<Widget> children;
  final List<Hint> hints;
  final bool wordmark;

  /// Drawn as a back affordance when given. A D-pad has a B button and a phone
  /// has a back gesture, but a browser window has neither.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: m.contentWidth),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: m.safeInset,
                vertical: m.scaled(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (onBack != null) ...[
                    _BackRow(metrics: m, onBack: onBack!),
                    SizedBox(height: m.scaled(14)),
                  ],
                  _Heading(metrics: m, title: title, wordmark: wordmark),
                  SizedBox(height: m.scaled(6)),
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontSize: m.scaled(10),
                      height: 1.4,
                      letterSpacing: 1.3,
                      fontWeight: FontWeight.w500,
                      color: Palette.inkFaint,
                    ),
                  ),
                  SizedBox(height: m.scaled(26)),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: children,
                    ),
                  ),
                  SizedBox(height: m.scaled(12)),
                  HintBar(metrics: m, hints: hints),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({
    required this.metrics,
    required this.title,
    required this.wordmark,
  });

  final Metrics metrics;
  final String title;
  final bool wordmark;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    if (!wordmark) {
      return Text(
        title,
        style: TextStyle(
          fontSize: m.scaled(24),
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
          color: Palette.ink,
        ),
      );
    }

    // Split so the second half carries the accent. One word, two weights of
    // attention, which is the whole logo.
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'kitchen'),
          TextSpan(text: 'table', style: const TextStyle(color: Palette.accent)),
        ],
      ),
      style: TextStyle(
        fontSize: m.scaled(28),
        fontWeight: FontWeight.w700,
        letterSpacing: -0.9,
        color: Palette.ink,
      ),
    );
  }
}

class _BackRow extends StatelessWidget {
  const _BackRow({required this.metrics, required this.onBack});

  final Metrics metrics;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return Semantics(
      button: true,
      label: 'Back',
      child: GestureDetector(
        onTap: onBack,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.arrow_back_rounded,
              size: m.scaled(16),
              color: Palette.inkFaint,
            ),
            SizedBox(width: m.scaled(6)),
            Text(
              'Back',
              style: TextStyle(
                fontSize: m.scaled(12),
                color: Palette.inkFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
