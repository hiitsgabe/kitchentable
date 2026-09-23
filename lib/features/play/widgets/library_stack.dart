import 'package:flutter/material.dart';

import '../../../decks/model/game.dart';
import '../../../ui/atoms/card_art.dart';
import '../../../ui/tokens/metrics.dart';
import '../../../ui/tokens/palette.dart';

/// How many cards of thickness the pile ever draws.
///
/// A real Commander deck is about two centimetres and the difference between
/// ninety and a hundred cards is not something anybody sees. Tracking the
/// count linearly would put a Yorion pile off the top of the screen, so the
/// drawn thickness saturates and the number underneath carries the precision.
const _mostLeaves = 12;

/// How far each leaf below the top one is offset, in points before scaling.
const _leafStep = 1.6;

/// Your deck, as a pile that gets thinner as you draw it.
///
/// Tapping draws. The second button is everything else you can do to a
/// library, which is behind its own control because shuffling by accident is
/// the one thing at a table that cannot be undone by looking.
class LibraryStack extends StatelessWidget {
  const LibraryStack({
    super.key,
    required this.metrics,
    required this.count,
    required this.width,
    required this.onDraw,
    required this.onWork,
    this.game,
  });

  final Metrics metrics;
  final int count;
  final double width;

  /// How far past a card the pile is drawn, for a deck this size.
  ///
  /// Said out loud because the pile is wider than the card in it and whoever
  /// gives it room has to know by how much.
  static double spreadFor(int count) =>
      (count > _mostLeaves ? _mostLeaves : count) * _leafStep;

  /// Whose back the pile is drawn with. Null draws the plain box, which is
  /// what a pile the app cannot name a back for has always looked like.
  final Game? game;

  final VoidCallback onDraw;

  /// Shuffle, look at the top, and whatever else arrives later.
  final VoidCallback onWork;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final height = width * 88 / 63;
    final leaves = count > _mostLeaves ? _mostLeaves : count;
    final lift = spreadFor(count);

    final pile = SizedBox(
      key: const Key('library-stack'),
      width: width + lift,
      height: height + lift,
      child: Stack(
        children: [
          for (var i = leaves; i > 0; i--)
            Positioned(
              left: (leaves - i) * _leafStep,
              top: (leaves - i) * _leafStep,
              child: CardBack(width: width, game: game),
            ),
          if (count > 0)
            Positioned(
              left: lift,
              top: lift,
              child: CardBack(width: width, game: game),
            ),
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (count == 0)
          pile
        else
          GestureDetector(
            key: const Key('library-draw'),
            onTap: onDraw,
            behavior: HitTestBehavior.opaque,
            child: pile,
          ),
        SizedBox(height: m.scaled(6)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: m.scaled(14),
                fontWeight: FontWeight.w700,
                color: Palette.ink,
              ),
            ),
            SizedBox(width: m.scaled(8)),
            GestureDetector(
              key: const Key('library-work'),
              onTap: onWork,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: EdgeInsets.all(m.scaled(6)),
                decoration: BoxDecoration(
                  color: Palette.tile,
                  borderRadius: BorderRadius.circular(m.scaled(8)),
                  border: Border.all(color: Palette.tileEdge),
                ),
                child: Icon(
                  Icons.more_horiz_rounded,
                  size: m.scaled(15),
                  color: Palette.inkMuted,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
