# kitchentable, design

Written 2026 09 21. This is the record of what we decided and why, including
the things we decided against. If you are about to change one of these, read
the reasoning first, because most of them were traded against something.

## What this is

A card table for playing with friends over the internet. You bring the card
data, the app brings the table, the shuffler, the dice and the connection.

Three things are true at once and they shape everything else:

1. Nobody runs a server. Not the author, not the players.
2. The app ships knowing zero cards and makes zero network requests until a
   human switches a source on.
3. The app does not know the rules of any game, on purpose.

## Why no rules engine in v1

"Kitchen table" is the name for the version of a card game you play at home
with friends, where a rules question is settled by reading the card out loud.
That is the product. It is also the only version that one person can finish.

Forge and XMage each spent about fifteen years implementing cards one at a
time. That is not a gap we can close by working harder.

But the door stays open, because the referee is a slot rather than something
welded to the screen. See "The referee slot" below.

### What we looked at

`phase-rs/phase` is a Rust MTG engine, dual licensed MIT and Apache 2.0, that
parses oracle text into an IR instead of scripting cards one by one. Its own CI
badges, read on 2026 09 21, report 89% card coverage (32202 of 36079), 93% for
Commander, 97% for Pauper, and 192 of 192 keywords. The `phase-engine` crate
depends only on serde, tracing, thiserror, rand, rand_chacha, indexmap,
petgraph, nom, serde_json, sha2 and toml, so it has no platform dependencies
and compiles for Android and iOS. It already ships an `engine-wasm` wrapper,
which means it is designed to be driven across a serializable boundary.

Nobody on this project has played a game with it. The coverage numbers are
theirs, not ours, and the missing 7% of Commander will be the strange cards
that decks are built around, not a random sample.

Forge and XMage are both Java and both out of reach. Forge's Android build is a
libGDX monolith that paints its own screen, and XMage talks to its server over
native Java serialization.

## The core is eleven verbs

The table does not know what game it is hosting. Everything it can do:

```
move(card, zone)   rotate   flip   counter(+/-)   attach
shuffle(seed)      draw(n)  token  life/points    die    undo
```

That set covers Magic and Pokemon completely without a single rule. `attach` is
aura, equipment, energy and evolution. `counter` is +1/+1, loyalty and damage.
This is not a coincidence. Every tabletop card game is piles of cards with
state on them.

Cockatrice has run on this bet for fifteen years.

## Game packs are declarations, not code

A game pack declares zones, starting totals, deck construction rules and
booster structure. It does not contain logic.

**Magic** declares library, hand, battlefield, graveyard, exile and command.
Card data comes from MTGJSON, images from Scryfall.

**Pokemon** declares deck, hand, active, bench, prize, discard and lost zone.
Card data comes from `PokemonTCG/pokemon-tcg-data`.

Pokemon ships second, after Magic works. An abstraction shaped by one real case
and one imagined case comes out wrong. This is deliberate sequencing, not
deprioritization.

Note on durability: the pokemontcg.io API goes offline on 2027 03 01 and moves
to a paid service. The raw data behind it is a git repository and outlives it.
Because the app imports rather than calls, this does not affect us. The import
model is the robust choice here, not a compromise.

## Three formats, two tables

Standard and Pauper are the same table. Both are two seats, sixty cards, a
fifteen card sideboard and twenty life. The only difference between them is
which legality filter runs during deck building, and Scryfall already ships
that in the `legalities` field.

So there are two table setups, not three:

**Duel**, two seats, twenty life, five zones. Serves Standard, Pauper and the
game after a draft.

**Pod**, three to six seats, forty life plus commander damage at twenty one per
source, the five zones plus command. This is the hardest screen in the app.

Draft is not a table. It is a phase that produces a deck and then hands off to
the duel table.

### Draft

MTGJSON ships real booster structure. Checked against Foundations on
2026 09 21: the play booster has four pack variations weighted 788, 197, 12 and
3 out of 1000, drawing from sheets of 80 commons, 101 uncommons and 140
rare/mythic. This is weighted sampling, not an approximation of one.

The host generates packs, holds them, and rotates. Every other player only ever
talks to the host, so nobody needs a connection to anybody else.

## The network

WebRTC data channels in a star. Whoever starts the game is the authority: they
own the state, apply every intent and broadcast the result.

The star is not an optimization, it falls out of two problems at once. A full
mesh of four players needs six pairings, a star needs three. And hidden
information needs one owner, otherwise every client can lie about its own hand
and its own shuffle.

Trusting the host is the same contract as trusting the person who shuffles at a
physical table.

### Pairing

A short code or a QR, passed around however the players already talk. No
signaling server, no lobby service, no account.

Raw SDP is about 2500 bytes. QWBP compresses WebRTC signaling to 55 to 100
bytes, which fits in a typed code. Worth evaluating before writing our own.

For contrast, Pokemon TCG Pocket makes players leave the app and send a
password out of band to play a friend. Doing better than that is a low bar and
we should clear it on day one.

### Relay

About one connection in ten lands behind a NAT that will not cooperate and
needs TURN. There is no trick that avoids this.

The app ships with no relay configured. When a connection fails this way, it
says so plainly and offers a field for the player's own TURN server. It never
spins forever pretending to connect. Shipping a default relay would mean the
author runs infrastructure, which is the one thing this project refuses.

