import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../decks/model/game.dart';
import '../../sources/model/catalog_card.dart';
import '../../ui/atoms/card_art.dart';
import '../../ui/atoms/pressable.dart';
import '../../ui/atoms/tray.dart';
import '../../ui/organisms/screen_frame.dart';
import '../../ui/tokens/lettering.dart';
import '../../ui/tokens/metrics.dart';
import '../../ui/tokens/palette.dart';
import 'draft_build_screen.dart';
import 'draft_controller.dart';
import 'draft_state.dart';
import 'pack_opening.dart';

/// The draft, from the player's chair.
///
/// It follows the one view the host sends this seat: a pack to pick from, a
/// wait while a neighbour's pack comes around, or the deck builder once the
/// packs are spent. A freshly cracked pack plays the opening crack once before
/// its cards are laid out to pick from; a pack passed along by a neighbour goes
/// straight to the grid.
class DraftScreen extends ConsumerStatefulWidget {
  const DraftScreen({super.key, this.game = Game.magic, this.onBack});

  final Game game;
  final VoidCallback? onBack;

  @override
  ConsumerState<DraftScreen> createState() => _DraftScreenState();
}

class _DraftScreenState extends ConsumerState<DraftScreen> {
  /// The pack whose crack we have already played, so picking within a pack
  /// does not replay it and a neighbour's pack never triggers it.
  String? _openedPack;

  static String _signature(DraftView v) {
    final first = (v.pack != null && v.pack!.isNotEmpty) ? v.pack!.first.uuid : '';
    return '${v.packNumber}:${v.pack?.length ?? 0}:$first';
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final m = Metrics.of(
      classifyDevice(
        size: media.size,
        hasTouch: media.navigationMode == NavigationMode.traditional,
      ),
    );

    final view = ref.watch(draftProvider);
    final cards = ref.watch(draftCardsProvider).value ?? const {};

    if (view == null) {
      return ScreenFrame(
        metrics: m,
        title: 'Draft',
        label: 'dealing the packs',
        onBack: widget.onBack,
        children: [
          Padding(
            padding: EdgeInsets.all(m.scaled(24)),
            child: Center(child: Text('…', style: slabText(m.scaled(28)))),
          ),
        ],
      );
    }

    if (view.phase == DraftPhase.building) {
      return DraftBuildScreen(game: widget.game, onBack: widget.onBack);
    }

    if (view.phase == DraftPhase.waiting) {
      return ScreenFrame(
        metrics: m,
        title: 'Draft',
        label: 'pack ${view.packNumber}',
        onBack: widget.onBack,
        children: [_Waiting(metrics: m, pool: view.pool, cards: cards)],
      );
    }

    // Picking. Crack a freshly opened pack once, then lay out the grid.
    final pack = view.pack ?? const <DraftCard>[];
    final sig = _signature(view);
    if (view.fresh && _openedPack != sig) {
      return Scaffold(
        backgroundColor: Palette.felt,
        body: SafeArea(
          child: PackOpening(
            metrics: m,
            count: pack.length,
            packNumber: view.packNumber,
            game: widget.game,
            onDone: () => setState(() => _openedPack = sig),
          ),
        ),
      );
    }

    return ScreenFrame(
      metrics: m,
      title: 'Draft',
      label: 'pack ${view.packNumber} · pick ${view.pickNumber}',
      onBack: widget.onBack,
      children: [
        if (view.queueDepth > 0)
          Padding(
            padding: EdgeInsets.only(bottom: m.scaled(8)),
            child: TrayLabel(
              metrics: m,
              text: '${view.queueDepth} more waiting',
            ),
          ),
        _PackGrid(
          metrics: m,
          pack: pack,
          cards: cards,
          game: widget.game,
          onPick: (uuid) => ref.read(draftProvider.notifier).pick(uuid),
        ),
        SizedBox(height: m.scaled(12)),
        _PoolStrip(metrics: m, pool: view.pool, cards: cards, game: widget.game),
      ],
    );
  }
}

