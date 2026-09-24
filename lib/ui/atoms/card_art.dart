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
      pixelRatio: (MediaQuery.maybeDevicePixelRatioOf(context) ?? 1) *
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

/// The generic Magic back, served by Scryfall. Every Magic card has this one
/// on the other side, so turning a card over onto it invents nothing.
const _magicBack =
    'https://backs.scryfall.io/large/0/a/0aeebaf5-8c7d-4636-9e82-8c27447861f7.jpg';

/// The back of a card, per game.
///
/// Magic's is the one Scryfall serves, which `CardViewer` has turned cards
/// over onto since plan 1. It lives here rather than in the viewer because
/// there is one back per game and both the viewer and the deck pile want it.
///
/// Null for a game the app has no back for, and for no game at all, which is
/// a token or a card the table knows nothing about.
String? backFor(Game? game) => switch (game) {
      Game.magic => _magicBack,
      // Nothing the app imports serves a Pokemon back, there is no Pokemon
      // catalog to ask, and a fan site is not a source. It arrives with the
      // catalog that serves it. Until then the pile draws the plain box,
      // which is already what the table draws when it knows nothing.
      Game.pokemon => null,
      null => null,
    };

/// The back of a card.
///
/// A face down permanent, a card the catalog has never heard of, and every
/// leaf of a library except the one on top are all the same box, which is why
/// it lives here rather than inside whichever widget wanted it first.
///
/// With a game it is that game's back, because which back it is says which
/// game is on the table before anybody reads a word. Without one, or for a
/// game with no back to fetch, it stays the plain box.
class CardBack extends StatelessWidget {
  const CardBack({super.key, required this.width, this.game});

  final double width;
  final Game? game;

  @override
  Widget build(BuildContext context) {
    final height = width * 88 / 63;
    final url = backFor(game);
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
        child: url == null
            ? blank
            : CardImage(
                key: const Key('card-back-art'),
                url: url,
                fallback: blank,
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
