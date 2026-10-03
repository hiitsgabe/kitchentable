import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sources/model/catalog_card.dart';
import '../../table/actions/table_action.dart';
import '../../table/model/card_instance.dart';
import '../../table/model/zone.dart';
import '../../table/shuffle.dart';
import '../../table/view/seat_view.dart';
import '../../ui/atoms/toast.dart';
import '../../ui/organisms/card_viewer.dart';
import '../../ui/organisms/screen_frame.dart';
import '../../ui/tokens/metrics.dart';
import '../../ui/tokens/palette.dart';
import '../lobby/lobby.dart';
import '../menu/menu_controller.dart';
import 'card_size.dart';
import 'dice/dice_tray.dart';
import 'look_at_top.dart';
import 'play_controller.dart';
import 'said_out_loud.dart';
import 'table_news.dart';
import 'renderers/focus_view.dart';
import 'renderers/grid_view.dart';
import 'renderers/mat_layout.dart';
import 'renderers/renderer_choice.dart';
import 'renderers/split_view.dart';
import 'seat_label.dart';
import 'widgets/command_slot.dart';
import 'widgets/cursor_board.dart';
import 'widgets/deck_sheet.dart';
import 'widgets/hand_sheet.dart';
import 'widgets/library_stack.dart';
import 'widgets/pile_sheet.dart';
import 'widgets/seat_board.dart';
import 'widgets/seat_rail.dart';
import 'widgets/token_sheet.dart';
import 'widgets/watched_board.dart';
import 'widgets/zone_rail.dart';
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
  ///
  /// From the decks at the table first. A guest's deck came over the wire
  /// with every printing field and the catalog here may never have imported
  /// it, so a card looked up in the catalog alone drew a blank on the host's
  /// phone, and the host's did the same on the guest's. The catalog answers
  /// only for a card that came from nowhere: a token, or a table dealt with
  /// no room around it.
  Future<void> _loadPrintings() async {
    final table = ref.read(playProvider);
    if (table == null) return;

    final dealt = ref.read(lobbyProvider)?.printings ?? const {};
    final ids = table.allZones
        .expand((z) => z.cards)
        .map((c) => c.oracleId)
        .where((id) => !dealt.containsKey(id))
        .toSet()
        .toList();

    final db = ref.read(catalogDbProvider);
    final found = db == null || ids.isEmpty
        ? const <CatalogCard>[]
        : await db.cardsByOracleIds(ids);
    if (mounted) {
      setState(() {
        _printings = {...dealt, for (final c in found) c.oracleId: c};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final device = classifyDevice(
      size: media.size,
      hasTouch: media.navigationMode == NavigationMode.traditional,
    );
    final m = Metrics.of(device);
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

    // What somebody else did, said out loud. A table on four phones is four
    // people watching a state change with nobody named: a die rolled at the
    // other end of a call used to be a number that quietly read differently.
    ref.listen(tableNewsProvider, (_, news) {
      if (news == null) return;
      final line = saidOutLoud(news, me: ref.read(transportProvider)?.me);
      if (line != null) {
        Toast.show(context, line, icon: Icons.casino_rounded);
      }
    });

    if (table == null) {
      return ScreenFrame(
        metrics: m,
        title: 'Play',
        label: 'no table',
        onBack: () => Navigator.of(context).maybePop(),
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

    final renderer = rendererFor(chosen: ref.watch(rendererChoiceProvider));
    final watched = ref.watch(watchedSeatProvider);
    final game = play.gameAt(seat.id);
    final others = views.where((v) => v.seatId != seat.id).toList();

    String labelOf(SeatView v) => seatLabel(v, chair: views.indexOf(v));

    // The battlefield alone; the piles stand in the rail beside it.
    final zones = [
      (id: battlefield.id, label: battlefield.label, cards: battlefield.cards),
    ];

    // What a card in your hand is drawn at: the card a board this wide
    // draws, up to the width one line of the hand has always been.
    final thumb = m.scaled(52);
    // The deck stands at the left of the hand's row, so the hand's room is
    // the width less the deck's thickest pile and the gap.
    final handRoom =
        media.size.width -
        media.padding.horizontal -
        m.safeInset * 2 -
        (thumb + LibraryStack.spreadFor(1, 1)) -
        m.scaled(10);
    final handCard = cardWidthFor(handRoom) * cardScale;

    Widget boardFor(SeatView v) {
      if (!(mine && v.seatId == seat.id)) {
        return SeatBoard(
          metrics: m,
          seatId: v.seatId,
          label: labelOf(v),
          life: v.life,
          mine: false,
          hand: v.pile('hand')?.count ?? 0,
          onTapBadge: () => _pick(v.seatId),
          canvas: WatchedCanvas(
            metrics: m,
            seat: v,
            printings: _printings,
            game: play.gameAt(v.seatId),
            onTapCard: _inspect,
            onInspectCard: _inspect,
          ),
        );
      }
      return SeatBoard(
        metrics: m,
        seatId: v.seatId,
        label: labelOf(v),
        life: v.life,
        mine: true,
        canvas: CursorBoard(
          key: const Key('your-board'),
          metrics: m,
          cardScale: cardScale,
          zones: zones,
          printings: _printings,
          onActivate: (c) => play.run(RotateCard(c.id)),
          onInspect: _inspect,
          onPlace: _place,
          game: game,
          showLabels: false,
        ),
        zoneRail: ZoneRail(
          metrics: m,
          // The corner and the chip each keep a few points beside the card
          // for their own edge, so the rail is that much wider than the card
          // it draws them at.
          width: thumb + m.scaled(8),
          graveyard: _chip(m, graveyard, width: thumb),
          command: command == null
              ? null
              : CommandSlot(
                  metrics: m,
                  cards: command.cards,
                  printings: _printings,
                  width: thumb,
                  onTap: (c) => play.run(
                    MoveCard(cardId: c.id, toZoneId: battlefield.id),
                  ),
                  onInspect: _inspect,
                  onSendHome: (c) =>
                      play.run(MoveCard(cardId: c.id, toZoneId: command.id)),
                  game: game,
                ),
        ),
      );
    }

    // Which chip the rail draws as chosen: the page Focus is on, the second
    // board of a Split, nothing in the grid where every board is on screen.
    final picked = switch (renderer) {
      TableRenderer.grid => null,
      TableRenderer.focus => watched ?? seat.id,
      TableRenderer.split =>
        others.any((v) => v.seatId == watched)
            ? watched
            : others.firstOrNull?.seatId,
    };

    final area = switch (renderer) {
      TableRenderer.grid => TableGrid(
        metrics: m,
        seats: views,
        mineId: seat.id,
        board: boardFor,
      ),
      TableRenderer.focus => FocusView(
        seats: views,
        mineId: seat.id,
        watchedSeatId: watched,
        onWatched: (id) => ref.read(watchedSeatProvider.notifier).state = id,
        board: boardFor,
      ),
      TableRenderer.split => SplitView(
        metrics: m,
        seats: views,
        mineId: seat.id,
        watchedSeatId: watched,
        board: boardFor,
      ),
    };

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(m.safeInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopBar(
                metrics: m,
                life: seat.life,
                canUndo: play.canUndo,
                renderer: renderer,
                onSwitchRenderer: () => ref
                    .read(rendererChoiceProvider.notifier)
                    .choose(renderer.next),
                onLife: (by) => play.run(ChangeLife(seatId: seat.id, by: by)),
                onUndo: play.undo,
                onMore: _more,
                onLeave: () {
                  play.leave();
                  Navigator.of(context).maybePop();
                },
              ),
              if (views.length > 1) ...[
                SizedBox(height: m.scaled(6)),
                SeatRail(
                  metrics: m,
                  seats: [
                    for (final v in views)
                      (
                        seatId: v.seatId,
                        label: labelOf(v),
                        life: v.life,
                        hand: v.pile('hand')?.count ?? 0,
                        mine: v.seatId == seat.id,
                      ),
                  ],
                  pickedSeatId: picked,
                  onPick: _pick,
                ),
              ],
              SizedBox(height: m.scaled(8)),
              Expanded(child: area),
              SizedBox(height: m.scaled(6)),
              // The bottom bar, fixed whichever view is showing: your deck,
              // always visible, and your hand beside it, tucked until asked
              // for. Off the battlefield, the way untap pins the game bar and
              // the seat panel to the bottom of a phone: the deck is the one
              // pile you touch every turn and it never moves, and it costs
              // the board nothing.
              Container(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Palette.rule)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    KeyedSubtree(
                      key: const Key('deck-bar'),
                      child: LibraryStack(
                        metrics: m,
                        count: library.size,
                        of: play.deckSizeAt(seat.id),
                        width: thumb,
                        game: game,
                        onDraw: () => play.run(
                          DrawCards(
                            fromZoneId: library.id,
                            toZoneId: hand.id,
                            count: 1,
                          ),
                        ),
                        onWork: _workTheDeck,
                      ),
                    ),
                    SizedBox(width: m.scaled(10)),
                    Expanded(
                      child: HandSheet(
                        metrics: m,
                        cardWidth: handCard,
                        startsOpen: !handIsExpensive(
                          media.size,
                          m,
                          room: handRoom,
                          card: handCard,
                          cards: mine ? hand.cards.length : 0,
                        ),
                        cards: mine ? hand.cards : const [],
                        printings: _printings,
                        onPlay: (c) => play.run(
                          MoveCard(cardId: c.id, toZoneId: battlefield.id),
                        ),
                        onInspect: _inspect,
                        onReorder: (id, to) => play.run(
                          MoveCard(cardId: id, toZoneId: hand.id, at: to),
                        ),
                        game: game,
                      ),
                    ),
                  ],
                ),
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
    ref
        .read(playProvider.notifier)
        .run(
          MoveCard(
            cardId: cardId,
            toZoneId: toZoneId,
            at: already
                ? found.zone.cards.indexWhere((c) => c.id == cardId)
                : null,
            position: (x: x, y: y),
          ),
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
    play.run(
      MoveCard(
        cardId: c.id,
        toZoneId: play.isCommander(c.id)
            ? 'command-${graveyard.seatId}'
            : graveyard.id,
      ),
    );
  };

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
    final m = Metrics.of(
      classifyDevice(
        size: media.size,
        hasTouch: media.navigationMode == NavigationMode.traditional,
      ),
    );

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
          ref
              .read(playProvider.notifier)
              .run(
                CreateToken(
                  zoneId: battlefield.id,
                  oracleId: card.oracleId,
                  cardId: 'token-${freshSeed()}',
                ),
              );
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
    final m = Metrics.of(
      classifyDevice(
        size: media.size,
        hasTouch: media.navigationMode == NavigationMode.traditional,
      ),
    );

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

  /// A chip on the rail, or a badge on a board, was tapped.
  ///
  /// A seat this device holds becomes the one it acts for, which is a pod on
  /// one tablet passing the phone round; any seat becomes the one looked at,
  /// which Focus turns to and Split puts in its second half.
  void _pick(String seatId) {
    final table = ref.read(playProvider);
    final me = ref.read(transportProvider)?.me;
    final actable = table?.seat(seatId)?.owner.actableHere(me: me) ?? false;
    if (actable && seatId != ref.read(viewerSeatProvider)) {
      ref.read(viewerSeatProvider.notifier).look(seatId);
    }
    ref.read(watchedSeatProvider.notifier).state = seatId;
  }

  /// The controls that are not piles of cards: a token, and the dice.
  ///
  /// Off the board and in a sheet, because every client the benchmark read
  /// keeps the battlefield for cards and the furniture for counts; the dice
  /// and the token button stood in a row under the board that cost a phone
  /// its second row of cards.
  Future<void> _more() async {
    final media = MediaQuery.of(context);
    final m = Metrics.of(
      classifyDevice(
        size: media.size,
        hasTouch: media.navigationMode == NavigationMode.traditional,
      ),
    );
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Palette.surface,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(m.scaled(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                key: const Key('make-token'),
                leading: const Icon(Icons.add_circle_outline_rounded),
                title: const Text('Make a token'),
                onTap: () {
                  Navigator.of(sheet).pop();
                  _makeToken();
                },
              ),
              // The size of the cards on the table, one notch at a time.
              // Out of the top bar, which on a phone had no room for them
              // beside the life and the view; this is where every control
              // that is not a card goes.
              ListTile(
                leading: const Icon(Icons.photo_size_select_large_rounded),
                title: const Text('Card size'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: const Key('cards-smaller'),
                      icon: const Icon(Icons.zoom_out_rounded),
                      onPressed: () =>
                          ref.read(cardScaleProvider.notifier).nudge(-1),
                    ),
                    IconButton(
                      key: const Key('cards-bigger'),
                      icon: const Icon(Icons.zoom_in_rounded),
                      onPressed: () =>
                          ref.read(cardScaleProvider.notifier).nudge(1),
                    ),
                  ],
                ),
              ),
              SizedBox(height: m.scaled(8)),
              Consumer(
                builder: (context, ref, _) => Center(
                  child: DiceTray(
                    showing: ref.watch(playProvider)?.dice ?? const [],
                    width: m.scaled(220),
                    announced: announcedRoll(
                      ref.watch(tableNewsProvider),
                      me: ref.read(transportProvider)?.me,
                    ),
                    onRoll: (die, results) => ref
                        .read(playProvider.notifier)
                        .run(RollDice(results, die: die)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
    final m = Metrics.of(
      classifyDevice(
        size: media.size,
        hasTouch: media.navigationMode == NavigationMode.traditional,
      ),
    );

    // Closed once, however many of its callbacks fire. Searching the deck ends
    // in an arrange and a shuffle, and each of those used to pop: the first
    // closed the sheet and the second closed the table under it, so finishing
    // a search put you back in the main menu.
    var closed = false;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Palette.surface,
      isScrollControlled: true,
      builder: (sheet) {
        void close() {
          if (closed) return;
          closed = true;
          Navigator.of(sheet).pop();
        }

        return DeckSheet(
          metrics: m,
          count: library.size,
          printings: _printings,
          peek: (n) async => library.cards.take(n).toList(),
          onShuffle: () {
            close();
            ref
                .read(playProvider.notifier)
                .run(ShuffleZone(zoneId: library.id, seed: freshSeed()));
          },
          onArrange: (placements) {
            close();
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
        );
      },
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
      onCount: (kind, by) => ref
          .read(playProvider.notifier)
          .run(ChangeCounter(cardId: instance.id, kind: kind, by: by)),
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
        play.run(
          CreateToken(
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
          ),
        );
    }
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.metrics,
    required this.life,
    required this.canUndo,
    required this.renderer,
    required this.onSwitchRenderer,
    required this.onLife,
    required this.onUndo,
    required this.onMore,
    required this.onLeave,
  });

  final Metrics metrics;
  final int life;
  final bool canUndo;
  final TableRenderer renderer;
  final VoidCallback onSwitchRenderer;
  final void Function(int) onLife;
  final VoidCallback onUndo;
  final VoidCallback onMore;
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
        // No name here: the rail says whose table this is, and on a phone
        // the bar had no room for it anyway.
        const Spacer(),
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
          icon: switch (renderer) {
            TableRenderer.grid => Icons.grid_view_rounded,
            TableRenderer.focus => Icons.fullscreen_rounded,
            TableRenderer.split => Icons.vertical_split_rounded,
          },
          onTap: onSwitchRenderer,
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
        SizedBox(width: m.scaled(10)),
        _Pill(
          metrics: m,
          key: const Key('more'),
          icon: Icons.more_horiz_rounded,
          onTap: onMore,
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
