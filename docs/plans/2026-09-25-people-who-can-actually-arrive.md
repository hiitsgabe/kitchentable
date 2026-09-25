# People who can actually arrive, implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The phone that starts a table is the server. A friend anywhere on
the internet opens the link or types the code, and their phone connects to the
host's phone directly. No server of ours, ever.

**Architecture:** Two halves behind the `Transport` seam that Task 4 of the
last plan left. **Rendezvous** is Nostr: the host's phone publishes where it
can be reached under the room code on public relays, a guest asks the same
relays, and the relays see a handshake and never a table. **Connection** is
WebRTC data channels, which expose each phone's own address to the internet
via STUN and carry the game peer to peer. Between them a **lobby** collects
each guest's deck so the host can deal everybody in.

**Tech Stack:** Flutter 3.47.5, Dart 3.13.4. New: `flutter_webrtc` 1.6.x,
`bip340` 0.3.x, and `web_socket_channel` 3.0.x promoted from transitive.
The design names `ndk` and `dart_nostr` as candidates; neither is used.
`dart_nostr` does not list web, and `ndk` is thirty dependencies and a Rust
component for one ephemeral event kind. NIP-01 is a WebSocket carrying JSON
and the only hard part is the Schnorr signature, which `bip340` does.

The why is in `docs/specs/2026-09-21-kitchentable-design.md` under "The
network". Read it. Two decisions there are locked and are what this plan
implements: the link names a meeting place rather than an address, and the
app ships with no relay for media configured and takes a TURN server the
player supplies.

**What this plan cannot prove.** No `flutter test` opens a WebRTC connection.
Tasks 1, 2 and 4 are real and tested against an in-process relay and fake
links. Task 3's connection code is tested through a seam and checked by hand
on two phones on two networks, and the plan says so at that step instead of
letting a green suite imply it.

---

## The baseline

At `4e03b33`, 649 tests, `No issues found!`. Take your own.

---

## Task 0: No turns, and the network where the spec put it

**Files:**
- Modify: `lib/table/model/table_state.dart`, `lib/table/actions/table_action.dart`,
  `lib/table/actions/apply.dart`, `lib/table/wire/wire.dart`
- Move: `lib/table/net/mesh.dart`, `lib/table/net/transport.dart` to `lib/net/`;
  `test/table/mesh_test.dart`, `test/table/fake_transport.dart` to `test/net/`
- Test: `test/table/wire_test.dart`, `test/table/table_state_test.dart`,
  `test/table/mesh_test.dart`, `test/table/referee_test.dart`

**There are no turns.** The spec's eleven verbs are `move, rotate, flip,
counter, attach, shuffle, draw, token, life, die, undo`. The code has a
`PassTurn` verb and a `turnSeatId` on the table instead, and nothing on any
screen reads either. A table that "tracks whose turn it is and enforces
nothing about it" is a field that exists to be wrong on the wire. Both go.
This is a wire shape change, so `wireVersion` bumps.

**Real time is already what the mesh does**, and it stays that way: `run`
applies a verb locally and hands it to every peer in the same call. Nothing
in this plan may add a queue, a batch, a tick, or a gate on whose go it is.
A case in Task 3 asserts that a verb sent from one phone is applied on the
other before any other message is exchanged.

**The network lives in `lib/net/`**, per the design's "Code structure", not
`lib/table/net/` where the mesh landed. Move it, with `git mv`, and fix the
imports. The lobby is a feature, `lib/features/lobby/`, because it is the
thing the room screen talks to.

- [ ] **Step 1: Write the failing test**

The wire's derived verb sweep expects ten. `stateToWire` carries no
`turnSeatId` and refuses one that arrives. The wire refuses the previous
version by number.

- [ ] **Step 2: Run them and watch them fail**

- [ ] **Step 3: Remove the turn, move the net**

The encoder is an exhaustive switch, so deleting the verb fails to compile
until every arm is gone: that is the compiler doing the sweep.

- [ ] **Step 4: Run everything**

Five test files name `PassTurn`. `wire_test.dart` uses it as the sample verb
for the version refusal case: pick another, and say which.

- [ ] **Step 5: Probe**

- Put `turnSeatId` back on the wire. The state case must fail on the key.
- Leave the version unbumped. The refusal case must fail.

- [ ] **Step 6: Commit**

```bash
git commit -m "Take the turn off a table that never had one"
```

---

## Task 1: A Nostr client small enough to read

**Files:**
- Create: `lib/net/nostr/relay.dart`
- Create: `lib/net/nostr/keys.dart`
- Create: `test/net/nostr/fake_relay.dart`
- Test: `test/net/nostr/relay_test.dart`
- Modify: `pubspec.yaml` (`bip340`, `web_socket_channel` direct)

Not `ndk` (thirty dependencies and a Rust component for one event kind) and
not `dart_nostr` (no web). NIP-01 is a WebSocket carrying JSON arrays:
`["EVENT", event]`, `["REQ", id, filter]`, `["CLOSE", id]`, and
`["EVENT", id, event]` coming back. An event is signed with BIP-340 Schnorr,
which `bip340` does in pure Dart on every platform.

- [ ] **Step 1: Write the failing test**

A fake relay: `HttpServer` on a free port, `WebSocketTransformer`, and the
three verbs above implemented honestly, fanning an `EVENT` out to every open
`REQ` whose filter matches on `kinds` and on `#d`. It lives under `test/` and
is used by every later task.

