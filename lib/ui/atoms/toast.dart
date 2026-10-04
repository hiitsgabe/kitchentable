import 'package:flutter/material.dart';

import '../tokens/app_palette.dart';
import '../tokens/metrics.dart';
import '../tokens/palette.dart';

/// A line that says what just happened, then goes away.
///
/// Its own overlay rather than a SnackBar: a SnackBar is Material's shape and
/// colour and would be the only thing in the app that looks borrowed. It also
/// pins itself to the bottom of the screen, which is where the hint bar lives.
class Toast {
  static OverlayEntry? _showing;

  static void show(BuildContext context, String message, {IconData? icon}) =>
      announce(context, message, leading: icon == null ? null : _IconFor(icon));

  /// A line with something in front of it that is not an icon: a die being
  /// thrown, for one. [lasts] is how long it stays, because a thing that
  /// moves needs longer than a line that is read at a glance.
  static void announce(
    BuildContext context,
    String message, {
    Widget? leading,
    Duration lasts = const Duration(milliseconds: 1600),
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final media = MediaQuery.of(context);
    final m = Metrics.of(
      classifyDevice(
        size: media.size,
        hasTouch: media.navigationMode == NavigationMode.traditional,
      ),
    );

    // One at a time. Tapping five cards quickly should leave one line saying
    // the last thing, not five stacked on top of each other.
    _showing?.remove();

    final entry = OverlayEntry(
      builder: (_) => _Toast(metrics: m, message: message, leading: leading),
    );
    _showing = entry;
    overlay.insert(entry);

    Future.delayed(lasts, () {
      if (_showing == entry) {
        entry.remove();
        _showing = null;
      }
    });
  }
}

/// An icon drawn the way the toast has always drawn one.
class _IconFor extends StatelessWidget {
  const _IconFor(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final m = Metrics.of(
      classifyDevice(
        size: media.size,
        hasTouch: media.navigationMode == NavigationMode.traditional,
      ),
    );
    return Icon(icon, size: m.scaled(16), color: context.palette.accent);
  }
}

class _Toast extends StatefulWidget {
  const _Toast({required this.metrics, required this.message, this.leading});

  final Metrics metrics;
  final String message;
  final Widget? leading;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  )..forward();

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.metrics;

    return Positioned(
      left: 0,
      right: 0,
      top: MediaQuery.of(context).padding.top + m.scaled(16),
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _in,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, -0.4),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: _in, curve: Curves.easeOutCubic)),
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: m.scaled(16),
                  vertical: m.scaled(10),
                ),
                decoration: BoxDecoration(
                  color: Palette.surface,
                  borderRadius: BorderRadius.circular(m.scaled(99)),
                  border: Border.all(color: context.palette.accent),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: m.scaled(16),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.leading case final leading?) ...[
                      leading,
                      SizedBox(width: m.scaled(8)),
                    ],
                    Text(
                      widget.message,
                      style: TextStyle(
                        fontSize: m.scaled(13),
                        fontWeight: FontWeight.w500,
                        color: Palette.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
