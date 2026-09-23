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
      chosen: ref.watch(rendererChoiceProvider),
    );

    final zones = [
      (id: battlefield.id, label: battlefield.label, cards: battlefield.cards),
      (id: graveyard.id, label: graveyard.label, cards: graveyard.cards),
    ];

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
                LibraryStack.spreadFor(library.size),
                m.scaled(6),
              );
              final gap = m.scaled(10);

              // What is left over when height is what runs out. Infinite
              // when the board is too short to fit a mat at all and scrolls
              // instead, and then the width below is the only answer.
              final byHeight = cardOnMat.width *
                  cardScale *
                  CursorBoard.scaleFor(
                    box: Size(double.infinity, box.maxHeight),
                    zones: zones,
                    metrics: m,
                  );

              // And when width is. The card is on both sides of this one,
              // because the board only gets the width the cards beside it
              // leave: a card of w takes w + aside + gap out of the row, and
              // the mat is scaled by what remains. Solved once, here.
              final room = box.maxWidth - aside - gap;
              final byWidth = cardOnMat.width *
                  cardScale *
                  (room < 0 ? 0.0 : room) /
                  (matSize.width + cardOnMat.width * cardScale);

              final card = math.min(byHeight, byWidth);

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: CursorBoard(
                      key: const Key('your-board'),
                      metrics: m,
                      cardScale: cardScale,
                      zones: zones,
                      printings: _printings,
                      onActivate: (c) => play.run(RotateCard(c.id)),
                      onInspect: _inspect,
                      onPlace: _place,
                    ),
                  ),
                  SizedBox(width: gap),
                  _Beside(
                    metrics: m,
                    command: command == null
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
                          ),
                    library: LibraryStack(
                      metrics: m,
                      count: library.size,
                      width: card,
                      game: play.gameAt(seat.id),
                      onDraw: () => play.run(DrawCards(
                        fromZoneId: library.id,
                        toZoneId: hand.id,
                        count: 1,
                      )),
                      onWork: _workTheDeck,
                    ),
                    graveyard: _pile(m, graveyard, width: card),
                    makeToken: _tokenButton(m, width: card),
                  ),
                ],
              );
            },
          ),
        ),
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
                              commandCards: command?.cards,
                              // The same pile the bands draw, at the surface's
                              // own card size: a mat is in surface units and
                              // the canvas is the thing that zooms.
                              graveyard: _pile(
                                m,
                                graveyard,
                                width: cardOnMat.width,
                              ),
                              game: play.gameAt(seat.id),
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
      onDrop: (c) => ref.read(playProvider.notifier).run(
            MoveCard(cardId: c.id, toZoneId: graveyard.id),
          ),
    );
  }

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

    final action = await CardViewer.show(context, printing,
        instance: instance, hasCommandZone: command != null);
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
        play.run(ChangeCounter(cardId: instance.id, kind: '+1/+1', by: 1));
      case CardAction.counterDown:
        play.run(ChangeCounter(cardId: instance.id, kind: '+1/+1', by: -1));
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

/// The corner and the pile, standing beside your own mat.
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
    required this.graveyard,
    required this.makeToken,
  });

  final Metrics metrics;

  /// Null in a format without commanders, which is not the same as an empty
  /// corner: an empty corner is still drawn, because a corner that comes and
  /// goes reads as a bug rather than as a rule.
  final Widget? command;

  final Widget library;

  /// Under the deck, in a column and not beside it. The row's width is what
  /// the board's scale is read from, and a second pile across from the first
  /// would take a whole card's width off the board on a phone.
  final Widget graveyard;

  /// Last, under the pile. A token is the one thing in this column that is not
  /// already a pile of cards, and it is also the one nobody reaches for in the
  /// first minute of a game.
  final Widget makeToken;

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
          SizedBox(height: m.scaled(12)),
          graveyard,
          SizedBox(height: m.scaled(12)),
          makeToken,
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
