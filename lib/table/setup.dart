import '../decks/model/deck.dart';
import '../games/magic_pack.dart';
import 'actions/apply.dart';
import 'actions/table_action.dart';
import 'model/card_instance.dart';
import 'model/seat.dart';
import 'model/seat_owner.dart';
import 'model/table_state.dart';

/// How many a Magic player starts with. It belongs to the game rather than to
/// the table, and it lives here until there is a second game to disagree with
/// it.
const openingHandSize = 7;

/// Turns a deck into a table with one seat at it.
///
/// Every copy becomes its own card: thirty seven Mountains are thirty seven
/// things, because each one ends up somewhere different with its own state.
TableState sitDown({
  required Deck deck,
  required String seatName,
  required String seed,
  String seatId = 's1',
}) {
  final zones = magicZonesFor(seatId, deck.format);
  var counter = 0;

  CardInstance mint(String oracleId) =>
      CardInstance(id: '$seatId-${counter++}', oracleId: oracleId);

  final library = <CardInstance>[];
  final command = <CardInstance>[];

  for (final slot in deck.slots) {
    if (slot.sideboard) continue; // a sideboard is not at the table
    for (var i = 0; i < slot.quantity; i++) {
      final card = mint(slot.card.oracleId);
      (slot.commander ? command : library).add(card);
    }
  }

  final seat = Seat(
    id: seatId,
    name: seatName,
    life: deck.format.startingLife,
    zones: [
      for (final zone in zones)
        if (zone.id.startsWith('library'))
          zone.copyWith(cards: library)
        else if (zone.id.startsWith('command'))
          zone.copyWith(cards: command)
        else
          zone,
    ],
  );

  var table = TableState(seats: [seat], turnSeatId: seatId);

  table = apply(
    table,
    ShuffleZone(zoneId: 'library-$seatId', seed: seed),
  );

  return apply(
    table,
    DrawCards(
      fromZoneId: 'library-$seatId',
      toZoneId: 'hand-$seatId',
      count: openingHandSize,
    ),
  );
}

/// One player arriving at a table.
typedef Player = ({Deck deck, String name, SeatOwner owner});

/// Seats everybody and deals. A table of one goes through here too, because
/// solo is not a mode, it is the case where nobody else has joined.
TableState sitDownTogether({
  required List<Player> players,
  required String seed,
}) {
  final seats = <Seat>[];

  for (var i = 0; i < players.length; i++) {
    final player = players[i];
    final seatId = 's${i + 1}';

    // A seed per seat, derived from the table's. One seed for the whole table
    // would give two people with the same decklist the same seven cards.
    final single = sitDown(
      deck: player.deck,
      seatName: player.name,
      seed: '$seed/$seatId',
      seatId: seatId,
    );

    seats.add(single.seats.single.copyWith(owner: player.owner));
  }

  return TableState(seats: seats, turnSeatId: seats.first.id);
}
