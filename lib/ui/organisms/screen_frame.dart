import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../atoms/kitchentable_mark.dart';
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
    this.label,
    required this.children,
    this.wordmark = false,
    this.onBack,
    this.primary,
    this.home = false,
  });

  final Metrics metrics;

  /// Rendered as the kitchentable wordmark when [wordmark] is set, otherwise as
  /// a plain screen title.
  final String title;

  /// The small line of capitals. It says what is true at this moment, not what
  /// the screen is called. Null draws none: the menu has nothing true to say
  /// that four bare words do not already.
  final String? label;

  /// The list the screen is made of.
  final List<Widget> children;

  final bool wordmark;

  /// Drawn as a slab along the bottom when given, and bound to Escape and the
  /// gamepad B button. A browser window and a television remote have neither a
  /// back gesture nor a system back button.
  ///
  /// Back keeps the prominent bottom slab only on a screen with no action of
  /// its own. Where the screen has one thing it is for, that is what [primary]
  /// is, and Back steps down to a slim control beneath it: the one button that
  /// is not a choice the screen offers should not be the loudest thing on it.
  final VoidCallback? onBack;

  /// The one dominant action the screen is for, drawn as the bright slab along
  /// the bottom. Null on a screen that only reads or only lists, where there is
  /// nothing to make primary and Back is the only way out.
  final ScreenAction? primary;

  /// Draws a Home slab beside Back that pops to the first screen, for a
  /// screen that is two or more steps below it.
  ///
  /// Decks, a game, a deck, its cards: four screens down, and the only way
  /// out was Back four times. Home is one. The first screen is the menu, or
  /// on a first run the wizard that stands in for it, which is why this pops
  /// to the root rather than pushing a menu: it goes to whatever this app
  /// opened on. Off by default, and off on purpose inside a room, where
  /// going home would be leaving the table without saying so.
  final bool home;

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
                      if (label != null) ...[
                        SizedBox(height: m.scaled(7)),
                        TrayLabel(
                          metrics: m,
                          text: label!,
                          align: TextAlign.center,
                        ),
                      ],
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
                      if (onBack != null || primary != null) ...[
                        SizedBox(height: m.scaled(12)),
                        _WayOut(
                          metrics: m,
                          onBack: onBack,
                          home: home,
                          primary: primary,
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

/// The one action a screen is for, handed to [ScreenFrame.primary] so the frame
/// draws it as the bright bottom slab rather than leaving it buried in the list
/// above a louder Back.
class ScreenAction {
  const ScreenAction({
    required this.label,
    required this.onActivate,
    this.enabled = true,
    this.icon,
    this.slabKey,
  });

  final String label;
  final VoidCallback onActivate;

  /// A disabled action still draws, dimmed, saying what is missing through the
  /// screen rather than vanishing: a button that is not there cannot explain
  /// why it is not there.
  final bool enabled;
  final IconData? icon;
  final Key? slabKey;
}

/// The way out of a screen, and the way on from it.
///
/// With no [primary], Back keeps the prominent warm slab and Home sits beside
/// it when the screen is deep enough to want one. With a [primary], that action
/// takes the bright bottom slab and Back drops to a slim plain control beneath
/// it, Home beside it: the screen's own action leads, and the way out is still
/// there, bound to Escape and the pad, without shouting.
class _WayOut extends StatelessWidget {
  const _WayOut({
    required this.metrics,
    required this.onBack,
    required this.home,
    required this.primary,
  });

  final Metrics metrics;
  final VoidCallback? onBack;
  final bool home;
  final ScreenAction? primary;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final primary = this.primary;

    if (primary != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Slab(
            key: primary.slabKey,
            metrics: m,
            tone: SlabTone.choice,
            enabled: primary.enabled,
            onActivate: primary.enabled ? primary.onActivate : () {},
            semanticLabel: primary.label,
            padding: EdgeInsets.symmetric(
              horizontal: m.scaled(14),
              vertical: m.scaled(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (primary.icon != null) ...[
                  Icon(
                    primary.icon,
                    size: m.scaled(18),
                    color: Palette.slabInk,
                  ),
                  SizedBox(width: m.scaled(8)),
                ],
                Flexible(
                  child: Text(
                    primary.label,
                    style: slabText(m.scaled(15)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (onBack != null) ...[
            SizedBox(height: m.scaled(8)),
            _discreetRow(context, m),
          ],
        ],
      );
    }

    return _prominentRow(context, m);
  }

  /// Back the slim plain way, under a primary action: low and quiet, Home a
  /// matching square beside it.
  Widget _discreetRow(BuildContext context, Metrics m) {
    final padding = EdgeInsets.symmetric(
      horizontal: m.scaled(12),
      vertical: m.scaled(9),
    );
    final back = Slab(
      metrics: m,
      tone: SlabTone.plain,
      depth: m.scaled(3),
      onActivate: onBack!,
      semanticLabel: 'Back',
      padding: padding,
      child: Center(
        child: Text(
          'Back',
          style: pixel(
            size: m.scaled(12),
            weight: 600,
            color: Palette.slabInk,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
    if (!home) return back;
    return Row(
      children: [
        Expanded(child: back),
        SizedBox(width: m.scaled(8)),
        Slab(
          key: const Key('home'),
          metrics: m,
          tone: SlabTone.cool,
          depth: m.scaled(3),
          onActivate: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
          semanticLabel: 'Home',
          padding: padding,
          child: Icon(
            Icons.home_rounded,
            size: m.scaled(16),
            color: Palette.slabInk,
          ),
        ),
      ],
    );
  }

  /// Back the loud way, on a screen with no action of its own: the warm slab
  /// across the width, Home the narrower cool one beside it.
  Widget _prominentRow(BuildContext context, Metrics m) {
    final padding = EdgeInsets.symmetric(
      horizontal: m.scaled(14),
      vertical: m.scaled(14),
    );

    final back = Slab(
      metrics: m,
      tone: SlabTone.warm,
      onActivate: onBack!,
      semanticLabel: 'Back',
      padding: padding,
      child: Center(child: Text('Back', style: slabText(m.scaled(15)))),
    );

    if (!home) return back;

    return Row(
      children: [
        Expanded(child: back),
        SizedBox(width: m.scaled(10)),
        Slab(
          key: const Key('home'),
          metrics: m,
          tone: SlabTone.cool,
          onActivate: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
          semanticLabel: 'Home',
          padding: padding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.home_rounded,
                size: m.scaled(18),
                color: Palette.slabInk,
              ),
              SizedBox(width: m.scaled(6)),
              Text('Home', style: slabText(m.scaled(15))),
            ],
          ),
        ),
      ],
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
        textAlign: TextAlign.center,
        style: pixel(
          size: m.scaled(26),
          weight: 700,
          color: Palette.ink,
          outlined: true,
        ),
      );
    }

    // The mark over the name, which is the logo. The word alone was the
    // whole of it, and a word is not a thing anybody recognises across a
    // room or in a list of tabs.
    //
    // Split so the second half carries the accent. One word, two weights of
    // attention, and the mark above it in the same colour.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        KitchentableMark(size: m.scaled(96)),
        SizedBox(height: m.scaled(12)),
        Text.rich(
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
        ),
      ],
    );
  }
}
