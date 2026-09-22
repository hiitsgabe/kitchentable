# What a table still needs, for Magic and for Pokemon

Written 2026 09 22, after the player asked what is missing for a Magic table
and a Pokemon table to actually work. Sources for the Pokemon side are checked
rather than recalled: Bulbapedia's Play area and Special Condition articles.

This is an inventory, not a plan. It says what exists, what is built but
unreachable, and what is genuinely absent, so the next plans can be argued
about rather than guessed at.

## The eleven verbs, and who calls them

The table has eleven actions and a sealed type, so the reducer cannot forget
one. Measured on 2026 09 22, callers in `lib/` excluding the verb's own
declaration and the reducer:

| verb | callers | note |
|---|---|---|
| `MoveCard` | many | the workhorse: play, drop, bottom, arrange |
| `RotateCard` | 2 | tap toggles, the viewer sets an angle |
| `FlipCard` | 1 | the viewer |
| `ChangeCounter` | 2 | the viewer, one kind only |
| `DrawCards` | 2 | the deck pile, setup |
| `ShuffleZone` | 2 | setup, the deck sheet |
| `ChangeLife` | 1 | the top bar |
| `AttachCard` | **0** | nothing constructs it |
| `CreateToken` | **0** | nothing constructs it |
| `RollDice` | **0** | nothing constructs it |
| `PassTurn` | **0** | nothing constructs it |

**Four of eleven verbs have no caller.** That is the same fault this project
has hit seven times, and it is worth naming here rather than discovering it
again per feature: the model is ahead of the screen, and three of the four are
things both games need.

## Magic

### Built, needs a screen

- **Tokens.** `CreateToken` exists. A Magic table without tokens cannot play
  half the decks printed since 2010.
- **Attaching.** `AttachCard` is one verb for aura, equipment, energy and
  evolution. Equipment alone makes it necessary.
- **Passing the turn.** `PassTurn` exists and nothing passes a turn, so the
  turn marker never moves.
- **Counters other than `+1/+1`.** `ChangeCounter` takes any name; the viewer
  hardcodes one. Loyalty, charge, and the dozen named counters a deck uses are
  a screen away.
- **Coin flips.** `RollDice` covers a two sided die.

### Absent, and needed

- **Searching a pile.** The deck sheet looks at the top N. Searching a
  graveyard, an exile or the whole library for one card is a different sheet
  and it is the single most common thing a Magic player does that this table
  cannot do. No new verb: it is a browse plus a `MoveCard`.
- **Milling.** `DrawCards` from library to graveyard already is milling; it
  needs a control.
- **Untap all.** Every rotated card of one seat, straight. Today that is one
  tap per card. It is the first thing every turn.
- **Revealing a card.** Showing a card from a hidden pile to everyone, without
  moving it. No verb covers this, and the honest answer is probably a zone
  rather than a verb: a `reveal` pile that is public and temporary.
- **More than one number per seat.** `ChangeLife` is a single integer.
  Commander needs commander damage per opponent, poison counters, and the
  experience and energy counters several decks run on. This is the one place
  where Magic outgrows the model.
- **Commander tax.** Derived from how many times the commander has been cast,
  which nothing counts.
- **The sideboard.** `setup.dart` drops sideboard slots with a comment saying a
  sideboard is not at the table. Wishes and companions disagree.

### Deliberately absent, and staying that way

The stack, priority, phases, the mana pool and any rule enforcement. The
referee's chair is empty on purpose and the permissive referee is the only one
there is.

## Pokemon

### What the model already gets right, by accident of being game agnostic

- **Special conditions are rotation.** Asleep is the card turned sideways
  counterclockwise, paralyzed sideways clockwise, confused upside down.
  `RotateCard(to: 270 | 90 | 180)` is exactly that, and it exists because plan
  B needed upside down for Magic. Burned and poisoned are markers, which is
  `ChangeCounter`.
- **Damage counters** are `ChangeCounter`.
- **Attaching energy and evolving** are both `AttachCard`.
- **Prize cards taken** is the seat's number, which the spec already describes
  as "life in Magic, prize cards in Pokemon".
- **Coin flips** are `RollDice` with two sides.
- **Retreating and switching** are `MoveCard`.

### The zones, against what `magic_pack.dart` provides

| Pokemon zone | holds | visibility | have it? |
|---|---|---|---|
| Deck | 60 | nobody reads it | yes, the library |
| Hand | any | its owner | yes |
| Discard pile | any | everybody | yes, the graveyard |
| **Active spot** | exactly 1 | everybody | **no** |
| **Bench** | up to 5 | everybody | **no** |
| **Prize cards** | 6, face down | **nobody, its owner included** | **no** |
| **Lost zone** | any | everybody, and nothing comes back | **no** |
| **Stadium** | 1 | everybody | **no, and it cannot be added as is** |

Four of those are a `pokemon_pack.dart` alongside `magic_pack.dart`, which is
the shape the table was built for: a list of zones with an id, a label, a
visibility and whether order matters. Prize cards are `ZoneVisibility.hidden`,
the state that exists precisely because a library's owner cannot read it
either, and that is the same rule.

**The stadium is the one that does not fit.** Every `Zone` carries a required
`seatId`. A stadium belongs to nobody and both players use it. That is the
single model change Pokemon needs, and it is worth doing carefully because
`SeatView`, `seenBy` and everything in plan 3's replication assume a zone has
an owner.

An active spot holding exactly one card and a bench holding at most five are
capacity rules, which is a referee's job and not the table's. The table should
let you put seven Pokemon on a bench and the referee should be the one that
minds, the day there is one.

## What this suggests doing next, in order

1. **The three unreachable verbs that both games need**: tokens, attaching,
   passing the turn. One sheet each, all three already reduced.
2. **Searching a pile.** The most missed thing in Magic, a browse over a
   sheet that already exists.
3. **More than one number per seat.** Commander damage and poison are not
   optional for the format the player cares most about.
4. **A shared zone**, then `pokemon_pack.dart`. Doing the model change first
   means the Pokemon pack is a declaration rather than a special case.

Untap all, milling and named counters are small enough to ride along with
whichever of those they touch.
