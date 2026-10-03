import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../atoms/slab.dart';
import '../atoms/tray.dart';
import '../tokens/app_palette.dart';
import '../tokens/lettering.dart';
import '../tokens/metrics.dart';
import '../tokens/palette.dart';

/// Every screen in this app is the same shape: a title, a small line of
/// capitals under it saying what is true right now, and a tray with the
/// screen in it.
///
/// The tray is the change. Everything used to float directly on the backdrop,
/// which is the reason thin text had to fight the paint behind it; now the
/// paint stops at a border and the screen stands on something solid. See
/// docs/benchmarks/2026-10-03-balatro-ui.md.
///
/// Back moved to the bottom and became a slab the width of the tray. It is
/// where the reference puts it, and it is also the only thing on the screen
/// that is not one of the screen's own choices, so it has no business being
/// the first thing above them.
///
/// No footer. It carried a row naming the D-pad buttons on every screen, on
/// devices that have no D-pad: a phone and a desktop both drew "move" and "A
/// open" along the bottom of every menu in the app.
class ScreenFrame extends StatelessWidget {
  const ScreenFrame({
    super.key,
    required this.metrics,
    required this.title,
    required this.label,
    required this.children,
    this.wordmark = false,
    this.onBack,
  });

  final Metrics metrics;

  /// Rendered as the kitchentable wordmark when [wordmark] is set, otherwise as
  /// a plain screen title.
  final String title;

  /// The small line of capitals. It says what is true at this moment, not what
  /// the screen is called.
  final String label;

  /// The list the screen is made of.
  final List<Widget> children;

  final bool wordmark;

  /// Drawn as a slab along the bottom when given, and bound to Escape and the
  /// gamepad B button. A browser window and a television remote have neither a
  /// back gesture nor a system back button.
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
                    vertical: m.scaled(20),
                  ),
                  // Header pinned to the top, Back pinned to the bottom, and
                  // only the tray between them grows. This oscillated twice:
                  // full width with a floating footer, then a hugging column
                  // with the header stranded mid screen. The complaint both
                  // times was the width, never the height.
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Heading(metrics: m, title: title, wordmark: wordmark),
                      SizedBox(height: m.scaled(7)),
                      TrayLabel(
                        metrics: m,
                        text: label,
                        align: TextAlign.center,
                      ),
                      SizedBox(height: m.scaled(16)),
                      // Flexible with a shrink-wrapping list, not Expanded: a
                      // tray has to end where its contents end. Stretched to
                      // the viewport it left four rows floating in half a
                      // screen of empty slate, which is the one thing the
                      // reference never does.
                      Flexible(
                        child: Tray(
                          metrics: m,
                          padding: EdgeInsets.fromLTRB(
                            m.scaled(14),
                            m.scaled(14),
                            m.scaled(14),
                            m.scaled(4),
                          ),
                          child: ListView(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            children: children,
                          ),
                        ),
                      ),
                      if (onBack != null) ...[
                        SizedBox(height: m.scaled(12)),
                        Slab(
                          metrics: m,
                          tone: SlabTone.warm,
                          onActivate: onBack!,
                          semanticLabel: 'Back',
                          padding: EdgeInsets.symmetric(
                            horizontal: m.scaled(14),
                            vertical: m.scaled(14),
                          ),
                          child: Center(
                            child: Text('Back', style: slabText(m.scaled(15))),
                          ),
                        ),
                      ],
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
        textAlign: TextAlign.center,
        style: pixel(
          size: m.scaled(26),
          weight: 700,
          color: Palette.ink,
          outlined: true,
        ),
      );
    }

    // Split so the second half carries the accent. One word, two weights of
    // attention, which is the whole logo.
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'kitchen'),
          TextSpan(
            text: 'table',
            style: TextStyle(color: context.palette.accent),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      style: pixel(
        size: m.scaled(34),
        weight: 700,
        color: Palette.ink,
        outlined: true,
      ),
    );
  }
}
