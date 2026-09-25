import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../decks/model/deck.dart';
import '../../decks/model/game.dart';
import '../../table/model/seat_owner.dart';
import '../../table/setup.dart';
import '../../table/shuffle.dart';
import '../../ui/atoms/hint_bar.dart';
import '../../ui/atoms/menu_row.dart';
import '../../ui/atoms/toast.dart';
import '../../ui/organisms/screen_frame.dart';
import '../../ui/tokens/metrics.dart';
import '../play/play_controller.dart';
import '../play/play_screen.dart';
import '../room/room_controller.dart';
import 'decks_controller.dart';

/// Pick a deck and the game starts.
///
/// The same decks as the Decks screen, going somewhere else. That is the
/// difference worth having: one road is for building a deck and the other is
/// for sitting down with one, and a menu entry called Play that opened a deck
/// editor would be a lie.
///
/// A tap on a row still deals that deck on its own, which is the whole of what
/// this screen was asked for first. The seat toggle sits above the list and
/// changes what a tap means rather than what a row is: with it on, a tap
/// collects the deck instead of dealing it, and Deal opens one table with a
/// chair for each deck collected.
///
/// Reached from inside a room rather than from the menu. The room is the place
/// and this is where you say what you brought to it, which is why it reads the
/// room for what the table plays to.
class PlayDecksScreen extends ConsumerStatefulWidget {
  const PlayDecksScreen({super.key});

  @override
  ConsumerState<PlayDecksScreen> createState() => _PlayDecksScreenState();
}

class _PlayDecksScreenState extends ConsumerState<PlayDecksScreen> {
  /// Whether a tap on a deck collects it rather than dealing it.
  bool _collecting = false;

  /// The decks collected so far, in the order they were tapped, which is the
  /// order the seats end up in. A list and not a set: two people at a kitchen
  /// table can turn up with the same deck.
  final List<Deck> _picked = [];

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final m = Metrics.of(classifyDevice(
      size: media.size,
      hasTouch: media.navigationMode == NavigationMode.traditional,
    ));
    final decks = ref.watch(decksProvider);

