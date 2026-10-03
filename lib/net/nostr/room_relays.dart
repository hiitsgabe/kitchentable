import 'dart:math';

/// Where a room lives on the open relay network, and under what kind.
///
/// Both are derived from the room's own code rather than fixed, and both
/// answers are the same on every phone that knows the code, which is what
/// lets people meet without anybody being told where to look.
///
/// This is the lesson of [Trystero](https://github.com/dmotz/trystero),
/// which has been doing exactly this for five years: pick a few relays out
/// of a wide pool, deterministically, and put each room on a kind of its
/// own. See docs/benchmarks/2026-10-03-who-already-built-this.md.

/// The relays a room may be held on.
///
/// Three things about this list. It is wide, so that rooms spread out. It
/// is quiet: the busiest relays on the network are not in it, and the
/// reason is that this app has already been rate limited and banned by
/// relay.damus.io, which is not a thing that gets better by sending less.
/// And every one of them was measured accepting an ephemeral event from
/// this client, which is not true of every relay that is up: one answered
/// "blocked: kind 24242 is not accepted by this relay", and relays that
/// refuse an entire kind are a room nobody can join.
const relayPool = [
  'wss://schnorr.me',
  'wss://nostrue.com',
  'wss://relay.44billion.net',
  'wss://nostr.red5d.dev',
  'wss://relay.agentry.com',
  'wss://relay.mwaters.net',
  'wss://relay.froth.zone',
  'wss://nostr.purpura.cloud',
  'wss://nostr.mom',
  'wss://relay.ngengine.org',
  'wss://bitcoiner.social',
  'wss://nostr.robosats.org',
  'wss://nostr.superfriends.online',
  'wss://nostr.stakey.net',
  'wss://nostr.chaima.info',
  'wss://relay.nostrfeed.com',
  'wss://nostr.mad-social.net',
  'wss://relay.bitmacro.cloud',
];

/// How many of the pool a room is held on at once.
///
/// Five, because one relay is a single point of failure and eighteen is
/// eighteen copies of every move. Enough that losing two is survivable, few
/// enough that no relay carries the whole app.
const relayRedundancy = 5;

/// The relays this room is on.
///
/// Shuffled by the code, so every phone holding the code picks the same
/// five, and two different rooms almost certainly do not.
List<Uri> relaysFor(
  String code, {
  int redundancy = relayRedundancy,
  List<String> pool = relayPool,
}) {
  final shuffled = [...pool]..shuffle(Random(stableHash(code)));
  return [
    for (final url in shuffled.take(redundancy.clamp(1, pool.length)))
      Uri.parse(url),
  ];
}

/// Nostr's ephemeral range, which relays forward and do not keep.
const _firstEphemeral = 20000;
const _ephemeralKinds = 10000;

/// The kind a room's handshake rides on, and the kind its game rides on,
/// which is the one after it.
///
/// Derived rather than fixed. The app used to send everything on 25050,
/// which is also the kind the NIP-RTC draft reserves for WebRTC signalling,
/// so it read strangers' traffic off the wire and filtered it out by tag,
/// and every room in the world queued on one kind. A kind per room costs
/// nothing and fixes both.
int handshakeKindFor(String code) =>
    _firstEphemeral + stableHash(code) % (_ephemeralKinds - 1);

int roomDataKindFor(String code) => handshakeKindFor(code) + 1;

/// A hash that is the same number on every device and every build.
///
/// FNV-1a, because `String.hashCode` in Dart is seeded per isolate and is
/// explicitly not stable across runs: using it here would put two phones
/// holding the same code on two different kinds and two different relays,
/// and they would never see each other.
int stableHash(String s) {
  var h = 0x811c9dc5;
  for (final unit in s.codeUnits) {
    h = ((h ^ unit) * 0x01000193) & 0x7fffffff;
  }
  // Masked on the way out as well as inside the loop. Without it an empty
  // string comes back as the unmasked seed, which is the one input whose
  // answer does not fit where every other answer does.
  return h & 0x7fffffff;
}
