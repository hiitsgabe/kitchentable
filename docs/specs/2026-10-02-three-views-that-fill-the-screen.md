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

## The shared piece: a seat's free canvas that fills its box

Every board in every view is a free canvas, the way the table already works:
cards sit where they are put, by a normalised 0..1 position, draggable on your
own board and shown exactly as placed on everyone else's. That does not change
and is not a view; it is how a board is managed, in all three layouts at once.

What changes is that one seat's free canvas becomes a widget that fills whatever
rectangle it is given, rather than a fixed 640x380 mat scaled to fit inside a
surface you pan. The cards map onto the box by their normalised positions and
are drawn as a share of the box, so a bigger box means bigger cards and a full
screen; the piles (graveyard, command, deck), the life, and the seat's label
arrange around the box edges. Yours takes drops and carries the hand drawer;
the others are watched, not touched.

The three views only arrange these free canvases: Focus pages one across the
whole area, Grid tiles them equally, Split stands two side by side. The card
management inside each is identical in all three.

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
- The free-canvas card model is kept everywhere, it is the point. What is
  retired is the single pan-and-pinch surface that held every seat at once and
  the fixed-mat fit of `stackedSeats`; the three views above, built on the
  fill-the-box seat canvas, replace both current renderers.

## Open, deferred

- Default view is Grid, the divided one, on every device. The player's last
  pick is remembered and wins over that once they choose.
- Encryption of the relay traffic (a separate track, folded into sealed hands).
