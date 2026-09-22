import 'dart:math' as math;

import 'package:flutter/gestures.dart';

import 'package:flutter/material.dart';

import '../../sources/model/catalog_card.dart';
import '../../table/model/card_instance.dart';
import '../tokens/metrics.dart';
import '../atoms/card_image.dart';
import '../tokens/palette.dart';
import 'card_shading.dart';

/// The generic Magic back, served by Scryfall, for a card with only one face.
const _genericBack =
    'https://backs.scryfall.io/large/0/a/0aeebaf5-8c7d-4636-9e82-8c27447861f7.jpg';

/// What the viewer can ask for, beyond looking.
///
/// Turning a card ninety degrees is not here: that is the tap, on the table,
/// where the player can see the board around it. These are the deliberate
/// ones, which is why they are behind a press and hold.
enum CardAction { upsideDown, straighten, flip, counterUp, counterDown }

/// One card, lifted off the screen and turnable in the hand.
///
/// The first version swapped two flat pictures at a quarter turn and looked
/// exactly like that. What makes an object read as an object is not the
/// rotation, it is everything that moves with it: a highlight sliding across
/// the face, the side turning away going dark, a shadow that leans the other
/// way.
///
/// An earlier version also drew the card's edge at the instant it is side on,
/// to cover the texture swapping over. Both faces are mounted now so there is
/// no swap to cover, and what the edge actually did was flick a white line
/// across the middle of the card on every single turn.
class CardViewer extends StatefulWidget {
  const CardViewer({
    super.key,
    required this.card,
    this.instance,
    this.onAct,
  });

  final CatalogCard card;

  /// The card on a table, when there is one. Null from the deck builder,
  /// where a printing is being looked at rather than a card being played, and
  /// then the viewer offers nothing to do because there is nothing to do it
  /// to.
  final CardInstance? instance;

  final void Function(CardAction)? onAct;

