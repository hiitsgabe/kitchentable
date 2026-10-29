import 'package:flutter/material.dart';

import '../../decks/model/game.dart';
import '../../sources/model/catalog_card.dart';
import '../tokens/metrics.dart';
import '../tokens/palette.dart';
import 'card_image.dart';

/// Which file to fetch for a card drawn this big.
///
/// Scryfall's sizes are small 146, normal 488 and large 672 pixels wide. The
/// board used to ask for small whatever it was drawing, so a card at 90 points
/// on a two times screen was a 146 pixel picture stretched to 180 and then to
/// 540 when the player opened the window wide. That is what "qualidade baixa"
/// was.
///
/// Null when the card has no picture at all, which is a token or a card from a
/// source that was cleared.
String? artFor(
  CatalogCard card, {
  required double width,
  required double pixelRatio,
}) {
  final needed = width * pixelRatio;
  if (needed > 488 && card.imageLarge != null) return card.imageLarge;
  if (needed > 146 && card.imageNormal != null) return card.imageNormal;
  return card.imageSmall ?? card.imageNormal ?? card.imageLarge;
}

/// How much bigger than its own width a card is actually being drawn.
///
/// The canvas lays every card out in mat units and then scales the whole
/// surface with an `InteractiveViewer`, so a card that asks for a 90 unit
/// picture can be on screen at 225 points once somebody zooms in. [artFor]
/// only ever saw the 90 and kept handing out the small file to be stretched,
/// which is what "a qualidade da imagem das cartas diminui" was on the view
/// with everybody's mat in it.
///
/// An inherited value and not a parameter. The cards it has to reach are
/// behind mats, asides, piles and corners, and threading a number through all
/// of them is a hand off site per widget that nothing checks: this codebase
/// has already shipped a `Game?` that six widgets passed on and a seventh
/// quietly did not.
///
/// One where nothing says otherwise, which is every view that draws a card at
/// the size it means.
class ArtScale extends InheritedWidget {
  const ArtScale({super.key, required this.scale, required super.child});

  final double scale;

  static double around(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ArtScale>()?.scale ?? 1;

  @override
  bool updateShouldNotify(ArtScale old) => old.scale != scale;
}

/// A card, as a picture.
///
/// Fetched one at a time and cached on the device, never in bulk. A whole
/// Commander deck is a hundred images at about 76 KB each, which is under eight
/// megabytes and only of the cards somebody actually chose. Pulling the
/// catalog's images up front would be several gigabytes of cards nobody asked
/// for, which is the reason the importer only ever takes the text.
class CardArt extends StatelessWidget {
  const CardArt({
    super.key,
    required this.metrics,
    required this.card,
    required this.width,
  });

  final Metrics metrics;
  final CatalogCard card;
  final double width;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    // Magic cards are 63 by 88 millimetres, and everything from Scryfall comes
    // in that ratio, so the box never has to guess.
    final height = width * 88 / 63;
    final radius = BorderRadius.circular(width * 0.045);
    final url = artFor(
      card,
      width: width,
      pixelRatio:
          (MediaQuery.maybeDevicePixelRatioOf(context) ?? 1) *
          ArtScale.around(context),
    );

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: width,
        height: height,
        child: url == null
            ? _Fallback(metrics: m, card: card)
            : CardImage(
                url: url,
                // The name, not a blank box. If the picture never arrives the
                // name is what somebody wanted from it anyway.
                fallback: _Fallback(metrics: m, card: card),
              ),
      ),
    );
  }
}

/// The back of a card, painted, per game.
///
/// Not the printed back: that is the publisher's, and the app shows only
/// what a source the user turned on serves, which for a back is nothing.
/// Magic's used to be fetched from the card source's CDN; a reviewer opening
/// the app should see nothing the user did not ask for. A deep colour with a
/// pale ring on it, in a tint per game, is enough to say "a card, face down,
/// in this game" at any size.
class PaintedBack extends StatelessWidget {
  const PaintedBack({super.key, required this.game});

  final Game game;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final w = box.maxWidth.isFinite ? box.maxWidth : 63.0;
      final (key, colors) = switch (game) {
        Game.magic => (
          'magic-back',
          [const Color(0xFF8A4A24), const Color(0xFF3A1B0C)],
        ),
        Game.pokemon => (
          'pokemon-back',
          [const Color(0xFF2A5DB0), const Color(0xFF0E2A66)],
        ),
      };
      return Container(
        key: Key(key),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          border: Border.all(color: const Color(0xFFE8C14A), width: w * 0.045),
        ),
        child: Center(
          child: Container(
            width: w * 0.46,
            height: w * 0.46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xCCFFFFFF),
                width: w * 0.045,
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// The back of a card.
///
/// A face down permanent, a card the catalog has never heard of, and every
/// leaf of a library except the one on top are all the same box, which is why
/// it lives here rather than inside whichever widget wanted it first.
///
/// With a game it is that game's painted back, because which back it is says
/// which game is on the table before anybody reads a word. Without one it
/// stays the plain box.
class CardBack extends StatelessWidget {
  const CardBack({super.key, required this.width, this.game});

  final double width;
  final Game? game;

  @override
  Widget build(BuildContext context) {
    final height = width * 88 / 63;
    final game = this.game;
    final blank = DecoratedBox(
      decoration: BoxDecoration(
        color: Palette.tile,
        border: Border.all(color: Palette.tileEdge),
      ),
    );

    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width * 0.05),
        child: game == null
            ? blank
            : KeyedSubtree(
                key: const Key('card-back-art'),
                child: PaintedBack(game: game),
              ),
      ),
    );
  }
}

/// Shown when a card has no image, which happens for a token or a card the
/// source did not carry art for. Prints the name rather than an error icon,
/// because the name is what the player needed from the picture anyway.
class _Fallback extends StatelessWidget {
  const _Fallback({required this.metrics, required this.card});

  final Metrics metrics;
  final CatalogCard card;

  @override
  Widget build(BuildContext context) => Container(
    color: Palette.tile,
    alignment: Alignment.center,
    padding: EdgeInsets.all(metrics.scaled(6)),
    child: Text(
      card.name,
      textAlign: TextAlign.center,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: metrics.scaled(10),
        height: 1.25,
        color: Palette.inkMuted,
      ),
    ),
  );
}
