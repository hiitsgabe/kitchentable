import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../decks/model/basic_lands.dart';
import '../../decks/model/deck.dart';
import '../../decks/model/deck_format.dart';
import '../../decks/model/game.dart';
import '../../sources/model/catalog_card.dart';
import '../../ui/atoms/card_art.dart';
import '../../ui/atoms/pressable.dart';
import '../../ui/atoms/slab.dart';
import '../../ui/atoms/tray.dart';
import '../../ui/organisms/screen_frame.dart';
import '../../ui/tokens/lettering.dart';
import '../../ui/tokens/metrics.dart';
import '../../ui/tokens/palette.dart';
import '../decks/decks_controller.dart';
import 'draft_controller.dart';
import 'draft_state.dart';

/// The slots a draft deck saves with: the chosen pool cards as the deck, the
/// basics added from outside, and every pool card left behind as the sideboard.
///
/// Copies are aggregated by oracle id, so three of one common become one slot
/// of quantity three. A pool card the catalog could not resolve is dropped,
/// because a slot needs a real card to point at, and a basic is only added if
/// the catalog has it. The leftover pool as the sideboard is what keeps "the
/// cards in your draft but outside the deck" with the deck rather than lost.
List<DeckSlot> draftDeckSlots({
  required List<DraftCard> pool,
  required Set<int> inDeck,
  required Map<String, int> basics,
  required Map<String, CatalogCard> cards,
  required Map<String, CatalogCard> basicCards,
}) {
  final deckCount = <String, int>{};
  final sideCount = <String, int>{};
  final byOracle = <String, CatalogCard>{};
  for (var i = 0; i < pool.length; i++) {
    final card = cards[pool[i].oracleId];
    if (card == null) continue;
    byOracle[card.oracleId] = card;
    final bucket = inDeck.contains(i) ? deckCount : sideCount;
    bucket[card.oracleId] = (bucket[card.oracleId] ?? 0) + 1;
  }

  return [
    for (final e in deckCount.entries)
      DeckSlot(card: byOracle[e.key]!, quantity: e.value),
    for (final e in basics.entries)
      if (basicCards[e.key] != null)
        DeckSlot(card: basicCards[e.key]!, quantity: e.value),
    for (final e in sideCount.entries)
      DeckSlot(card: byOracle[e.key]!, quantity: e.value, sideboard: true),
  ];
}

/// Building a deck from the drafted pool, and nothing from outside it but land.
///
/// Two zones: the deck, and the pool it leaves behind. A pool card taps into
/// the deck and a deck card taps back out; the basics are the one thing that
/// can be added from nowhere, because a draft deck is forty cards and the packs
/// never give you enough land. What is left in the pool is kept as the deck's
/// sideboard, so "the cards in your draft but outside the deck" are saved with
/// it rather than lost.
class DraftBuildScreen extends ConsumerStatefulWidget {
  const DraftBuildScreen({super.key, this.game = Game.magic, this.onBack});

  final Game game;
  final VoidCallback? onBack;

  @override
  ConsumerState<DraftBuildScreen> createState() => _DraftBuildScreenState();
}

class _DraftBuildScreenState extends ConsumerState<DraftBuildScreen> {
  /// Which pool entries, by their index, are in the deck.
  final _inDeck = <int>{};

  /// Basic lands added from outside the pool, by name.
  final _basics = <String, int>{};

  bool _saved = false;

  int get _deckCount => _inDeck.length + _basics.values.fold(0, (a, b) => a + b);

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
    final basics = ref.watch(draftBasicsProvider).value ?? const {};
    final pool = view?.pool ?? const <DraftCard>[];

    final target = DeckFormat.draft.deckSize;
    final enough = _deckCount >= target;

