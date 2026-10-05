import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/decks/model/deck.dart';
import 'package:kitchentable/decks/model/deck_format.dart';
import 'package:kitchentable/features/draft/draft_room.dart';
import 'package:kitchentable/features/draft/draft_state.dart';
import 'package:kitchentable/features/lobby/lobby.dart';
import 'package:kitchentable/table/room/room.dart';
import 'package:kitchentable/table/setup.dart';

import '../../net/fake_transport.dart';

RoomConfig _draftRoom({int seats = 2}) => RoomConfig(
  format: DeckFormat.draft,
  seats: seats,
  hostName: 'Gabe',
  roomName: 'the shed',
  draft: const DraftOptions(setCode: 'mh3', packs: 1),
);

List<List<List<DraftCard>>> _packs(List<String> seats) => [
  for (var s = 0; s < seats.length; s++)
    [
      [
        DraftCard(uuid: '${seats[s]}-1', oracleId: 'o1', rarity: 'common'),
        DraftCard(uuid: '${seats[s]}-2', oracleId: 'o2', rarity: 'common'),
      ],
    ],
];

void main() {
  test('a draft seats without a deck and opens when the chairs fill', () async {
    final net = FakeNetwork();
    final hostT = net.join('host');
    final guestT = net.join('ana');

    final host = Lobby.host(transport: hostT, config: _draftRoom());
    final guest = Lobby.guest(transport: guestT);
    await net.settle();

    // The host took its chair on its own; the guest learned it is a draft.
    expect(host.seated.length, 1, reason: 'the host seats itself');
    expect(guest.isDraft, isTrue, reason: 'the guest learned the format');
    expect(host.canStartDraft, isFalse, reason: 'a chair is still empty');

    // The guest takes a chair with a name and no deck.
    guest.attend(name: 'Ana');
    await net.settle();

    expect(host.seated.length, 2);
    expect(host.canStartDraft, isTrue, reason: 'every chair is taken');

    // The host opens the draft; the guest is pulled into it.
    final hostRoom = host.startDraft(
      (seatIds) => DraftRoom.fromPacks(
        transport: hostT,
        seatIds: seatIds,
        sealed: false,
        packsPerSeat: _packs(seatIds),
      ),
    );
    await net.settle();

    expect(guest.drafting, isTrue, reason: 'the guest heard the draft open');
    expect(guest.draft, isNotNull);

    // Each seat has been dealt its own pack of two.
    expect(hostRoom.view?.pack?.length, 2, reason: 'the host sees its pack');
    expect(guest.draft!.view?.pack?.length, 2, reason: 'the guest sees its own');

    host.dispose();
    guest.dispose();
  });

  test('a sealed draft builds decks, and the host deals the table', () async {
    final net = FakeNetwork();
    final hostT = net.join('host');
    final guestT = net.join('ana');

    final host = Lobby.host(
      transport: hostT,
      config: RoomConfig(
        format: DeckFormat.draft,
        seats: 2,
        hostName: 'Gabe',
        roomName: 'sealed',
        draft: const DraftOptions(setCode: 'mh3', sealed: true, packs: 1),
      ),
    );
    final guest = Lobby.guest(transport: guestT);
    await net.settle();
    guest.attend(name: 'Ana');
    await net.settle();

    host.startDraft(
      (seatIds) => DraftRoom.fromPacks(
        transport: hostT,
        seatIds: seatIds,
        sealed: true,
        packsPerSeat: _packs(seatIds),
      ),
    );
    await net.settle();

    // Sealed opens straight into building; each seat turns its pool into a
    // deck and hands it in.
    Deck deck(String id) =>
        Deck(id: id, name: id, format: DeckFormat.draft, slots: const []);
    host.draft!.submit(deck('host-deck'));
    guest.draft!.submit(deck('ana-deck'));
    await net.settle();

    expect(host.draftReadyToDeal, isTrue, reason: 'both decks are in');

    host.dealDraft(
      (players) => sitDownTogether(players: players, seed: 'seed'),
    );
    await net.settle();

    expect(host.dealt, isTrue, reason: 'the host is at the table');
    expect(host.drafting, isFalse, reason: 'the draft is over');
    expect(guest.dealt, isTrue, reason: 'the guest followed to the table');
    expect(guest.drafting, isFalse);

    host.dispose();
    guest.dispose();
  });
}
