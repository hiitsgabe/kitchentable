import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../decks/model/game.dart';
import '../../ui/atoms/card_art.dart';
import '../../ui/atoms/pressable.dart';
import '../../ui/tokens/lettering.dart';
import '../../ui/tokens/metrics.dart';
import '../../ui/tokens/palette.dart';

/// The booster crack: a foil wrapper you tear open, the cards fanning out with
/// a shine sweeping across them, the way Pokemon TCG Pocket opens a pack.
///
/// It is a lead-in and nothing more: when the fan settles it calls [onDone] and
/// the picking grid takes over with the same cards face up. The whole area is
/// one [Pressable], so a tap or the pad's A button drives it, and there is no
/// on-screen prompt saying so. First press tears the wrapper; a press while it
/// is tearing skips to the end.
class PackOpening extends StatefulWidget {
  const PackOpening({
    super.key,
    required this.metrics,
    required this.count,
    required this.packNumber,
    required this.game,
    required this.onDone,
  });

  final Metrics metrics;

  /// How many cards are inside, so the fan has the right number of backs.
  final int count;

  /// Which pack this is, for the wrapper's label.
  final int packNumber;

  final Game game;

  /// Called once, when the crack animation finishes or is skipped.
  final VoidCallback onDone;

  @override
  State<PackOpening> createState() => _PackOpeningState();
}

class _PackOpeningState extends State<PackOpening>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  )..addStatusListener((s) {
    if (s == AnimationStatus.completed && !_done) {
      _done = true;
      widget.onDone();
    }
  });

  bool _torn = false;
  bool _done = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _advance() {
    if (!_torn) {
      setState(() => _torn = true);
      _c.forward();
    } else if (_c.isAnimating) {
      _c.value = 1; // skip straight to the settled fan
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.metrics;
    return Pressable(
      metrics: m,
      onPress: _advance,
      autofocus: true,
      ring: false,
      semanticLabel: _torn ? 'Opening the pack' : 'Open the pack',
      child: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => _torn
              ? _Fan(metrics: m, count: widget.count, game: widget.game, t: _c.value)
              : _Wrapper(metrics: m, packNumber: widget.packNumber),
        ),
      ),
    );
  }
}

/// The unopened foil before the first press.
class _Wrapper extends StatelessWidget {
  const _Wrapper({required this.metrics, required this.packNumber});

  final Metrics metrics;
  final int packNumber;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final w = m.scaled(132);
    return Container(
      width: w,
      height: w * 88 / 63,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(m.scaled(12)),
        border: Border.all(color: Palette.accent, width: m.scaled(2)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Palette.tileFocused, Palette.tile, Palette.focusWash],
        ),
        boxShadow: const [
          BoxShadow(color: Palette.accent, blurRadius: 24, spreadRadius: -8),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('PACK', style: slabText(m.scaled(22))),
            Text('$packNumber', style: slabText(m.scaled(34))),
          ],
        ),
      ),
    );
  }
}

/// The cards fanned out of the torn wrapper, with a shine sweeping over them.
class _Fan extends StatelessWidget {
  const _Fan({
    required this.metrics,
    required this.count,
    required this.game,
    required this.t,
  });

  final Metrics metrics;
  final int count;
  final Game game;
  final double t;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final cardW = m.scaled(84);
    final n = math.max(1, math.min(count, 15));

    // The fan eases open over the first two thirds, then the shine sweeps.
    final spread = Curves.easeOutBack.transform(math.min(1, t / 0.7));
    final shine = t < 0.55 ? 0.0 : (t - 0.55) / 0.45;

    final maxAngle = math.min(0.9, 0.12 * n); // radians, whole fan
    final box = cardW * 2.6;

    return SizedBox(
      width: box + cardW,
      height: box,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < n; i++)
            _fanned(m, cardW, i, n, maxAngle, spread),
          if (shine > 0)
            IgnorePointer(
              child: Opacity(
                opacity: (1 - (shine - 0.5).abs() * 2).clamp(0, 1).toDouble(),
                child: Transform.translate(
                  offset: Offset((shine * 2 - 1) * box, 0),
                  child: Transform.rotate(
                    angle: 0.35,
                    child: Container(
                      width: m.scaled(40),
                      height: box * 1.6,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0x00FFFFFF),
                            Color(0x66FFFFFF),
                            Color(0x00FFFFFF),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fanned(
    Metrics m,
    double cardW,
    int i,
    int n,
    double maxAngle,
    double spread,
  ) {
    final frac = n == 1 ? 0.5 : i / (n - 1);
    final angle = (frac - 0.5) * maxAngle * spread;
    final lift = math.sin(frac * math.pi) * cardW * 0.6 * spread;
    final dx = (frac - 0.5) * cardW * 2.2 * spread;
    return Transform.translate(
      offset: Offset(dx, -lift),
      child: Transform.rotate(
        angle: angle,
        child: CardBack(width: cardW, game: game),
      ),
    );
  }
}
