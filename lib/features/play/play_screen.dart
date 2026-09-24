import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sources/model/catalog_card.dart';
import '../../table/actions/table_action.dart';
import '../../table/model/card_instance.dart';
import '../../table/model/zone.dart';
import '../../table/shuffle.dart';
import '../../table/view/seat_view.dart';
import '../../ui/atoms/hint_bar.dart';
import '../../ui/atoms/toast.dart';
import '../../ui/organisms/card_viewer.dart';
import '../../ui/organisms/screen_frame.dart';
import '../../ui/tokens/metrics.dart';
import '../../ui/tokens/palette.dart';
import '../menu/menu_controller.dart';
import 'card_size.dart';
import 'dice/dice_tray.dart';
import 'look_at_top.dart';
import 'play_controller.dart';
import 'renderers/free_canvas.dart';
import 'renderers/mat_layout.dart';
import 'renderers/renderer_choice.dart';
import 'renderers/stacked_seats.dart';
import 'widgets/command_slot.dart';
import 'widgets/cursor_board.dart';
import 'widgets/deck_sheet.dart';
import 'widgets/hand_sheet.dart';
import 'widgets/library_stack.dart';
import 'widgets/pile_sheet.dart';
import 'widgets/radar_strip.dart';
import 'widgets/token_sheet.dart';
import 'widgets/zone_chip.dart';

