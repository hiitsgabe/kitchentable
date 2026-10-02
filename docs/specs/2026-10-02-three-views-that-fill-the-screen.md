# Three views of the table, each filling the screen

Built on [the benchmark](../benchmarks/2026-10-02-multiplayer-card-table-layouts.md):
seven clients, read for how they put several battlefields on one screen.
This spec is the second version; the first put every seat in an equal
slice while leaving the life band and the furniture row in place, and on a
phone that left one cropped row of cards. The numbers below are measured,
not hoped.

## The problem, restated from the screenshots

- The life totals take a band across the screen, two boxes for two players,
  and a row per two more. Nobody needs a number that big; every client puts
  it on a plate or in one thin row.
- The furniture under your board (deck, graveyard, command, dice, token)
  takes a row taller than a card. Every client makes zones counts that open.
- Your battlefield, the one you play on, ends up a sliver: one cropped row
  on a phone, two rows on a desktop with the rest empty.
- Both players read "you" in the life band.

The rule the whole redesign serves: **at least two rows of cards on every
battlefield on screen, yours first.** A readable card is 72 wide and 100.6
tall, so that is about 230 points of battlefield each.

## The pieces every view is built from

### The seat rail
One thin row for the whole table, 28 points: a chip per player with their
label and life, in table order, your own chip marked. This replaces the
life band. A chip is also the switch: in Focus it turns to that board, in
Split it picks the second board. Life for a seat is also shown on its board
badge, so the rail is a summary, not the only copy.

### The zone rail
Your library, graveyard, command and exile stand in a narrow rail on the
right edge of your board, a thumbnail each with its count, the way
TableCommander's column and Forge's zone buttons work. Tap the library to
draw, long press to work the deck; tap the graveyard or command to open it
as a sheet over the board. This replaces the furniture row. Token, dice and
undo live in the top bar's overflow; they are not pile-shaped and do not
belong beside piles.

### The board
One seat's free canvas, filling the rectangle it is given. Cards sit by
their normalised position and are drawn at a card width chosen for the box:
yours never below the 72 point readable card (it scrolls sideways past the
box before it shrinks, as Arena does); an opponent's shrinks to fit down to
56 on a phone, with long press for the detail, as MTGO does. A badge in the
corner carries the label and life. Yours is draggable and takes drops and
has the zone rail; the others are watched, with their public piles
(graveyard, command) openable by tap and their hand a count in the badge.
Your board carries an accent edge so whose it is never needs reading.

### The hand
Unchanged: tucked along the bottom, peeking at 34 points, opened by a tap,
closed by tapping the board. It overlays the bottom of whichever view is
showing and never takes height from the boards while tucked.

## The three views

The top bar's view button cycles them; the last pick is remembered; the
table opens on Grid.

### 1. Focus
One board fills the whole table area. On a phone, swipe sideways to page
through the seats in table order; on a desktop the seat rail chips switch.
Starts on yours. The seat rail stays, so every other player's life and hand
count is still on screen while you read one board. This is untap's Full and
TableCommander's Single.

### 2. Grid, the default
Everyone at once, each board filling its share, laid out by how many and
how wide:

- **Two players.** Desktop and landscape: side by side, each board the full
  height. Phone: stacked, you below, each about 345 points tall, three rows
  of cards.
- **Three players.** Desktop: you across the bottom at full width, the two
  others sharing the top. Phone: three rows, about 230 each, two rows of
  cards; opponents' cards at the smaller width.
- **Four players.** Desktop and phone: a two by two grid, you bottom left,
  opponents' cards shrunk to fit. This is Quadrant, four-corner, and the
  thing Cockatrice found four rows could not do.
- **More than four.** The grid keeps four cells and scrolls; the seat rail
  shows everybody.

Your cell is never smaller than an opponent's, and on a phone with three or
four players it may be the taller one so your two rows stay readable; the
equal split is the rule until it would cost you a row.

### 3. Split
Two boards: yours and one other. Desktop and landscape: left and right.
Phone: top and bottom, each about 345 points. The seat rail chips pick which
other; with two players there is nothing to pick. This is untap's Split and
TableCommander's Side-by-side.

## Desktop and phone, in numbers

Phone, 390 by 844, scale 1: top bar 48, insets 32, seat rail 28, hand peek
34. About 700 points for boards. Two players 345 each, three 230 each, four a
grid of 170 by 170 cells with opponents' cards at 56 and yours scrolling
sideways at 72.

Desktop, 1280 by 800: top bar 48, seat rail 28, hand peek 34, about 680
tall and 1250 wide for boards. Two players side by side at 625 by 680 each,
six rows of cards; four in quadrants of 625 by 340, three rows each.

## What stays

- The transport, the mesh, the table model, the wire: untouched.
- The free-canvas card model in every board in every view.
- The hand sheet, the counters, the deck search, the inspector, the token
  and dice sheets: reused, re-homed where the pieces above say.
- The stacked bands and the panned canvas are retired by this; the three
  views replace them. The code stays in git history.

## Naming

"You" is computed at draw time for the seat this device holds; any other
seat shows its player's name, or "Player N" by its chair when they gave
none. The seat rail, the board badge and the top bar all read this one
function.

## What building it found

- **The deck is off the battle zone.** The author's rule, given mid-build:
  only the graveyard and the commander belong on the battlefield; the deck
  is fixed in the bottom bar beside the hand, always visible, and the dice
  and token-making sit under the top bar's overflow with the card size.
  That also hands your board its full width on a phone, where a rail with
  the deck in it had cost a column of cards.
- **Tall screens: opponents across the top, you full width below.** The
  first cut tiled a phone with three and four players as rows and as a two
  by two, and your board came out one column wide beside the rail. Forge's
  Rows and MTGO's top half are what works: the others side by side at the
  smaller card, yours across the width, two to three in height. Wide
  screens keep the two by two for four.
- **A `#demo=N&view=V` link** deals a pod of N on one device from sample
  decks and opens on view V, so the three views can be screenshotted on a
  desktop and a phone without a room or a second person. Two bugs fell out
  of it: the app clears the address bar's hash after reading the room
  code, so anything read later from it is gone, and `RendererChoice`
  restored the stored view over a choice made in the same frame.
- **Measured on the screenshots**, 390 by 844: two players give your board
  two rows of cards with room over; three and four give two rows; the seat
  rail is one line; nothing is a band.
