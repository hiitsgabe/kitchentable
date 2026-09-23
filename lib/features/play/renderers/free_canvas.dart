import 'dart:math' as math;
import 'dart:ui' show clampDouble;

import 'package:flutter/material.dart';

import '../../../decks/model/game.dart';
import '../../../sources/model/catalog_card.dart';
import '../../../table/model/card_instance.dart';
import '../../../table/view/seat_view.dart';
import '../../../ui/tokens/metrics.dart';
import '../../../ui/tokens/palette.dart';
import '../widgets/card_drag.dart';
import '../widgets/command_slot.dart';
import '../widgets/library_stack.dart';
import '../widgets/table_card.dart';
import 'mat_layout.dart';

/// The wide view. Every mat on one surface you pan and pinch.
///
/// Only battlefields are here. A hand belongs to one person and lives in its
/// own sheet below the board, which is the Arena rule the spec pins by
/// geometry: you must be able to look at your hand and the table at once.
class FreeCanvas extends StatefulWidget {
  const FreeCanvas({
    super.key,
    required this.metrics,
    required this.seats,
    required this.viewerSeatId,
    required this.printings,
    required this.onTapCard,
    required this.onInspectCard,
    required this.onPlace,
    required this.onDraw,
    required this.onWorkDeck,
    this.libraryCount = 0,
    this.libraryOf,
    this.commandCards,
    this.graveyard,
    this.tokenButton,
    this.diceTray,
    this.gameFor,
    this.onPlayCommand,
    this.onSendHome,
    this.turnSeatId,
    this.cardScale = 1,
  });

  final Metrics metrics;
  final List<SeatView> seats;
  final String viewerSeatId;
  final Map<String, CatalogCard> printings;
  final void Function(CardInstance) onTapCard;
  final void Function(CardInstance) onInspectCard;

  /// Where one of your own cards was dropped, normalized 0 to 1 against your
  /// mat. Somebody else's card never reports: it is theirs to move.
  final void Function(String cardId, double x, double y) onPlace;

  /// How many cards are left in your own deck.
  ///
  /// A number and not a pile, because a library is hidden from everybody, its
  /// owner included, and a `SeatView` correctly carries no cards for it. The
  /// count is public at a real table and is all the pile needs.
  final int libraryCount;

  /// How many cards the deck started at, so the pile thins as it is drawn
  /// rather than standing at its full height until it is nearly gone.
  final int? libraryOf;

  /// Whatever is standing in your command zone.
  ///
  /// Null in a format without commanders, which is not the same as an empty
  /// corner: an empty corner is still drawn, because a corner that comes and
  /// goes reads as a bug rather than as a rule.
  final List<CardInstance>? commandCards;

  /// Your graveyard, as a pile, built by the screen rather than from parts
  /// handed over here.
  ///
  /// A widget and not its cards, so that the bands and the mat draw one pile
  /// and not two that have to be kept looking alike: which end of an ordered
  /// pile is its top is the sort of thing that would be got right in one place
  /// and wrong in the other.
  final Widget? graveyard;

  /// Built by the screen and handed over, the way [graveyard] is, so the deck
  /// and the token control cannot drift apart between the two renderers.
  final Widget? tokenButton;

  /// The three dice, built by the screen for the same reason: this is the
  /// third control the two views could each build their own of.
  final Widget? diceTray;

  /// Which game a seat is playing: the back on a face down card belongs to
  /// whoever turned it over, and this canvas draws everybody's battlefield
  /// rather than only yours. Null all round draws the plain box, which is what
  /// a pile the app cannot name a back for has always looked like.
  final Game? Function(String seatId)? gameFor;

  final VoidCallback onDraw;

  /// Shuffling and looking at the top, which is the deck's second button.
  final VoidCallback onWorkDeck;

  /// A tap on a card standing in the command corner, which puts it out.
  final void Function(CardInstance)? onPlayCommand;

  /// A card let go over the command corner, which sends it there.
  final void Function(CardInstance)? onSendHome;

  final String? turnSeatId;

  /// The player's own multiplier on the card size. One is the surface exactly
  /// as the layout drew it.
  final double cardScale;

  @override
  State<FreeCanvas> createState() => _FreeCanvasState();
}

