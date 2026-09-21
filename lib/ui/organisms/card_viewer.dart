import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../sources/model/catalog_card.dart';
import '../tokens/metrics.dart';
import '../tokens/palette.dart';

/// The generic Magic back, for a card that has only one face. Served by
/// Scryfall, 131 KB, and cached like any other card image.
const _genericBack =
    'https://backs.scryfall.io/large/0/a/0aeebaf5-8c7d-4636-9e82-8c27447861f7.jpg';

/// One card, big, and turnable.
///
/// Drag it and it spins. Past a quarter turn the far side is what you are
/// looking at, so the image swaps and is mirrored back the right way round.
/// For a transforming card the far side is its real second face, which is the
/// whole reason this is worth having and not just a picture.
class CardViewer extends StatefulWidget {
  const CardViewer({super.key, required this.card});

  final CatalogCard card;

  static Future<void> show(BuildContext context, CatalogCard card) =>
      Navigator.of(context).push(
        PageRouteBuilder<void>(
          opaque: false,
          barrierColor: Colors.black.withValues(alpha: 0.72),
          pageBuilder: (_, _, _) => CardViewer(card: card),
          transitionsBuilder: (_, animation, _, child) => FadeTransition(
            opacity: animation,
            child: child,
          ),
        ),
      );

  @override
  State<CardViewer> createState() => _CardViewerState();
}

class _CardViewerState extends State<CardViewer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  double _angle = 0;
  double _from = 0;
  double _to = 0;

  @override
  void initState() {
    super.initState();
    _spin.addListener(() {
      setState(() {
        _angle = _from + (_to - _from) * Curves.easeOutCubic.transform(
              _spin.value,
            );
      });
    });
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  void _settle() {
    // Land on whichever face is nearer, so it never rests on its edge.
    final turns = (_angle / math.pi).round();
    _from = _angle;
    _to = turns * math.pi;
    _spin.forward(from: 0);
  }

  void _flip() {
    _from = _angle;
    _to = _angle + math.pi;
    _spin.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final m = Metrics.of(classifyDevice(
      size: media.size,
      hasTouch: media.navigationMode == NavigationMode.traditional,
    ));

    final width = math.min(
      media.size.width * 0.78,
      media.size.height * 0.62 * 63 / 88,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.of(context).maybePop(),
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                // Absorbs the tap that would close, so the card itself is
                // draggable without the backdrop stealing the gesture.
                onTap: _flip,
                onHorizontalDragUpdate: (d) => setState(() {
                  _angle += d.delta.dx * 0.012;
                }),
                onHorizontalDragEnd: (_) => _settle(),
                child: _Face(card: widget.card, angle: _angle, width: width),
              ),
              SizedBox(height: m.scaled(22)),
              Text(
                widget.card.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: m.scaled(17),
                  fontWeight: FontWeight.w600,
                  color: Palette.ink,
                ),
              ),
              SizedBox(height: m.scaled(6)),
              Text(
                'drag to turn it over',
                style: TextStyle(
                  fontSize: m.scaled(11),
                  color: Palette.inkFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({
    required this.card,
    required this.angle,
    required this.width,
  });

  final CatalogCard card;
  final double angle;
  final double width;

  @override
  Widget build(BuildContext context) {
    // Normalised so the test survives a card spun many times round.
    final turned = (angle / math.pi).abs() % 2 >= 0.5 &&
        (angle / math.pi).abs() % 2 < 1.5;

    final url = turned
        ? (card.imageBack ?? _genericBack)
        : (card.imageNormal ?? card.imageSmall);

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0012) // the perspective, without which it is a squash
        ..rotateY(angle),
      child: Transform(
        alignment: Alignment.center,
        // The far side would render mirrored, so it is flipped back.
        transform: Matrix4.identity()..rotateY(turned ? math.pi : 0),
        child: Container(
          width: width,
          height: width * 88 / 63,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(width * 0.045),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: width * 0.12,
                offset: Offset(0, width * 0.04),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(width * 0.045),
            child: url == null
                ? ColoredBox(
                    color: Palette.tile,
                    child: Center(
                      child: Text(
                        card.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Palette.inkMuted),
                      ),
                    ),
                  )
                : CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => const ColoredBox(color: Palette.tile),
                    errorWidget: (_, _, _) =>
                        const ColoredBox(color: Palette.tile),
                  ),
          ),
        ),
      ),
    );
  }
}
