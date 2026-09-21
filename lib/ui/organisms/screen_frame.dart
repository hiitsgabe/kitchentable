import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../atoms/hint_bar.dart';
import '../tokens/metrics.dart';
import '../tokens/palette.dart';

/// Every screen in this app is the same shape: a wordmark or a title, a small
/// uppercase line under it saying what is true right now, a list, and a hint
/// bar along the bottom.
///
/// It lives in one place because the first version did not, and three screens
/// each grew their own Column with their own padding and their own idea of
/// where the bottom was.
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

  /// Drawn as a back affordance when given, and bound to Escape and the gamepad
  /// B button. A browser window and a television remote have neither a back
  /// gesture nor a system back button.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    final frame = Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            return Center(
              child: SizedBox(
                width: m.contentWidthFor(box.maxWidth),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: m.safeInset,
                    vertical: m.scaled(24),
                  ),
                  // Hugs its content rather than filling the viewport. Pinning
                  // the hint bar to the bottom of a tall window left a hand
                  // span of nothing between the last row and the legend, which
                  // read as a bug rather than as space.
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (onBack != null) ...[
                        _BackRow(metrics: m, onBack: onBack!),
                        SizedBox(height: m.scaled(16)),
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
                      Flexible(
                        child: ListView(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          children: children,
                        ),
                      ),
                      SizedBox(height: m.scaled(20)),
                      HintBar(metrics: m, hints: hints),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    if (onBack == null) return frame;

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.escape): _GoBackIntent(),
        SingleActivator(LogicalKeyboardKey.gameButtonB): _GoBackIntent(),
        SingleActivator(LogicalKeyboardKey.browserBack): _GoBackIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _GoBackIntent: CallbackAction<_GoBackIntent>(
            onInvoke: (_) {
              onBack!();
              return null;
            },
          ),
        },
        // A FocusScope so the shortcuts have somewhere to bubble up from. Key
        // events travel the focus chain, so with nothing focused inside the
        // frame, Escape reaches nobody. A row that autofocuses still wins, the
        // scope only catches the case where nothing does.
        child: FocusScope(autofocus: true, child: frame),
      ),
    );
  }
}

class _GoBackIntent extends Intent {
  const _GoBackIntent();
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

class _BackRow extends StatefulWidget {
  const _BackRow({required this.metrics, required this.onBack});

  final Metrics metrics;
  final VoidCallback onBack;

  @override
  State<_BackRow> createState() => _BackRowState();
}

class _BackRowState extends State<_BackRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.metrics;

    // The first version was an unpadded Row of a 16 point icon and 12 point
    // text: twenty three points tall, measured, and unable to take focus at
    // all. It missed often enough to read as broken.
    return FocusableActionDetector(
      onFocusChange: (v) => setState(() => _focused = v),
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onBack();
            return null;
          },
        ),
      },
      child: Semantics(
        button: true,
        label: 'Back',
        child: GestureDetector(
          onTap: widget.onBack,
          behavior: HitTestBehavior.opaque,
          child: Container(
            constraints: BoxConstraints(minHeight: m.scaled(44)),
            padding: EdgeInsets.symmetric(
              horizontal: m.scaled(12),
              vertical: m.scaled(10),
            ),
            decoration: BoxDecoration(
              color: _focused ? Palette.focusWash : Colors.transparent,
              borderRadius: BorderRadius.circular(m.scaled(10)),
              border: Border.all(
                color: _focused ? Palette.accent : Colors.transparent,
                width: m.focusRing,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_back_rounded,
                  size: m.scaled(18),
                  color: _focused ? Palette.accent : Palette.inkMuted,
                ),
                SizedBox(width: m.scaled(8)),
                Text(
                  'Back',
                  style: TextStyle(
                    fontSize: m.scaled(13),
                    color: _focused ? Palette.ink : Palette.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
