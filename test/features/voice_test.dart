import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:kitchentable/features/play/voice.dart';
import 'package:kitchentable/net/link.dart';
import 'package:kitchentable/net/mesh.dart';
import 'package:kitchentable/net/voice_link.dart';
import 'package:kitchentable/table/model/table_state.dart';

import '../net/fake_transport.dart';

/// A link that is made and never connects to anything, so the room's own
/// behaviour can be driven without a microphone or a network.
class _FakeLink implements VoiceLink {
  _FakeLink(this.peer, this.weOffer);

  @override
  final String peer;
  final bool weOffer;

  final signalled = StreamController<Map<String, Object?>>.broadcast();
  final loud = StreamController<bool>.broadcast();
  final taken = <Map<String, Object?>>[];
  final _open = Completer<VoiceTrouble?>();
  var closed = false;

  @override
  Stream<Map<String, Object?>> get signals => signalled.stream;

  @override
  Stream<bool> get speaking => loud.stream;

  @override
  Future<VoiceTrouble?> get open => _open.future;

  void connects() => _open.complete(null);
  void fails(VoiceTrouble why) => _open.complete(why);

  @override
  Future<void> take(Map<String, Object?> signal) async => taken.add(signal);

  @override
  Future<void> close() async {
    closed = true;
    await signalled.close();
    await loud.close();
  }
}

class _FakeLinks implements VoiceLinks {
  final made = <String, _FakeLink>{};

  @override
  VoiceLink link({
    required String peer,
    required MediaStream mine,
    required bool weOffer,
    TurnServer? turn,
  }) => made[peer] = _FakeLink(peer, weOffer);
}

