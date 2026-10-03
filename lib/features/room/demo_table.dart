import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../decks/model/deck.dart';
import '../../decks/model/deck_format.dart';
import '../../sources/model/catalog_card.dart';
import '../../table/actions/table_action.dart';
import '../../table/model/seat_owner.dart';
import '../play/chat.dart';
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
  const DemoTable({
    super.key,
    required this.seats,
    this.view,
    this.fresh = false,
    this.chat = false,
  });

  final int seats;

  /// Stops at the opening hand, with nothing on any battlefield.
  ///
  /// The four cards this normally puts out are there so a layout can be
  /// looked at, and they are also exactly what tells the table that the
  /// opening is over: with them there, nothing a game starts with can be
  /// seen at all.
  final bool fresh;

  /// Puts a few lines in the chat. It only appears when there is somebody
  /// to talk to, and a demo table is several seats on one device with
  /// nobody at the other end of anything.
  final bool chat;

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
      ref
          .read(rendererChoiceProvider.notifier)
          .choose(
            TableRenderer.values.where((r) => r.name == view).firstOrNull,
          );
    }
    final names = ['', 'Carla', 'Diego', 'Bea', 'Ana', 'Rui'];
    ref
        .read(playProvider.notifier)
        .startPod(
          players: [
            for (var i = 0; i < widget.seats.clamp(1, 6); i++)
              (
                deck: _deck(i),
                name: names[i],
                // The first chair is this device's and the rest belong to
                // keys, which is what a real table looks like. They were all
                // `here`, a pod passed round one tablet, and that is a
                // different thing: it left everybody nameless to the chat,
                // because a name is found by the key holding the chair.
                owner: i == 0
                    ? const SeatOwner.here()
                    : SeatOwner.peer('demo-$i'),
              ),
          ],
          seed: 'demo',
        );
    if (widget.chat) _talk();
    if (widget.fresh) return;

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

  /// A conversation to look at, in the voice of the table.
  void _talk() {
    final table = ref.read(playProvider);
    final desk = ref.read(chatProvider.notifier);
    const talk = [
      ('s2', 'anybody got removal for that?'),
      ('s1', 'not a thing. it resolves'),
      ('s2', 'ok go on then'),
      ('s1', 'attacking with everything'),
      ('s2', 'blocking the big one, taking the rest'),
    ];
    for (final (seat, line) in talk) {
      desk.heard(
        by: table?.seat(seat)?.owner.peerId ?? seat,
        text: line,
        table: table,
        me: table?.seat('s1')?.owner.peerId ?? 's1',
      );
    }
  }

  @override
  Widget build(BuildContext context) =>
      ref.watch(playProvider) == null ? const SizedBox() : const PlayScreen();
}

CatalogCard _card(String name, {String type = 'Creature', int cmc = 2}) =>
    CatalogCard(
      oracleId: name,
      name: name,
      typeLine: type,
      cmc: cmc.toDouble(),
    );

Deck _deck(int seat) => Deck(
  id: 'demo-$seat',
  name: 'demo deck $seat',
  format: DeckFormat.commander,
  slots: [
    DeckSlot(card: _card('Mountain', type: 'Basic Land'), quantity: 30),
    DeckSlot(card: _card('Goblin Guide'), quantity: 10),
    DeckSlot(
      card: _card('Lightning Bolt', type: 'Instant', cmc: 1),
      quantity: 10,
    ),
    DeckSlot(card: _card('Hobgoblin Bandit Lord'), quantity: 10),
    DeckSlot(
      card: _card('Goblin Trashmaster', cmc: 4),
      quantity: 1,
      commander: true,
    ),
  ],
);
