import 'package:flutter/material.dart';

import '../tokens/palette.dart';
import '../tokens/metrics.dart';

/// One line in a list. Focus has to be loud, because the same widget is read
/// from thirty centimetres on a handheld and from three metres on a television.
///
/// It answers ActivateIntent as well as a tap, and that is not decoration.
/// MaterialApp maps the select button and gameButtonA to ActivateIntent, but
/// WidgetsApp.defaultActions has no handler for it, so without the action below
/// the intent is dispatched and nothing catches it: the row would take focus,
/// draw its border and do nothing when pressed.
///
/// A disabled row can still be focused under directional navigation, which is
/// Flutter's choice and the right one. Its subtitle usually says why it is
/// disabled, and that sentence is worth reaching. It just never activates.
class MenuRow extends StatefulWidget {
  const MenuRow({
    super.key,
    required this.title,
    required this.metrics,
    required this.onActivate,
    this.subtitle,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
  });

  final String title;
  final String? subtitle;
  final Metrics metrics;
  final VoidCallback onActivate;
  final bool enabled;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<MenuRow> {
  bool _focused = false;

  void _activate() {
    if (widget.enabled) widget.onActivate();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.metrics;

    return FocusableActionDetector(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus && widget.enabled,
      enabled: widget.enabled,
      descendantsAreFocusable: widget.enabled,
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
        enabled: widget.enabled,
        label: widget.subtitle == null
            ? widget.title
            : '${widget.title}. ${widget.subtitle}',
        child: GestureDetector(
          onTap: widget.enabled ? _activate : null,
          behavior: HitTestBehavior.opaque,
          child: Opacity(
            opacity: widget.enabled ? 1 : 0.42,
            child: Container(
              margin: EdgeInsets.only(bottom: m.scaled(5)),
              padding: EdgeInsets.symmetric(
                horizontal: m.scaled(12),
                vertical: m.scaled(11),
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
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: m.scaled(15),
                            color: _focused ? Colors.white : Palette.ink,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (widget.subtitle != null) ...[
                          SizedBox(height: m.scaled(2)),
                          Text(
                            widget.subtitle!,
                            style: TextStyle(
                              fontSize: m.scaled(11),
                              color: Palette.inkFaint,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    '›',
                    style: TextStyle(
                      fontSize: m.scaled(16),
                      color: _focused ? Palette.accent : Palette.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