class _FreeCanvasState extends State<FreeCanvas> {
  final _view = TransformationController();

  /// Whether the table has been fitted to the window once already. After that
  /// the view is the player's: a fit that ran again would undo every pan.
  bool _fitted = false;

  @override
  void dispose() {
    _view.dispose();
    super.dispose();
  }

  /// Fits the whole table in the window the first time it is laid out.
  ///
  /// `InteractiveViewer` with `constrained: false` starts at one to one with
  /// the surface pinned to the top left, so a table of three opened with two
  /// of its mats past the edge and nothing saying so. Only the first time:
  /// after that the view is the player's.
  void _fitOnce(Size viewport, Size surface) {
    if (_fitted) return;
    _fitted = true;

    // A gap of room off each axis, and not the window exactly. Two reasons,
    // and whoever thinks of tidying the gap away has to take them together.
    // Fitted exactly, the far mat's edge lands on the viewport's own edge,
    // `Rect.contains` is `dx < right`, and `the whole table is on screen when
    // it opens` fails on the last of its six assertions with `mat s3 runs off
    // screen`. The other reason is the layout: a table drawn flush against two
    // edges of the window has no room around it, and room around the table is
    // what this view is for.
    final scale = math.min(
      (viewport.width - matGap) / surface.width,
      (viewport.height - matGap) / surface.height,
    );
    if (scale <= 0 || !scale.isFinite) return;
    // scaleByDouble and not scale: the one argument form scales all three
    // axes too and is the one anybody would write, and it is deprecated.
    _view.value = Matrix4.identity()..scaleByDouble(scale, scale, scale, 1);
  }

