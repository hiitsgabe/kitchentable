import 'package:flutter/material.dart';

import '../tokens/app_palette.dart';
import '../tokens/lettering.dart';
import '../tokens/metrics.dart';
import '../tokens/palette.dart';
import 'pressable.dart';

/// A box you type into, drawn as a hole in the tray rather than a tile on it.
///
/// Every pressable thing in the app is a slab standing proud of the surface,
/// so the one thing that is not pressable has to be the other way up: dark,
/// inset, with the near black outline on the outside of the hole. The pixel
/// face is used for what is typed, because a name typed here is read off a
/// chair at the table in the same face.
///
/// Two states under a pad, the way a television app does it. The box is a
/// stop like any other: the ring lands on it and moves off it. Select, or a
/// tap, opens it for typing, which is when the field inside takes focus and
/// the keyboard comes up; Enter or back closes it and the ring is on the
/// box again. Without the two states a D-pad that reached the field could
/// never leave it, because a field keeps the arrows for its own caret.
class TextFieldBox extends StatefulWidget {
  const TextFieldBox({
    super.key,
    required this.metrics,
    required this.controller,
    required this.hint,
    this.lines = 1,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
  });

  final Metrics metrics;
  final TextEditingController controller;
  final String hint;
  final int lines;

  /// Opens for typing straight away, for a screen that is about the typing.
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<TextFieldBox> createState() => _TextFieldBoxState();
}

class _TextFieldBoxState extends State<TextFieldBox> {
  final _box = FocusNode(debugLabel: 'text box');

  // Skipped by the D-pad, never by a tap, a test or select on the box: the
  // ring walks past the caret and only a deliberate press puts it there.
  final _field = FocusNode(debugLabel: 'text field', skipTraversal: true);

  @override
  void initState() {
    super.initState();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _edit();
      });
    }
  }

  @override
  void dispose() {
    _field.dispose();
    _box.dispose();
    super.dispose();
  }

  void _edit() => _field.requestFocus();

  void _leave() => _box.requestFocus();

  @override
  Widget build(BuildContext context) {
    final m = widget.metrics;

    return Pressable(
      metrics: m,
      focusNode: _box,
      onPress: _edit,
      descendantsAreFocusable: true,
      radius: m.scaled(9),
      semanticLabel: widget.hint,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: m.scaled(13),
          vertical: m.scaled(11),
        ),
        decoration: BoxDecoration(
          color: Palette.trayWell,
          borderRadius: BorderRadius.circular(m.scaled(9)),
          border: Border.all(color: Palette.outline, width: m.scaled(2)),
        ),
        child: Actions(
          actions: <Type, Action<Intent>>{
            // Back while typing shuts the field, not the screen.
            DismissIntent: CallbackAction<DismissIntent>(
              onInvoke: (_) {
                _leave();
                return null;
              },
            ),
          },
          child: TextField(
            controller: widget.controller,
            focusNode: _field,
            minLines: widget.lines,
            maxLines: widget.lines,
            onChanged: widget.onChanged,
            onSubmitted: (text) {
              _leave();
              widget.onSubmitted?.call(text);
            },
            onTapOutside: (_) => _field.unfocus(),
            cursorColor: context.palette.accent,
            style: pixel(size: m.scaled(16), weight: 600, height: 1.3),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: widget.hint,
              hintStyle: pixel(
                size: m.scaled(16),
                weight: 500,
                color: Palette.inkFaint,
                height: 1.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
