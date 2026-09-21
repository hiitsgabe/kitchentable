import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../tokens/palette.dart';

/// One card picture, fetched the way the platform is good at fetching.
///
/// On a device, cached_network_image, which keeps the file on disk so reopening
/// a deck does not refetch a hundred images.
///
/// In a browser, plain Image.network. cached_network_image leans on a disk
/// cache that a browser does not have, and it shows: in a web build some cards
/// sat on the placeholder forever and others fell straight to the error
/// widget, while cards either side of them loaded fine. The browser already
/// has an HTTP cache and it is better at this than we are.
class CardImage extends StatelessWidget {
  const CardImage({
    super.key,
    required this.url,
    required this.fallback,
  });

  final String url;

  /// Drawn while loading and if it never arrives. Loading and failing look the
  /// same on purpose here: a card that is taking its time and a card that is
  /// never coming are the same to somebody staring at the space.
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : fallback,
        errorBuilder: (_, _, _) => fallback,
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 140),
      placeholder: (_, _) => fallback,
      errorWidget: (_, _, _) => fallback,
    );
  }
}

/// The plain dark rectangle a card sits in before its picture turns up.
class CardPlaceholder extends StatelessWidget {
  const CardPlaceholder({super.key});

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: Palette.tile);
}
