import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/net/mesh.dart';
import 'package:kitchentable/table/actions/table_action.dart';
import 'package:kitchentable/table/model/seat.dart';
import 'package:kitchentable/table/model/seat_owner.dart';
import 'package:kitchentable/table/model/table_state.dart';

import 'fake_transport.dart';

TableState _table(String p1, String p2) => TableState(
  seats: [
    Seat(id: 's1', name: 'one', life: 40, owner: SeatOwner.peer(p1), zones: const []),
    Seat(id: 's2', name: 'two', life: 40, owner: SeatOwner.peer(p2), zones: const []),
  ],
);

void main() {
  test('two scoped meshes over one transport keep their tables apart', () async {
    final net = FakeNetwork();
    final a1 = net.join('a1');
    final a2 = net.join('a2');
    final b1 = net.join('b1');
    final b2 = net.join('b2');

    final meshA1 = Mesh(
      transport: a1,
      table: _table('a1', 'a2'),
      creator: true,
      scope: 'A',
    )..start();
    final meshA2 = Mesh(transport: a2, scope: 'A')..start();
    final meshB1 = Mesh(
      transport: b1,
      table: _table('b1', 'b2'),
      creator: true,
      scope: 'B',
    )..start();
    final meshB2 = Mesh(transport: b2, scope: 'B')..start();
    await net.settle();

    // Each joiner was handed its own game's table, not the other's.
    expect(meshA2.table?.seat('s1')?.life, 40);
    expect(meshB2.table?.seat('s1')?.life, 40);

    // A move in game A reaches both of A's players and neither of B's.
    meshA1.run(const ChangeLife(seatId: 's1', by: -5));
    await net.settle();

    expect(meshA1.table!.seat('s1')!.life, 35);
    expect(meshA2.table!.seat('s1')!.life, 35, reason: "A's opponent sees it");
    expect(meshB1.table!.seat('s1')!.life, 40, reason: "B's host does not");
    expect(meshB2.table!.seat('s1')!.life, 40, reason: "B's opponent does not");

    for (final m in [meshA1, meshA2, meshB1, meshB2]) {
      await m.close();
    }
  });
}