    return ScreenFrame(
      metrics: m,
      title: 'Build your deck',
      label: 'your $target-card deck',
      onBack: widget.onBack,
      children: [
        _Count(metrics: m, count: _deckCount, target: target),
        SizedBox(height: m.scaled(10)),
        if (basics.isNotEmpty)
          _BasicsRow(
            metrics: m,
            basics: basics,
            counts: _basics,
            onAdd: (name) => setState(
              () => _basics[name] = (_basics[name] ?? 0) + 1,
            ),
            onRemove: (name) => setState(() {
              final n = (_basics[name] ?? 0) - 1;
              if (n <= 0) {
                _basics.remove(name);
              } else {
                _basics[name] = n;
              }
            }),
          ),
        SizedBox(height: m.scaled(12)),
        TrayLabel(metrics: m, text: 'In the deck · $_deckCount'),
        SizedBox(height: m.scaled(6)),
        _Zone(
          metrics: m,
          game: widget.game,
          empty: 'tap pool cards to add them',
          entries: [
            for (final i in _inDeck) (pool[i], i),
          ],
          cards: cards,
          onTap: (i) => setState(() => _inDeck.remove(i)),
        ),
        SizedBox(height: m.scaled(16)),
        TrayLabel(metrics: m, text: 'Pool · ${pool.length - _inDeck.length}'),
        SizedBox(height: m.scaled(6)),
        _Zone(
          metrics: m,
          game: widget.game,
          empty: 'the whole pool is in the deck',
          entries: [
            for (var i = 0; i < pool.length; i++)
              if (!_inDeck.contains(i)) (pool[i], i),
          ],
          cards: cards,
          onTap: (i) => setState(() => _inDeck.add(i)),
        ),
        SizedBox(height: m.scaled(18)),
        Slab(
          metrics: m,
          tone: enough ? SlabTone.cool : SlabTone.plain,
          dimmed: !enough || _saved,
          onActivate: enough && !_saved
              ? () => _save(context, pool, cards, basics)
              : () {},
          child: Text(
            _saved
                ? 'SAVED'
                : enough
                ? 'SAVE DECK'
                : 'NEED ${target - _deckCount} MORE',
            style: slabText(m.scaled(16)),
          ),
        ),
      ],
    );
  }

  Future<void> _save(
    BuildContext context,
    List<DraftCard> pool,
    Map<String, CatalogCard> cards,
    Map<String, CatalogCard> basics,
  ) async {
    final repo = ref.read(deckRepositoryProvider);
    if (repo == null) return;

    final slots = draftDeckSlots(
      pool: pool,
      inDeck: _inDeck,
      basics: _basics,
      cards: cards,
      basicCards: basics,
    );

    final id = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    await repo.save(
      Deck(
        id: id,
        name: 'Draft deck',
        format: DeckFormat.draft,
        game: widget.game,
        slots: slots,
      ),
    );
    ref.invalidate(decksProvider);
    if (!context.mounted) return;
    setState(() => _saved = true);
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.metrics, required this.count, required this.target});

  final Metrics metrics;
  final int count;
  final int target;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    final ratio = (count / target).clamp(0.0, 1.0);
    return Well(
      metrics: m,
      label: 'Deck',
      trailing: Text(
        '$count / $target',
        style: pixel(
          size: m.scaled(14),
          color: count >= target ? Palette.slabCool : Palette.inkMuted,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(m.scaled(3)),
        child: LinearProgressIndicator(
          value: ratio,
          minHeight: m.scaled(6),
          backgroundColor: Palette.tile,
          valueColor: AlwaysStoppedAnimation(
            count >= target ? Palette.slabCool : Palette.accent,
          ),
        ),
      ),
    );
  }
}

/// The five basics, each a small stepper: press adds one, long press removes.
class _BasicsRow extends StatelessWidget {
  const _BasicsRow({
    required this.metrics,
    required this.basics,
    required this.counts,
    required this.onAdd,
    required this.onRemove,
  });

  final Metrics metrics;
  final Map<String, CatalogCard> basics;
  final Map<String, int> counts;
  final void Function(String name) onAdd;
  final void Function(String name) onRemove;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    return Well(
      metrics: m,
      label: 'Add basic land',
      child: Wrap(
        spacing: m.scaled(6),
        runSpacing: m.scaled(6),
        children: [
          for (final name in basicLandNames)
            if (basics.containsKey(name))
              Pressable(
                metrics: m,
                onPress: () => onAdd(name),
                onLongPress: () => onRemove(name),
                semanticLabel: 'Add $name',
                radius: m.scaled(6),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: m.scaled(10),
                    vertical: m.scaled(8),
                  ),
                  decoration: BoxDecoration(
                    color: Palette.tile,
                    borderRadius: BorderRadius.circular(m.scaled(6)),
                    border: Border.all(color: Palette.tileEdge),
                  ),
                  child: Text(
                    (counts[name] ?? 0) > 0
                        ? '$name ${counts[name]}'
                        : name,
                    style: pixel(
                      size: m.scaled(12),
                      color: (counts[name] ?? 0) > 0
                          ? Palette.ink
                          : Palette.inkMuted,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// A grid of cards you can tap. The deck zone taps cards out, the pool zone
/// taps them in.
class _Zone extends StatelessWidget {
  const _Zone({
    required this.metrics,
    required this.game,
    required this.empty,
    required this.entries,
    required this.cards,
    required this.onTap,
  });

  final Metrics metrics;
  final Game game;
  final String empty;
  final List<(DraftCard, int)> entries;
  final Map<String, CatalogCard> cards;
  final void Function(int index) onTap;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    if (entries.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: m.scaled(14)),
        child: Text(
          empty,
          textAlign: TextAlign.center,
          style: pixel(size: m.scaled(12), color: Palette.inkFaint),
        ),
      );
    }
    final w = m.scaled(72);
    return Wrap(
      spacing: m.scaled(6),
      runSpacing: m.scaled(6),
      children: [
        for (final (draft, index) in entries)
          Pressable(
            metrics: m,
            onPress: () => onTap(index),
            semanticLabel: cards[draft.oracleId]?.name ?? 'Unknown card',
            radius: m.scaled(6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(m.scaled(5)),
              child: cards[draft.oracleId] == null
                  ? CardBack(width: w, game: game)
                  : CardArt(metrics: m, card: cards[draft.oracleId]!, width: w),
            ),
          ),
      ],
    );
  }
}
