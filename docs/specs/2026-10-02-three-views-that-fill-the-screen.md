# Three views of the table, each filling the screen

## The problem

Two things are wrong with the table today, from the player who tried it on two
phones across two networks:

1. **It is confusing whose board is whose.** Every seat is labelled "you"
   (a nameless player is stored as the literal `namelessPlayer`), and the one
   board on screen is whichever seat the viewer jumped to, so there is no
   steady sense of "mine" against "theirs".
2. **The battlefields do not use the screen.** A mat is drawn at a fixed
   640x380 and scaled to fit, which leaves wide empty margins, worst on a
   phone held upright where most of the glass is dark green nothing.

Today there are two renderers chosen by screen size: `stackedSeats` (bands of
opponents above, your station below) and `freeCanvas` (all seats on a surface
you pan and pinch). Neither fills the screen with battlefields, and the player
cannot pick the arrangement they want.

## The design: three views the player switches between

One switch in the top bar cycles three views. Each one fills the whole table
area with battlefields; none leaves a fixed-aspect mat floating in empty space.
The player's own hand is a bottom drawer in every view, as it is now, because
it is always and only theirs.

### 1. Focus (swipe)

Your battlefield fills the entire table area. Swipe left and right to page
through the other players' battlefields, each one full-screen in turn. A small
page indicator says where you are and whose board you are on. Starts on yours.

This is the view for reading one board closely, yours most of the time.

### 2. Grid (equal split)

The table area is divided equally among the seats: each seat's board gets an
equal share of the screen, so nothing is wasted. Up to four seats share the
screen at once; past four the grid scrolls rather than shrinking a board below
readable. On a tall screen the shares stack as rows; on a wide screen they fall
into two columns.

This is the view for watching the whole table, the Commander view.

### 3. Split (two up)

The screen is divided in half: your board on one half, one other player's on the
other. When there are more than two players, a selector picks which other player
fills the second half.

This is the view for a duel, or for watching one threat while you play.

## The shared piece: a board that fills its box

All three views compose one widget: a seat's board that fills whatever
rectangle it is given, rather than a fixed mat scaled to fit. The battlefield
(cards sit by a normalised 0..1 position) stretches to the box; the piles
(graveyard, command, deck), the life, and the seat's label arrange around its
edges and scale with the box. Yours carries the hand drawer; the others do not.

This replaces the per-mat fit math with a fill, which is the whole point: a
board is as big as the room it is given.

## Naming

"You" is computed at draw time, not stored. A seat is yours when
`seat.owner.actableHere(me: myKey)` is true; that seat is labelled "You". Any
other seat shows its player's name, and a nameless other shows "Player N" by
its chair, never "you". The name still crosses the wire exactly as it does now;
only the label on the glass changes.

## What stays

- The transport, the mesh, the table model, the wire: untouched. This is a
  rendering change.
- The hand drawer, the top bar, the counters, the deck search, the inspector:
  reused as they are.
- `freeCanvas` (pan and pinch) is retired; the three views above replace both
  current renderers. The code stays in git history if the surface is wanted back.

## Open, deferred

- Whether the default view per device is Focus (phone) and Grid (tablet), or a
  remembered last choice. Start with: remembered choice, falling back to Focus
  on a narrow screen and Grid on a wide one.
- Encryption of the relay traffic (a separate track, folded into sealed hands).
