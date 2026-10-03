import 'package:flutter/material.dart';

import '../tokens/app_palette.dart';
import '../tokens/metrics.dart';
import '../tokens/palette.dart';

/// What a slab is for, which decides its colour.
///
/// Balatro gives every important button its own saturated colour rather than
/// tinting one accent four ways: blue to play, green for the collection,
/// orange for options, red to quit. No two things you might press by accident
/// look alike. [choice] is the exception and it is ours: it takes whatever
/// colour the player picked, because the app lets them pick one and that is
/// the thing their choice should reach.
enum SlabTone { choice, plain, warm, hot, cool }

/// A button that is an object.
///
/// Flat fill, near black outline, and a darker strip of its own colour along
/// the bottom, which is the whole illusion: the strip reads as the side of a
/// tile with a thickness, so the thing looks like it is lying on the tray
/// rather than painted onto it. Pressing it slides the face down into its own
/// ledge, so the press is felt rather than animated.
///
/// It answers ActivateIntent as well as a tap. MaterialApp maps the select
/// button and gameButtonA to ActivateIntent and WidgetsApp.defaultActions has
/// no handler for it, so without the action below a focused slab would draw
/// its ring and do nothing when pressed.
class Slab extends StatefulWidget {
  const Slab({
    super.key,
    required this.metrics,
    required this.onActivate,
    required this.child,
    this.tone = SlabTone.plain,
    this.enabled = true,
    this.dimmed = false,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
    this.padding,
    this.depth,
  });

  final Metrics metrics;
  final VoidCallback onActivate;
  final Widget child;
  final SlabTone tone;
  final bool enabled;

  /// Drawn dead without being dead. A stepper at the end of its range looks
  /// like this: the clamp inside it is the one thing that decides what a press
  /// does, and a button that refused to call the clamp as well would hide a
  /// broken clamp behind a disabled button.
  final bool dimmed;

  final FocusNode? focusNode;
  final bool autofocus;
  final String? semanticLabel;
  final EdgeInsets? padding;

  /// How thick the slab is. Defaults to five points scaled, which is what the
  /// reference screens look like at the size our rows are.
  final double? depth;

  @override
  State<Slab> createState() => _SlabState();
}

class _SlabState extends State<Slab> {
  bool _focused = false;
  bool _down = false;

  void _activate() {
    if (widget.enabled) widget.onActivate();
  }

  Color _face(BuildContext context) {
    final accent = context.palette.accent;
    return switch (widget.tone) {
      SlabTone.choice => accent,
      SlabTone.plain => Palette.slabPlain,
      SlabTone.warm => _apart(Palette.slabWarm, accent),
      SlabTone.hot => _apart(Palette.slabHot, accent),
      SlabTone.cool => _apart(Palette.slabCool, accent),
    };
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.metrics;
    final depth = widget.depth ?? m.scaled(5);
    var face = _face(context);
    if (_focused) face = Color.lerp(face, Colors.white, 0.16)!;

    return FocusableActionDetector(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus && widget.enabled,
      enabled: widget.enabled,
      descendantsAreFocusable: false,
      onFocusChange: (v) => setState(() => _focused = v),
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _activate();
            return null;
          },
        ),
      },
      child: Semantics(
        button: true,
        enabled: widget.enabled && !widget.dimmed,
        label: widget.semanticLabel,
        child: GestureDetector(
          onTap: widget.enabled ? _activate : null,
          onTapDown: widget.enabled
              ? (_) => setState(() => _down = true)
              : null,
          onTapUp: widget.enabled ? (_) => setState(() => _down = false) : null,
          onTapCancel: widget.enabled
              ? () => setState(() => _down = false)
              : null,
          behavior: HitTestBehavior.opaque,
          child: Opacity(
            opacity: widget.enabled && !widget.dimmed ? 1 : 0.4,
            child: Container(
              decoration: BoxDecoration(
                color: ledgeUnder(face),
                borderRadius: BorderRadius.circular(m.scaled(10)),
                border: Border.all(
                  color: _focused ? Palette.slabInk : Palette.outline,
                  width: m.scaled(2),
                ),
              ),
              // The face sits above its ledge, and a press moves it down onto
              // it. Padding rather than a translation, so the slab's own
              // height never changes and nothing below it moves.
              padding: _down
                  ? EdgeInsets.only(top: depth)
                  : EdgeInsets.only(bottom: depth),
              child: Container(
                padding:
                    widget.padding ??
                    EdgeInsets.symmetric(
                      horizontal: m.scaled(14),
                      vertical: m.scaled(11),
                    ),
                decoration: BoxDecoration(
                  color: face,
                  borderRadius: BorderRadius.circular(m.scaled(7)),
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pushes a role's colour away from the one the player picked.
///
/// The roles are fixed and the accent is not, so they collide. Choosing the
/// teal backdrop put a teal Play directly above a green Join and the menu had
/// two buttons that looked like the same button, which is the one thing the
/// whole colour-per-role idea exists to stop. Anything inside fifty five
/// degrees of the accent is rotated out to fifty five, on the side it was
/// already on, keeping its own weight and saturation.
Color _apart(Color role, Color accent) {
  const room = 55.0;
  final it = HSLColor.fromColor(role);
  final mine = HSLColor.fromColor(accent);

  // Signed, shortest way round, in (-180, 180].
  final delta = ((it.hue - mine.hue + 540) % 360) - 180;
  if (delta.abs() >= room) return role;

  final away = (mine.hue + (delta < 0 ? -room : room) + 360) % 360;
  return it.withHue(away).toColor();
}
