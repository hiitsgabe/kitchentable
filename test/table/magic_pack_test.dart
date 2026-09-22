import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/decks/model/deck_format.dart';
import 'package:kitchentable/games/magic_pack.dart';
import 'package:kitchentable/table/model/zone.dart';

void main() {
  test('a duel seat has five zones and no command zone', () {
    final zones = magicZonesFor('s1', DeckFormat.standard);

    expect(zones.map((z) => z.id), [
      'library-s1',
      'hand-s1',
      'battlefield-s1',
      'graveyard-s1',
      'exile-s1',
    ]);
  });

  test('a Commander seat gets the command zone as well', () {
    final zones = magicZonesFor('s1', DeckFormat.commander);

    expect(zones.map((z) => z.id), contains('command-s1'));
    expect(zones.length, 6);
  });

  test('zone ids carry the seat, because two seats have a library each', () {
    final mine = magicZonesFor('s1', DeckFormat.commander);
    final theirs = magicZonesFor('s2', DeckFormat.commander);

    expect(mine.map((z) => z.id).toSet().intersection(
          theirs.map((z) => z.id).toSet(),
        ),
        isEmpty);
  });

  test('a library is hidden from everybody, a hand from everybody else', () {
    final zones = magicZonesFor('s1', DeckFormat.commander);

    Zone find(String prefix) =>
        zones.firstWhere((z) => z.id.startsWith(prefix));

    expect(find('library').visibility, ZoneVisibility.hidden);
    expect(find('hand').visibility, ZoneVisibility.owner);
    expect(find('battlefield').visibility, ZoneVisibility.public);
    expect(find('graveyard').visibility, ZoneVisibility.public);
    expect(find('command').visibility, ZoneVisibility.public);
  });

  test('order matters in a library and a graveyard, not on a battlefield', () {
    final zones = magicZonesFor('s1', DeckFormat.commander);

    Zone find(String prefix) =>
        zones.firstWhere((z) => z.id.startsWith(prefix));

    expect(find('library').ordered, isTrue);
    expect(find('graveyard').ordered, isTrue);
    expect(find('battlefield').ordered, isFalse);
    expect(find('hand').ordered, isFalse);
  });
}
