# A room that reads right, implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The room asks for what a room is, the settings hold what you are, and
the controls are the shape of what they set.

**Architecture:** Four small changes, reported from the built app. Nothing in
`lib/table/` moves.

**Tech Stack:** Flutter 3.47.5, Dart 3.13.4, flutter_riverpod 3.4.3.

Baseline at `e9dbc16`: 635 tests, `No issues found!`. Take your own.

---

## Task 1: Your name is yours, not the room's

**Files:**
- Modify: `lib/features/room/start_screen.dart`
- Modify: `lib/features/settings/settings_screen.dart`
- Create or modify: wherever a setting already persists
- Test: `test/features/room_flow_test.dart`, `test/features/settings_*`

A name is a property of the person, not of the room. It is the same in every
room you ever join, so asking for it again each time is asking you to repeat
yourself, and it makes two places where it can disagree.

- [ ] **Step 1: Write the failing test**

That the start screen has no name field, that settings has one, that it
persists, and that a room built after setting it carries that name as the
host's.

- [ ] **Step 2: Run them and watch them fail**

- [ ] **Step 3: Move it**

`RoomConfig.hostName` stays: the room still carries who made it. What changes
is where the value comes from. Default stays `you` when nothing is set.

- [ ] **Step 4: Run everything**

- [ ] **Step 5: Probe**

- Make the start screen fill `hostName` from a literal again. The room case
  must fail on the name.
- Make the setting not persist. Its case must fail.

- [ ] **Step 6: Commit**

```bash
git commit -m "Keep your name with you, not with the room"
```

---

## Task 2: Controls the shape of what they set

**Files:**
- Modify: `lib/features/room/start_screen.dart`
- Test: `test/features/room_flow_test.dart`

Format is a choice from a closed list, so it is a select and not a row you tap
to cycle. Chairs is a number with two ends, so it is a stepper with a plus and
a minus, and both ends say when they have stopped.

- [ ] **Step 1: Write the failing test**

That the format control offers every `DeckFormat` and picking one sets it; that
the stepper moves between the ends of `roomSeatChoices` and that pressing past
either end does nothing rather than wrapping.

**Wrapping is the failure to watch for.** A row you tap to cycle wraps by
nature and a stepper must not: somebody pressing minus at two chairs and
landing on four has been lied to.

- [ ] **Step 2: Run them and watch them fail**

- [ ] **Step 3: Build them**

Read `roomSeatChoices` rather than retyping 2 and 4.

- [ ] **Step 4: Run everything**

- [ ] **Step 5: Probe**

- Make the stepper wrap. Its case must fail on the end that wrapped, and say
  which.
- Drop a format from the select. Its case must fail naming the missing one,
  which means the case is derived from `DeckFormat.values` and not a list you
  typed.

- [ ] **Step 6: Commit**

```bash
git commit -m "Make the room's controls the shape of what they set"
```

---

## Task 3: The deck picker inside a room picks your deck

**Files:**
- Modify: `lib/features/decks/play_decks_screen.dart`
- Modify: `lib/features/room/room_screen.dart`
- Test: `test/features/room_flow_test.dart`, `test/features/play_entry_test.dart`

`More than one seat` collects several decks and deals them as one table. In a
room that is nonsense twice over: the room already said how many chairs, and
seats are meant to fill with people.

**Do not simply delete it.** It is the only way today to see a table with more
than one seat at all, because no transport exists yet, and deleting it makes
the pod renderers unreachable.

- [ ] **Step 1: Write the failing test**

That the picker opened from a room offers no way to collect a second deck, and
that the room screen offers filling the other chairs from this device, named as
what it is.

- [ ] **Step 2: Run them and watch them fail**

- [ ] **Step 3: Move it**

The picker, inside a room, picks one deck. The collecting mode moves to the
room screen as its own row, worded as what it actually does: the other chairs
filled from this phone, which is the only way to fill them until people can
arrive. It says that rather than implying it.

Offer it only when the room has more than one chair, because a row that fills
the other chairs on a table with no other chairs is a control that cannot do
anything.

- [ ] **Step 4: Run everything**

`tapping a deck still deals straight away` and `dealing several decks seats
several people` pump the picker directly. Report what happened to each.

- [ ] **Step 5: Probe**

- Offer the collecting row on a two chair room. Its case must fail.
- Leave the collecting mode in the picker. Its case must fail.

- [ ] **Step 6: Commit**

```bash
git commit -m "Let a room's picker pick your deck and nobody else's"
```

---

## What this plan does not do

- **The public link.** The room's link is `window.location.origin` plus the
  path, which is correct by construction: it is wherever the build is served.
  That the current test deploy is reachable only by somebody logged into the VM
  is a fact about the deploy and not about the app, and the fix is a command on
  the host rather than a line of Dart.
- **The transport.** Still the next slice, and still the one nothing here can
  prove.
