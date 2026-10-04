import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gamepads/gamepads.dart';

/// Every way of pressing things, made the same thing.
///
/// Arrows, a D-pad and a stick move focus. A, Enter and Space press what is
/// focused. B and Escape close what is open. Nothing on screen names any of
/// them: the ring on the focused thing is the whole of the interface, and
/// it is the same ring a mouse sees on hover.
///
/// Two halves. The [Shortcuts] below bind the buttons that arrive as key
/// events, which is every keyboard and every controller on Android, where
/// the system turns a pad into KEYCODE_DPAD and KEYCODE_BUTTON events
/// before Flutter sees them. Flutter already maps arrows to focus direction
/// and A to activate; what it lacks is B, which is bound here to the same
/// intent Escape carries, and a fallback for that intent that closes the
/// route on top, so a sheet or a screen goes away under B whether or not
/// the screen inside bound it.
///
/// The other half is [_PadDriver], for the platforms where a controller is
/// not a keyboard: iOS and macOS, which hand controllers to the app through
/// GameController and never as key events, and the browser, which has a
/// Gamepad API nobody turns into keys. There the `gamepads` plugin reports
/// buttons and axes, and this turns them into the same intents, aimed at
/// whatever has focus. Off on Android on purpose: the plugin and the key
/// events would both report every press.
class PadInput extends StatelessWidget {
  const PadInput({super.key, required this.child});

  final Widget child;

  static bool get _drives =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  @override
  Widget build(BuildContext context) {
    final bound = Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.gameButtonB): DismissIntent(),
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
        SingleActivator(LogicalKeyboardKey.browserBack): DismissIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{DismissIntent: _CloseWhatIsOpen()},
        child: child,
      ),
    );
    return _drives ? _PadDriver(child: bound) : bound;
  }
}

/// Pops the route on top, if there is one under the focused thing.
///
/// Reached only when nothing closer to the focus took the intent: a modal
/// barrier takes it for its own sheet, a frame takes it for its own screen.
/// This is for the rest, and it is deliberately not a `Navigator.pop`: the
/// first route has nowhere to go and stays.
class _CloseWhatIsOpen extends Action<DismissIntent> {
  @override
  bool isEnabled(DismissIntent intent) {
    final context = primaryFocus?.context;
    return context != null && (Navigator.maybeOf(context)?.canPop() ?? false);
  }

  @override
  Object? invoke(DismissIntent intent) {
    final context = primaryFocus?.context;
    if (context == null) return null;
    Navigator.maybeOf(context)?.maybePop();
    return null;
  }
}

/// Turns the `gamepads` plugin's reports into intents on the focused thing.
class _PadDriver extends StatefulWidget {
  const _PadDriver({required this.child});

  final Widget child;

  @override
  State<_PadDriver> createState() => _PadDriverState();
}

class _PadDriverState extends State<_PadDriver> {
  StreamSubscription<GamepadEvent>? _events;

  /// Which way each axis last pointed, so a stick held over counts once.
  final _held = <String, TraversalDirection?>{};

  @override
  void initState() {
    super.initState();
    _events = Gamepads.events.listen(_on, onError: (_) {});
  }

  @override
  void dispose() {
    _events?.cancel();
    super.dispose();
  }

  void _on(GamepadEvent event) {
    final press = padPress(event.key, event.value, held: _held);
    if (press == null) return;
    aim(press);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// What a pad did, in the app's own words.
sealed class PadPress {
  const PadPress();
}

class PadActivate extends PadPress {
  const PadActivate();
}

class PadDismiss extends PadPress {
  const PadDismiss();
}

class PadMove extends PadPress {
  const PadMove(this.direction);
  final TraversalDirection direction;
}

/// Reads one plugin report. Null for a release, a half-pressed stick, or
/// a button this app does not use.
///
/// The plugin names keys per platform: iOS and macOS by SF Symbol
/// (`a.circle`, `dpad xAxis`, `l.joystick yAxis`), the browser by index
/// (`button 0`, `button 12` to `button 15`, `analog 0`). Matched by what
/// they contain rather than by a table per platform, because every name
/// that means A contains an `a` and a 0, and nothing else does.
///
/// [held] remembers which way each axis points, so a stick pushed and kept
/// there moves focus once and a stick let go moves it no further.
PadPress? padPress(
  String key,
  double value, {
  required Map<String, TraversalDirection?> held,
}) {
  final k = key.toLowerCase();

  // Buttons: on press only.
  if (k == 'a.circle' || k == 'button 0') {
    return value >= 0.5 ? const PadActivate() : null;
  }
  if (k == 'b.circle' || k == 'button 1') {
    return value >= 0.5 ? const PadDismiss() : null;
  }
  const webDpad = {
    'button 12': TraversalDirection.up,
    'button 13': TraversalDirection.down,
    'button 14': TraversalDirection.left,
    'button 15': TraversalDirection.right,
  };
  if (webDpad.containsKey(k)) {
    return value >= 0.5 ? PadMove(webDpad[k]!) : null;
  }

  // Axes: the D-pad and the left stick, each as x and y. One move per
  // push, none while it stays pushed, none on the way back to centre.
  final isX = k.endsWith('xaxis') || k == 'analog 0';
  final isY = k.endsWith('yaxis') || k == 'analog 1';
  final leftish =
      k.startsWith('dpad') ||
      k.startsWith('l.joystick') ||
      k.startsWith('analog');
  if (!(isX || isY) || !leftish) return null;

  TraversalDirection? now;
  if (value >= 0.5) {
    now = isX ? TraversalDirection.right : TraversalDirection.down;
  } else if (value <= -0.5) {
    now = isX ? TraversalDirection.left : TraversalDirection.up;
  }
  // iOS reports the D-pad and the stick with y up; the browser with y down.
  if (now != null && isY && !k.startsWith('analog')) {
    now = now == TraversalDirection.up
        ? TraversalDirection.down
        : TraversalDirection.up;
  }
  final before = held[k];
  held[k] = now;
  if (now == null || now == before) return null;
  return PadMove(now);
}

/// Delivers a press to whatever has focus.
void aim(PadPress press) {
  final focus = primaryFocus;
  final context = focus?.context;
  if (focus == null || context == null) return;
  switch (press) {
    case PadActivate():
      Actions.maybeInvoke(context, const ActivateIntent());
    case PadDismiss():
      Actions.maybeInvoke(context, const DismissIntent());
    case PadMove(:final direction):
      // Through the intent first, so a widget that handles direction itself
      // (the board, a text field) gets its say; then the plain traversal.
      final taken = Actions.maybeInvoke(
        context,
        DirectionalFocusIntent(direction),
      );
      if (taken == null) focus.focusInDirection(direction);
  }
}