Cases: keys are minted, the public key derives from the private one and never
the other way; an event is signed and the fake relay's own verification
accepts it and rejects a tampered one; a subscription by kind and `d` tag
receives what is published under it and nothing published under another code;
two relays given the same event deliver it once each, and a client subscribed
to both dedupes by event id; a relay that closes the socket is reported by the
client's status stream and reconnected to.

- [ ] **Step 2: Run them and watch them fail**

- [ ] **Step 3: Write the client**

`Keys` mints and holds a hex private key and exposes the public key, which is
the peer's identity everywhere above. `Relay` connects to a list of URLs,
publishes to all, subscribes on all, dedupes by event id. Kind is
**ephemeral**, in the 20000 to 29999 range, so relays do not store the
handshake. Tag `["d", code]`.

- [ ] **Step 4: Run everything**

- [ ] **Step 5: Probe**

- Make the client accept an event whose signature does not verify. Its case
  must fail on the tampered event, and say which assertion.
- Stop deduping. The two-relay case must fail on a count.
- Drop the `#d` filter from the fake relay. The wrong-room case must fail,
  which proves the fake is honest about filtering and the client is not
  filtering client side.
- Make the kind non-ephemeral (under 20000). Write the case that catches it if
  none does: it is a one-line check on a constant and it is the cheapest
  privacy property in the plan.

- [ ] **Step 6: Commit**

```bash
git add lib/net/nostr test/net/nostr pubspec.yaml pubspec.lock
git commit -m "Speak enough Nostr to find each other"
```

---

## Task 2: Signaling under a room code

**Files:**
- Create: `lib/net/signaling.dart`
- Test: `test/net/signaling_test.dart`

The three messages WebRTC needs to set up a link, carried over Task 1 under
the room code: `offer`, `answer`, `ice`. Each addressed to one peer's public
key, each from one, each inside a signed event so the relay cannot forge one.

**Glare.** Two peers that discover each other at the same instant both offer,
and WebRTC does not resolve that. So the initiator is decided by arithmetic
nobody can influence: the peer with the **lower public key offers**. A peer
that receives an offer while holding its own drops its own.

**Discovery.** A peer announces itself under the code with a `here` message
and re-announces on a timer while in the room. Not a roster, and not the
host's: on the relay every peer is equal and the host only becomes the host
once the data channels are up and the mesh from the last plan stamps it.

- [ ] **Step 1: Write the failing test**

Against the fake relay: two peers under one code find each other and exactly
one offers; the lower key is the one; a peer joining late sees the two already
there; a `here` under another code is never seen; an `offer` addressed to
somebody else is never surfaced; a message whose event signature does not
verify is dropped and reported, not thrown.

- [ ] **Step 2: Run them and watch them fail**

- [ ] **Step 3: Write it**

- [ ] **Step 4: Run everything**

- [ ] **Step 5: Probe**

- Make both peers offer. The glare case must fail, and it must fail on the
  count of offers, not by exception.
- Make the higher key offer. The initiator case must fail.
- Surface offers addressed to anybody. Its case must fail.

- [ ] **Step 6: Commit**

```bash
git add lib/net/signaling.dart test/net/signaling_test.dart
git commit -m "Introduce two phones under a room code"
```

---

## Task 3: The link itself, behind a seam of its own

