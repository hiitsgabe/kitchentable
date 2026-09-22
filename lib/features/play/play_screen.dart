import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sources/model/catalog_card.dart';
import '../../table/actions/table_action.dart';
import '../../table/model/card_instance.dart';
import '../../ui/atoms/hint_bar.dart';
import '../../ui/organisms/card_viewer.dart';
import '../../ui/organisms/screen_frame.dart';
import '../../ui/tokens/metrics.dart';
import '../../ui/tokens/palette.dart';
import '../menu/menu_controller.dart';
import 'play_controller.dart';
import 'widgets/hand_sheet.dart';
import 'widgets/table_card.dart';

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

    final seat = table.seats.first;
    final hand = table.zone('hand-${seat.id}')!;
    final battlefield = table.zone('battlefield-${seat.id}')!;
    final library = table.zone('library-${seat.id}')!;
    final graveyard = table.zone('graveyard-${seat.id}')!;

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
                onLife: (by) =>
                    play.run(ChangeLife(seatId: seat.id, by: by)),
                onUndo: play.undo,
                onLeave: () {
                  play.leave();
                  Navigator.of(context).maybePop();
                },
              ),
              SizedBox(height: m.scaled(12)),
              Expanded(
                child: _Battlefield(
                  metrics: m,
                  cards: battlefield.cards,
                  printings: _printings,
                  onTap: (c) => play.run(RotateCard(c.id)),
                  onInspect: _inspect,
                ),
              ),
              SizedBox(height: m.scaled(10)),
              _Piles(
                metrics: m,
                librarySize: library.size,
                graveyardSize: graveyard.size,
                onDraw: () => play.run(DrawCards(
                  fromZoneId: library.id,
                  toZoneId: hand.id,
                  count: 1,
                )),
              ),
              HandSheet(
                metrics: m,
                cards: hand.cards,
                printings: _printings,
                onPlay: (c) => play.run(
                  MoveCard(cardId: c.id, toZoneId: battlefield.id),
                ),
                onInspect: _inspect,
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

  void _inspect(CardInstance instance) {
    final printing = _printings[instance.oracleId];
    if (printing != null) CardViewer.show(context, printing);
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.metrics,
    required this.seatName,
    required this.life,
    required this.canUndo,
    required this.onLife,
    required this.onUndo,
    required this.onLeave,
  });

  final Metrics metrics;
  final String seatName;
  final int life;
  final bool canUndo;
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

class _Battlefield extends StatelessWidget {
  const _Battlefield({
    required this.metrics,
    required this.cards,
    required this.printings,
    required this.onTap,
    required this.onInspect,
  });

  final Metrics metrics;
  final List<CardInstance> cards;
  final Map<String, CatalogCard> printings;
  final void Function(CardInstance) onTap;
  final void Function(CardInstance) onInspect;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    if (cards.isEmpty) {
      return Center(
        child: Text(
          'Nothing on the battlefield',
          style: TextStyle(fontSize: m.scaled(12), color: Palette.inkFaint),
        ),
      );
    }

    return SingleChildScrollView(
      child: Wrap(
        spacing: m.scaled(8),
        runSpacing: m.scaled(10),
        children: [
          for (final card in cards)
            TableCard(
              metrics: m,
              instance: card,
              printing: printings[card.oracleId],
              width: m.scaled(70),
              onTap: () => onTap(card),
              onLongPress: () => onInspect(card),
            ),
        ],
      ),
    );
  }
}

class _Piles extends StatelessWidget {
  const _Piles({
    required this.metrics,
    required this.librarySize,
    required this.graveyardSize,
    required this.onDraw,
  });

  final Metrics metrics;
  final int librarySize;
  final int graveyardSize;
  final VoidCallback onDraw;

  @override
  Widget build(BuildContext context) {
    final m = metrics;

    return Row(
      children: [
        GestureDetector(
          key: const Key('draw'),
          onTap: onDraw,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: m.scaled(14),
              vertical: m.scaled(9),
            ),
            decoration: BoxDecoration(
              color: Palette.tile,
              borderRadius: BorderRadius.circular(m.scaled(10)),
              border: Border.all(color: Palette.tileEdge),
            ),
            child: Text(
              'Draw · $librarySize',
              style: TextStyle(fontSize: m.scaled(13), color: Palette.ink),
            ),
          ),
        ),
        SizedBox(width: m.scaled(10)),
        Text(
          'Graveyard $graveyardSize',
          style: TextStyle(fontSize: m.scaled(12), color: Palette.inkFaint),
        ),
      ],
    );
  }
}
