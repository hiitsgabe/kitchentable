# A room you can share, implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A room exists before anybody has a deck. You make one, you share a
link and a QR code for it, people arrive, and then everybody sits down with a
deck.

**Architecture:** Four tasks. Actions and state learn a wire format. A room
becomes a thing with a code and a link. The entry flow is rebuilt around it.
The mesh is written against a transport seam with a fake behind it, so the real
Nostr and WebRTC can land without touching any of the logic.

**Tech Stack:** Flutter 3.47.5, Dart 3.13.4, flutter_riverpod 3.4.3.

The reasoning is in `docs/specs/2026-09-25-a-table-you-can-invite-people-to.md`
and the network's shape was settled in
`docs/specs/2026-09-21-kitchentable-design.md` under "The network". Read both.
This plan does not re-decide either.

---

## The baseline

At `cf32731`, 589 tests, `No issues found!`. Take your own and report it.

---

## Task 1: Actions and state on a wire

**Files:**
- Create: `lib/table/wire/wire.dart`
- Test: `test/table/wire_test.dart`

Nothing in `lib/table/` serializes today. This is the backbone: peers exchange
actions, not screens, and that only works because `apply` is a pure reducer and
every id and roll is minted by the caller.

- [ ] **Step 1: Write the failing test**

A round trip for **every** variant of the sealed `TableAction`, one case each,
asserting the decoded action equals the original. Not a loop over a list you
write by hand: a hand written list only covers the verbs somebody remembered,
and the failure mode here is a verb added later and never put on the wire.
Assert the count against the sealed set as well.

```dart
  test('every verb survives the round trip', () {
    for (final action in _oneOfEach) {
      expect(fromWire(toWire(action)), action, reason: '$action');
    }
  });

  test('every verb is in the list above', () {
    // The list is hand written and a hand written list cannot prove absence.
    // This is what notices a twelfth verb: `apply` switches exhaustively over
    // the sealed set, so a verb it handles and this does not is a verb nobody
    // put on the wire.
    expect(_oneOfEach.map((a) => a.runtimeType).toSet(), hasLength(11));
  });
```

Also: an unknown verb decodes to an error that names it, a wire carrying a
newer version is refused with a message about the version, and `TableState`
round trips with a card in every kind of zone.

- [ ] **Step 2: Run them and watch them fail**

Run: `flutter test test/table/wire_test.dart`
Expected: the file does not compile until `wire.dart` exists, which proves
nothing. Say so, then run again once it compiles and report the real failures.

- [ ] **Step 3: Write the wire**

JSON, a `v` field, a `type` field per verb. Hand written and not code
generated: eleven verbs is less work than a build step, and the error messages
are the point.

Unknown verb and future version are **errors that say what they are**, never
silently ignored: a peer on an older build dropping a verb it has not heard of
desynchronises the table and every screen goes on looking correct.

- [ ] **Step 4: Run everything**

Run: `flutter test && flutter analyze`

- [ ] **Step 5: Probe**

- Drop one verb from the encoder. The round trip case must name it.
- Make an unknown verb decode to a no-op. Its case must fail.
- Change the version check to accept anything. Its case must fail.
- Delete a field from one verb's encoding, one where the field is not the id.
  If the round trip still passes, the equality is not deep enough and the case
  is wrong rather than the code.

- [ ] **Step 6: Commit**

```bash
git add lib/table/wire/wire.dart test/table/wire_test.dart
git commit -m "Put the table's verbs on a wire"
```

---

## Task 2: A room with a code and a link

**Files:**
- Create: `lib/table/room/room.dart`
- Test: `test/table/room_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
  test('a code is typable out loud', () {
    final codes = {for (var i = 0; i < 500; i++) freshRoomCode()};

    // Somebody is going to read this across a kitchen table rather than send
    // it, so the alphabet has nothing in it that can be misheard or misread:
    // no O against 0, no I or l against 1.
    for (final code in codes) {
      expect(code, matches(RegExp(r'^[a-hjkmnp-z2-9]{4}-[a-hjkmnp-z2-9]{3}$')));
    }

    // And 500 of them are 500, which is the cheapest thing that notices a
    // generator seeded once.
    expect(codes, hasLength(500));
  });

  test('a link carries the code and comes back out of it', () {
    final code = freshRoomCode();
    final link = linkFor(code, origin: 'https://example.test/app');

    expect(link, 'https://example.test/app/#room=$code');
    expect(codeFrom(link), code);
    expect(codeFrom('https://example.test/app/#room=${code.toUpperCase()}'),
        code, reason: 'a code read out and typed back in has a case');
    expect(codeFrom('https://example.test/app/'), isNull);
    expect(codeFrom('nonsense'), isNull);
  });
```

Plus the room's own config: format, seats, starting life defaulting from the
format, the host's name and the room's name.

- [ ] **Step 2: Run them and watch them fail**

- [ ] **Step 3: Write the room**

`RoomConfig` is a value: format, seats (2 to 4), life, host name, room name.
Life defaults from the format, 40 for Commander and 20 otherwise, and is
editable after, because that default is a starting point and not a rule.

- [ ] **Step 4: Run everything**

- [ ] **Step 5: Probe**

