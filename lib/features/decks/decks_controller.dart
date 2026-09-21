import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../decks/deck_repository.dart';
import '../../decks/model/copy_limit.dart';
import '../../decks/model/deck.dart';
import '../menu/menu_controller.dart';

final deckRepositoryProvider = Provider<DeckRepository?>((ref) {
  final db = ref.watch(catalogDbProvider);
  return db == null ? null : DeckRepository(db);
});

final decksProvider = FutureProvider<List<Deck>>((ref) async {
  final repo = ref.watch(deckRepositoryProvider);
  return repo == null ? const [] : repo.list();
});

/// The deck currently open for editing. One at a time, so this is a plain
/// notifier rather than a family: a family would let two decks be edited at
/// once, which no screen in this app offers.
///
/// Every change is written straight through. A deck is small, and losing one to
/// a back button is the sort of thing that makes people stop using an app.
class DeckEditor extends Notifier<Deck?> {
  @override
  Deck? build() => null;

  Future<void> open(String id) async {
    final repo = ref.read(deckRepositoryProvider);
    state = await repo?.load(id);
  }

  void close() => state = null;

  Future<void> _persist(Deck next) async {
    state = next;
    await ref.read(deckRepositoryProvider)?.save(next);
    ref.invalidate(decksProvider);
  }

  int _indexOf(List<DeckSlot> slots, DeckSlot like) => slots.indexWhere((s) =>
      s.card.oracleId == like.card.oracleId &&
      s.sideboard == like.sideboard &&
      s.commander == like.commander);

  Future<void> add(DeckSlot slot) async {
    final deck = state;
    if (deck == null) return;

    final slots = [...deck.slots];
    final at = _indexOf(slots, slot);
    if (at >= 0) {
      slots[at] = slots[at].withQuantity(slots[at].quantity + slot.quantity);
    } else {
      slots.add(slot);
    }

    await _persist(deck.copyWith(slots: slots));
  }

  /// Writes once at the end rather than once per card. A pasted Commander list
  /// is a hundred slots, and saving a hundred times would rewrite the whole
  /// deck a hundred times.
  Future<void> addAll(Iterable<DeckSlot> incoming) async {
    final deck = state;
    if (deck == null) return;

    final slots = [...deck.slots];
    for (final slot in incoming) {
      final at = _indexOf(slots, slot);
      if (at >= 0) {
        slots[at] = slots[at].withQuantity(slots[at].quantity + slot.quantity);
      } else {
        slots.add(slot);
      }
    }

    await _persist(deck.copyWith(slots: slots));
  }

  /// The most copies of this card the deck may hold, counting both piles.
  /// Basic lands and the cards that grant themselves the exemption come back
  /// effectively unbounded.
  int limitFor(DeckSlot slot) {
    final deck = state;
    if (deck == null) return 0;
    return copyLimitFor(slot.card, deck.format);
  }

  bool canAddMore(DeckSlot slot) {
    final deck = state;
    if (deck == null) return false;
    return deck.totalCopiesOf(slot.card.oracleId) < limitFor(slot);
  }

  Future<void> setQuantity(DeckSlot slot, int quantity) async {
    final deck = state;
    if (deck == null) return;

    final slots = [...deck.slots];
    final at = _indexOf(slots, slot);
    if (at < 0) return;

    // The plus button used to add without asking. In Commander that put two
    // of a singleton card in the deck, which the rules had already forbidden
    // everywhere except here.
    if (quantity > slots[at].quantity) {
      final elsewhere =
          deck.totalCopiesOf(slot.card.oracleId) - slots[at].quantity;
      if (elsewhere + quantity > copyLimitFor(slot.card, deck.format)) return;
    }

    if (quantity <= 0) {
      slots.removeAt(at);
    } else {
      slots[at] = slots[at].withQuantity(quantity);
    }

    await _persist(deck.copyWith(slots: slots));
  }

  Future<void> makeCommander(DeckSlot slot) async {
    final deck = state;
    if (deck == null) return;

    final slots = [
      for (final s in deck.slots)
        if (s.commander)
          DeckSlot(card: s.card, quantity: s.quantity)
        else if (s.card.oracleId == slot.card.oracleId && !s.sideboard)
          DeckSlot(card: s.card, quantity: 1, commander: true)
        else
          s,
    ];

    await _persist(deck.copyWith(slots: slots));
  }

  Future<void> rename(String name) async {
    final deck = state;
    if (deck != null) await _persist(deck.copyWith(name: name));
  }
}

final deckEditorProvider =
    NotifierProvider<DeckEditor, Deck?>(DeckEditor.new);
