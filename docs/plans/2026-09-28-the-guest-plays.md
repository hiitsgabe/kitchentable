# The guest plays, implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A guest who brought a deck reaches the table, sees their own hand
and nobody else's, and a card moved on one phone moves on every phone.

**Architecture:** Three seams, each already located and each wrong in one
way. The wire says whose seat is whose with a word that means something
different on every phone. The play screen draws cards from a catalog the
guest may not have. The play controller runs verbs on a local session and
nothing carries them. Fix each where it is, and nothing in `lib/net/` moves.

**Tech Stack:** Flutter 3.47.5, Dart 3.13.4, flutter_riverpod 3.4.3.

Read first: `docs/plans/2026-09-25-people-who-can-actually-arrive.md`, the
"What running Task 4 found" section, which names these three gaps in the
implementer's own words. This plan is those three gaps and nothing else.

---

## The baseline

At `5d4e93b`: 700 tests with `flutter test -j 1`, `No issues found!`. Take
your own. The machine is short of memory; `-j 1` is the run that counts.

---

## Task 1: A seat's owner is a key, not a word

**Files:**
- Modify: `lib/table/wire/wire.dart` (the owner encoding at about line 212)
- Modify: `lib/table/model/seat_owner.dart`
- Modify: `lib/features/lobby/lobby.dart` (the host's own seat at the deal)
- Test: `test/table/wire_test.dart`, `test/table/seat_owner_test.dart`,
  `test/features/lobby_test.dart`

`SeatOwner` is `here`, `peer:<key>` or `empty`, and the wire carries those
three words literally. `here` is true on exactly one phone and the wire is
read on every phone, so on the guest's phone the host's seat says `here` and
`actableHere` lets the guest act for the host. That is the whole of why the
guest cannot be put in front of the table today.

**Every seat is owned by a key.** The host's seat at the deal is
`SeatOwner.peer(hostKey)` like everybody else's. `here` stops being stored
and becomes a question: `actableHere` compares the seat's key with the
transport's `me`. `SeatOwner.here()` survives only for a table with no
transport, the solo and the pod-on-one-device paths, and is encoded as such;
it never travels, and `stateFromWire` on a phone with a transport refuses it
by name, because a `here` arriving over the wire is exactly the bug.

This is a wire shape change: `wireVersion` bumps to 3.

- [ ] **Step 1: Write the failing test**

A state dealt with three keyed seats, encoded on the host and decoded on a
guest, where `actableHere(me: guestKey)` is true for the guest's seat only.
A `here` on the wire is refused with a `WireError` naming it. The lobby's
deal case (`start deals one seat per person, each owned by that person`)
asserts the host's seat is `peer(hostKey)`, not `here`.

- [ ] **Step 2: Run them and watch them fail**

Say which failed on a value. The lobby case will fail on the host's seat.

- [ ] **Step 3: Make the owner a key**

`actableHere` takes the local key. Grep every caller: `play_controller.dart`
has two, and there may be more; the count is yours to find and report, not
mine to guess.

- [ ] **Step 4: Run everything**

- [ ] **Step 5: Probe**

- Encode a keyed seat as `here` when the key is the encoder's own. The
  guest-side case must fail on `actableHere`, and it must fail on the host's
  seat being actable by the guest, which is the bug reproduced.
- Accept `here` from the wire. Its refusal case must fail.
- Leave the version at 2. The version case must fail.

- [ ] **Step 6: Commit**

```bash
git commit -m "Own a seat by key, so a guest's phone knows whose is whose"
```

---

## Task 2: The table draws the cards it was dealt

**Files:**
- Modify: `lib/features/play/play_screen.dart` (`_printings`, about line 46)
- Modify: `lib/features/lobby/lobby.dart`
- Test: `test/features/play_screen_test.dart`, `test/features/lobby_test.dart`

`PlayScreen` fills `_printings` from `catalogDbProvider`. A guest's deck
arrived over the wire **with every printing field** (Task 4's `deck_wire`),
and then the screen looks the card up in a catalog that never imported it
and draws a blank. The host has the same problem with a guest's card.

**The printings come from the decks at the table**, merged from every deck
the lobby collected, and the catalog is only the fallback for a card that
came from nowhere. The lobby already holds `_decks` keyed by peer; expose
the merge.

- [ ] **Step 1: Write the failing test**

A table dealt from two decks, one of whose cards is in no catalog, drawn on
a play screen with `catalogDbProvider` overridden to null: the card's name is
on screen. Today it is not.

- [ ] **Step 2: Run it and watch it fail**

- [ ] **Step 3: Merge the printings**

- [ ] **Step 4: Run everything**

Several `play_screen_test` cases seed printings through the catalog. Report
every one that moved and whether it was testing the catalog path or just
passing through it.

- [ ] **Step 5: Probe**

- Read printings from the catalog only. The new case must fail on the name.
- Take printings from the host's deck only. A case dealt from two decks must
  fail on the guest's card, and if none does, write it.

- [ ] **Step 6: Commit**

```bash
git commit -m "Draw a card from the deck it came in, not from a catalog"
```

---

## Task 3: A verb travels

**Files:**
- Modify: `lib/features/play/play_controller.dart`
- Modify: `lib/features/lobby/lobby.dart`
- Modify: `lib/features/room/room_screen.dart` (the guest reaches the table)
- Test: `test/features/play_controller_test.dart`,
  `test/features/room_flow_test.dart`, `test/features/lobby_test.dart`

`PlayController.run` reviews a verb, applies it to a `TableSession`, and
stops. The mesh has `run(action)` which applies locally and hands it to
every peer, and `tables` which delivers what peers ran. Nothing connects the
two, on either phone.

**When there is a mesh, the controller runs through it.** `run` hands the
verb to `mesh.run` after the referee, and the controller's state follows
`mesh.tables`. Undo stays local and is refused with a spoken reason while a
mesh is up, because whose undo travels is a decision this plan does not make.
Without a mesh, nothing changes: solo and pod keep the session.

**The guest reaches the table.** On `dealt`, the guest's room screen opens
`PlayScreen` the way the host's does, with the controller seeded from the
mesh's table rather than from `startPod`.

- [ ] **Step 1: Write the failing test**

Two controllers on the fake transport from `test/net/fake_transport.dart`,
one per phone, both under one mesh: a card moved on the host is at the same
normalized spot on the guest, and the guest's hand on the guest's phone is
drawn face up while the host's is face down. A guest's room screen opens the
play screen on `dealt`. Undo with a mesh up is refused in words.

- [ ] **Step 2: Run them and watch them fail**

- [ ] **Step 3: Wire it**

Nothing in `lib/net/` changes. The plan's probe is
`git diff --stat lib/net/` empty.

- [ ] **Step 4: Run everything**

- [ ] **Step 5: Probe**

- Apply locally and never hand to the mesh. The two-phone case must fail on
  the guest's spot, and say whether it failed on the host or the guest.
- Follow `mesh.tables` but never call `mesh.run`. Same case, and it must
  fail the other way round.
- Let undo through with a mesh up. Its case must fail.
- Never open the play screen on `dealt`. The guest case must fail.

- [ ] **Step 6: The check no test can do**

Two phones, two networks, one on mobile data. Host starts, guest opens the
link, both pick a deck, host starts the table. Record what each phone shows
in its three fact lines, whether both reached the table, and whether a card
moved on one moved on the other. If any of it did not happen, that is the
finding and the commit lands with it written down.

- [ ] **Step 7: Commit**

```bash
git commit -m "Carry a verb from one phone to every other"
```

---

## What this plan deliberately leaves out

- **Hands and libraries are still in the clear.** The room screen still says
  so. Sealing a hand is Task 6 of the previous plan and stays there.
- **Undo across a mesh.** Refused with a reason for now.
- **The "fill the other chairs from this device" path** still deals locally
  without handing over to a mesh. Flagged in the previous plan; not here.
- **Host migration on a real link drop.** The mesh handles it against the
  fake; whether WebRTC surfaces a drop in time is a measurement for after
  Task 3's hand check.

---

## What running Tasks 1 and 2 found

**The mesh's own tests were carrying the bug as correct behaviour.** Its
fixture seated the host as `SeatOwner.here()`, so every `welcome` shipped a
`here` seat over the wire and both guests decoded it as their own. Nothing
caught it because in one process "here" is true on both sides. Refusing
`here` on the wire, as Task 1 requires, went red on 14 net cases at once;
the ruling was to key the two fixtures (`peer('host')` in `mesh_test`, the
phone's own minted key in `webrtc_transport_test`) and touch nothing else in
`test/net/`. That is the plan's own rule applied to the fixtures.

**One probe survived and it was a real hole.** `_meOf` returning null left
every case green: nothing pinned that the controller reads the transport's
key, so a host would open its own table as a spectator. Three assertions
were added to the host-start case; the probe then bit on the viewer seat
(`Expected: 's1' Actual: <null>`) and, separately, on `look`.

**A guest did not keep the deck it brought.** `_bringing` was nulled after
sending and the guest held nothing, so `printings` on the guest was empty.
Found by Task 2's merge case on a value; fixed.

**The refusal of `here` is unconditional**, not "on a phone with a
transport": the wire has no transport to ask, and a solo table never encodes
itself.

**Not fixed, and Task 3's brief carries it:** on a guest's phone the merge
holds only the guest's own deck. The host never forwards the other decks and
the table wire carries oracle ids only, so the host's and other guests' cards
still fall back to the guest's catalog. Task 2's cases are host-side only.

**The pristine baseline was not measured.** The agent's first full run had
already been mutated by its own Step 1 edit; the totals after each task
(704, 706) agree with the plan's 700 by arithmetic, which is what it said.

**The relay reconnect case flakes under load, and I misread its cause
once.** Task 1's liveness case ("a relay that closes the socket...") failed
once in the full run and passed alone; on this memory-short machine it passes
about one run in three alone. I first wrote that it waited 5 s against a 2 s
reconnect default; the test's helper already sets `reconnectAfter` to 20 ms,
so that was not it. The real cause is not yet measured and the case is left
as it is until it is.

## What running Task 3 found

**The stream alone is not enough for the local phone.** The plan said "the
controller's state follows `mesh.tables`". `Mesh.run` applies locally before
the broadcast delivers, on a later microtask, and the play screen runs two
verbs back to back reading the table between them; with the stream alone the
second read is stale. So `run` also sets `state = mesh.table` synchronously.
Probe 2 (follow the stream, never call `mesh.run`) is what shows it: the
case fails on the **host**, `Actual: 'hand-s1'` at :154. Probe 1 (apply
locally, never hand over) fails on the **guest**, `Actual: 'hand-s1'` at
:158. Both directions, as the plan asked, and I re-ran probe 1 myself.

**Undo without the guard is a silent no-op, not a wrong table.** With the
session dropped there is no history, so the life assertion cannot catch it;
only the refusal-in-words assertion bites (`Expected: not null / Actual:
<null>` at :211). That is why the case asserts the refusal and the word.

**The guest reaches the table through a one-turn listener**, `dealtProvider`
(false to true), not by watching the lobby, which notifies on every chair
and every verb. The flagged gap: `ref.listen` reports changes, not the
initial value, so a guest whose room screen was not mounted at the turn
would arrive at a room with `dealt` already true and no push. Every path to
the picker today goes through the room screen, so it is believed
unreachable and not proven.

**One existing case moved, and it is the one that was the point:** the
guest's room_flow case used to assert the guest stops on the room screen
with the "dealt" note; it now asserts the play screen is up, the seats are
`[peer(kit), peer(me)]`, the viewer is s2, the hand has 7 cards, and a
`MoveCard` run on the host's mesh lands at (0.25, 0.75) on the guest with
the printing's name drawn. It failed twice on the agent's own assertions
before passing: the route lands a frame after a single pump, and the 800 by
1600 test window takes the canvas renderer, where there are no bands.

**Known and left:** on a guest, `deckSizeAt` and `gameAt` are known only for
its own seat; other piles draw the plain fallback. Undo with a mesh is
refused for the host too. The "fill the other chairs" path still deals with
no mesh.

**Hand check pending.** Two phones, two networks. The commit says so.

## What the first two-phone check found

The owner opened the room on a computer and the link on a phone; they did
not see each other. What the host's screen said: "Relay: accepted", "STUN:
answered", "chair 2: empty". Read against the code, that is decisive: the
STUN line is emitted only inside a link, and a link is made only on a word
from a peer under the code, so **the host heard the phone and started
negotiating, and the link never opened**. The screen said nothing about
either fact, which is the first finding.

**A seen peer and a plain failure were invisible.** The room listed a peer
only once its channel was open, and a failure only when it was the TURN
kind. A link heard and never opened, or failed for any other reason, drew
nothing. `Reach` now carries `seen` (from `peerHere` and from any link
step) and `failed` (every failure, by peer), and the room draws "Somebody
found this room and is connecting" and "Could not connect to X: <reason>".
Probed: dropping the `peerHere` branch, and recording only TURN failures,
each fail the new case on its own line.

**One silent relay held the whole handshake.** Reproduced with a socket that
accepts and never answers beside a good relay: `established` waited on
every relay and never completed, so nothing was ever announced.
`relay.nostr.band` behaved that way from the machine this was written on;
whether it did from the phone is not known. Two fixes, and they pin
different things: a per-relay cap on `established` is what lets the
handshake finish, and a `connectTimeout` on the socket is what lets
`publish` finish, since publishing waits on every relay's first attempt
with no cap of its own. A silent relay is retried after four of its own
timeouts. On the VM each timed-out attempt leaks its socket, because
closing a channel that never became ready does not tear the connect
down; the backoff bounds the rate and the browser path has no such leak.

**And the fixture lied first.** The probe "remove the connect timeout"
survived, because the test's silent server accepted sockets and dropped
them: the collector finalised them and the OS reset the connection, so the
server was silent only until the next garbage collection. That is why the
first repro hung twelve seconds and a later run on the same code settled in
under one. Traced by instrumenting `_run`, which printed `Connection reset
by peer` where a hang was expected. The fixture now holds every accepted
socket, and with that the probe bites on `publish` timing out.

**`Relay.close()` hung on a subscription nobody had read.** A single
subscription controller's `close()` completes only once a listener drains
it, and `_unsubscribe` awaited it. Every earlier case listened, so it never
showed. Guarded on `hasListener`, and pinned.

**The real rendezvous works from here.** Two peers on `relay.damus.io` and
`nos.lol`, one code, no fake anywhere: found each other in under a second,
the lower key offered. So the introduction is right; what failed on the
phone is after it, in the link, and the next check will say where.

**A link that never opens now fails by a deadline.** ICE that checks
forever reported nothing until the browser gave up, half a minute or
never, and that was the host's state on the first check: "connecting" with
no end. `WebRtcTransport.openWithin` (twenty seconds) fails the link with
the reason "did not open within N seconds of the link being made", not the
TURN verdict, and closes it, so the screen has a fact and the peer's next
announcement makes a fresh link. The fake grew a `stalled` set for links
that negotiate and then never open; the probe that removes the deadline
fails the case on `failures` staying empty for five seconds.

**Still unknown until the next check:** what the phone's own lines said.