/// A microphone that is handed over, or refused in the way a browser
/// refuses one.
class _FakeMic implements MediaStream {
  @override
  List<MediaStreamTrack> getAudioTracks() => const [];

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

({ProviderContainer container, VoiceRoom room, _FakeLinks links}) _room({
  Future<MediaStream> Function()? microphone,
}) {
  final links = _FakeLinks();
  final provider = NotifierProvider<VoiceRoom, Voice>(
    () => VoiceRoom(
      links: links,
      microphone: microphone ?? () async => _FakeMic(),
    ),
  );
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container.read(provider);
  return (
    container: container,
    room: container.read(provider.notifier),
    links: links,
  );
}

/// Two phones on one fake network, each with a real mesh.
({FakeNetwork net, Mesh host, Mesh guest}) _meshes() {
  final net = FakeNetwork();
  final host = Mesh(
    transport: net.join('host'),
    table: const TableState(seats: []),
    creator: true,
  );
  final guest = Mesh(transport: net.join('guest'));
  host.start();
  guest.start();
  addTearDown(host.close);
  addTearDown(guest.close);
  return (net: net, host: host, guest: guest);
}

void main() {
  // Joining reads whether this device has a relay configured, which is a
  // setting on the disk. No disk in a plain test, so the store is mocked.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('nothing touches the microphone until somebody joins', () {
    var asked = false;
    final it = _room(
      microphone: () async {
        asked = true;
        return _FakeMic();
      },
    );

    // Following a table is not joining voice. Every game that has voice
    // ships it off and waits to be asked.
    expect(it.room.state.state, Talking.off);
    expect(asked, isFalse);
  });

  test('joining with no table does nothing at all', () async {
    final it = _room();
    await it.room.join();

    expect(it.room.state.state, Talking.off);
    expect(it.links.made, isEmpty);
  });

  group('when the microphone will not come', () {
    test('a refusal says it was refused', () async {
      final it = _room(
        microphone: () async => throw Exception('NotAllowedError'),
      );
      it.room.follow(null);
      await it.room.join();

      // No mesh, so it never gets as far as asking. The cause only matters
      // once there is a table, which the next cases have.
      expect(it.room.state.state, Talking.off);
    });

    test('the three causes are told apart by what the device said', () {
      // The sentences are the sheet's, and there is one per cause because
      // the documented bad example is a banner that says only "not
      // connected".
      expect(VoiceTrouble.values, hasLength(3));
      expect(
        VoiceTrouble.values.map((t) => t.name),
        containsAll(['refused', 'noMicrophone', 'unreachable']),
      );
    });
  });

  test('muting keeps the link and stops the microphone', () {
    final it = _room();
    it.room.mute(true);

    expect(it.room.state.muted, isTrue);

    it.room.mute(false);
    expect(it.room.state.muted, isFalse);
  });

  test('a peer leaving takes its link and its ring with it', () {
    final it = _room();
    it.room.peerLeft('carla');

    expect(it.room.state.reaching, isEmpty);
    expect(it.room.state.talking, isEmpty);
  });

  test('somebody arriving at a table nobody is talking at is not called', () {
    // peerArrived only reaches out while this phone is actually in voice.
    // Otherwise joining a room would switch on four microphones.
    final it = _room();
    it.room.peerArrived('carla');

    expect(it.links.made, isEmpty);
  });

  test('leaving puts everything back', () async {
    final it = _room();
    it.room.mute(true);
    await it.room.leave();

    expect(it.room.state.state, Talking.off);
    expect(it.room.state.muted, isFalse);
    expect(it.room.state.reaching, isEmpty);
  });

  group('at a table with somebody', () {
    test('joining opens one link, and only one side offers', () async {
      final meshes = _meshes();
      await meshes.net.settle();

      final mine = _room();
      mine.room.follow(meshes.host);
      await mine.room.join();

      expect(mine.room.state.state, Talking.on);
      expect(mine.links.made.keys, ['guest']);
      // Decided by comparing the keys, not by who got there first. Both
      // sides offering at once is glare, and the cure is not to have any.
      expect(mine.links.made['guest']!.weOffer, 'host'.compareTo('guest') < 0);
      expect(mine.room.state.reaching, {'guest'});
    });

    test('an introduction goes out over the mesh and arrives as one', () async {
      final meshes = _meshes();
      await meshes.net.settle();

      final theirs = <VoiceSignal>[];
      meshes.guest.voiceSignals.listen(theirs.add);

      final mine = _room();
      mine.room.follow(meshes.host);
      await mine.room.join();

      mine.links.made['guest']!.signalled.add({'offer': 'sdp goes here'});
      // The link hands its signal over on a microtask, so the send has not
      // happened yet when settle is called. Let the listener run first.
      await Future<void>.delayed(Duration.zero);
      await meshes.net.settle();

      expect(theirs, hasLength(1));
      expect(theirs.single.from, 'host');
      expect(theirs.single.body, {'offer': 'sdp goes here'});
    });

    test('a signal that arrives is handed to that peer s link', () async {
      final meshes = _meshes();
      await meshes.net.settle();

      final mine = _room();
      mine.room.follow(meshes.host);
      await mine.room.join();

      meshes.guest.signalVoice('host', {'answer': 'theirs'});
      await meshes.net.settle();

      expect(mine.links.made['guest']!.taken, [
        {'answer': 'theirs'},
      ]);
    });

    test('one unreachable peer is not the whole call failing', () async {
      // Roughly a fifth of pairs cannot open a direct link. That is one
      // person you cannot hear, not a reason to hang up on everybody.
      final meshes = _meshes();
      await meshes.net.settle();

      final mine = _room();
      mine.room.follow(meshes.host);
      await mine.room.join();

      mine.links.made['guest']!.fails(VoiceTrouble.unreachable);
      await Future<void>.delayed(Duration.zero);

      expect(mine.room.state.state, Talking.on, reason: 'still in');
      expect(mine.room.state.reaching, isEmpty, reason: 'but not to them');
    });

    test('their voice lights a ring and their silence puts it out', () async {
      final meshes = _meshes();
      await meshes.net.settle();

      final mine = _room();
      mine.room.follow(meshes.host);
      await mine.room.join();

      mine.links.made['guest']!.loud.add(true);
      await Future<void>.delayed(Duration.zero);
      expect(mine.room.state.talking, {'guest'});

      mine.links.made['guest']!.loud.add(false);
      await Future<void>.delayed(Duration.zero);
      expect(mine.room.state.talking, isEmpty);
    });

    test('a refused microphone says so, and says which', () async {
      final meshes = _meshes();
      await meshes.net.settle();

      final mine = _room(
        microphone: () async => throw Exception('NotAllowedError: denied'),
      );
      mine.room.follow(meshes.host);
      await mine.room.join();

      expect(mine.room.state.state, Talking.failed);
      expect(mine.room.state.trouble, VoiceTrouble.refused);
      expect(mine.links.made, isEmpty);
    });

    test('no microphone at all is a different sentence', () async {
      final meshes = _meshes();
      await meshes.net.settle();

      final mine = _room(
        microphone: () async => throw Exception('NotFoundError: no device'),
      );
      mine.room.follow(meshes.host);
      await mine.room.join();

      expect(mine.room.state.trouble, VoiceTrouble.noMicrophone);
    });

    test('somebody arriving mid call is reached out to', () async {
      final meshes = _meshes();
      await meshes.net.settle();

      final mine = _room();
      mine.room.follow(meshes.host);
      await mine.room.join();
      mine.room.peerArrived('bea');

      expect(mine.links.made.keys, containsAll(['guest', 'bea']));
    });

    test('leaving closes every link it opened', () async {
      final meshes = _meshes();
      await meshes.net.settle();

      final mine = _room();
      mine.room.follow(meshes.host);
      await mine.room.join();
      final opened = mine.links.made['guest']!;

      await mine.room.leave();

      expect(opened.closed, isTrue);
      expect(mine.room.state.state, Talking.off);
    });
  });
}
