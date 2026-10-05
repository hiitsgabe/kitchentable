import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../decks/model/game.dart';
import '../../ui/atoms/card_art.dart';
import '../../ui/atoms/card_image.dart';
import '../../ui/atoms/pressable.dart';
import '../../ui/tokens/lettering.dart';
import '../../ui/tokens/metrics.dart';
import '../../ui/tokens/palette.dart';

/// The booster crack: a foil wrapper, crimped top and bottom, that sways in
/// space like a card until you tear the top off and the cards fan out, the way
/// Pokemon TCG Pocket opens a pack.
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
    this.label,
    this.coverUrl,
    this.symbolUrl,
  });

  final Metrics metrics;

  /// How many cards are inside, so the fan has the right number of backs.
  final int count;

  /// Which pack this is, for the wrapper's label.
  final int packNumber;

  /// The set, shown large on the foil. Null falls back to "PACK".
  final String? label;

  /// Art for a card from the pack, printed dimmed on the foil as the pack's
  /// face, the way a real booster shows a card. Null leaves the plain foil.
  final String? coverUrl;

  /// The set's symbol (an SVG), drawn above the name. Null, or a fetch that
  /// fails, leaves just the name.
  final String? symbolUrl;

  final Game game;

  /// Called once, when the crack animation finishes or is skipped.
  final VoidCallback onDone;

  @override
  State<PackOpening> createState() => _PackOpeningState();
}

class _PackOpeningState extends State<PackOpening>
    with TickerProviderStateMixin {
  // The sealed pack never sits still: a slow sway gives it the depth of a
  // thing held in a hand rather than a flat card pinned to the screen.
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  late final AnimationController _tear = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
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
    _idle.dispose();
    _tear.dispose();
    super.dispose();
  }

  void _advance() {
    if (!_torn) {
      setState(() => _torn = true);
      _idle.stop();
      _tear.forward();
    } else if (_tear.isAnimating) {
      _tear.value = 1; // skip to the settled fan
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
          animation: _torn ? _tear : _idle,
          builder: (context, _) => _torn
              ? _Tearing(
                  metrics: m,
                  count: widget.count,
                  packNumber: widget.packNumber,
                  label: widget.label,
                  coverUrl: widget.coverUrl,
                  symbolUrl: widget.symbolUrl,
                  game: widget.game,
                  t: _tear.value,
                )
              : _Sealed(
                  metrics: m,
                  packNumber: widget.packNumber,
                  label: widget.label,
                  coverUrl: widget.coverUrl,
                  symbolUrl: widget.symbolUrl,
                  sway: _idle.value,
                ),
        ),
      ),
    );
  }
}

/// The dimensions and the foil, shared by the sealed pack and the torn one so
/// the body does not jump when the top comes off.
const double _packW = 150;
const double _aspect = 88 / 60; // a touch taller and narrower than a card
const double _crimp = 12; // height of a crimped band

BoxDecoration _foil(Metrics m) => BoxDecoration(
  gradient: const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF3A1430),
      Palette.tileFocused,
      Color(0xFF17121F),
      Palette.tileFocused,
    ],
    stops: [0, 0.35, 0.7, 1],
  ),
  border: Border.all(color: Palette.accent, width: m.scaled(1.5)),
);

/// The unopened booster: a crimped foil wrapper tilting slowly in space.
class _Sealed extends StatelessWidget {
  const _Sealed({
    required this.metrics,
    required this.packNumber,
    required this.label,
    required this.coverUrl,
    required this.symbolUrl,
    required this.sway,
  });

  final Metrics metrics;
  final int packNumber;
  final String? label;
  final String? coverUrl;
  final String? symbolUrl;
  final double sway;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final angle = sway * math.pi * 2;
    final transform = Matrix4.identity()
      ..setEntry(3, 2, 0.0014)
      ..rotateY(math.sin(angle) * 0.22)
      ..rotateX(math.cos(angle) * 0.07);
    return Transform(
      alignment: Alignment.center,
      transform: transform,
      child: _Foil(
        metrics: m,
        packNumber: packNumber,
        label: label,
        coverUrl: coverUrl,
        symbolUrl: symbolUrl,
        glow: true,
      ),
    );
  }
}