class PlayScreen extends ConsumerStatefulWidget {
  const PlayScreen({super.key});

  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends ConsumerState<PlayScreen> {
  Map<String, CatalogCard> _printings = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPrintings());
  }

  /// Every card on the table at once, looked up in one go. Looking each one up
  /// as it is drawn would be a query per card per frame.
  Future<void> _loadPrintings() async {
    final db = ref.read(catalogDbProvider);
    final table = ref.read(playProvider);
    if (db == null || table == null) return;

    final ids = table.allZones
        .expand((z) => z.cards)
        .map((c) => c.oracleId)
        .toSet()
        .toList();

    final cards = await db.cardsByOracleIds(ids);
    if (mounted) {
      setState(() => _printings = {for (final c in cards) c.oracleId: c});
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final m = Metrics.of(classifyDevice(
      size: media.size,
      hasTouch: media.navigationMode == NavigationMode.traditional,
    ));
    final table = ref.watch(playProvider);
    final play = ref.read(playProvider.notifier);
    final cardScale = ref.watch(cardScaleProvider);

    // The referee's refusal, said out loud. Nothing refuses anything while the
    // permissive referee is the only one there is, so this path never fires
    // today. It is here because the argument for building the referee's chair
    // was that the screen pays its cost on day one, and for one commit the
    // screen did not: the controller recorded a refusal that nothing read.
    ref.listen(playRefusalProvider, (_, refusal) {
      if (refusal != null) {
        Toast.show(context, refusal.reason, icon: Icons.block_rounded);
      }
    });

    if (table == null) {
      return ScreenFrame(
        metrics: m,
        title: 'Play',
        label: 'no table',
        onBack: () => Navigator.of(context).maybePop(),
        hints: const [Hint(button: 'B', label: 'back')],
        children: [
          Text(
            'No table open. Start one from a deck.',
            style: TextStyle(fontSize: m.scaled(13), color: Palette.inkFaint),
          ),
        ],
      );
    }

    final viewerId = ref.watch(viewerSeatProvider) ?? '';
    final views = [
      for (final s in table.seats) SeatView.of(s, viewer: viewerId),
    ];
    // A spectator has no seat. It draws the table and offers no controls, and
    // plan 3 is where somebody arrives that way for real.
    final seat = table.seat(viewerId) ?? table.seats.first;
    final mine = seat.id == viewerId;

    final hand = table.zone('hand-${seat.id}')!;
    final battlefield = table.zone('battlefield-${seat.id}')!;
    final library = table.zone('library-${seat.id}')!;
    final graveyard = table.zone('graveyard-${seat.id}')!;
    // Null in a format without commanders: magicZonesFor only makes this zone
    // when the format asks for one.
    final command = table.zone('command-${seat.id}');

    final renderer = rendererFor(
      width: media.size.width,
      height: media.size.height,
      chosen: ref.watch(rendererChoiceProvider),
    );

    // The battlefield alone. The graveyard is a pile in the strip beside the
    // board, which is the one you drop a card onto and open, and a second mat
    // under the battlefield for the same zone was the leftover: two mats share
    // the board's height, so the column beside them had half the room it
    // needed and the corner, the deck and the token button ran off the bottom.
    //
    // It costs the D-pad the graveyard. BoardCursor walks the piles the board
    // is given, so a card in there was reachable with a shoulder button and
    // now is not. The answer is the pile's own sheet, which a D-pad cannot
    // open either, and that is a job of its own.
    final zones = [
      (id: battlefield.id, label: battlefield.label, cards: battlefield.cards),
    ];

    // What a card in your hand is drawn at: the card the board under it
    // draws, up to the width one line of the hand has always been.
    //
    // The hand's card was a flat `m.scaled(64)` and the board's was whatever
    // the leftover came to, 32.19 on a 390 point phone, so a card in your
    // hand was exactly twice the same card on the table and nothing related
    // the two. Nothing but the width here, because that is all the board's
    // card depends on once the furniture is a row under it, and the hand
    // stands outside the board's own LayoutBuilder where the number is
    // worked out. Above the threshold this comes out over the hand's ceiling
    // and the ceiling is what the hand draws at, which is the size it has
    // always drawn at.
    final handCard = cardOnMat.width *
        cardScale *
        (media.size.width - media.padding.horizontal - m.safeInset * 2) /
        matSize.width;

    final yours = Column(
      key: const Key('your-seat'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              // The deck and the commander are cards off this table, so
              // they are drawn at the table's scale rather than at a point
              // size of their own. The deck was a fixed 46 while a card
              // beside it was 270, which is the pile you draw from being
              // nearly six times smaller than the cards in it.
              //
              // They stand beside the mat and not over and under it. Stacked
              // in a column with the board, a bigger deck leaves the board
              // less height, which makes the mat smaller, which makes the
              // deck smaller again: sized straight off this box they came
              // out at 186 points beside a 99 point card, measured on a 1900
              // by 900 window. Beside it, the only thing they take is width,
              // and that has an answer rather than a chase.
              //
              // How much past the card the pile and the corner reach: the
              // leaves the pile is drawn with, and the corner's own padding.
              // Furniture, which does not scale with the card.
              //
              // An estimate and not a measurement, because the deck's count
              // row can be the wider thing when the card is small and that
              // width belongs to a widget that has not been laid out yet.
              // Being a few points out costs the board a few points of
              // width, which makes its cards a percent or so smaller than
              // the deck. It cannot put the deck back at six times out.
              final aside = math.max(
                LibraryStack.spreadFor(
                  library.size,
                  play.deckSizeAt(seat.id),
                ),
                m.scaled(6),
              );
              final gap = m.scaled(10);

              // Whether the furniture stands in a row under the board rather
              // than in two columns beside it.
              //
              // The columns cost `aside * 2 + gap * 2` of the row before
              // either of them has drawn a card in it. A tenth of the row
              // spent on furniture that draws nothing is the share this calls
              // too much, and at handheld metrics it falls out to 584 points
              // of row, which is a 616 point window.
              //
              // A tenth and not an eighth because it is also where the card
              // this arithmetic budgets for stops coming out under 64, the
              // width one line of the hand is drawn at: that crossing is at
              // 577.5 points of row, six below this, so from the threshold up
              // the hand draws at its own ceiling.
              //
              // The card the board then draws is not the card budgeted for
              // here, and it is the smaller of the two: measured at a 616
              // point window the budget comes to 65.2 and the mat draws 58.5,
              // so between there and about 690 the hand is still up to nine
              // percent the bigger of the two. It was a hundred percent on a
              // phone, which is what this is for, and closing the rest of it
              // means the hand reading a number that is only known inside
              // this builder.
              //
              // The thickest a pile is ever drawn and not the pile as it
              // stands, so the layout is settled when you sit down. A pile's
              // leaves are the fraction of itself it has left, so a count
              // equal to what it started at is a full one whatever that size
              // was. Read `aside` live instead and the threshold walks from a
              // 616 point window down to a 240 point one as the deck thins,
              // which moves the furniture from a row to two columns somewhere
              // around the fourth turn of a game.
              final widest = math.max(
                LibraryStack.spreadFor(1, 1),
                m.scaled(6),
              );
              final inARow = (widest * 2 + gap * 2) / box.maxWidth > 0.1;

              // What is left over when height is what runs out. Infinite
              // when the board is too short to fit a mat at all and scrolls
              // instead, and then the width below is the only answer.
              //
              // The row stands in that height, and what it stands there is a
              // card at the board's own scale: the same shape as the width
              // below, solved the same way, so the piles under the board are
              // the size of the cards on it rather than of the ones a board
              // with the whole height would have drawn. Generous by the
              // pile's own count row, the way `aside` is and for the same
              // reason.
              //
              // No case pins this: at a phone's width it is the width that
              // binds and this term changes nothing there. What it buys shows
              // up on a window too short for the mat it is wide enough for,
              // measured on a 390 by 500 one at a deck 1.53 times the card
              // beside it with this and 2.45 times without. Neither of those
              // is a phone and neither of them is right; a board that short
              // is its own job.
              final under = inARow ? cardOnMat.height * cardScale : 0.0;
              final byHeight = cardOnMat.width *
                  cardScale *
                  CursorBoard.scaleFor(
                    box: Size(
                      double.infinity,
                      inARow ? box.maxHeight - gap : box.maxHeight,
                    ),
                    zones: zones,
                    metrics: m,
                  ) *
                  matSize.height /
                  (matSize.height + under);

              // And when width is. The card is on both sides of this one,
              // because the board only gets the width the cards beside it
              // leave: a card of w takes w + aside + gap out of the row, and
              // the mat is scaled by what remains. Solved once, here.
              //
              // Two lots of that now, not one: the graveyard stands in its own
              // column across the board from the deck, so there is a card and
              // its furniture out of the row on each side.
              //
              // In a row there is neither a column to subtract nor a card
              // beside the board: it gets the whole row, and the mat's own
              // 640 units are all the card is a fraction of.
              final beside = inARow ? 0.0 : cardOnMat.width * cardScale;
              final room = inARow
                  ? box.maxWidth
                  : box.maxWidth - aside * 2 - gap * 2;
              final byWidth = cardOnMat.width *
                  cardScale *
                  (room < 0 ? 0.0 : room) /
                  (matSize.width + beside);

              // The room the row has, and deliberately not the floor the mat
              // keeps for itself. Below `matScaleFloor` the mat stops shrinking
              // and the board scrolls, and the furniture cannot follow it
              // there: five pieces at a floored card apiece is 428 points of
              // row on a 358 point phone, measured, and what scrolls off the
              // right hand end of it is the deck, which is the one thing here
              // you touch every turn. On a phone the deck comes out at 0.699 of
              // the card on the mat beside it, which is inside the six tenths
              // to fourteen tenths a pile of these cards has always been
              // allowed, and every window wide enough to stand the furniture in
              // columns is above the floor, where these are the same number.
              final card = math.min(byHeight, byWidth);

              // Built once and arranged twice. Two branches each building
              // their own board is how the two renderers drifted apart, and
              // the corner and the deck take the card they are handed here
              // whichever way round they end up standing.
              final board = CursorBoard(
                key: const Key('your-board'),
                metrics: m,
                cardScale: cardScale,
                zones: zones,
                printings: _printings,
                onActivate: (c) => play.run(RotateCard(c.id)),
                onInspect: _inspect,
                onPlace: _place,
                game: play.gameAt(seat.id),
              );
              final corner = command == null
                  ? null
                  : CommandSlot(
                      metrics: m,
                      cards: command.cards,
                      printings: _printings,
                      width: card,
                      onTap: (c) => play.run(
                        MoveCard(cardId: c.id, toZoneId: battlefield.id),
                      ),
                      onInspect: _inspect,
                      onSendHome: (c) => play.run(
                        MoveCard(cardId: c.id, toZoneId: command.id),
                      ),
                      game: play.gameAt(seat.id),
                    );
              final deck = LibraryStack(
                metrics: m,
                count: library.size,
                of: play.deckSizeAt(seat.id),
                width: card,
                game: play.gameAt(seat.id),
                onDraw: () => play.run(DrawCards(
                  fromZoneId: library.id,
                  toZoneId: hand.id,
                  count: 1,
                )),
                onWork: _workTheDeck,
              );

              if (inARow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: board),
                    SizedBox(height: gap),
                    _Underneath(
                      room: box.maxWidth,
                      gap: gap,
                      graveyard: _chip(m, graveyard, width: card),
                      dice: _diceTray(width: card),
                      makeToken: _tokenButton(m, width: card),
                      command: corner,
                      library: deck,
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Across(
                    graveyard: _chip(m, graveyard, width: card),
                    dice: _diceTray(width: card),
                    // Across from the deck, with the graveyard, because that
                    // is where the canvas had to put it: three things do not
                    // fit the right strip of a 380 unit station, measured at
                    // 395 against 380. Two views that disagree about which
                    // hand you reach with is worse than either arrangement.
                    makeToken: _tokenButton(m, width: card),
                  ),
                  SizedBox(width: gap),
                  Expanded(child: board),
                  SizedBox(width: gap),
                  _Beside(metrics: m, command: corner, library: deck),
                ],
              );
            },
          ),
        ),
        HandSheet(
          metrics: m,
          cardWidth: handCard,
          cards: mine ? hand.cards : const [],
          printings: _printings,
          onPlay: (c) => play.run(
            MoveCard(cardId: c.id, toZoneId: battlefield.id),
          ),
          onInspect: _inspect,
          onReorder: (id, to) => play.run(
            MoveCard(cardId: id, toZoneId: hand.id, at: to),
          ),
          game: play.gameAt(seat.id),
        ),
      ],
    );

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(m.safeInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopBar(
                metrics: m,
                seatName: seat.name,
                life: seat.life,
                canUndo: play.canUndo,
                renderer: renderer,
                onSwitchRenderer: () => ref
                    .read(rendererChoiceProvider.notifier)
                    .choose(renderer == TableRenderer.stackedSeats
                        ? TableRenderer.freeCanvas
                        : TableRenderer.stackedSeats),
                onCardSize: (by) =>
                    ref.read(cardScaleProvider.notifier).nudge(by),
                onLife: (by) => play.run(ChangeLife(seatId: seat.id, by: by)),
                onUndo: play.undo,
                onLeave: () {
                  play.leave();
                  Navigator.of(context).maybePop();
                },
              ),
              if (views.length > 1) ...[
                SizedBox(height: m.scaled(10)),
                RadarStrip(
                  metrics: m,
                  seats: [
                    for (final v in views)
                      (seatId: v.seatId, name: v.name, life: v.life),
                  ],
                  focusedSeatId: viewerId,
                  onJump: _look,
                ),
              ],
              SizedBox(height: m.scaled(12)),
              Expanded(
                child: switch (renderer) {
                  TableRenderer.stackedSeats => StackedSeats(
                      metrics: m,
                      seats: views,
                      viewerSeatId: viewerId,
                      printings: _printings,
                      turnSeatId: table.turnSeatId,
                      onFocusSeat: _look,
                      gameFor: play.gameAt,
                      yours: yours,
                    ),
                  TableRenderer.freeCanvas => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: KeyedSubtree(
                            key: const Key('your-board'),
                            child: FreeCanvas(
                              metrics: m,
                              cardScale: cardScale,
                              seats: views,
                              viewerSeatId: viewerId,
                              printings: _printings,
                              turnSeatId: table.turnSeatId,
                              // Your own deck and your own corner, on the mat
                              // they belong to. The bands drew both and the
                              // canvas drew neither, so opening the wide view
                              // was opening a table with no deck on it.
                              libraryCount: library.size,
                              libraryOf: play.deckSizeAt(seat.id),
                              commandCards: command?.cards,
                              // The same pile the bands draw, at the surface's
                              // own card size: a mat is in surface units and
                              // the canvas is the thing that zooms.
                              graveyard: _pile(
                                m,
                                graveyard,
                                width: cardOnMat.width,
                              ),
                              // Built here and not inside the canvas, for the
                              // same reason the pile is: one control, so the
                              // two renderers cannot drift apart.
                              tokenButton:
                                  _tokenButton(m, width: cardOnMat.width),
                              // The same three dice, for the same reason.
                              diceTray: _diceTray(width: cardOnMat.width),
                              gameFor: play.gameAt,
                              onDraw: () => play.run(DrawCards(
                                fromZoneId: library.id,
                                toZoneId: hand.id,
                                count: 1,
                              )),
                              onWorkDeck: _workTheDeck,
                              onPlayCommand: (c) => play.run(
                                MoveCard(
                                  cardId: c.id,
                                  toZoneId: battlefield.id,
                                ),
                              ),
                              onSendHome: command == null
                                  ? null
                                  : (c) => play.run(MoveCard(
                                        cardId: c.id,
                                        toZoneId: command.id,
                                      )),
                              onTapCard: (c) => play.run(RotateCard(c.id)),
                              onInspectCard: _inspect,
                              // Only your own mat takes a drop, and yours is
                              // this battlefield, so the canvas has no pile
                              // to name that this is not.
                              onPlace: (id, x, y) =>
                                  _place(battlefield.id, id, x, y),
                            ),
                          ),
                        ),
                        // The hand stays below the surface in both renderers.
                        // A hand floating over the canvas is the one thing the
                        // spec rules out by geometry.
                        HandSheet(
                          metrics: m,
                          cards: mine ? hand.cards : const [],
                          printings: _printings,
                          onPlay: (c) => play.run(
                            MoveCard(cardId: c.id, toZoneId: battlefield.id),
                          ),
                          onInspect: _inspect,
                          onReorder: (id, to) => play.run(
                            MoveCard(cardId: id, toZoneId: hand.id, at: to),
                          ),
                          game: play.gameAt(seat.id),
                        ),
                      ],
                    ),
                },
              ),
              HintBar(
                metrics: m,
                hints: const [
                  Hint(button: 'A', label: 'tap to turn'),
                  Hint(button: 'B', label: 'back'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Puts a card down where it was dropped, in whichever renderer dropped it.
  ///
  /// The pile is the one that took the drop and not the one the card is in.
  /// Reading it off the card works right up until the card comes out of your
  /// hand, and then it moves it neatly back into your hand.
  ///
  /// A card already on that pile keeps its place in it: this says where on the
  /// mat it is lying, and nothing else. One arriving from somewhere else has
  /// no place there to keep. Both renderers normalize against the same mat so
  /// a drag on the canvas and a drag on the D-pad board mean the same thing.
  void _place(String toZoneId, String cardId, double x, double y) {
    final found = ref.read(playProvider)?.locate(cardId);
    if (found == null) return;
    final already = found.zone.id == toZoneId;
    ref.read(playProvider.notifier).run(MoveCard(
          cardId: cardId,
          toZoneId: toZoneId,
          at: already
              ? found.zone.cards.indexWhere((c) => c.id == cardId)
              : null,
          position: (x: x, y: y),
        ));
  }

  /// Your graveyard, as a pile on the table.
  ///
  /// Built here and not twice, because both renderers draw the same pile and
  /// the only thing they disagree about is where it stands.
  ///
  /// The top card is the last one thrown in and not the first: `MoveCard`
  /// hands the card to `Zone.add` with no index and `Zone.add` inserts at
  /// nought, so the newest is `cards.first`, which is what `Zone.top` already
  /// means for a pile whose order is part of the game.
  ///
  /// A commander thrown in here goes to its own zone instead, which is where
  /// Magic keeps one and where you would have to fish it back out of by hand
  /// otherwise. Magic lets its owner choose between the two; a kitchen table
  /// wants the common case, and the choice is a rule question for the day
  /// somebody sits in the referee's chair.
  Widget _pile(Metrics m, Zone graveyard, {required double width}) {
    final onTop = graveyard.top;

    return LibraryStack(
      metrics: m,
      pileName: 'graveyard',
      label: graveyard.label,
      count: graveyard.size,
      width: width,
      faceUp: true,
      face: onTop == null ? null : _printings[onTop.oracleId],
      onDraw: _lookInThePile,
      onDrop: _throwIn(graveyard),
    );
  }

  /// Your graveyard as a chip, which is what it is worth on a screen with a
  /// row under the board rather than strips beside a mat.
  ///
  /// An empty one was a 50 by 70 outline of a card that is not there, and it
  /// was the leftmost and most prominent object on a 390 point phone. The chip
  /// grows into a card sized target for as long as a card is in the air, which
  /// is the only time a drop target has to be the size of a card.
  ///
  /// The same top card, the same sheet and the same drop as the pile above, so
  /// the two arrangements cannot disagree about which end of the pile is its
  /// top or about where a commander thrown in here ends up.
  Widget _chip(Metrics m, Zone graveyard, {required double width}) {
    final onTop = graveyard.top;

    return ZoneChip(
      metrics: m,
      pileName: 'graveyard',
      label: graveyard.label,
      count: graveyard.size,
      cardWidth: width,
      face: onTop == null ? null : _printings[onTop.oracleId],
      onTap: _lookInThePile,
      onDrop: _throwIn(graveyard),
    );
  }

  /// What a card let go over your graveyard does.
  ///
  /// One copy for the pile and the chip. Which zone a commander lands in is
  /// exactly the kind of rule that would be right in one of them and wrong in
  /// the other, and the seat is read off the zone rather than handed down from
  /// the build method: a seat threaded through each arrangement is a hand off
  /// site apiece that nothing pins, and the canvas took a wrong seat once with
  /// the whole suite green behind it.
  void Function(CardInstance) _throwIn(Zone graveyard) => (c) {
        final play = ref.read(playProvider.notifier);
        play.run(MoveCard(
          cardId: c.id,
          toZoneId: play.isCommander(c.id)
              ? 'command-${graveyard.seatId}'
              : graveyard.id,
        ));
      };

  /// The way to a token that is not a copy of something already on the table.
  ///
  /// Beside the deck and the pile, because that is where the furniture of a
  /// table lives, and no wider than a card: this column's width comes out of
  /// the board's, so a control that reached past the deck would shrink every
  /// card on the mat to pay for itself.
  Widget _tokenButton(Metrics m, {required double width}) => SizedBox(
        width: width,
        child: GestureDetector(
          key: const Key('make-token'),
          onTap: _makeToken,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: m.scaled(8)),
            decoration: BoxDecoration(
              color: Palette.tile,
              borderRadius: BorderRadius.circular(m.scaled(8)),
              border: Border.all(color: Palette.tileEdge),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_circle_outline_rounded,
                  size: m.scaled(16),
                  color: Palette.inkMuted,
                ),
                SizedBox(height: m.scaled(3)),
                Text(
                  'Token',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: m.scaled(10),
                    fontWeight: FontWeight.w600,
                    color: Palette.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  /// The three dice, standing with the graveyard across the board from the
  /// deck.
  ///
  /// Built here and handed to both renderers, the way the pile and the token
  /// control are: this is the third control the two views could each build
  /// their own of, and drifting apart is what happened the first two times.
  ///
  /// No wider than a card between the three of them, because that strip's
  /// width is what the board's scale is read from.
  Widget _diceTray({required double width}) => DiceTray(
        showing: ref.watch(playProvider)?.dice ?? const [],
        width: width,
        onRoll: (results) =>
            ref.read(playProvider.notifier).run(RollDice(results)),
      );

  /// Making a token out of a card somebody looked up.
  ///
  /// Onto your own battlefield, because that is the only mat this screen lets
  /// you put anything on.
  Future<void> _makeToken() async {
    final table = ref.read(playProvider);
    final seatId = ref.read(viewerSeatProvider);
    if (table == null || seatId == null) return;

    final battlefield = table.zone('battlefield-$seatId');
    if (battlefield == null) return;

    final media = MediaQuery.of(context);
    final m = Metrics.of(classifyDevice(
      size: media.size,
      hasTouch: media.navigationMode == NavigationMode.traditional,
    ));

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Palette.surface,
      isScrollControlled: true,
      builder: (sheet) => TokenSheet(
        metrics: m,
        // No catalog is no cards, and the sheet says so out loud rather than
        // offering to mint a token with no face on it.
        search: (term) async {
          final db = ref.read(catalogDbProvider);
          if (db == null) return const [];
          return db.searchByName(term);
        },
        onPick: (card) {
          Navigator.of(sheet).pop();
          ref.read(playProvider.notifier).run(CreateToken(
                zoneId: battlefield.id,
                oracleId: card.oracleId,
                cardId: 'token-${freshSeed()}',
              ));
        },
      ),
    );

    // The token's face is a card this screen has never drawn, so nothing in
    // the printings map answers for it and it would come out a blank back.
    if (mounted) await _loadPrintings();
  }

  /// Looking through the graveyard, and taking something back out of it.
  ///
  /// No first step asking whether you are sure, unlike the deck: the pile is
  /// public and has been all game, so opening it reveals nothing.
  Future<void> _lookInThePile() async {
    final table = ref.read(playProvider);
    final seatId = ref.read(viewerSeatProvider);
    if (table == null || seatId == null) return;

    final pile = table.zone('graveyard-$seatId');
    final library = table.zone('library-$seatId');
    if (pile == null || library == null) return;

    final media = MediaQuery.of(context);
    final m = Metrics.of(classifyDevice(
      size: media.size,
      hasTouch: media.navigationMode == NavigationMode.traditional,
    ));

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Palette.surface,
      isScrollControlled: true,
      builder: (sheet) => PileSheet(
        metrics: m,
        label: pile.label,
        cards: pile.cards,
        printings: _printings,
        onArrange: (placements) {
          Navigator.of(sheet).pop();
          final play = ref.read(playProvider.notifier);
          for (final move in arrange(
            libraryId: library.id,
            placements: placements,
            librarySize: library.size,
            // These cards are in the graveyard and not in the library, so a
            // card sent underneath lands in a pile one longer than this.
            fromLibrary: false,
            handId: table.zone('hand-$seatId')?.id,
          )) {
            play.run(move);
          }
        },
      ),
    );
  }

  /// Moves the viewer, and says out loud when it will not move.
  ///
  /// A seat somebody else holds is watched and not played, and a tap that does
  /// nothing silently is the bug this project has already shipped once, on the
  /// Play row that refused without a word.
  void _look(String seatId) {
    if (ref.read(viewerSeatProvider.notifier).look(seatId)) return;
    Toast.show(
      context,
      'That seat is not yours to look out of',
      icon: Icons.visibility_off_rounded,
    );
  }

  /// Shuffling, and looking at the top.
  ///
  /// `peek` reads the library straight off the table rather than through a
  /// `SeatView`, and that is deliberate: a `SeatView` correctly hides a
  /// library from everybody, its owner included, and this is the one act that
  /// is allowed to look. It is also why it is a callback and not a field, so
  /// the cards exist only while the sheet is open.
  Future<void> _workTheDeck() async {
    final table = ref.read(playProvider);
    final seatId = ref.read(viewerSeatProvider);
    if (table == null || seatId == null) return;

    final library = table.zone('library-$seatId');
    if (library == null) return;

    final media = MediaQuery.of(context);
    final m = Metrics.of(classifyDevice(
      size: media.size,
      hasTouch: media.navigationMode == NavigationMode.traditional,
    ));

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Palette.surface,
      isScrollControlled: true,
      builder: (sheet) => DeckSheet(
        metrics: m,
        count: library.size,
        printings: _printings,
        peek: (n) async => library.cards.take(n).toList(),
        onShuffle: () {
          Navigator.of(sheet).pop();
          ref.read(playProvider.notifier).run(
                ShuffleZone(zoneId: library.id, seed: freshSeed()),
              );
        },
        onArrange: (placements) {
          Navigator.of(sheet).pop();
          final play = ref.read(playProvider.notifier);
          for (final move in arrange(
            libraryId: library.id,
            placements: placements,
            librarySize: library.size,
            graveyardId: table.zone('graveyard-$seatId')?.id,
            handId: table.zone('hand-$seatId')?.id,
          )) {
            play.run(move);
          }
        },
      ),
    );
  }

  /// The long press: the big card, and the controls on it.
  Future<void> _inspect(CardInstance instance) async {
    final printing = _printings[instance.oracleId];
    if (printing == null) return;

    final table = ref.read(playProvider);
    final viewerId = ref.read(viewerSeatProvider) ?? '';
    final command = table?.zone('command-$viewerId');

    final action = await CardViewer.show(
      context,
      printing,
      instance: instance,
      hasCommandZone: command != null,
      // Counting happens while the viewer is still up, so the kind chosen in
      // there comes back out here. Everything else the viewer offers is a verb
      // with no argument and comes back as the action it popped with.
      onCount: (kind, by) => ref.read(playProvider.notifier).run(
            ChangeCounter(cardId: instance.id, kind: kind, by: by),
          ),
    );
    if (action == null || !mounted) return;

    final play = ref.read(playProvider.notifier);
    switch (action) {
      case CardAction.upsideDown:
        play.run(RotateCard(instance.id, to: 180));
      case CardAction.straighten:
        play.run(RotateCard(instance.id, to: 0));
      case CardAction.flip:
        play.run(FlipCard(instance.id));
      case CardAction.counterUp:
      case CardAction.counterDown:
        // Already run, by onCount above. The kind was `+1/+1` here until the
        // viewer learned to ask, which made a planeswalker's loyalty and a
        // Pokemon's damage the same number.
        break;
      case CardAction.commandZone:
        // Offered only when the zone is there, so the null case is a viewer
        // that has outlived the table rather than a format without a corner.
        if (command != null) {
          play.run(MoveCard(cardId: instance.id, toZoneId: command.id));
        }
      case CardAction.copy:
        // Onto whichever pile the card is on, read again here rather than
        // trusted from before the viewer opened: the big view is a route and
        // the card can have moved while it was up.
        final found = ref.read(playProvider)?.locate(instance.id);
        if (found == null) return;
        play.run(CreateToken(
          zoneId: found.zone.id,
          oracleId: instance.oracleId,
          // Minted here and not in the reducer, which is what keeps `apply` a
          // function: plan 3 replays these and has to get the same table.
          //
          // freshSeed and not microsecondsSinceEpoch, which is a double with
          // millisecond resolution on the web: two copies made in the same
          // millisecond would be one card with one id, and the second would
          // land on a Zone that already holds it.
          cardId: 'token-${freshSeed()}',
        ));
    }
  }
}

/// The graveyard, standing on the far side of the board from the deck.
///
/// Its own column and not under the deck. Stacked with the deck the column is
/// two cards tall before the corner and the token button are in it at all, and
/// on a phone that is more height than the row has: the corner, the deck and
/// the token button ran off the bottom of the screen. Across the board is also
/// where a graveyard sits at a table when the library is by your right hand.
///
/// It scrolls rather than overflowing, for the same reason [_Beside] does.
class _Across extends StatelessWidget {
  const _Across({
    required this.graveyard,
    required this.dice,
    required this.makeToken,
  });

  final Widget graveyard;

  /// On this side of the board and not up beside the deck, which is where the
  /// plan put them and where they do not fit: the wide view's right strip is
  /// the mat's own 380 units and the corner and the deck stand 333 of it, so
  /// the tray and its gap want 48.3 of the 46.3 that are left and the column
  /// overflowed by two points. Rather than shave the dice down to whatever the
  /// leftover happens to be this week, they come across with the other things
  /// that are not piles of cards, which is the argument the token button
  /// already made when it crossed for the same reason.
  final Widget dice;

  final Widget makeToken;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            graveyard,
            const SizedBox(height: 12),
            dice,
            const SizedBox(height: 12),
            makeToken,
          ],
        ),
      );
}