**Files:**
- Create: `lib/net/link.dart` (the seam: `PeerLink`, `LinkFactory`)
- Create: `lib/net/webrtc_link.dart` (the real one, `flutter_webrtc`)
- Create: `lib/net/webrtc_transport.dart` (`implements Transport`)
- Create: `test/net/fake_link.dart`
- Test: `test/net/webrtc_transport_test.dart`
- Modify: `pubspec.yaml` (`flutter_webrtc`)

`PeerLink` is one data channel to one peer: a stream of strings in, `send`
out, an `open` future, a `closed` future. `LinkFactory` makes one from a
signaling session. The real factory wraps `RTCPeerConnection` and a channel
named `table`; the fake pairs two links in memory.

`WebRtcTransport implements Transport`: `me` is the Nostr public key, `peers`
is the set of open links, `incoming` and `presence` are the links' streams
merged, `send` hands a string to one link. It is the mesh's `Transport` and
the mesh does not change.

**ICE servers.** A short list of public STUN servers by default. TURN is
whatever the player put in settings and nothing otherwise, per the design.
When a link fails to open after ICE completes with no candidate pair, the
transport reports it as a `LinkFailure` with the reason in words: this is the
one in ten connections the design says will need TURN, and the screen has to
be able to say so.

- [ ] **Step 1: Write the failing test**

With the fake relay from Task 1 and the fake factory: three transports under
one code end up with two peers each; a string sent lands at exactly the one
peer it was sent to and nowhere else; a link that closes is a `left` on
presence and gone from `peers`; a factory that fails to open a link produces a
`LinkFailure` and not an exception; and the transport, plugged into the
**existing** `Mesh` from the last plan with no change to `mesh.dart`, passes
that plan's replication case end to end.

- [ ] **Step 2: Run them and watch them fail**

- [ ] **Step 3: Write it**

`flutter_webrtc` is a native plugin and adding it regenerates tracked platform
registrant files. Surface every file `git status` shows, say which are the
registrants, and commit them with the task: do not silently commit them and
do not drop them.

- [ ] **Step 4: Run everything**

- [ ] **Step 5: Probe**

- Send to every link instead of one. The addressing case must fail on the
  wrong receiver, and name it.
- Leave a closed link in `peers`. Its case must fail.
- Swallow a link failure. Its case must fail on the reported reason.
- Change a line in `mesh.dart`. The point of the seam is that you did not
  have to: report `git diff --stat lib/net/mesh.dart` as empty.

- [ ] **Step 6: The check no test can do**

Two phones, two networks, one on mobile data. Host starts a table, guest opens
the link. Record: whether the data channel opened, how long it took, whether
STUN was enough or it failed the TURN way, and the two ICE candidate types
that paired. Put the numbers in the commit message. If it did not connect,
that is the finding and the commit still lands, with the failure written
down: a slice that connects on one network and not on another is exactly the
thing the design warned about, and hiding it would cost the next person a
week.

- [ ] **Step 7: Commit**

```bash
git add lib/net pubspec.yaml pubspec.lock test/net
git commit -m "Carry a table between two phones"
```

---

## Task 4: The lobby, and the chairs filling with people

**Files:**
- Create: `lib/features/lobby/lobby.dart`
- Create: `lib/table/wire/deck_wire.dart`
- Modify: `lib/features/room/room_screen.dart`
- Modify: `lib/features/room/room_controller.dart`
- Test: `test/features/lobby_test.dart`, `test/features/room_flow_test.dart`

Before a table exists there are only people and their decks. The lobby runs
on the transport first: each guest sends the host its deck, the host sees the
chairs fill, and when the host starts, it deals everybody with `startPod`,
builds the `Mesh` on the same transport, and every guest receives the table
as the late joiner they are. The lobby then stops listening: it **hands the
transport to the mesh** and never speaks again.

**A deck travels with its cards.** `Deck` has no wire today. It gets one that
carries each slot's printing (name, type line, cost, image urls) and not only
its oracle id, so a host never needs a card it never imported.

**The screen.** The chairs count down as people arrive, by name from settings.
The `room-reach` line, which says nobody can arrive yet, comes down in this
task and not before. The row that fills the other chairs from this device
stays, because it is still true that you can, and it is hidden once a real
person has taken a chair.

- [ ] **Step 1: Write the failing test**

Lobby, on the fake transport from the last plan: a guest's deck reaches the
host; the host cannot start with an empty chair and can with all full; start
deals a table with one seat per person, each owned by that person's peer id;
after start the lobby has stopped and the mesh has the transport; a guest who
arrives after start is handed the table by the mesh and not by the lobby.