/// The pack coming apart: the top crimp tears up and away, a dark mouth opens,
/// and the cards fan out of it. The body fades as the fan takes over.
class _Tearing extends StatelessWidget {
  const _Tearing({
    required this.metrics,
    required this.count,
    required this.packNumber,
    required this.label,
    required this.coverUrl,
    required this.symbolUrl,
    required this.game,
    required this.t,
  });

  final Metrics metrics;
  final int count;
  final int packNumber;
  final String? label;
  final String? coverUrl;
  final String? symbolUrl;
  final Game game;
  final double t;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final w = m.scaled(_packW);
    final h = w * _aspect;

    // The tear leads, the fan follows, and the body dims out behind the fan.
    final tear = Curves.easeIn.transform(math.min(1, t / 0.4));
    final fan = t < 0.3 ? 0.0 : (t - 0.3) / 0.7;
    final bodyFade = (1 - fan * 1.3).clamp(0.0, 1.0).toDouble();

    return SizedBox(
      width: w * 2.4,
      height: h * 1.4,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // The pack body, dimming as the cards come out.
          Opacity(
            opacity: bodyFade,
            child: _Foil(
              metrics: m,
              packNumber: packNumber,
              label: label,
              coverUrl: coverUrl,
              symbolUrl: symbolUrl,
              glow: false,
              openMouth: tear,
            ),
          ),
          // The torn-off top crimp, flung up and spinning away.
          Transform.translate(
            offset: Offset(tear * m.scaled(28), -h * 0.5 - tear * m.scaled(120)),
            child: Transform.rotate(
              angle: tear * 0.6,
              child: Opacity(
                opacity: (1 - tear).clamp(0.0, 1.0).toDouble(),
                child: _CrimpBand(metrics: m, width: w),
              ),
            ),
          ),
          // The cards fanning out of the opened top.
          if (fan > 0)
            Transform.translate(
              offset: Offset(0, -h * 0.12),
              child: _Fan(metrics: m, count: count, game: game, spread: fan),
            ),
        ],
      ),
    );
  }
}

/// The foil rectangle itself: crimped top and bottom, a sheen down the middle,
/// and the set on it. [openMouth] pulls a dark gap open under the top crimp as
/// the pack tears.
class _Foil extends StatelessWidget {
  const _Foil({
    required this.metrics,
    required this.packNumber,
    required this.label,
    required this.coverUrl,
    required this.symbolUrl,
    required this.glow,
    this.openMouth = 0,
  });

  final Metrics metrics;
  final int packNumber;
  final String? label;
  final String? coverUrl;
  final String? symbolUrl;
  final bool glow;
  final double openMouth;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final w = m.scaled(_packW);
    final h = w * _aspect;
    final crimp = m.scaled(_crimp);

    return Container(
      width: w,
      height: h,
      decoration: glow
          ? const BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Palette.accent,
                  blurRadius: 34,
                  spreadRadius: -10,
                ),
              ],
            )
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(m.scaled(10)),
        child: Stack(
          children: [
            // The foil body.
            Positioned.fill(
              child: DecoratedBox(
                decoration: _foil(m).copyWith(
                  borderRadius: BorderRadius.circular(m.scaled(10)),
                ),
              ),
            ),
            // A card from the set, printed dimmed over the foil as the pack's
            // face. A real booster shows a card; this is that, darkened so the
            // set reads and the pack still feels sealed.
            if (coverUrl != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                      Color(0x99120A16),
                      BlendMode.darken,
                    ),
                    child: CardImage(
                      url: coverUrl!,
                      fallback: const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            // A bright diagonal sheen.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: const [
                        Color(0x00FFFFFF),
                        Color(0x33FFFFFF),
                        Color(0x00FFFFFF),
                      ],
                      stops: const [0.35, 0.5, 0.65],
                    ),
                  ),
                ),
              ),
            ),
            // The set, centred.
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: m.scaled(8)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (symbolUrl != null) ...[
                      SvgPicture.network(
                        symbolUrl!,
                        width: m.scaled(40),
                        height: m.scaled(40),
                        colorFilter: const ColorFilter.mode(
                          Palette.slabInk,
                          BlendMode.srcIn,
                        ),
                        placeholderBuilder: (_) => SizedBox(height: m.scaled(40)),
                      ),
                      SizedBox(height: m.scaled(8)),
                    ],
                    Text(
                      (label ?? 'PACK').toUpperCase(),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: slabText(m.scaled(16)),
                    ),
                    SizedBox(height: m.scaled(4)),
                    Text(
                      'PACK $packNumber',
                      style: pixel(
                        size: m.scaled(10),
                        weight: 600,
                        color: Palette.inkMuted,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // The dark mouth that opens under the top crimp as it tears.
            if (openMouth > 0)
              Positioned(
                top: crimp,
                left: 0,
                right: 0,
                child: Container(
                  height: (h * 0.22) * openMouth,
                  color: Palette.felt,
                ),
              ),
            // The crimped bands, top and bottom.
            Align(
              alignment: Alignment.topCenter,
              child: _CrimpBand(metrics: m, width: w),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: _CrimpBand(metrics: m, width: w, pointDown: true),
            ),
          ],
        ),
      ),
    );
  }
}

