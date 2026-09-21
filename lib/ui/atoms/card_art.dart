import 'package:flutter/material.dart';

import '../../sources/model/catalog_card.dart';
import '../tokens/metrics.dart';
import '../tokens/palette.dart';
import 'card_image.dart';

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
    this.large = false,
  });

  final Metrics metrics;
  final CatalogCard card;
  final double width;

  /// Uses the bigger file. Worth it when the card fills a screen, wasteful in a
  /// list where it would be scaled down to a thumbnail anyway.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    // Magic cards are 63 by 88 millimetres, and everything from Scryfall comes
    // in that ratio, so the box never has to guess.
    final height = width * 88 / 63;
    final radius = BorderRadius.circular(width * 0.045);
    final url = large ? (card.imageNormal ?? card.imageSmall) : card.imageSmall;

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