  /// One of the two strips a seat's station keeps beside its mat.
  ///
  /// Read off the station and not off the mat, so the furniture cannot land on
  /// the battlefield however the grid is laid out.
  Rect _strip(int slot, int count, {required bool onTheLeft}) {
    final station = stationFor(slot, count);

    return Rect.fromLTWH(
      onTheLeft ? station.left : station.right - matAside,
      station.top,
      matAside,
      station.height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final surface = surfaceFor(widget.seats.length);
    final seats = widget.seats;

    return LayoutBuilder(
      builder: (context, box) {
        // From a post frame callback and not from here: a
        // TransformationController tells its listeners the moment it is
        // written to, and the InteractiveViewer listening to this one is in
        // the middle of the layout that called this builder.
        if (!_fitted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _fitOnce(box.biggest, surface);
          });
        }

        return InteractiveViewer(
          transformationController: _view,
          constrained: false,
          minScale: 0.2,
          maxScale: 2.5,
          boundaryMargin: const EdgeInsets.all(matGap),
          child: SizedBox(
            width: surface.width,
            height: surface.height,
            child: Stack(
              children: [
                // Walked in seat order and not in table order, so your own mat
                // is the one at the bottom, next to your hand.
                for (final (slot, seatAt) in seatOrder(
                  count: seats.length,
                  viewerAt:
                      seats.indexWhere((s) => s.seatId == widget.viewerSeatId),
                ).indexed) ...[
                  Positioned.fromRect(
                    rect: matFor(slot, seats.length),
                    child: _Mat(
                      metrics: widget.metrics,
                      seat: seats[seatAt],
                      printings: widget.printings,
                      isViewer: seats[seatAt].seatId == widget.viewerSeatId,
                      isTurn: seats[seatAt].seatId == widget.turnSeatId,
                      onTapCard: widget.onTapCard,
                      onInspectCard: widget.onInspectCard,
                      onPlace: widget.onPlace,
                      cardScale: widget.cardScale,
                      game: widget.gameFor?.call(seats[seatAt].seatId),
                    ),
                  ),
                  // In the strips beside the mat and not in it. Stacked inside
                  // the mat's own rect the corner and the piles sat over the
                  // battlefield at every zoom, and the token button ran off
                  // the bottom edge of the mat itself.
                  if (seats[seatAt].seatId == widget.viewerSeatId) ...[
                    Positioned.fromRect(
                      rect: _strip(slot, seats.length, onTheLeft: true),
                      child: _Across(
                        metrics: widget.metrics,
                        seatId: widget.viewerSeatId,
                        graveyard: widget.graveyard,
                        diceTray: widget.diceTray,
                        tokenButton: widget.tokenButton,
                      ),
                    ),
                    Positioned.fromRect(
                      rect: _strip(slot, seats.length, onTheLeft: false),
                      child: _Aside(
                        metrics: widget.metrics,
                        seatId: widget.viewerSeatId,
                        printings: widget.printings,
                        libraryCount: widget.libraryCount,
                        libraryOf: widget.libraryOf,
                        commandCards: widget.commandCards,
                        game: widget.gameFor?.call(widget.viewerSeatId),
                        onInspectCard: widget.onInspectCard,
                        onDraw: widget.onDraw,
                        onWorkDeck: widget.onWorkDeck,
                        onPlayCommand: widget.onPlayCommand,
                        onSendHome: widget.onSendHome,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Mat extends StatelessWidget {
  const _Mat({
    required this.metrics,
    required this.seat,
    required this.printings,
    required this.isViewer,
    required this.isTurn,
    required this.onTapCard,
    required this.onInspectCard,
    required this.onPlace,
    required this.cardScale,
    required this.game,
  });

  final Metrics metrics;
  final SeatView seat;

  /// Whose back a card face down on this mat is turned onto.
  final Game? game;
  final Map<String, CatalogCard> printings;
  final bool isViewer;
  final bool isTurn;
  final void Function(CardInstance) onTapCard;
  final void Function(CardInstance) onInspectCard;
  final void Function(String cardId, double x, double y) onPlace;
  final double cardScale;

  /// The card as this mat lays it out. The whole size scales and not just the
  /// drawn width, so a bigger card is still centred on its own spot and still
  /// leaves a gap in the flow.
  Size get _cardSize => cardOnMat * cardScale;

  @override
  Widget build(BuildContext context) {
    final board = seat.pile('battlefield');
    final cards = board?.cards ?? const <CardInstance>[];

    // Keyed apart from the mat because the mat's border insets it by the
    // border's width, so this and not the mat is the box a position is
    // measured against, and the two are a unit out.
    final surface = Stack(
      key: Key('mat-surface-${seat.seatId}'),
      children: [
        Positioned(
          left: matPadding,
          top: matPadding / 2,
          child: Text(
            '${seat.name} · ${seat.life}',
            style: TextStyle(
              fontSize: 18,
              color: seat.life <= 0 ? Palette.attention : Palette.inkMuted,
            ),
          ),
        ),
        for (var i = 0; i < cards.length; i++)
          _place(cards[i], i),
      ],
    );

    return Container(
      key: Key('mat-${seat.seatId}'),
      decoration: BoxDecoration(
        color: isViewer ? Palette.tileFocused : Palette.tile,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isTurn ? Palette.accent : Palette.tileEdge,
          width: isTurn ? 3 : 1,
        ),
      ),
      // Only your own mat takes a card. Letting go over somebody else's is
      // letting go over nothing, and the card stays where it was, which is
      // what it did when a foreign card simply could not be picked up.
      child: isViewer ? CardDropTarget(onDrop: _drop, child: surface) : surface,
    );
  }

  Widget _place(CardInstance card, int index) {
    final spot = spotFor(
      position: card.position,
      index: index,
      card: _cardSize,
    );

    final face = TableCard(
      metrics: metrics,
      instance: card,
      printing: printings[card.oracleId],
      width: _cardSize.width,
      game: game,
      onTap: () => onTapCard(card),
      onLongPress: () => onInspectCard(card),
      // The same as the D-pad board: the canvas draws a card at the mat's
      // scale, and a preview of one that is already big helps nobody.
      hoverPreview: false,
    );

    return Positioned(
      key: Key('card-${card.id}'),
      left: spot.dx,
      // Below the seat's name, which sits in the padding at the top.
      top: spot.dy + matPadding,
      // A card on somebody else's mat is theirs to move, so it is not even
      // picked up: no drag, no half move that snaps back.
      child: DraggableCard(card: card, canDrag: isViewer, child: face),
    );
  }

  void _drop(CardInstance card, Offset at) {
    // Where the pointer was let go, in this mat's own units, which the
    // canvas's zoom is already out of: globalToLocal walks the
    // InteractiveViewer's transform, so a screen pixel on a zoomed table is
    // not mistaken for a mat unit.
    //
    // The card rides centred on the finger, so the pointer is the card's new
    // centre and spotFor is its inverse. The padding the seat's name sits in
    // shifts every card down and so is in the reported position too: it used
    // to cancel between two numbers in the same frame, and now it has to come
    // back out by hand.
    onPlace(
      card.id,
      clampDouble(at.dx / matSize.width, 0, 1),
      clampDouble((at.dy - matPadding) / matSize.height, 0, 1),
    );
  }
}

/// The command corner and your deck, standing in the strip on your own side of
/// the table.
///
/// Beside the mat and not on it. Stacked inside the mat's own rect the corner
/// and the piles sat over the battlefield at every zoom, and whatever did not
/// fit ran off the mat's bottom edge: the player's words were out of the view.
///
/// Drawn at `cardOnMat.width` and not at the mat's own card size: this is a
/// card at the surface's scale, which is what the whole canvas zooms. The
/// player's card size runs to twice life size, and a corner and a pile that
/// followed it would stand taller than the 380 units a mat has.
class _Aside extends StatelessWidget {
  const _Aside({
    required this.metrics,
    required this.seatId,
    required this.printings,
    required this.libraryCount,
    required this.libraryOf,
    required this.commandCards,
    required this.game,
    required this.onInspectCard,
    required this.onDraw,
    required this.onWorkDeck,
    required this.onPlayCommand,
    required this.onSendHome,
  });

  final Metrics metrics;
  final String seatId;
  final Map<String, CatalogCard> printings;
  final int libraryCount;
  final int? libraryOf;
  final List<CardInstance>? commandCards;
  final Game? game;
  final void Function(CardInstance) onInspectCard;
  final VoidCallback onDraw;
  final VoidCallback onWorkDeck;
  final void Function(CardInstance)? onPlayCommand;
  final void Function(CardInstance)? onSendHome;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final width = cardOnMat.width;

    return Column(
      children: [
        if (commandCards case final corner?) ...[
          CommandSlot(
            metrics: m,
            cards: corner,
            printings: printings,
            width: width,
            onTap: (c) => onPlayCommand?.call(c),
            onInspect: onInspectCard,
            onSendHome: (c) => onSendHome?.call(c),
            game: game,
          ),
          SizedBox(height: m.scaled(10)),
        ],
        KeyedSubtree(
          key: Key('canvas-library-$seatId'),
          child: LibraryStack(
            metrics: m,
            count: libraryCount,
            of: libraryOf,
            width: width,
            game: game,
            onDraw: onDraw,
            onWork: onWorkDeck,
          ),
        ),
      ],
    );
  }
}

/// The graveyard and the token button, in the strip across the mat from the
/// deck.
///
/// Which is where a graveyard sits at a table once the library is by your
/// right hand. The token button comes with it because the three of them do not
/// fit on the other side: the corner, the deck and the button stand 395 units
/// tall between them and a station is the mat's own 380, so one of them had to
/// cross the mat, and the button is the one item that is not a pile of cards.
///
/// The dice cross for the second half of that reason and the first half again.
/// Beside the deck they overflowed the strip by two points: the corner and the
/// deck already stand 333 of the 380, and the tray and its gap want 48.3 of
/// the 46.3 left over. They are not a pile of cards either.
class _Across extends StatelessWidget {
  const _Across({
    required this.metrics,
    required this.seatId,
    required this.graveyard,
    required this.diceTray,
    required this.tokenButton,
  });

  final Metrics metrics;
  final String seatId;
  final Widget? graveyard;
  final Widget? diceTray;
  final Widget? tokenButton;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return Column(
      children: [
        if (graveyard case final pile?)
          KeyedSubtree(key: Key('canvas-graveyard-$seatId'), child: pile),
        if (diceTray case final tray?) ...[
          SizedBox(height: m.scaled(10)),
          SizedBox(width: cardOnMat.width, child: tray),
        ],
        if (tokenButton case final button?) ...[
          SizedBox(height: m.scaled(10)),
          SizedBox(width: cardOnMat.width, child: button),
        ],
      ],
    );
  }
}
