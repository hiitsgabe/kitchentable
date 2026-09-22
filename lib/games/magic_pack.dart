import '../decks/model/deck_format.dart';
import '../table/model/zone.dart';

/// Which piles a Magic player has in front of them.
///
/// A declaration, not code. The table does not import this and would work the
/// same with Pokemon's seven zones instead, which is the whole point of the
/// eleven verbs.
List<Zone> magicZonesFor(String seatId, DeckFormat format) => [
      _zone(seatId, 'library', 'Library', ZoneVisibility.hidden, true),
      _zone(seatId, 'hand', 'Hand', ZoneVisibility.owner, false),
      _zone(seatId, 'battlefield', 'Battlefield', ZoneVisibility.public, false),
      _zone(seatId, 'graveyard', 'Graveyard', ZoneVisibility.public, true),
      _zone(seatId, 'exile', 'Exile', ZoneVisibility.public, false),
      if (format.needsCommander)
        _zone(seatId, 'command', 'Command', ZoneVisibility.public, false),
    ];

Zone _zone(
  String seatId,
  String kind,
  String label,
  ZoneVisibility visibility,
  bool ordered,
) =>
    Zone(
      id: '$kind-$seatId',
      seatId: seatId,
      label: label,
      visibility: visibility,
      ordered: ordered,
    );
