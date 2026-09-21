import 'package:flutter/foundation.dart';

import 'card_instance.dart';

/// Who may look at what is in a pile.
///
/// Three states and not two, because a library is not merely private: its owner
/// cannot read it either, and a table that let them would be a table nobody
/// would trust in plan 3.
enum ZoneVisibility {
  /// Everybody sees it. A battlefield, a graveyard.
  public,

  /// Only the owner. A hand.
  owner,

  /// Nobody, including the owner. A library, a face down pile.
  hidden;

  bool seenBy(String seatId, {required String owner}) => switch (this) {
        ZoneVisibility.public => true,
        ZoneVisibility.owner => seatId == owner,
        ZoneVisibility.hidden => false,
      };
}

/// A pile of cards belonging to a seat.
@immutable
class Zone {
  const Zone({
    required this.id,
    required this.seatId,
    required this.label,
    required this.visibility,
    required this.ordered,
    this.cards = const [],
  });

  final String id;
  final String seatId;

  /// What the game calls it. The table has no opinion: `Library` and `Deck` are
  /// the same thing wearing different words.
  final String label;

  final ZoneVisibility visibility;

  /// True where the order is part of the game, as in a library or a graveyard.
  /// False for a battlefield, where the order is only how it got laid out.
  final bool ordered;

  final List<CardInstance> cards;

  /// The front of an ordered pile. Null for an unordered one, which has no top
  /// to speak of.
  CardInstance? get top =>
      ordered && cards.isNotEmpty ? cards.first : null;

  bool get isEmpty => cards.isEmpty;

  int get size => cards.length;

  /// Takes up to [n]. Fewer if there are fewer, because drawing from an empty
  /// library is a rule about losing the game and not a reason to crash.
  (List<CardInstance>, Zone) takeFromTop(int n) {
    final count = n.clamp(0, cards.length);
    final taken = cards.take(count).toList();
    return (taken, copyWith(cards: cards.skip(count).toList()));
  }

  Zone add(CardInstance card, {int? at}) {
    final next = [...cards];
    next.insert(at ?? 0, card);
    return copyWith(cards: next);
  }

  Zone remove(String cardId) =>
      copyWith(cards: cards.where((c) => c.id != cardId).toList());

  CardInstance? find(String cardId) =>
      cards.where((c) => c.id == cardId).firstOrNull;

  Zone replace(CardInstance card) => copyWith(
        cards: [
          for (final c in cards) c.id == card.id ? card : c,
        ],
      );

  Zone copyWith({List<CardInstance>? cards}) => Zone(
        id: id,
        seatId: seatId,
        label: label,
        visibility: visibility,
        ordered: ordered,
        cards: cards ?? this.cards,
      );
}
