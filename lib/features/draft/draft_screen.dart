import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../decks/model/game.dart';
import '../../sources/model/catalog_card.dart';
import '../../ui/atoms/card_art.dart';
import '../../ui/atoms/pressable.dart';
import '../../ui/atoms/tray.dart';
import '../../ui/organisms/card_viewer.dart';
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
  const DraftScreen({
    super.key,
    this.game = Game.magic,
    this.onBack,
    this.setLabel,
  });

  final Game game;
  final VoidCallback? onBack;

  /// The set this draft opens, shown on the pack wrapper. Null falls back to
  /// the plain "PACK" label.
  final String? setLabel;

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

  /// Art for the pack's face: the rarest card in it that the catalog could
  /// resolve, the way a booster features its hit, falling back to the first.
  static String? _coverUrl(
    List<DraftCard> pack,
    Map<String, CatalogCard> cards,
  ) {
    CatalogCard? pick;
    for (final draft in pack) {
      final card = cards[draft.oracleId];
      if (card == null) continue;
      pick ??= card;
      final r = draft.rarity.toLowerCase();
      if (r == 'mythic' || r == 'rare') {
        pick = card;
        break;
      }
    }
    return pick?.imageNormal ?? pick?.imageLarge ?? pick?.imageSmall;
  }

  /// Scryfall's symbol for a set, by its code. Null for anything that is not a
  /// set code, so a demo's made-up label draws no broken symbol.
  static String? _symbolUrl(String? code) {
    if (code == null) return null;
    final c = code.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9]{2,6}$').hasMatch(c)) return null;
    return 'https://svgs.scryfall.io/sets/$c.svg';
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
        backLabel: 'Leave draft',
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
        backLabel: 'Leave draft',
        children: [_Waiting(metrics: m, pool: view.pool, cards: cards)],
      );
    }

    // Picking. Crack a freshly opened pack once, then lay out the grid.
    final pack = view.pack ?? const <DraftCard>[];
    final sig = _signature(view);
    if (view.fresh && _openedPack != sig) {
      // Transparent, not felt: the app's backdrop lives behind every route and
      // a solid colour here would paint over it, which is the black screen the
      // crack used to open on.
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: PackOpening(
            metrics: m,
            count: pack.length,
            packNumber: view.packNumber,
            label: widget.setLabel,
            coverUrl: _coverUrl(pack, cards),
            symbolUrl: _symbolUrl(widget.setLabel),
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
      backLabel: 'Leave draft',
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
        _PoolStrip(
          metrics: m,
          pool: view.pool,
          cards: cards,
          game: widget.game,
          onAccept: (uuid) => ref.read(draftProvider.notifier).pick(uuid),
        ),
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

/// One card in the pack. A tap lifts it to read, with a Pick button under it;
/// a drag drops it on the pool to take it straight away. A glow marks a rare.
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

  Future<void> _open(BuildContext context) async {
    final c = card;
    // A card the catalog never resolved has no face to read, so there is
    // nothing to expand: a tap just takes it.
    if (c == null) {
      onPick();
      return;
    }
    final action = await CardViewer.show(
      context,
      c,
      actionLabel: 'Pick this card',
      actionIcon: Icons.add_rounded,
    );
    if (action == CardAction.pick) onPick();
  }

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final face = ClipRRect(
      borderRadius: BorderRadius.circular(m.scaled(6)),
      child: card == null
          ? CardBack(width: width, game: game)
          : CardArt(metrics: m, card: card!, width: width),
    );

    final pressable = Pressable(
      metrics: m,
      onPress: () => _open(context),
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
        child: face,
      ),
    );

    // Long-press to drag, so a plain tap stays the card's own: it opens the
    // viewer. Holding then dragging drops the card on the pool to pick it.
    return LongPressDraggable<String>(
      data: draft.uuid,
      feedback: Opacity(
        opacity: 0.9,
        child: SizedBox(width: width, child: face),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: pressable),
      child: pressable,
    );
  }
}

/// The pool you have drafted so far, a scrollable strip under the pack. With
/// [onAccept] it is also where a dragged card is dropped to pick it.
class _PoolStrip extends StatelessWidget {
  const _PoolStrip({
    required this.metrics,
    required this.pool,
    required this.cards,
    required this.game,
    this.onAccept,
  });

  final Metrics metrics;
  final List<DraftCard> pool;
  final Map<String, CatalogCard> cards;
  final Game game;
  final void Function(String uuid)? onAccept;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    if (onAccept == null) return _strip(m);
    return DragTarget<String>(
      onAcceptWithDetails: (d) => onAccept!(d.data),
      builder: (context, candidate, _) => AnimatedScale(
        scale: candidate.isEmpty ? 1 : 1.03,
        duration: const Duration(milliseconds: 120),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(m.scaled(10)),
            border: Border.all(
              color: candidate.isEmpty
                  ? Colors.transparent
                  : Palette.accent,
              width: m.focusRing,
            ),
          ),
          child: _strip(m, dropping: candidate.isNotEmpty),
        ),
      ),
    );
  }

  Widget _strip(Metrics m, {bool dropping = false}) {
    final w = m.scaled(52);
    return Well(
      metrics: m,
      label: dropping
          ? 'Drop to pick · ${pool.length}'
          : 'Your pool · ${pool.length}',
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
