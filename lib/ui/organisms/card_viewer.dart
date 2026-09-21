import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../sources/model/catalog_card.dart';
import '../tokens/metrics.dart';
import '../tokens/palette.dart';

/// The generic Magic back, served by Scryfall, for a card with only one face.
const _genericBack =
    'https://backs.scryfall.io/large/0/a/0aeebaf5-8c7d-4636-9e82-8c27447861f7.jpg';

/// One card, lifted off the screen and turnable in the hand.
///
/// The first version swapped two flat pictures at a quarter turn and looked
/// exactly like that. What makes an object read as an object is not the
/// rotation, it is everything that moves with it: a highlight sliding across
/// the face, the side turning away going dark, a shadow that leans the other
/// way, and a visible edge at the moment it is side on. That last one also
/// hides the texture swap, because a card seen edge on has no face to swap.
class CardViewer extends StatefulWidget {
  const CardViewer({super.key, required this.card});

  final CatalogCard card;

  static Future<void> show(BuildContext context, CatalogCard card) =>
      Navigator.of(context).push(
        PageRouteBuilder<void>(
          opaque: false,
          barrierColor: Colors.black.withValues(alpha: 0.78),
          pageBuilder: (_, _, _) => CardViewer(card: card),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );

  @override
  State<CardViewer> createState() => _CardViewerState();
}

class _CardViewerState extends State<CardViewer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ease = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  /// Turn around the vertical axis. This is the flip.
  double _yaw = 0;

  /// Tilt around the horizontal axis. This is the lean, and it always returns
  /// to flat, because a card resting in your hand does not stay tipped.
  double _pitch = 0;

  double _yawFrom = 0, _yawTo = 0, _pitchFrom = 0, _pitchTo = 0;

  @override
  void initState() {
    super.initState();
    _ease.addListener(() {
      final t = Curves.easeOutBack.transform(_ease.value).clamp(-0.4, 1.4);
      setState(() {
        _yaw = _yawFrom + (_yawTo - _yawFrom) * t;
        _pitch = _pitchFrom + (_pitchTo - _pitchFrom) * t;
      });
    });
  }

  @override
  void dispose() {
    _ease.dispose();
    super.dispose();
  }

  void _settle() {
    _yawFrom = _yaw;
    _pitchFrom = _pitch;
    _yawTo = (_yaw / math.pi).round() * math.pi;
    _pitchTo = 0;
    _ease.forward(from: 0);
  }

  void _flip() {
    _yawFrom = _yaw;
    _pitchFrom = _pitch;
    _yawTo = (_yaw / math.pi).round() * math.pi + math.pi;
    _pitchTo = 0;
    _ease.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final m = Metrics.of(
      classifyDevice(
        size: media.size,
        hasTouch: media.navigationMode == NavigationMode.traditional,
      ),
    );

    // Fits whichever way round the screen is, leaving room for the name.
    final width = math.min(
      media.size.width * 0.74,
      media.size.height * 0.56 * 63 / 88,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.of(context).maybePop(),
        behavior: HitTestBehavior.opaque,
        // Centred on both axes, with the caption riding along underneath
        // rather than pushing the card off centre.
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _flip,
                onPanUpdate: (d) => setState(() {
                  _yaw += d.delta.dx * 0.011;
                  // Inverted so dragging the top of the card away from you
                  // tips the top away from you.
                  _pitch = (_pitch - d.delta.dy * 0.006).clamp(-0.45, 0.45);
                }),
                onPanEnd: (_) => _settle(),
                child: _Card(
                  card: widget.card,
                  yaw: _yaw,
                  pitch: _pitch,
                  width: width,
                ),
              ),
              SizedBox(height: m.scaled(26)),
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
                widget.card.imageBack == null
                    ? 'drag to turn it over'
                    : 'drag to turn it over, it has a second face',
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

class _Card extends StatelessWidget {
  const _Card({
    required this.card,
    required this.yaw,
    required this.pitch,
    required this.width,
  });

  final CatalogCard card;
  final double yaw;
  final double pitch;
  final double width;

  @override
  Widget build(BuildContext context) {
    final height = width * 88 / 63;
    final radius = BorderRadius.circular(width * 0.048);

    final facing = math.cos(yaw);
    final showingBack = facing < 0;
    final url = showingBack
        ? (card.imageBack ?? _genericBack)
        : (card.imageNormal ?? card.imageSmall);

    // Zero when the card is edge on, one when it is square to you. Drives the
    // edge, the shadow and how far the highlight has travelled.
    final openness = facing.abs();

    return Stack(
      alignment: Alignment.center,
      children: [
        // Outside the rotation on purpose. A shadow belongs to the ground, and
        // the first version put it inside, so it turned and squashed along
        // with the card and stopped reading as a shadow at all.
        Transform.translate(
          offset: Offset(
            -math.sin(yaw) * width * 0.18,
            math.sin(pitch) * width * 0.12 + width * 0.07,
          ),
          child: Container(
            width: width * 0.88,
            height: height * 0.88,
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6 * openness),
                  blurRadius: width * 0.26,
                  spreadRadius: width * 0.015,
                ),
              ],
            ),
          ),
        ),
        Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0014) // perspective, or it is just a squash
            ..rotateX(pitch)
            ..rotateY(yaw),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform(
                alignment: Alignment.center,
                // The far side would come out mirrored, so it is turned back.
                transform: Matrix4.identity()
                  ..rotateY(showingBack ? math.pi : 0),
                child: SizedBox(
                  width: width,
                  height: height,
                  child: ClipRRect(
                    borderRadius: radius,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (url == null)
                          ColoredBox(
                            color: Palette.tile,
                            child: Center(
                              child: Text(
                                card.name,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Palette.inkMuted),
                              ),
                            ),
                          )
                        else
                          CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            placeholder: (_, _) =>
                                const ColoredBox(color: Palette.tile),
                            errorWidget: (_, _, _) =>
                                const ColoredBox(color: Palette.tile),
                          ),

                        // Gloss. A narrow band of white that slides across the
                        // face as the card turns, which is most of what sells it.
                        IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment(-1 - math.sin(yaw) * 2, -1),
                                end: Alignment(1 - math.sin(yaw) * 2, 1),
                                stops: const [0.30, 0.46, 0.62],
                                colors: [
                                  Colors.white.withValues(alpha: 0),
                                  Colors.white.withValues(
                                    alpha: 0.26 * (1 - openness * 0.5),
                                  ),
                                  Colors.white.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // The side swinging away falls into shadow.
                        IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: yaw.isNegative
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                end: yaw.isNegative
                                    ? Alignment.centerLeft
                                    : Alignment.centerRight,
                                colors: [
                                  Colors.black.withValues(
                                    alpha: 0.55 * (1 - openness),
                                  ),
                                  Colors.black.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // The edge of the card, widest exactly when it is side on. This is
              // what turns the texture swap from a glitch into a thing turning
              // over, because at that instant there is no face to see anyway.
              IgnorePointer(
                // Cubed rather than linear so it is gone by the time the face is
                // readable. The first version kept a minimum width and drew a
                // bright line straight down the middle of the art.
                child: Opacity(
                  opacity: math.pow(1 - openness, 3).toDouble().clamp(0.0, 1.0),
                  child: Container(
                    width: width * 0.055 * (1 - openness) + width * 0.008,
                    height: height * 0.985,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(width * 0.008),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF2A2430),
                          Color(0xFFCFC6D6),
                          Color(0xFF1A1620),
                        ],
                        stops: [0, 0.45, 1],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
