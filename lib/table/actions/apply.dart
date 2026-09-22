import '../model/card_instance.dart';
import '../model/table_state.dart';
import '../shuffle.dart';
import 'table_action.dart';

/// One state in, one state out. No rules, no validation, no opinion about
/// whether any of it is legal: that is what the referee is for, and the only
/// referee so far permits everything.
///
/// An action naming something that is not there is a no op rather than an
/// error. At a real table you do not get an exception for reaching for a card
/// that somebody already moved, you just find it gone.
TableState apply(TableState table, TableAction action) => switch (action) {
      MoveCard() => _move(table, action),
      RotateCard() => _onCard(
          table,
          action.cardId,
          (c) => action.to == null ? c.turned() : c.turnedTo(action.to!),
        ),
      FlipCard() => _onCard(table, action.cardId, (c) => c.flipped()),
      ChangeCounter() => _onCard(
          table,
          action.cardId,
          (c) => c.withCounter(action.kind, action.by),
        ),
      AttachCard() => _onCard(
          table,
          action.cardId,
          (c) => action.toCardId == null
              ? c.copyWith(clearAttachment: true)
              : c.copyWith(attachedTo: action.toCardId),
        ),
      ShuffleZone() => _shuffle(table, action),
      DrawCards() => _draw(table, action),
      CreateToken() => _token(table, action),
      ChangeLife() => table.withLife(action.seatId, action.by),
      RollDice() => table.copyWith(dice: action.results),
      PassTurn() => table.passTurn(),
    };

TableState _onCard(
  TableState table,
  String cardId,
  CardInstance Function(CardInstance) change,
) {
  final found = table.locate(cardId);
  if (found == null) return table;
  return table.withZone(found.zone.replace(change(found.card)));
}

TableState _move(TableState table, MoveCard action) {
  final found = table.locate(action.cardId);
  final destination = table.zone(action.toZoneId);
  if (found == null || destination == null) return table;

  var card = found.card;
  if (action.faceDown != null) {
    card = card.copyWith(faceDown: action.faceDown);
  }
  card = action.position == null
      ? card.copyWith(clearPosition: true)
      : card.copyWith(position: action.position);

  // Taken out first, in case it is going back into the pile it came from.
  final emptied = found.zone.remove(action.cardId);
  final withSource = table.withZone(emptied);

  final target = withSource.zone(action.toZoneId)!;
  return withSource.withZone(target.add(card, at: action.at));
}

TableState _draw(TableState table, DrawCards action) {
  final from = table.zone(action.fromZoneId);
  final to = table.zone(action.toZoneId);
  if (from == null || to == null) return table;

  final (taken, rest) = from.takeFromTop(action.count);
  if (taken.isEmpty) return table;

  var next = table.withZone(rest);
  var destination = next.zone(action.toZoneId)!;

  // Backwards, so the first card off the top ends up on top of the hand too.
  for (final card in taken.reversed) {
    destination = destination.add(card.copyWith(clearPosition: true));
  }

  return next.withZone(destination);
}

TableState _shuffle(TableState table, ShuffleZone action) {
  final zone = table.zone(action.zoneId);
  if (zone == null) return table;
  return table.withZone(
    zone.copyWith(cards: shuffleWithSeed(zone.cards, action.seed)),
  );
}

TableState _token(TableState table, CreateToken action) {
  final zone = table.zone(action.zoneId);
  if (zone == null) return table;
  return table.withZone(
    zone.add(CardInstance(id: action.cardId, oracleId: action.oracleId)),
  );
}
