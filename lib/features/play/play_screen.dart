import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sources/model/catalog_card.dart';
import '../../table/actions/table_action.dart';
import '../../table/model/card_instance.dart';
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
import 'renderers/renderer_choice.dart';
import 'renderers/stacked_seats.dart';
import 'widgets/command_slot.dart';
import 'widgets/cursor_board.dart';
import 'widgets/deck_sheet.dart';
import 'widgets/hand_sheet.dart';
import 'widgets/library_stack.dart';
import 'widgets/radar_strip.dart';

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

    final yours = Column(
      key: const Key('your-seat'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (command != null)
          Align(
            alignment: Alignment.centerRight,
            child: CommandSlot(
              metrics: m,
              cards: command.cards,
              printings: _printings,
              width: m.scaled(52),
              onTap: (c) => play.run(
                MoveCard(cardId: c.id, toZoneId: battlefield.id),
              ),
              onInspect: _inspect,
            ),
          ),
        Expanded(
          child: CursorBoard(
            key: const Key('your-board'),
            metrics: m,
            cardScale: cardScale,
            zones: [
              (
                id: battlefield.id,
                label: battlefield.label,
                cards: battlefield.cards
              ),
              (
                id: graveyard.id,
                label: graveyard.label,
                cards: graveyard.cards
              ),
            ],
            printings: _printings,
            onActivate: (c) => play.run(RotateCard(c.id)),
            onInspect: _inspect,
            onPlace: (cardId, x, y) {
              final found = ref.read(playProvider)?.locate(cardId);
              if (found == null) return;
              play.run(MoveCard(
                cardId: cardId,
                toZoneId: found.zone.id,
                at: found.zone.cards.indexWhere((c) => c.id == cardId),
                position: (x: x, y: y),
              ));
            },
          ),
        ),
        SizedBox(height: m.scaled(10)),
        LibraryStack(
          metrics: m,
          count: library.size,
          width: m.scaled(46) * cardScale,
          onDraw: () => play.run(DrawCards(
            fromZoneId: library.id,
            toZoneId: hand.id,
            count: 1,
          )),
          onWork: _workTheDeck,
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
                              onTapCard: (c) => play.run(RotateCard(c.id)),
                              onInspectCard: _inspect,
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

    final action = await CardViewer.show(context, printing,
        instance: instance);
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
    }
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
