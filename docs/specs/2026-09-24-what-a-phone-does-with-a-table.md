# What a phone does with a table

The bands layout was designed on a desktop and then squeezed. Twice now the
squeezing has been the whole change: the furniture moved from two columns to a
row under the board, the numbers got better, and the thing on screen was still
a desktop table with smaller parts. This is the research that should have come
first.

## What a phone gets today, measured

At 390 by 844, with one seat and a commander, the height divides like this:

| band | points | share |
|---|---|---|
| top chrome (life, renderer, zoom, undo) | 88 | 10% |
| battlefield | 455 | 54% |
| furniture row (graveyard, dice, token, corner, deck) | 133 | 16% |
| hand | 117 | 14% |
| hints below | 51 | 6% |

A card on the mat comes out 50.3 points wide. You cannot read a name on it,
and the rules text is not even a texture.

The 133 point furniture row, on a table nobody has discarded anything on yet,
is drawing **an empty graveyard at 50 by 70 and an empty command zone at the
same size**. Sixteen percent of a phone spent on two outlines of nothing, and
the leftmost, most prominent object on the screen is the emptier of the two.

Turning the phone does not rescue it. `rendererFor` in
`lib/features/play/renderers/renderer_choice.dart:20` decides on **width
alone**, so a phone held sideways is 844 wide, clears the 720 point cut, and
is handed the free canvas, whose per seat side strips take 28 percent of the
width before a card is drawn. The question that breakpoint asks is "is this
wide", and the question it means is "is there room".

## What other clients do

**MTG Arena on a phone.** The deck and the discard pile are minimized at the
edge, and **tapping a zone opens a browser** of its contents rather than the
zone being big enough to read in place. The hand is **half hidden along the
bottom** and spreads out over the field only when you tap it. And the
battlefield is **not shrunk to fit**: cards stay at a size you can tell apart
and the field **scrolls sideways**.

**The practice literature agrees from the other end.** Piles are minimized and
pushed into corners with the cards barely sticking out past the screen edge;
and when a screen is too small to recognise a card, the answer is a popover at
the original size, never a smaller card on the table. The Fairtravel Battle
write up adds the harder version, which is to condense a permanent on the
board into a squared tile instead of a card.

**Board Game Arena**, which has our exact problem of a free table on a phone,
tells its own developers to declare a minimum width and make it **actually
work**, and to **reorganise the content on a narrow screen rather than relying
on scaling**. In their forums the standing workaround when a board comes out
too small is to turn the phone sideways.

**And the pattern that shows how hard the problem is.** Every client with a
free form board went landscape on a phone: Arena is landscape, Pokemon TCG
Live added a landscape layout. The ones that stayed in portrait redesigned the
board into a small fixed number of slots first: Pokemon TCG Pocket is one
active Pokemon and three on the bench.

**That is context, not a recommendation, and this is the locked decision:
making the player turn the phone is not an option here.** Portrait at 390 by
844 has to be a good table on its own. The industry going landscape says the
constraint is real and that the other three decisions have to carry the whole
weight; it does not license leaning on rotation, an orientation lock, or a
message telling anyone the app is best held sideways. Landscape is allowed to
be better than portrait. It is not allowed to be the answer.

The place this bites is the readable floor in decision 3. If the floor makes
portrait scroll so far that the table stops being usable, the floor comes
down, and if the floor and the portrait budget genuinely cannot both be
satisfied then that is a finding worth stopping on, not a reason to ask for a
rotation.

## The four decisions

### 1. A zone is a chip until you aim at it

An empty graveyard is a chip: a rounded thing about 36 points tall carrying
its name and a count, not a card sized outline of a card that is not there. A
zone with cards in it shows the top card cropped into the same chip, which is
the "barely sticking out past the edge" the literature describes. Tapping one
opens the sheet that already exists.

**They grow while a card is in the air.** A drop target only needs to be the
size of a card when you are dragging something at it, so the chips expand into
card sized targets when a drag starts and collapse when it ends. That is the
whole justification for the 133 points, and it is worth exactly as long as the
drag.

The drag state goes in a provider rather than a parameter on `DraggableCard`.
Threading it would create a hand off site per widget between the drag and each
chip, and this codebase has already shipped one dropped hand off that way.

### 2. The hand peeks

The hand owns 117 points at all times so that it can be ready. Arena's phone
hand is half hidden and comes up over the field on a tap, which is the same
information and none of the rent. Collapsed it is a strip showing the tops of
the cards; opened it covers the board, because while you are choosing a card
the board is not what you are looking at.

### 3. The mat stops shrinking

This is the one I had backwards. `matScaleFor` is `min(box.width / matWidth,
box.height / matHeight)`, pure fit, and fit on a phone is a 50 point card.
Arena's answer is a floor under the card size and a board you move.

So: `matScaleFor` gains a readable floor, and when the mat comes out bigger
than its box the board scrolls on both axes instead of scaling past the floor.

**The invariant survives, and this is why it is safe.** A drop is normalized
in `lib/features/play/widgets/cursor_board.dart:360`, which divides the offset
by the scale before dividing by `matSize`. The mat's 640 by 380 shape and the
meaning of a normalized position do not depend on how big it is drawn or on
how much of it is on screen, so plan 4 can still replicate a drop across
devices.

### 4. Renderer choice asks for room, not width

`rendererFor` takes the height as well. The canvas needs a window that is both
wide and tall enough to hold seats with strips on them; a phone turned
sideways is wide and short, and should get the bands.

## What this does not do

**It does not condense a permanent into a tile.** Hearthstone and Legends of
Runeterra both do it and it works. This app is about a table with real cards
on it, and a tile is the first thing that stops being one. If the readable
floor plus a pan turns out not to be enough, this is the next idea, and it
should be a decision made on purpose rather than arrived at by shrinking.

**It does not make the mat portrait.** A phone shaped mat would use the height
a phone has, and it would break the one thing that makes a dropped position
mean the same place on two devices.

**It does not fix the 28 point board in a four seat pod.** Still the whole
screen's vertical budget split across bands, a hand and two bars.
