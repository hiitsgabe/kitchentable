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

The host generates packs and rotates them. A pack's contents become public the
moment it has been picked through, so unlike a library it needs no hiding, only
a committed seed proving nobody chose what was in it.

## The network

**This section replaces an earlier one, and the change is worth reading.**

The first version chose a star: one host owning the state and broadcasting it,
argued for on two grounds, that a mesh of four needs six pairings against a
star's three, and that hidden information needs a single owner.

Both grounds held. The star was rejected anyway, because it fails at the thing
players actually hit: **if the host's connection drops, the game is over.**
Everyone will be on mobile data on different networks, so that is not an edge
case, it is Tuesday. A game that cannot survive one person going through a
tunnel is not a game people will use.

So: **a full mesh, every seat replicating the whole state, with the host role
able to move.**

### Host migration

Whoever created the table is the host. If they drop, the next seat in a fixed
order takes over, and the game continues. If the original comes back, they take
the role again. This is a standard pattern in peer to peer games and it is the
reason the mesh is worth its cost.

It has a known attack, and the fix is cheap but only if it is built in from the
start. Succession needs an order. The obvious order is each peer saying when it
joined, and a modified client then claims to have joined first, wins every
succession, and pushes whatever state it likes the moment it takes over. So the
host **stamps** a monotonic sequence number on each peer at handshake, and
succession reads that rather than anything a peer says about itself.

### The link is a rendezvous, not an address

A link cannot reach a phone. Mobile carriers put everyone behind CGNAT, where
the public address is not yours and forwarding a port does nothing. A tunnel
would fix it and a tunnel is a central server owned by somebody else, which is
the one thing this project refuses. It also would not help: ngrok and its kind
have never carried UDP.

The fix is that the link names a **meeting place** instead of an address. Both
sides go to a public relay, introduce themselves, and everything after that is
direct. The relay sees the handshake and never sees the game.

Nostr is the relay network: hundreds of independent relays, no account, no
owner, tiny messages. Trystero does exactly this in JavaScript and defaults to
Nostr. In Dart the pieces exist and are current, `ndk`, `dart_nostr`, and
`flutter_webrtc`, all published within the last few months.

So the link is `.../#room=k7-42q`, carrying a **name rather than an address**.
It works with no DNS of ours, no tunnel, no open port and no server. It is also
reusable and works in both directions, unlike a code carrying an SDP offer,
which is single use and needs a second code coming back.

### Relay, still

About one connection in ten to twenty needs TURN, and mobile carriers are the
worst case: symmetric CGNAT gives a different external port per destination, so
the address STUN discovers is useless to the other peer. No trick avoids this.
The question is only who pays for the bandwidth.

The app ships with no relay configured, says plainly when a connection has
failed this way, and takes a TURN server the player supplies.

## Who can see what

Replicating everything to everyone would mean every peer holds every hand. That
is a real cost and it is paid selectively.

**The board, graveyards and exile are public.** Replicated in the clear,
because they already are in a real game. This is free.

**A hand is encrypted to its owner.** Everybody else holds a blob they cannot
read, which is mathematics rather than trust. Playing a card publishes it in
the clear along with proof it was that blob. This is cheap.

**A library is the hard one, and the obvious answer is backwards.** Encrypting
it to its owner would let you read your own deck, which is a worse cheat than
the one being fixed. The requirement is not "nobody but me", it is **nobody,
including me**, until the card is drawn.

The chosen protocol is two layers and two neighbours. The player on your left
shuffles and encrypts your deck; the player on your right shuffles again on top
without being able to read underneath. Neither of them alone knows the order,
and you know it least of all. Drawing means asking both for the key to that
position.

Its honest leak: **whoever hands you a key learns which card you drew.** One
card at a time, and only if that person is deliberately looking.

Closing that leak is mental poker, which is a solved problem with libraries and
a shuffle proof measured in tens of milliseconds, and which exists only in
JavaScript. It is deferred, not dismissed, and the revealing step is built as a
seam so it can arrive without rewriting the table. That is the same move the
referee's chair made, and that one worked.

### Relay

About one connection in ten lands behind a NAT that will not cooperate and
needs TURN. There is no trick that avoids this.

The app ships with no relay configured. When a connection fails this way, it
says so plainly and offers a field for the player's own TURN server. It never
spins forever pretending to connect. Shipping a default relay would mean the
author runs infrastructure, which is the one thing this project refuses.

### Shuffling

Seeded and deterministic, with the seat committing to a hash of the seed before
the shuffle and revealing it after, so anybody who cares can check that nobody
cooked the pack.

Note what this does and does not buy once libraries are hidden, above. A public
seed proves nobody **chose** the order, and it also means anybody can recompute
it, which is precisely why a seed alone cannot hide a library. The commitment
protects a draft pack, where the contents become public anyway, and the two
layer protocol protects a library, where they must not. They are different jobs
and both are needed.

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

## Importing card data

Sizes measured on 2026 09 21.

```
MTGJSON AllPrintings     636.0 MB   the obvious path
Scryfall oracle_cards     23.6 MB   one entry per unique card
MTGJSON per set            ~1.0 MB   FDN 1.1, FIN 1.3, DSK 0.9, BLB 0.8
card image, normal          76 KB   on demand
```

The obvious path is to pull AllPrintings and it does not fit on a phone.
Nobody needs it.

Playing and building decks needs name, mana cost, type line, oracle text, power,
toughness, colors and legalities. Scryfall's `oracle_cards` carries all of that
for 36079 cards in 23.6 MB. The one thing AllPrintings adds is booster
structure, and MTGJSON publishes that per set at about 1 MB, so draft downloads
one set when the player picks that set to draft.

Images are never fetched in bulk. A whole Commander deck is 100 times 76 KB,
about 7.6 MB, and only for cards the player actually chose.

The whole import is therefore about 25 MB, which is the difference between
possible and not possible on a phone.

### The import screens

There is no welcome screen. The menu draws itself from real state: with no
source, Play and Decks are dimmed and focus starts on Sources. With a catalog,
Play lights up, focus moves to it, and the subtitle becomes the real card
count. The menu is the tutorial.

Download shows two bars, not one. Fetching depends on the network and indexing
depends on the device. They are different waits and a single bar for both is
the one that sticks at 99%.

Every source row states its size and states that it will download, before the
player touches it.

## Input: touch and D-pad, on two device classes

The app is driven by touch and by a D-pad, and it targets both Android
handhelds with physical controls and Android TV.

This is a design system requirement, not a navigation feature bolted on later.

- Every atom is born with a visible focus state. Not a hairline, something you
  can see across a room.
- Traversal order is declared explicitly rather than inferred from layout.
- A hint bar shows the current button legend, the way handheld interfaces do.

On the table this stops being free. The D-pad has to walk card by card inside a
zone and jump between zones on a separate button. That is a real interaction
design problem and it is owed a solution before the table is built, not after.

Two device classes means a type scale that responds to the class. TV sits far
from the eye and needs larger type, overscan margins and bigger targets.
Handhelds sit close and use normal metrics. One scale factor resolved at
startup, applied through tokens, so no widget hardcodes a size.

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