/// The pack laid face up, each card a button that takes it.
class _PackGrid extends StatelessWidget {
  const _PackGrid({
    required this.metrics,
    required this.pack,
    required this.cards,
    required this.game,
    required this.onPick,
  });

  final Metrics metrics;
  final List<DraftCard> pack;
  final Map<String, CatalogCard> cards;
  final Game game;
  final void Function(String uuid) onPick;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final w = m.scaled(96);
    return Wrap(
      spacing: m.scaled(8),
      runSpacing: m.scaled(8),
      alignment: WrapAlignment.center,
      children: [
        for (var i = 0; i < pack.length; i++)
          _PickableCard(
            metrics: m,
            draft: pack[i],
            card: cards[pack[i].oracleId],
            game: game,
            width: w,
            autofocus: i == 0,
            onPick: () => onPick(pack[i].uuid),
          ),
      ],
    );
  }
}

/// One card in the pack: its art, a glow if it is rare, and a press that takes
/// it into the pool.
class _PickableCard extends StatelessWidget {
  const _PickableCard({
    required this.metrics,
    required this.draft,
    required this.card,
    required this.game,
    required this.width,
    required this.autofocus,
    required this.onPick,
  });

  final Metrics metrics;
  final DraftCard draft;
  final CatalogCard? card;
  final Game game;
  final double width;
  final bool autofocus;
  final VoidCallback onPick;

  bool get _rare {
    final r = draft.rarity.toLowerCase();
    return r == 'rare' || r == 'mythic';
  }

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    return Pressable(
      metrics: m,
      onPress: onPick,
      autofocus: autofocus,
      semanticLabel: card?.name ?? 'Unknown card',
      radius: m.scaled(8),
      child: Container(
        decoration: _rare
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(m.scaled(8)),
                boxShadow: const [
                  BoxShadow(
                    color: Palette.attention,
                    blurRadius: 18,
                    spreadRadius: -6,
                  ),
                ],
              )
            : null,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(m.scaled(6)),
          child: card == null
              ? CardBack(width: width, game: game)
              : CardArt(metrics: m, card: card!, width: width),
        ),
      ),
    );
  }
}

/// The pool you have drafted so far, a scrollable strip under the pack.
class _PoolStrip extends StatelessWidget {
  const _PoolStrip({
    required this.metrics,
    required this.pool,
    required this.cards,
    required this.game,
  });

  final Metrics metrics;
  final List<DraftCard> pool;
  final Map<String, CatalogCard> cards;
  final Game game;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final w = m.scaled(52);
    return Well(
      metrics: m,
      label: 'Your pool · ${pool.length}',
      child: pool.isEmpty
          ? Text(
              'nothing yet',
              style: pixel(size: m.scaled(12), color: Palette.inkFaint),
            )
          : SizedBox(
              height: w * 88 / 63,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: pool.length,
                separatorBuilder: (_, _) => SizedBox(width: m.scaled(4)),
                itemBuilder: (context, i) {
                  final c = cards[pool[i].oracleId];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(m.scaled(4)),
                    child: c == null
                        ? CardBack(width: w, game: game)
                        : CardArt(metrics: m, card: c, width: w),
                  );
                },
              ),
            ),
    );
  }
}

/// Shown while a neighbour's pack has not come around yet.
class _Waiting extends StatelessWidget {
  const _Waiting({
    required this.metrics,
    required this.pool,
    required this.cards,
  });

  final Metrics metrics;
  final List<DraftCard> pool;
  final Map<String, CatalogCard> cards;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: m.scaled(20)),
          child: Text(
            'waiting for the next pack',
            textAlign: TextAlign.center,
            style: pixel(size: m.scaled(14), color: Palette.inkMuted),
          ),
        ),
        _PoolStrip(
          metrics: m,
          pool: pool,
          cards: cards,
          game: Game.magic,
        ),
      ],
    );
  }
}