/// The graveyard, the dice, the token control, the corner and the deck, in a
/// row under your own board.
///
/// Two columns beside the board cost `aside * 2 + gap * 2` of the row before
/// either of them draws a card, and on a 390 point phone that left the board
/// 59 percent of the screen with a card on it half the size of the same card
/// in your hand. Under the board what they cost is height, which is the one
/// thing a phone held upright has to spare.
///
/// The graveyard at one end and the deck at the other, the way the columns
/// had them: a graveyard sits across the table from the library, and the
/// controls that are not piles of cards stand between them rather than either
/// side of the board.
///
/// It scrolls sideways rather than overflowing, for the same reason [_Beside]
/// scrolls down. Five pieces of furniture at a card's width each is more than
/// a phone's row holds, and the answer is not to shave the card down to
/// whatever a fifth of the row comes to: these are cards off this table and
/// the size of the cards on it is the whole reason the board says its scale
/// out loud.
class _Underneath extends StatelessWidget {
  const _Underneath({
    required this.room,
    required this.gap,
    required this.graveyard,
    required this.dice,
    required this.makeToken,
    required this.command,
    required this.library,
  });

  /// How wide the row it stands in is.
  ///
  /// So the pieces spread across it rather than bunching at the left: the
  /// graveyard ends up hard against one edge and the deck against the other,
  /// which is where the two columns had them and where a deck is at a table.
  /// It is also the width past which the row scrolls, and then there is no
  /// room left over to spread and the gaps are the gaps below.
  final double room;

