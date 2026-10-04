import 'package:flutter/material.dart';

import '../tokens/app_palette.dart';
import '../tokens/metrics.dart';

/// What a pressable thing is being, at this moment.
typedef PressState = ({bool focused, bool hovered, bool down});

/// Anything that can be pressed, and so anything a pad can land on.
///
/// Every tap target in the app that is not a [Slab] used to be a bare
/// `GestureDetector`: a pill, a die, a pile, a card in the hand, a swatch.
/// A finger reaches those; a D-pad cannot, because focus never visits a
/// widget that has no focus node. This is the one wrapper that gives such a
/// thing a node, a ring when it is focused, a lift when it is hovered, and
/// an answer to the select button, so the same widget serves a finger, a
/// mouse and a controller without saying which.
///
/// No prompt, no glyph. The ring is the whole of what a pad user sees, and
/// the ring is also what a mouse user sees on hover, fainter.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.metrics,
    required this.onPress,
    this.onLongPress,
    this.builder,
    this.child,
    this.semanticLabel,
    this.autofocus = false,
    this.focusNode,
    this.enabled = true,
    this.radius,
    this.ring = true,
    this.descendantsAreFocusable = false,
  }) : assert(builder != null || child != null, 'a builder or a child');

  final Metrics metrics;
  final VoidCallback onPress;
  final VoidCallback? onLongPress;

  /// Draws the thing given its state, for a widget that changes its own
  /// colour. [child] is for one that is happy with the ring alone.
  final Widget Function(BuildContext context, PressState state)? builder;
  final Widget? child;

  final String? semanticLabel;
  final bool autofocus;
  final FocusNode? focusNode;
  final bool enabled;

  /// The corner of the ring. Defaults to the app's usual small radius.
  final double? radius;

  /// Whether the ring is drawn here at all. Off for a widget that draws its
  /// own focus, the way the board draws a ring around its cursor.
  final bool ring;

  /// Off, so the thing is one stop for the D-pad. On for the one case with
  /// something inside that takes focus of its own: a text field.
  final bool descendantsAreFocusable;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  var _focused = false;
  var _hovered = false;
  var _down = false;

  void _press() {
    if (widget.enabled) widget.onPress();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.metrics;
    final state = (focused: _focused, hovered: _hovered, down: _down);
    final inner = widget.builder?.call(context, state) ?? widget.child!;

    Widget body = inner;
    if (widget.ring) {
      final accent = context.palette.accent;
      body = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius ?? m.scaled(8)),
          border: Border.all(
            color: _focused
                ? accent
                : _hovered
                ? accent.withValues(alpha: 0.5)
                : Colors.transparent,
            width: m.focusRing,
          ),
        ),
        child: inner,
      );
    }

    return FocusableActionDetector(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus && widget.enabled,
      enabled: widget.enabled,
      descendantsAreFocusable: widget.descendantsAreFocusable,
      onFocusChange: (v) => setState(() => _focused = v),
      onShowHoverHighlight: (v) => setState(() => _hovered = v),
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _press();
            return null;
          },
        ),
      },
      child: Semantics(
        button: true,
        enabled: widget.enabled,
        label: widget.semanticLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? _press : null,
          onLongPress: widget.enabled ? widget.onLongPress : null,
          onSecondaryTap: widget.enabled ? widget.onLongPress : null,
          onTapDown: widget.enabled
              ? (_) => setState(() => _down = true)
              : null,
          onTapUp: widget.enabled ? (_) => setState(() => _down = false) : null,
          onTapCancel: widget.enabled
              ? () => setState(() => _down = false)
              : null,
          child: body,
        ),
      ),
    );
  }
}
