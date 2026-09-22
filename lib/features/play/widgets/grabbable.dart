import 'package:flutter/material.dart';

/// A child you can pick up and move, that starts where your finger did.
///
/// `onPanStart` does not fire until the finger has travelled `kTouchSlop`, and
/// that first stretch of travel is never reported as a delta. Anything driven
/// by `details.delta` alone therefore trails the finger by about eighteen
/// logical pixels for the whole drag and is let go short of where it was put
/// down. Measured once at sixteen mat units on a drop that the geometry said
/// should have been a hundred and nine.
///
/// The `Listener` sees the raw pointer down, which happens before the drag
/// recogniser has decided anything, and the first [onMove] hands back the
/// travel the recogniser swallowed.
///
/// Everything here is in the child's own coordinates, which is what a drag
/// delta already is. The canvas draws its mats inside an `InteractiveViewer`,
/// so on a zoomed table screen pixels and mat units are not the same thing,
/// and handing back travel measured in the wrong one would overshoot.
///
/// There is one of these rather than a copy in each renderer because the
/// mistake is easy to make twice and invisible both times.
class Grabbable extends StatefulWidget {
  const Grabbable({
    super.key,
    required this.onMove,
    required this.onDrop,
    required this.child,
  });

  /// How far the finger has gone since the last call, in logical pixels. The
  /// first call of a drag carries the swallowed travel with it.
  final void Function(Offset delta) onMove;

  /// The finger is up. Nothing more arrives for this drag.
  final VoidCallback onDrop;

  final Widget child;

  @override
  State<Grabbable> createState() => _GrabbableState();
}

class _GrabbableState extends State<Grabbable> {
  /// Where the finger went down, before the drag was recognised.
  Offset? _grabbedAt;

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (event) => _grabbedAt = event.localPosition,
        child: GestureDetector(
          onPanStart: _start,
          onPanUpdate: (details) => widget.onMove(details.delta),
          onPanEnd: (_) => widget.onDrop(),
          child: widget.child,
        ),
      );

  void _start(DragStartDetails details) {
    final grabbed = _grabbedAt;
    if (grabbed == null) return;
    widget.onMove(details.localPosition - grabbed);
  }
}
