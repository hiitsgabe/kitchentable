import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../decks/model/deck.dart';
import '../../decks/model/deck_format.dart';
import '../../sources/model/catalog_card.dart';
import '../../table/actions/table_action.dart';
import '../../table/model/seat_owner.dart';
import '../play/play_controller.dart';
import '../play/play_screen.dart';
import '../play/renderers/renderer_choice.dart';

/// A table of [seats] players dealt on this device from sample decks, opened
/// straight onto the play screen.
///
/// For looking at the table: a `#demo=N` link on the web build lands here so
/// the three views can be checked on a desktop and a phone without a room, a
/// catalog or a second person. The cards are named and have no printing, so
/// they draw as named backs; the layout is what this is for.
class DemoTable extends ConsumerStatefulWidget {
  const DemoTable({super.key, required this.seats, this.view});

  final int seats;

  /// grid, focus or split, read with the seats before the address bar is
  /// cleared; null is the default.
  final String? view;

  @override
  ConsumerState<DemoTable> createState() => _DemoTableState();
}

class _DemoTableState extends ConsumerState<DemoTable> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _deal());
  }

  void _deal() {
    final view = widget.view;
    if (view != null) {
      ref.read(rendererChoiceProvider.notifier).choose(
        TableRenderer.values.where((r) => r.name == view).firstOrNull,
      );
    }
    final names = ['', 'Carla', 'Diego', 'Bea', 'Ana', 'Rui'];
    ref.read(playProvider.notifier).startPod(
          players: [
            for (var i = 0; i < widget.seats.clamp(1, 6); i++)
              (
                deck: _deck(i),
                name: names[i],
                owner: const SeatOwner.here(),
              ),
          ],
          seed: 'demo',
        );
    // A few cards out on every battlefield, so the boards are not empty.
    final play = ref.read(playProvider.notifier);
    final table = ref.read(playProvider);
    if (table == null) return;
    for (final seat in table.seats) {
      final hand = table.zone('hand-${seat.id}');
      if (hand == null) continue;
      for (final card in hand.cards.take(4)) {
        play.run(MoveCard(cardId: card.id, toZoneId: 'battlefield-${seat.id}'));
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      ref.watch(playProvider) == null ? const SizedBox() : const PlayScreen();
}

CatalogCard _card(String name, {String type = 'Creature', int cmc = 2}) =>
    CatalogCard(oracleId: name, name: name, typeLine: type, cmc: cmc.toDouble());

Deck _deck(int seat) => Deck(
      id: 'demo-$seat',
      name: 'demo deck $seat',
      format: DeckFormat.commander,
      slots: [
        DeckSlot(card: _card('Mountain', type: 'Basic Land'), quantity: 30),
        DeckSlot(card: _card('Goblin Guide'), quantity: 10),
        DeckSlot(card: _card('Lightning Bolt', type: 'Instant', cmc: 1), quantity: 10),
        DeckSlot(card: _card('Hobgoblin Bandit Lord'), quantity: 10),
        DeckSlot(card: _card('Goblin Trashmaster', cmc: 4), quantity: 1, commander: true),
      ],
    );