### Shuffling

Seeded and deterministic, with the seat committing to a hash of the seed before
the shuffle and revealing it after. Anyone who cares can verify the host did
not cook the pack. This costs almost nothing now and cannot be retrofitted.

## The referee slot

The authority does not apply rules itself. It asks a referee.

```
Referee
  validate(intent, state) -> accepted | rejected(reason)
  legalTargets(intent, state) -> [cards]   // may return null for "I do not know"
```

**PermissiveReferee** ships in v1. It accepts everything and knows no targets.

**PhaseReferee** is the reserved seat for phase-rs, bound through
flutter_rust_bridge.

The cost of the slot is paid in the UI, not in extra code: the screen must
handle "the referee rejected this" and "the referee knows the legal targets"
from day one, even while nothing ever rejects and nothing is ever lit up. That
discipline is the whole reason a rules engine can arrive later without a
rewrite.

## Sources

The app opens knowing nothing. First run shows an empty list and makes no
request.

The app knows the address of some sources. All of them are off. Switching one
on is a deliberate tap, and only then does anything leave the device.

This is not only a preference about architecture. It is the legal position: the
author never distributes, hosts or fetches anything belonging to Wizards of the
Coast or The Pokemon Company. The player's device does, because the player
asked it to. Scryfall additionally requires that images be rehosted rather than
hotlinked, which the local cache satisfies.

## The table on a screen

### The rule we took from Arena's mistake

On mobile, MTG Arena hides the hand at the bottom edge and opens it into a fan
that covers most of the battlefield. You cannot look at your hand and the board
at the same time. Players also report confusing similar cards because they are
shrunk too far.

So: **the hand never covers the board, it pushes it.** The hand is a draggable
sheet that displaces the table upward.

### Two renderers, one state

Both read the same `TableState`.

**StackedSeats** is the default on phones. The table is a vertical scrolling
surface. Each opponent is a band, yours is pinned at the bottom and taller. A
radar strip at the top keeps every life total visible and jumps to a seat when
tapped. Tapping a band expands that opponent.

**FreeCanvas** is the default on tablets and wide web. The same seats laid out
on a pan and pinch surface.

The app picks by screen width, the player can switch at any time, and the choice
is remembered per device. Neither renderer is a mode the player has to
understand before playing.

### Card position

A card on the battlefield carries an optional position, normalized from 0 to 1
against its own seat's mat rather than in pixels.

When the position is null, the layout places the card and groups it by type:
creatures in one row, lands in another, artifacts and enchantments in another.
This is the default and it is what most players will ever see.

When the player drags a card freely, the position is set and both renderers
honor it. Normalizing against the seat's own mat is what makes this work in
both views: the same relative arrangement survives whether the seat is a short
wide band or a large canvas tile.

Grouping is a per player setting, and it applies to the zone's owner. If Carla
arranges her board by hand, everybody sees Carla's arrangement, because it is
her board.

One honest degradation: in StackedSeats a band can be too short to show a free
arrangement legibly. Below a height threshold the band renders grouped
regardless. The arrangement is preserved in the data, it is just not drawn.

## Code structure

Flutter 3.47.5, Dart 3.13.4. Riverpod. Targets are Android, iOS and web. Web is
in because the development machine has no display and no emulator, so it is the
only way to look at the app while building it. Desktop is a one line change
when somebody wants it.

```
lib/
  main.dart
  app.dart
  ui/          design system: tokens, atoms, molecules, organisms
  table/       model, the eleven verbs, referee slot
  games/       declarative game packs
  sources/     catalog, import, image cache
  net/         webrtc, host authority, pairing
  features/    lobby, deckbuilder, draft, play
```

Atomic Design lives in `ui/` and nowhere else. It is a vocabulary for visual
components, and the table genuinely needs one because it is built almost
entirely from repeated pieces: card, pile, life dial, seat, battlefield, hand.
Applied to the whole app it would force us to decide whether the table screen
is an organism or a template, and it would bury WebRTC and booster generation
in a tree that only knows how to talk about UI.

Inside a feature there are three roles and no more. `_screen.dart` only draws.
`_controller.dart` is a Riverpod notifier, decides, and exposes state. A service
talks to disk and network and knows about no widget.

**None of these folders is created before a second file asks for it.** Empty
directories placed to complete a pattern are the most recognizable signature of
generated code, and this project is explicitly not that.

## Distribution and the legal position

The Wizards Fan Content Policy excludes game mechanics and says not to use
their IP in other games. Free is necessary and not sufficient. Forge, XMage and
Cockatrice are tolerated rather than permitted, and have been for fifteen years.

What follows in practice: no store, no charge, no donation tied to access,
distribution as a direct APK, and an understanding that a takedown is possible.
iOS is a much worse story, since Forge ships an unsigned IPA, which tells you
they cannot sign one either.

## Open questions

- Whether to use QWBP for pairing or write a simpler exchange.
- How the deck importer accepts a decklist. Pasted text is the obvious first
  answer. Moxfield and Archidekt have no official public API, so a URL importer
  means scraping, which is a dependency on somebody's HTML.
- Whether the pod renderer needs a distinct layout for five and six seats, or
  whether scrolling covers it.
