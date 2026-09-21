import 'dart:io' show File;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mesh_gradient/mesh_gradient.dart';

import 'backdrop_style.dart';

/// What sits behind every screen.
///
/// The app draws on top of this, and its surfaces are translucent so the thing
/// shows through instead of being covered up. That is the whole reason the
/// palette's ground colour is almost nothing: it is a fallback, not the look.
class Backdrop extends StatelessWidget {
  const Backdrop({super.key, required this.style, required this.child});

  final BackdropStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: _paint()),
        Positioned.fill(child: child),
      ],
    );
  }

  Widget _paint() => switch (style.kind) {
        BackdropKind.aurora => _Aurora(style: style),
        BackdropKind.drift => _Drift(style: style),
        BackdropKind.flat => _Flat(style: style),
        BackdropKind.image => _Picture(style: style),
      };
}

class _Flat extends StatelessWidget {
  const _Flat({required this.style});

  final BackdropStyle style;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(style.bottom, style.top, 0.14)!,
              style.bottom,
            ],
          ),
        ),
      );
}

/// The fluid one, and the only part of the app that leans on a fragment shader.
/// If the shader ever stops working the other three still do, which is why the
/// player can pick.
class _Aurora extends StatelessWidget {
  const _Aurora({required this.style});

  final BackdropStyle style;

  @override
  Widget build(BuildContext context) {
    final bottom = style.bottom;
    final top = style.top;

    return AnimatedMeshGradient(
      colors: [
        bottom,
        Color.lerp(bottom, top, 0.55)!,
        Color.lerp(bottom, top, 0.12)!,
        Color.lerp(bottom, top, 0.32)!,
      ],
      options: AnimatedMeshGradientOptions(speed: 1.4, frequency: 2.6),
    );
  }
}

/// Painted rather than shaded: three blobs drifting on long, prime-ish periods
/// so the loop never lines up and never reads as a loop.
class _Drift extends StatefulWidget {
  const _Drift({required this.style});

  final BackdropStyle style;

  @override
  State<_Drift> createState() => _DriftState();
}

class _DriftState extends State<_Drift> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  )..repeat();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _clock,
        builder: (_, _) => CustomPaint(
          painter: _DriftPainter(style: widget.style, t: _clock.value),
        ),
      );
}

class _DriftPainter extends CustomPainter {
  _DriftPainter({required this.style, required this.t});

  final BackdropStyle style;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = style.bottom);

    const periods = [1.0, 0.61, 0.37];
    const origins = [Offset(0.25, 0.3), Offset(0.78, 0.22), Offset(0.5, 0.85)];
    const strengths = [0.30, 0.22, 0.16];

    for (var i = 0; i < periods.length; i++) {
      final a = 2 * math.pi * (t * periods[i] + i / 3);
      final centre = Offset(
        (origins[i].dx + 0.12 * math.cos(a)) * size.width,
        (origins[i].dy + 0.10 * math.sin(a * 1.3)) * size.height,
      );
      final radius = size.shortestSide * (0.55 + 0.08 * math.sin(a));

      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              style.top.withValues(alpha: strengths[i]),
              style.top.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: centre, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(_DriftPainter old) => old.t != t || old.style != style;
}

class _Picture extends StatelessWidget {
  const _Picture({required this.style});

  final BackdropStyle style;

  @override
  Widget build(BuildContext context) {
    final path = style.imagePath;
    // A path is meaningless in a browser, where there is no file system to
    // point at, so the web build falls back rather than showing a broken box.
    if (path == null || kIsWeb) return _Flat(style: style);

    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _Flat(style: style),
      // Dimmed, because the app has to stay readable on top of whatever
      // somebody picked, and people pick bright pictures.
      color: Colors.black.withValues(alpha: 0.45),
      colorBlendMode: BlendMode.darken,
    );
  }
}