- Put `o`, `0`, `i`, `1` and `l` back in the alphabet. The first case must fail
  on the pattern.
- Make the generator take a fixed seed. The distinctness case must fail.
- Make `codeFrom` case sensitive. Its case must fail on the upper case line.

- [ ] **Step 6: Commit**

```bash
git add lib/table/room/room.dart test/table/room_test.dart
git commit -m "Give a table a room, a code and a link"
```

---

## Task 3: Start a table, or join one

**Files:**
- Create: `lib/features/room/start_screen.dart`
- Create: `lib/features/room/room_screen.dart`
- Create: `lib/features/room/join_screen.dart`
- Modify: `lib/features/menu/menu_controller.dart`
- Modify: `lib/features/menu/menu_screen.dart`
- Modify: `pubspec.yaml`
- Test: `test/features/room_flow_test.dart`

- [ ] **Step 1: Write the failing test**

The flow, end to end, as cases: the menu offers starting and joining rather
than playing; starting opens the config; confirming it opens a room screen
carrying the code, a link and a QR; the deck is chosen from the room and not
before it; and a link pasted into the join screen lands on the room with that
code.

And one about the honesty line:

```dart
  testWidgets('the room says plainly that nothing is hidden yet',
      (tester) async {
    // Everything replicates in the clear in this slice: a peer holds every
    // hand and every library, and what stops them being drawn is software
    // running on somebody else's phone. That is fine for friends and it is not
    // what a security promise sounds like, so the room says so rather than
    // leaving it to be assumed.
    await tester.pumpWidget(_room());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('room-openness')), findsOneWidget);
  });
```

- [ ] **Step 2: Run them and watch them fail**

- [ ] **Step 3: Build the three screens**

`qr_flutter` for the QR. Add it to `pubspec.yaml` with a comment saying what it
is for, the way `vector_math` is declared.

**On the web, opening the app with `#room=` goes straight to joining.** That is
the whole point of the link; a link that opens the menu is a link that did not
work.

**Nothing about a deck until the room exists.** The deck picker moves from the
menu to the room, which is the whole of this task in one sentence.

- [ ] **Step 4: Run everything**

`PlayDecksScreen` is reachable from the menu today and several cases go through
it. **Report every case that moved before changing it**, and say for each
whether it should point at the new flow or whether it was testing the picker
itself and can stay where it is.

- [ ] **Step 5: Probe**

- Make the join screen ignore the code it was given. Its case must fail.
- Make the room screen build the link from the wrong code. Its case must fail
  on the link and not only on the QR.
- Delete the openness line. Its case must fail.

- [ ] **Step 6: Commit**

```bash
git add lib/features/room test/features/room_flow_test.dart \
        lib/features/menu pubspec.yaml
git commit -m "Make a room before anybody brings a deck"
```

---

## Task 4: The mesh, against a seam

**Files:**
- Create: `lib/table/net/transport.dart`
- Create: `lib/table/net/mesh.dart`
- Create: `test/table/fake_transport.dart`
- Test: `test/table/mesh_test.dart`

- [ ] **Step 1: Write the failing test**

A `Transport` is an interface: send to a peer, a stream of what arrives, a
stream of peers coming and going. The fake is a set of them wired to each
other in memory, and every case in this task runs three of them.

Cases: an action run on one seat lands on the other two; a peer arriving late
is handed the game so far and catches up to the same state; the host stamps
each peer as it joins; when the host goes, the peer with the lowest stamp takes
over and the others agree; and when the original comes back it takes the role
again.

And the one that matters most:

```dart
  test('a peer cannot promote itself by claiming to be senior', () async {
    // The attack the design names. Succession that reads what a peer says
    // about when it joined lets a modified client claim to be first, win every
    // succession, and push whatever state it likes the moment it takes over.
    // The host stamps the number instead.
    ...
  });
```

- [ ] **Step 2: Run them and watch them fail**

- [ ] **Step 3: Write the mesh**

Actions go out through the wire from Task 1. A late peer gets a state snapshot
and then the stream. Succession reads the host's stamp.

**Nothing in here knows what Nostr or WebRTC are.** That is the point of the
seam: the next slice writes a real `Transport` and this file does not change.

- [ ] **Step 4: Run everything**

- [ ] **Step 5: Probe**

- Make succession read a number the peer sends about itself. The attack case
  must fail.
- Drop the snapshot for late joiners. Its case must fail on the state and not
  on an exception.
- Send actions to everybody except the sender's own table. The first case must
  fail, and say whether it failed on the sender or on the receivers.

- [ ] **Step 6: Commit**

```bash
git add lib/table/net test/table/mesh_test.dart test/table/fake_transport.dart
git commit -m "Replicate a table across a mesh"
```

---

## What this plan deliberately leaves out

- **Nostr and WebRTC.** Task 4 leaves a seam exactly the shape of them, and
  they are the next plan. Nothing in this one can prove a connection: a green
  suite here means the logic is right, not that two phones found each other.
- **Hand and library encryption.** Everything replicates in the clear and Task
  3 puts that on the screen in a line. The design's two layer library protocol
  and the encrypted hands are their own slice, and the seam for them is that
  the wire is already the only way state moves.
- **Draft.** A phase that produces a deck and hands off to a table. Not a table.