  final double gap;
  final Widget graveyard;
  final Widget dice;
  final Widget makeToken;

  /// Null in a format without commanders, which is not an empty corner: an
  /// empty one is still drawn, for the reason [_Beside] gives.
  final Widget? command;

  final Widget library;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        // Along the bottom edge and not up the middle of the row. The pieces
        // are different heights, and a table stands them all on the same
        // surface.
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: room),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              graveyard,
              SizedBox(width: gap),
              dice,
              SizedBox(width: gap),
              makeToken,
              SizedBox(width: gap),
              if (command != null) ...[
                command!,
                SizedBox(width: gap),
              ],
              library,
            ],
          ),
        ),
      );
}

/// The corner, the deck and the token button, standing beside your own mat.
///
/// Beside it and not over and under it, because the board's height is what
/// the whole table's scale is read from and anything stacked with the board
/// takes that height away from it. Once the mat fits the window rather than
/// filling it there is room at the sides anyway, which is where a deck and a
/// commander sit at a real table.
///
/// It scrolls rather than overflowing. A phone in a pod leaves this column
/// less height than two cards need, and that squeeze belongs to the screen's
/// budget rather than to the pile.
class _Beside extends StatelessWidget {
  const _Beside({
    required this.metrics,
    required this.command,
    required this.library,
  });