    return ScreenFrame(
      metrics: m,
      title: 'Play',
      label: switch (decks) {
        AsyncData(:final value) when value.isEmpty => 'no decks to play with',
        AsyncData() when _collecting => 'pick the decks and deal them together',
        AsyncData() => 'pick one and it deals',
        AsyncError() => 'could not read your decks',
        _ => 'reading',
      },
      onBack: () => Navigator.of(context).maybePop(),
      hints: const [
        Hint(button: HintBar.dpad, label: 'move'),
        Hint(button: 'A', label: 'deal'),
        Hint(button: 'B', label: 'back'),
      ],
      children: [
        ...switch (decks) {
          AsyncData(:final value) => [
              if (value.isNotEmpty) ...[
                MenuRow(
                  key: const Key('add-seat'),
                  title: _collecting
                      ? 'One deck at a time'
                      : 'More than one seat',
                  subtitle: _collecting
                      ? 'back to a tap dealing the deck it is on'
                      : 'collect several decks and deal them as one table',
                  icon: _collecting
                      ? Icons.person_rounded
                      : Icons.group_add_rounded,
                  metrics: m,
                  onActivate: _toggleSeats,
                ),
                if (_collecting)
                  MenuRow(
                    key: const Key('deal'),
                    title: 'Deal',
                    // Dimmed rather than missing, like every other dead row,
                    // and the subtitle says who is at the table so far.
                    subtitle: _picked.isEmpty
                        ? 'nobody at the table yet'
                        : _picked.map((d) => d.name).join(', '),
                    icon: Icons.play_arrow_rounded,
                    enabled: _picked.isNotEmpty,
                    metrics: m,
                    onActivate: () => _dealPod(_picked),
                  ),
              ],
              for (final (i, deck) in value.indexed)
                MenuRow(
                  key: Key('deck-row-$i'),
                  title: deck.name,
                  subtitle: _describe(deck),
                  icon: _iconFor(deck.game),
                  // A deck with no cards deals nothing, so it is here and
                  // dimmed rather than missing, like every other dead row.
                  enabled: deck.cardCount > 0,
                  metrics: m,
                  autofocus: i == 0,
                  onActivate: () => _collecting ? _pick(deck) : _deal(deck),
                ),
            ],
          _ => const <Widget>[],
        },
      ],
    );
  }

  static String _describe(Deck deck) => deck.cardCount == 0
      ? '${deck.format.label} · empty, nothing to deal'
      : '${deck.format.label} · ${deck.cardCount} cards';

  static IconData _iconFor(Game game) => switch (game) {
        Game.magic => Icons.auto_awesome_rounded,
        Game.pokemon => Icons.catching_pokemon_rounded,
      };

  void _toggleSeats() => setState(() {
        _collecting = !_collecting;
        _picked.clear();
      });

  void _pick(Deck deck) => setState(() => _picked.add(deck));

  /// Loads the deck's cards. The list is deliberately read without them, so
  /// dealing straight from a row would sit down at an empty table.
  ///
  /// Null means it cannot be dealt, and every way that happens has already
  /// been said out loud by the time this returns. The first version returned
  /// quietly on a null repository or a deck that would not load, which is
  /// exactly the nothing somebody reported: tap a deck, watch the screen not
  /// change, and have no idea whether the app refused or missed the tap. Both
  /// ways of dealing come through here so neither can lose that.
  Future<Deck?> _hydrate(Deck deck) async {
    final repo = ref.read(deckRepositoryProvider);
    if (repo == null) {
      Toast.show(
        context,
        'No catalog on this build, so there is nothing to deal',
        icon: Icons.block_rounded,
      );
      return null;
    }

    final Deck? full;
    try {
      full = await repo.load(deck.id);
    } catch (e) {
      if (mounted) {
        Toast.show(context, 'Could not read that deck: $e',
            icon: Icons.block_rounded);
      }
      return null;
    }

    if (!mounted) return null;

    if (full == null) {
      Toast.show(context, 'That deck is no longer there',
          icon: Icons.block_rounded);
      return null;
    }
    if (full.slots.isEmpty) {
      Toast.show(context, 'That deck has no cards in it yet',
          icon: Icons.block_rounded);
      return null;
    }
    return full;
  }

  /// What the room plays to, or null where there is no room saying.
  ///
  /// Null is not only the no room case: a guest has a code and not the host's
  /// settings, because those travel over a mesh that does not exist yet. A guest
  /// therefore starts on the format's own number until it does, which is wrong
  /// and is at least wrong in the same direction as knowing nothing.
  int? get _roomLife => ref.read(roomProvider)?.config?.life;

  /// One deck, one seat, straight from the row that was tapped.
  Future<void> _deal(Deck deck) async {
    final full = await _hydrate(deck);
    if (full == null || !mounted) return;

    ref.read(playProvider.notifier).start(
          full,
          seed: freshSeed(),
          life: _roomLife,
        );
    await _open();
  }

  /// Several decks, one table, every chair held by this device.
  Future<void> _dealPod(List<Deck> decks) async {
    final full = <Player>[];
    for (var i = 0; i < decks.length; i++) {
      final deck = await _hydrate(decks[i]);
      if (deck == null || !mounted) return;
      full.add((
        deck: deck,
        name: i == 0 ? 'you' : 'seat ${i + 1}',
        owner: const SeatOwner.here(),
      ));
    }

    ref.read(playProvider.notifier).startPod(
          players: full,
          seed: freshSeed(),
          life: _roomLife,
        );
    await _open();
  }

  /// Opens the table, or says why there is none. Both ways of dealing end
  /// here, because a table that would not come up is the same silence either
  /// way.
  Future<void> _open() async {
    if (ref.read(playProvider) == null) {
      Toast.show(context, 'The table would not come up',
          icon: Icons.block_rounded);
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PlayScreen()),
    );
  }
}