/// One heat-sealed crimp: a band of chevrons across the pack. [pointDown] draws
/// the bottom one, its teeth the other way.
class _CrimpBand extends StatelessWidget {
  const _CrimpBand({
    required this.metrics,
    required this.width,
    this.pointDown = false,
  });

  final Metrics metrics;
  final double width;
  final bool pointDown;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    return SizedBox(
      width: width,
      height: m.scaled(_crimp),
      child: CustomPaint(
        painter: _CrimpPainter(
          pointDown: pointDown,
          tooth: m.scaled(9),
        ),
      ),
    );
  }
}

class _CrimpPainter extends CustomPainter {
  _CrimpPainter({required this.pointDown, required this.tooth});

  final bool pointDown;
  final double tooth;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = Palette.accent;
    final back = Paint()..color = const Color(0xFF2A0E1E);
    // A solid strip behind the teeth, so the crimp reads as a sealed edge.
    canvas.drawRect(Offset.zero & size, back);

    final path = Path();
    final mid = size.height * 0.45;
    if (!pointDown) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, mid);
      for (var x = size.width; x > 0; x -= tooth) {
        path.lineTo(x - tooth / 2, size.height);
        path.lineTo(x - tooth, mid);
      }
      path.close();
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, size.height - mid);
      for (var x = size.width; x > 0; x -= tooth) {
        path.lineTo(x - tooth / 2, 0);
        path.lineTo(x - tooth, size.height - mid);
      }
      path.close();
    }
    canvas.drawPath(path, fill);
  }

  @override
  bool shouldRepaint(_CrimpPainter old) =>
      old.pointDown != pointDown || old.tooth != tooth;
}

/// The cards fanned out of the torn wrapper, opening over [spread] from 0 to 1.
class _Fan extends StatelessWidget {
  const _Fan({
    required this.metrics,
    required this.count,
    required this.game,
    required this.spread,
  });

  final Metrics metrics;
  final int count;
  final Game game;
  final double spread;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final cardW = m.scaled(84);
    final n = math.max(1, math.min(count, 15));
    final open = Curves.easeOutBack.transform(spread.clamp(0, 1).toDouble());
    final maxAngle = math.min(0.9, 0.12 * n);
    final box = cardW * 2.6;

    return SizedBox(
      width: box + cardW,
      height: box,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < n; i++)
            _fanned(m, cardW, i, n, maxAngle, open),
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
    double open,
  ) {
    final frac = n == 1 ? 0.5 : i / (n - 1);
    final angle = (frac - 0.5) * maxAngle * open;
    final lift = math.sin(frac * math.pi) * cardW * 0.6 * open;
    final dx = (frac - 0.5) * cardW * 2.2 * open;
    return Transform.translate(
      offset: Offset(dx, -lift),
      child: Transform.rotate(
        angle: angle,
        child: Opacity(
          opacity: open.clamp(0.0, 1.0).toDouble(),
          child: CardBack(width: cardW, game: game),
        ),
      ),
    );
  }
}