Screen: the chair count moves when a peer arrives; the reach line is gone;
the fill row hides once a real person is seated.

- [ ] **Step 2: Run them and watch them fail**

- [ ] **Step 3: Write it**

- [ ] **Step 4: Run everything**

- [ ] **Step 5: Probe**

- Let the host start with an empty chair. Its case must fail.
- Deal every seat as `SeatOwner.here()`. The ownership case must fail, and
  that is the case that keeps a guest's hand a guest's.
- Leave the lobby listening after start. The handover case must fail on a
  double delivery, and it must be a wrong count, not an exception.
- Drop the printings from the deck wire. The host-without-catalog case must
  fail.

- [ ] **Step 6: Commit**

```bash
git add lib/features/lobby lib/table/wire/deck_wire.dart \
        lib/features/room test/features
git commit -m "Let the chairs fill with people"
```

---

## Task 5: Settings for the relays and a TURN server

**Files:**
- Create: `lib/features/settings/network.dart`
- Modify: `lib/features/settings/settings_screen.dart`
- Test: `test/features/settings_network_test.dart`

A relay list with a sane default and a TURN entry that is empty by default,
persisted the way `player_name.dart` is. When a link fails the TURN way, the
room screen says so in words and points here.

- [ ] Steps 1 to 6 as above: failing test, red, write, green, probe (the
  default relay list is not empty; an empty TURN entry configures no TURN;
  the failure message names this screen), commit
  `"Let a player bring their own relay"`.

---

## Task 6: A hand nobody else can read

**Files:**
- Create: `lib/net/sealed.dart`
- Modify: `lib/table/wire/wire.dart`, `lib/net/mesh.dart`
- Test: `test/net/sealed_test.dart`, `test/net/mesh_test.dart`

The spec, "Who can see what": a hand is encrypted to its owner and everybody
else holds a blob they cannot read, which is mathematics rather than trust,
and it calls this cheap. It is in this plan and not a later one because the
room screen currently says "everybody in this room can see everything in it",
and the day that line can come down is the day this task lands.

The key is the peer's own Nostr key, which every peer already has. The seam
is the wire: a card in a hand zone serialises as a blob sealed to the seat's
owner, and `stateFromWire` on any other peer yields a card it cannot name.
Playing a card publishes it in the clear; the proof it was that blob is a
hash the blob carried.

- [ ] Steps 1 to 6: failing test (a guest's snapshot carries the host's hand
  as blobs; the host reads its own; a played card is clear everywhere and
  its hash matches its blob), red, write, green, probe (seal with the wrong
  key: the owner case must fail; skip the hash: the played-card case must
  fail), commit `"Seal a hand to the one who holds it"`.

**The library stays in the clear in this plan.** The two-neighbour protocol
is the spec's hard problem and it has its own seam; the openness line on the
room screen shrinks to say libraries, not hands.

---

## Task 7: A shuffle anybody can check

**Files:**
- Modify: `lib/table/actions/table_action.dart` (`ShuffleZone` carries a
  commitment), `lib/net/mesh.dart`
- Test: `test/table/shuffle_test.dart`, `test/net/mesh_test.dart`

The spec, "Shuffling": seeded and deterministic, with the seat committing to
a hash of the seed before the shuffle and revealing it after. `commitToSeed`
already exists in `lib/table/shuffle.dart` and nothing sends it. Two verbs
on the wire where there was one: the commitment travels first, the seed
travels after, and every peer checks the hash before applying the shuffle.

- [ ] Steps 1 to 6: failing test (a shuffle whose revealed seed does not
  hash to the commitment is refused and reported, not applied), red, write,
  green, probe (skip the check: the refusal case must fail on the table
  having shuffled), commit `"Commit to a shuffle before it happens"`.

---

## What this plan deliberately leaves out

- **Library encryption.** Hands are sealed in Task 6; libraries still
  replicate in the clear and the room screen says so. The design's
  two-neighbour library protocol is its own slice, behind the seam the spec
  asks for.
- **Host migration across a real link drop.** The mesh already handles it
  against the fake; whether WebRTC surfaces a drop fast enough to matter is a
  measurement for after Task 3's hand check.
- **Native app links.** On a phone the way in is the code or the QR; the
  link is for the web build. A `kitchentable://` scheme is a later slice.
