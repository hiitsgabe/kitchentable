import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether a card is in the air right now.
///
/// A provider and not a parameter on `DraggableCard`. Threading it would make a
/// hand off site out of every widget between the drag and each zone it could
/// land on, and this codebase has already shipped a dropped hand off of exactly
/// that shape: a `Game?` passed down through six widgets, where `CommandSlot`
/// accepted it and never passed it on, behind a green suite and a clean
/// analyze. `flutter analyze` does not say a word about a field that is taken
/// and not given away again.
///
/// A flag and not the card. Nothing watching this asks what is in the air, only
/// whether anything is: a drop target is worth a card of room while a drag is
/// on and worth nothing the rest of the time, whichever card is over it.
class Dragging extends Notifier<bool> {
  @override
  bool build() => false;

  void started() => state = true;

  /// Every way a drag can end, which `DraggableCard` has to collect from two
  /// callbacks rather than one: a card let go somewhere that took it, and one
  /// let go anywhere else or interrupted. A drag that ends with the zones still
  /// expanded is the failure this would actually have.
  void ended() => state = false;
}

final draggingProvider = NotifierProvider<Dragging, bool>(Dragging.new);
