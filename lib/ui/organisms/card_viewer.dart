import 'dart:math' as math;

import 'package:flutter/gestures.dart';

import 'package:flutter/material.dart';

import '../../decks/model/game.dart';
import '../../sources/model/catalog_card.dart';
import '../../table/model/card_instance.dart';
import '../tokens/metrics.dart';
import '../atoms/card_art.dart';
import '../atoms/card_image.dart';
import '../tokens/palette.dart';
import 'card_shading.dart';

/// What the viewer can ask for, beyond looking.
///
/// Turning a card ninety degrees is not here: that is the tap, on the table,
/// where the player can see the board around it. These are the deliberate
/// ones, which is why they are behind a press and hold.
enum CardAction {
  upsideDown,
  straighten,
  flip,
  counterUp,
  counterDown,
  commandZone,

  /// A second one of this card, onto the pile this one is on. Most tokens in
  /// Magic are a copy of something already on the table, and a copy needs no
  /// search: the face is the face of the card being looked at.
  copy,
}

/// The counters a table puts on cards often enough to be worth a button.
///
/// Not a closed list: whatever is already on the card is offered too, so a
/// card that arrives carrying a kind nobody listed can still be counted. The
/// table has never cared what these are called, which is why they are strings
/// and not an enum, and it is also why Pokemon needs nothing added here.
const counterKinds = ['+1/+1', '-1/-1', 'loyalty', 'charge', 'damage'];

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
    this.onCount,
    this.hasCommandZone = false,
  });

  final CatalogCard card;

  /// The card on a table, when there is one. Null from the deck builder,
  /// where a printing is being looked at rather than a card being played, and
  /// then the viewer offers nothing to do because there is nothing to do it
  /// to.
  final CardInstance? instance;

  final void Function(CardAction)? onAct;

  /// Counting, which is the one action that carries an argument: which kind.
  ///
  /// Beside [onAct] rather than inside it. The other six verbs carry nothing,
  /// and widening all of them so one can hold a string is how an enum turns
  /// into a variant type nobody meant to write. The verb still comes out of
  /// [onAct], so a caller that only wants to know what was pressed is
  /// unchanged; this is the argument that goes with it.
  final void Function(String kind, int by)? onCount;

  /// Whether this table has a command zone at all. Standard and Pauper have
  /// no such corner, and an action that moves a card into a zone that is not
  /// there is a button that does nothing.
  final bool hasCommandZone;

  static Future<CardAction?> show(
    BuildContext context,
    CatalogCard card, {
    CardInstance? instance,
    bool hasCommandZone = false,
    void Function(String kind, int by)? onCount,
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
            hasCommandZone: hasCommandZone,
            onCount: onCount,
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

  /// What the plus and the minus mean, and which number sits between them.
  ///
  /// `+1/+1` to start with, because it is what a Magic table reaches for
  /// twenty times a game and every other kind once. It was hardcoded before
  /// this, which made a planeswalker's loyalty, a Pokemon's damage and an
  /// artifact's charge all the same thing.
  String _counting = counterKinds.first;

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

    final kinds = [
      ...counterKinds,
      // Whatever arrived on the card and is on no list. Appended rather than
      // sorted in, so the five that are always there never move about.
      for (final kind in instance.counters.keys)
        if (!counterKinds.contains(kind)) kind,
    ];

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.all(m.safeInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Its own Wrap above the verbs, and not children of theirs. Five
            // kinds and seven controls in one Wrap flow into each other, so
            // `damage` ends a line that starts with `Face down` and the player
            // has to read the whole bar to find either. One Wrap each keeps
            // what a tap chooses apart from what a tap does, and neither can
            // overflow.
            Wrap(
              alignment: WrapAlignment.center,
              spacing: m.scaled(6),
              runSpacing: m.scaled(6),
              children: [
                for (final kind in kinds)
                  _kind(m, kind, instance.counters[kind] ?? 0),
              ],
            ),
            SizedBox(height: m.scaled(10)),
            // Wrapped, not a Row. Four controls with words on them are 358
            // points wide and a phone is 390 before the safe inset, so a Row
            // overflowed by 141 points before the command zone button existed
            // and by 190 after. Nothing saw it because this is only ever built
            // at 800 wide in a test. Three lines on a phone and one on
            // anything wider, with every control still readable, which is why
            // this is a Wrap rather than a FittedBox or a scroll with half the
            // buttons off the edge.
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: m.scaled(10),
              runSpacing: m.scaled(10),
              children: [
                if (instance.rotation == 180)
                  _act(m, const Key('act-straighten'),
                      Icons.straighten_rounded, 'Straighten',
                      CardAction.straighten)
                else
                  _act(m, const Key('act-upside-down'),
                      Icons.flip_camera_android_rounded, 'Upside down',
                      CardAction.upsideDown),
                _act(
                  m,
                  const Key('act-flip'),
                  Icons.layers_rounded,
                  instance.faceDown ? 'Face up' : 'Face down',
                  CardAction.flip,
                ),
                if (widget.hasCommandZone) ...[
                  _act(m, const Key('act-command'), Icons.home_rounded, null,
                      CardAction.commandZone),
                ],
                _act(m, const Key('act-copy'), Icons.content_copy_rounded,
                    'Copy', CardAction.copy),
                _act(m, const Key('act-counter-down'), Icons.remove_rounded,
                    null, CardAction.counterDown, by: -1),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: m.scaled(10)),
                  child: Text(
                    // The chosen kind and not every kind added up, which read
                    // `+1/+1: 2, damage: 3` back as five of something.
                    '${instance.counters[_counting] ?? 0}',
                    key: const Key('counter-count'),
                    style: TextStyle(
                      fontSize: m.scaled(18),
                      fontWeight: FontWeight.w700,
                      color: Palette.ink,
                    ),
                  ),
                ),
                _act(m, const Key('act-counter-up'), Icons.add_rounded, null,
                    CardAction.counterUp, by: 1),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// One kind of counter, and whether it is the one being counted.
  ///
  /// The count rides on the chips that are not chosen, because the chosen
  /// one's number is already the big one between the plus and the minus and
  /// printing it twice is how somebody ends up counting the wrong one. What
  /// the unchosen ones carry is the answer to what else is on this card.
  Widget _kind(Metrics m, String kind, int count) {
    final chosen = kind == _counting;

    return GestureDetector(
      key: Key('kind-$kind'),
      onTap: () => setState(() => _counting = kind),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: m.scaled(9),
          vertical: m.scaled(6),
        ),
        decoration: BoxDecoration(
          color: chosen ? Palette.tileFocused : Palette.tile,
          borderRadius: BorderRadius.circular(m.scaled(99)),
          border: Border.all(
            color: chosen ? Palette.accent : Palette.tileEdge,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              kind,
              style: TextStyle(
                fontSize: m.scaled(11),
                fontWeight: chosen ? FontWeight.w700 : FontWeight.w500,
                color: chosen ? Palette.ink : Palette.inkMuted,
              ),
            ),
            if (!chosen && count != 0) ...[
              SizedBox(width: m.scaled(5)),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: m.scaled(11),
                  fontWeight: FontWeight.w700,
                  color: Palette.accent,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// One control. [by] is set only on the two that count, and it is what
  /// carries the chosen kind out: the verb still goes through `onAct`, which
  /// is what closes the viewer.
  Widget _act(
    Metrics m,
    Key key,
    IconData icon,
    String? label,
    CardAction action, {
    int? by,
  }) =>
      GestureDetector(
        key: key,
        onTap: () {
          if (by != null) widget.onCount?.call(_counting, by);
          widget.onAct?.call(action);
        },
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
    // A card with only one face turns over onto its game's back, which is
    // the same one the pile in front of you is drawn with. There used to be
    // a second copy of the Magic URL here.
    final backUrl = card.imageBack ?? backFor(Game.magic);

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