  final Metrics metrics;

  /// Null in a format without commanders, which is not the same as an empty
  /// corner: an empty corner is still drawn, because a corner that comes and
  /// goes reads as a bug rather than as a rule.
  final Widget? command;

  final Widget library;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (command != null) ...[
            command!,
            SizedBox(height: m.scaled(12)),
          ],
          library,
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.metrics,
    required this.seatName,
    required this.life,
    required this.canUndo,
    required this.renderer,
    required this.onSwitchRenderer,
    required this.onCardSize,
    required this.onLife,
    required this.onUndo,
    required this.onLeave,
  });

  final Metrics metrics;
  final String seatName;
  final int life;
  final bool canUndo;
  final TableRenderer renderer;
  final VoidCallback onSwitchRenderer;

  /// One notch bigger or smaller, for the cards on the table.
  final void Function(int) onCardSize;
  final void Function(int) onLife;
  final VoidCallback onUndo;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return Row(
      children: [
        GestureDetector(
          onTap: onLeave,
          behavior: HitTestBehavior.opaque,
          child: Icon(
            Icons.arrow_back_rounded,
            size: m.scaled(20),
            color: Palette.inkMuted,
          ),
        ),
        SizedBox(width: m.scaled(12)),
        Expanded(
          child: Text(
            seatName,
            style: TextStyle(fontSize: m.scaled(14), color: Palette.inkMuted),
          ),
        ),
        _Pill(
          metrics: m,
          key: const Key('life-down'),
          icon: Icons.remove_rounded,
          onTap: () => onLife(-1),
        ),
        SizedBox(width: m.scaled(10)),
        Text(
          '$life',
          style: TextStyle(
            fontSize: m.scaled(22),
            fontWeight: FontWeight.w700,
            color: Palette.ink,
          ),
        ),
        SizedBox(width: m.scaled(10)),
        _Pill(
          metrics: m,
          key: const Key('life-up'),
          icon: Icons.add_rounded,
          onTap: () => onLife(1),
        ),
        SizedBox(width: m.scaled(12)),
        _Pill(
          metrics: m,
          key: const Key('switch-renderer'),
          icon: renderer == TableRenderer.stackedSeats
              ? Icons.grid_view_rounded
              : Icons.view_agenda_rounded,
          onTap: onSwitchRenderer,
        ),
        SizedBox(width: m.scaled(12)),
        _Pill(
          metrics: m,
          key: const Key('cards-smaller'),
          icon: Icons.zoom_out_rounded,
          onTap: () => onCardSize(-1),
        ),
        SizedBox(width: m.scaled(10)),
        _Pill(
          metrics: m,
          key: const Key('cards-bigger'),
          icon: Icons.zoom_in_rounded,
          onTap: () => onCardSize(1),
        ),
        SizedBox(width: m.scaled(12)),
        Opacity(
          opacity: canUndo ? 1 : 0.35,
          child: _Pill(
            metrics: m,
            key: const Key('undo'),
            icon: Icons.undo_rounded,
            onTap: onUndo,
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    required this.metrics,
    required this.icon,
    required this.onTap,
  });

  final Metrics metrics;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: m.scaled(34),
        height: m.scaled(34),
        decoration: BoxDecoration(
          color: Palette.tile,
          borderRadius: BorderRadius.circular(m.scaled(8)),
          border: Border.all(color: Palette.tileEdge),
        ),
        child: Icon(icon, size: m.scaled(17), color: Palette.inkMuted),
      ),
    );
  }
}