  static Future<CardAction?> show(
    BuildContext context,
    CatalogCard card, {
    CardInstance? instance,
  }) =>
      Navigator.of(context).push(
        // Not PageRouteBuilder<CardAction?>. push<T> already hands back a
        // Future<T?>, so the route's own type argument is the non null one.
        PageRouteBuilder<CardAction>(
          opaque: false,
          barrierColor: Colors.black.withValues(alpha: 0.78),
          pageBuilder: (context, _, _) => CardViewer(
            card: card,
            instance: instance,
            onAct: (action) => Navigator.of(context).pop(action),
          ),
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

  /// Pinched, or scrolled with a wheel. One is the card at its natural size.
  double _zoom = 1;
  double _zoomAtGestureStart = 1;

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
        // The bar is a sibling of the card, never a child of it. Everything
        // under _Card lives inside a Matrix4 that is being turned in three
        // dimensions, and a control mounted in there turns with it.
        child: Stack(
          children: [
            // Centred on both axes, with the caption riding along underneath
            // rather than pushing the card off centre.
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Listener(
                    // A mouse wheel is not a scale gesture, so it is caught
                    // separately. Without this, zoom would be touch only and
                    // the browser build could never read a card's text.
                    onPointerSignal: (event) {
                      if (event is PointerScrollEvent) {
                        setState(() {
                          _zoom = (_zoom - event.scrollDelta.dy * 0.0016)
                              .clamp(1.0, 3.2);
                        });
                      }
                    },
                    child: GestureDetector(
                      onTap: _flip,
                      // Scale rather than pan, because a GestureDetector
                      // cannot arbitrate both. focalPointDelta carries the
                      // drag, so the turn and the pinch come from one
                      // recogniser.
                      onScaleStart: (_) => _zoomAtGestureStart = _zoom,
                      onScaleUpdate: (d) => setState(() {
                        _zoom = (_zoomAtGestureStart * d.scale).clamp(1.0, 3.2);
                        if (d.pointerCount == 1) {
                          _yaw += d.focalPointDelta.dx * 0.011;
                          // Inverted so dragging the top of the card away from
                          // you tips the top away from you.
                          _pitch = (_pitch - d.focalPointDelta.dy * 0.006)
                              .clamp(-0.45, 0.45);
                        }
                      }),
                      onScaleEnd: (_) => _settle(),
                      child: _Card(
                        card: widget.card,
                        yaw: _yaw,
                        pitch: _pitch,
                        width: width * _zoom,
                      ),
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
                        ? 'drag to turn it over, pinch or scroll to read it'
                        : 'drag to turn it over, it has a second face',
                    style: TextStyle(
                      fontSize: m.scaled(11),
                      color: Palette.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
            _actions(m),
          ],
        ),
      ),
    );
  }

  Widget _actions(Metrics m) {
    final instance = widget.instance;
    if (instance == null) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.all(m.safeInset),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (instance.rotation == 180)
              _act(m, const Key('act-straighten'), Icons.straighten_rounded,
                  'Straighten', CardAction.straighten)
            else
              _act(m, const Key('act-upside-down'),
                  Icons.flip_camera_android_rounded, 'Upside down',
                  CardAction.upsideDown),
            SizedBox(width: m.scaled(10)),
            _act(
              m,
              const Key('act-flip'),
              Icons.layers_rounded,
              instance.faceDown ? 'Face up' : 'Face down',
              CardAction.flip,
            ),
            SizedBox(width: m.scaled(18)),
            _act(m, const Key('act-counter-down'), Icons.remove_rounded, null,
                CardAction.counterDown),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: m.scaled(10)),
              child: Text(
                '${instance.counters.values.fold(0, (a, b) => a + b)}',
                style: TextStyle(
                  fontSize: m.scaled(18),
                  fontWeight: FontWeight.w700,
                  color: Palette.ink,
                ),
              ),
            ),
            _act(m, const Key('act-counter-up'), Icons.add_rounded, null,
                CardAction.counterUp),
          ],
        ),
      ),
    );
  }

  Widget _act(
    Metrics m,
    Key key,
    IconData icon,
    String? label,
    CardAction action,
  ) =>
      GestureDetector(
        key: key,
        onTap: () => widget.onAct?.call(action),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: m.scaled(label == null ? 10 : 14),
            vertical: m.scaled(10),
          ),
          decoration: BoxDecoration(
            color: Palette.tile,
            borderRadius: BorderRadius.circular(m.scaled(10)),
            border: Border.all(color: Palette.tileEdge),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: m.scaled(17), color: Palette.inkMuted),
              if (label != null) ...[
                SizedBox(width: m.scaled(8)),
                Text(
                  label,
                  style:
                      TextStyle(fontSize: m.scaled(12), color: Palette.ink),
                ),
              ],
            ],
          ),
        ),
      );
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

    final light = CardShading(yaw: yaw, pitch: pitch);
    final showingBack = light.showingBack;
    final openness = light.openness;
    final frontUrl = card.imageNormal ?? card.imageSmall;
    final backUrl = card.imageBack ?? _genericBack;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Outside the rotation on purpose. A shadow belongs to the ground, and
        // the first version put it inside, so it turned and squashed along
        // with the card and stopped reading as a shadow at all.
        Transform.translate(
          offset: Offset(
            light.groundDx * width * 0.18,
            light.groundDy * width * 0.12 + width * 0.07,
          ),
          child: Container(
            width: width * 0.88,
            height: height * 0.88,
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: light.groundAlpha),
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
                        // Both faces are built, always. Only one is painted,
                        // but a widget in the tree fetches its picture, so the
                        // far side has already arrived by the time the card
                        // turns. Building it on demand meant turning over onto
                        // a black rectangle and watching it load.
                        Opacity(
                          opacity: showingBack ? 0 : 1,
                          child: _Side(url: frontUrl, name: card.name),
                        ),
                        Opacity(
                          opacity: showingBack ? 1 : 0,
                          child: _Side(url: backUrl, name: card.name),
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
            ],
          ),
        ),
      ],
    );
  }
}

/// One face of the card. Always built, sometimes invisible.
class _Side extends StatelessWidget {
  const _Side({required this.url, required this.name});

  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final blank = ColoredBox(
      color: Palette.tile,
      child: Center(
        child: Text(
          name,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Palette.inkMuted),
        ),
      ),
    );

    final address = url;
    if (address == null) return SizedBox.expand(child: blank);

    return SizedBox.expand(
      child: CardImage(url: address, fallback: blank),
    );
  }
}
