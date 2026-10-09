import 'package:flutter_test/flutter_test.dart';
import 'package:kitchentable/net/mesh.dart';
import 'package:kitchentable/net/talk.dart';
import 'package:kitchentable/table/model/table_state.dart';

import 'fake_transport.dart';

void main() {
  test(
    'a line said on the channel reaches everybody, the sayer included',
    () async {
      final net = FakeNetwork();
      final ana = TalkChannel(net.join('ana'));
      final bo = TalkChannel(net.join('bo'));
      final heard = <String, List<Said>>{'ana': [], 'bo': []};
      ana.chatter.listen(heard['ana']!.add);
      bo.chatter.listen(heard['bo']!.add);
      await net.settle();

      ana.say('  your turn ');
      await net.settle();

      expect(heard['ana'], [(by: 'ana', text: 'your turn')]);
      expect(heard['bo'], [(by: 'ana', text: 'your turn')]);

      bo.say('   ');
      await net.settle();
      expect(heard['ana'], hasLength(1), reason: 'nothing said is nothing');

      await ana.close();
      await bo.close();
    },
  );

  test('a voice signal goes to one peer and never back', () async {
    final net = FakeNetwork();
    final ana = TalkChannel(net.join('ana'));
    final bo = TalkChannel(net.join('bo'));
    final cy = TalkChannel(net.join('cy'));
    final atBo = <VoiceSignal>[];
    final atCy = <VoiceSignal>[];
    final atAna = <VoiceSignal>[];
    bo.voiceSignals.listen(atBo.add);
    cy.voiceSignals.listen(atCy.add);
    ana.voiceSignals.listen(atAna.add);
    await net.settle();

    ana.signalVoice('bo', {'sdp': 'offer'});
    await net.settle();

    expect(atBo, hasLength(1));
    expect(atBo.single.from, 'ana');
    expect(atBo.single.body, {'sdp': 'offer'});
    expect(atCy, isEmpty);
    expect(atAna, isEmpty);

    await ana.close();
    await bo.close();
    await cy.close();
  });

  test('a mesh on the same transport leaves the channel alone', () async {
    final net = FakeNetwork();
    final anaLine = net.join('ana');
    final boLine = net.join('bo');
    final ana = TalkChannel(anaLine);
    final bo = TalkChannel(boLine);
    final hostMesh = Mesh(
      transport: anaLine,
      table: const TableState(seats: []),
      creator: true,
    )..start();
    final guestMesh = Mesh(transport: boLine);
    final refused = <String>[];
    hostMesh.refusals.listen(refused.add);
    guestMesh.refusals.listen(refused.add);
    final meshHeard = <Said>[];
    guestMesh.chatter.listen(meshHeard.add);
    final heard = <Said>[];
    bo.chatter.listen(heard.add);
    guestMesh.start();
    await net.settle();

    ana.say('hello');
    await net.settle();

    expect(heard, [(by: 'ana', text: 'hello')]);
    expect(meshHeard, isEmpty, reason: 'the channel is not the table');
    expect(refused, isEmpty, reason: 'not ours is not wrong');

    await hostMesh.close();
    await guestMesh.close();
    await ana.close();
    await bo.close();
  });
}
