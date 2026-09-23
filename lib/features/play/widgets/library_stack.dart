import 'package:flutter/material.dart';

import '../../../decks/model/game.dart';
import '../../../sources/model/catalog_card.dart';
import '../../../table/model/card_instance.dart';
import '../../../ui/atoms/card_art.dart';
import '../../../ui/tokens/metrics.dart';
import '../../../ui/tokens/palette.dart';
import 'card_drag.dart';

/// How many cards of thickness the pile ever draws.
///
/// A real Commander deck is about two centimetres and the difference between
/// ninety and a hundred cards is not something anybody sees. Tracking the
/// count linearly would put a Yorion pile off the top of the screen, so the
/// drawn thickness saturates and the number underneath carries the precision.
const _mostLeaves = 12;

/// How far each leaf below the top one is offset, in points before scaling.
const _leafStep = 1.6;

/// How many leaves a pile this size is drawn with.
///
/// Given a starting size the thickness is the fraction of it that is left,
/// scaled to [_mostLeaves], so a full deck of any size looks full and drawing
/// thins it the whole way down. It used to be the count itself, saturating,
/// which meant a Commander deck stood at its full height from a hundred all
/// the way down to twelve: drawing eighty cards moved nothing on the table.
///
/// Without a starting size it is still the count, saturating, which is a
/// graveyard: that one fills up rather than emptying, so there is nothing it is
/// a fraction of and the count it always used is the right answer.
int _leavesFor(int count, int? of) {
  if (count <= 0) return 0;
  if (of == null || of <= 0) {
    return count > _mostLeaves ? _mostLeaves : count;
  }
  final left = (count / of * _mostLeaves).round();
  return left > _mostLeaves ? _mostLeaves : left;
}

/// A pile of cards on the table, as a pile that grows and shrinks.
///
/// Your deck is one, face down, that you tap to draw from and whose second
/// button is everything else you can do to a library, behind its own control
/// because shuffling by accident is the one thing at a table that cannot be
/// undone by looking. Your graveyard is the same pile face up, with no second
/// button, that takes a card let go over it. One widget and not two, because
/// two piles on one screen that were written twice would stop looking alike.
class LibraryStack extends StatelessWidget {
  const LibraryStack({
    super.key,
    required this.metrics,
    required this.count,
    required this.width,
    required this.onDraw,
    this.onWork,
    this.pileName = 'library',
    this.label,
    this.faceUp = false,
    this.face,
    this.onDrop,
    this.game,
    this.of,
  });

  final Metrics metrics;
  final int count;
  final double width;

  /// How many cards the deck started at, so the pile can be drawn as the
  /// fraction of itself that is left.
  ///
  /// Null for a pile with no starting size, which is the graveyard: a graveyard
  /// fills up rather than emptying, and there is nothing it is a fraction of.
  final int? of;

  /// How far past a card the pile is drawn, for a deck this size.
  ///
  /// Said out loud because the pile is wider than the card in it and whoever
  /// gives it room has to know by how much. Still a function of nothing but
  /// what it is handed, because the board's width arithmetic calls it for a
  /// pile that has not been laid out yet, and it has to be given the same
  /// starting size the pile itself is or the two disagree by a few points and
  /// the board budgets for a column that is not the one it gets.
  static double spreadFor(int count, [int? of]) =>
      _leavesFor(count, of) * _leafStep;

  /// Whose back the pile is drawn with. Null draws the plain box, which is
  /// what a pile the app cannot name a back for has always looked like.
  final Game? game;

  /// What this pile is called in the widget tree: `library-stack` is the box
  /// and `library-draw` the gesture on it. Two of these on one screen need two
  /// names, or a tap aimed at one lands on both, and these are the names the
  /// deck has always been found by.
  final String pileName;

  /// The word above the pile, or nothing at all. A deck reads as a deck; a
  /// face up pile of somebody's dead cards does not say what it is.
  final String? label;

  /// Whether the card on top is showing. A graveyard is face up.
  final bool faceUp;

  /// The printing of the card on top, for a pile that is face up. Null draws a
  /// back, which is what this app does everywhere for a card it has no picture
  /// of.
  final CatalogCard? face;

  /// A tap on the pile. A deck draws a card and a graveyard opens itself, and
  /// the name is the deck's because that is the one the suite aims at.
  final VoidCallback onDraw;

  /// Shuffle, look at the top, and whatever else arrives later. Null draws no
  /// button, which is a pile with nothing else you can do to it.
  final VoidCallback? onWork;

  /// A card let go over the pile. Null takes no drops, which is a deck: a card
  /// going back into a library goes through the sheet, where it can be put on
  /// top or underneath rather than wherever a finger happened to land.
  final void Function(CardInstance)? onDrop;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final height = width * 88 / 63;
    final leaves = _leavesFor(count, of);
    final lift = spreadFor(count, of);
    final work = onWork;
    final word = label;

    final pile = SizedBox(
      key: Key('$pileName-stack'),
      width: width + lift,
      height: height + lift,
      child: Stack(
        children: [
          // An empty pile still draws its outline, the way the command corner
          // does: a place on the table that comes and goes reads as a bug
          // rather than as a rule, and it is also the thing you are trying to
          // drop a card onto.
          if (count == 0)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(width * 0.05),
                  border: Border.all(color: Palette.tileEdge),
                ),
              ),
            ),
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
              child: _top(m),
            ),
        ],
      ),
    );

    final tappable = count == 0
        ? pile
        : GestureDetector(
            key: Key('$pileName-draw'),
            onTap: onDraw,
            behavior: HitTestBehavior.opaque,
            child: pile,
          );

    final thrownAt = onDrop;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (word != null) ...[
          // Boxed to the pile's own width and allowed to shrink inside it. A
          // caption longer than the thing it names used to set this column's
          // width, and the column's width comes out of the board: on a 390
          // point phone "Graveyard" made the column 92.3 points against the
          // 19.2 the board's arithmetic budgets, and the card on the board
          // went a third smaller for a word.
          SizedBox(
            width: width + lift,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                word,
                style:
                    TextStyle(fontSize: m.scaled(10), color: Palette.inkFaint),
              ),
            ),
          ),
          SizedBox(height: m.scaled(4)),
        ],
        if (thrownAt == null)
          tappable
        else
          CardDropTarget(
            onDrop: (card, _) => thrownAt(card),
            child: tappable,
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
            if (work != null) ...[
              SizedBox(width: m.scaled(8)),
              GestureDetector(
                key: Key('$pileName-work'),
                onTap: work,
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
          ],
        ),
      ],
    );
  }

  /// The card on top: its own face where the pile is face up and the app has a
  /// picture of it, and a back otherwise.
  Widget _top(Metrics m) {
    final showing = face;
    if (!faceUp || showing == null) {
      return CardBack(width: width, game: game);
    }
    return CardArt(metrics: m, card: showing, width: width);
  }
}
