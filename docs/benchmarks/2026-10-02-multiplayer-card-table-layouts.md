# Benchmark: how digital card tables lay out more than two players

What the established clients do with the one problem this app has: several
battlefields, one screen, a phone as often as a desktop. Seven products,
read from their own documentation and release notes; the conclusions at the
end are what kitchentable's three views are built on.

## The products

### Magic Online (MTGO), Commander
Source: [Gameplay: Multiplayer & Commander](https://www.mtgo.com/getting-started/getting-started-multiplayer)

- "Your battlefield is in a similar position, while your opponents are split
  across the top half of the screen." You are the bottom; everybody else
  shares the top.
- "Zones do not pop out, but instead can be toggled open or closed." The
  library, graveyard and exile are not standing furniture; they are small
  controls that open. "Your graveyard is duplicated on the left side above
  your avatar for ease of use."
- "The game re-sizes opponents' permanents as needed to keep everything
  visible, use Hover Zoom liberally." Opponents' cards shrink to fit; detail
  comes from zoom, not from size.
- "The +/- button at the bottom-right of each opponent's section can be
  toggled to hide that opponent; this makes the remaining players' zones
  larger." Space is reclaimed from whoever you are not watching.
- Life sits on the avatar, not in a band.

### untap.in
Source: [Updates & release notes](https://untap.in/updates)

- Four desktop layouts: Overlay, Split, Accordion, Full. "Full gives you the
  overlaid board view, but shows only the player you're currently
  following." "Accordion: opponents stay visible across the top, while the
  board you're following expands to give you more room. Click any player to
  switch focus."
- "Opponents now appear in turn order across the top of the board."
- Mobile: "a new seat bar above the game controls" to "switch between
  opponents"; "the game bar and your seat panel now stay put at the bottom
  of the screen and an expanded pile opens above them." Controls pinned,
  piles open as sheets over the board.
- Life: one seat panel per player, "a much larger life total" on "a wider
  dark plate with your seat colour on the name bar." One plate, not a row of
  boxes.

### TableCommander
Source: [Playmat docs](https://tablecommander.com/docs/gameplay/playmat)

- "Across the top, every player has a stat row: life, poison, energy,
  experience, commander damage." One thin row for the whole table.
- Zones in "a column on the right: Command, Graveyard, Exile and Library,
  each with a count." A rail, not a row under the board.
- Four view modes on keys 1 to 4: Single, Side-by-side ("your board next to
  one opponent's"), Stacked ("opponents' boards stacked above yours"),
  Quadrant ("everyone at once. Needs enough players to fill it").
- "Cards go wherever you drop them and they'll happily overlap." Free
  placement, with auto-arrange and snap-to-grid as helpers.
- The battlefield splits creatures above lands, "the bar between them drags
  to resize."

### Forge
Source: [User Guide](https://github.com/Card-Forge/forge/wiki/User-Guide)

- Each field: "avatar and life total", then "zone buttons: hand, library,
  graveyard, exile, command, and sideboard with live counts", then the
  battlefield. Zones are buttons with counts.
- Multiplayer field layout: "Grid distributes opponents across both top and
  bottom rows; Rows stacks all opponents in the top row above the player."
- Field panels: "Tabbed groups multiple fields as tabs in the same panel;
  Split gives each field its own side-by-side panel."
- "(N new)" on a tab marks cards that changed since you last looked at that
  opponent: a cue for boards you are not watching.

### SpellTable
Source: [Draftsim guide](https://draftsim.com/mtg-spelltable/),
[SpellTable](https://spelltable.wizards.com/)

- Default is "the four-corner layout, which shows all four players at the
  same time." A quadrant grid for a pod.
- Also a "focused layout or picture-in-picture layout, which show the active
  player as the largest view and the rest of the table in smaller windows."
  Focused is "recommended for non-multiplayer formats."

### Cockatrice
Source: [Issue 3158](https://github.com/Cockatrice/Cockatrice/issues/3158),
[Issue 2798](https://github.com/Cockatrice/Cockatrice/issues/2798)

- The negative result. Its 4-player UI "is too cramped", with the fix
  proposed as "4 squares instead of 4 lines top down", and "the UI doesn't
  really favor 4 man+ games, as the screen size goes really small." Four
  full-width rows do not work; a grid does. Users asked to "allow resizing
  of individual player tables."

### MTG Arena on a phone, and Hearthstone
Source: [Draftsim, MTGA mobile](https://draftsim.com/mtg-arena-mobile/),
[TechRadar hands-on](https://www.techradar.com/news/mtg-arena-mobile-hands-on-with-phone-sized-fantasy-card-battles),
[Hearthstone design notes](https://medium.com/@matt.tsui/hearthstone-design-thinking-inside-the-box-78dbacb96040)

- Portrait. Opponent on top, you on the bottom, mirrored. The hand is
  "half-hidden at the bottom of the screen and needs to be tapped to spread
  the cards out"; tap the battlefield to tuck it back.
- "You don't really get to read the names of the creatures, but their power
  and toughness are clearly indicated, and the art is sizable enough to help
  identify them." Art over text at phone sizes; long press for the rules.
- "When board states become too large, the mobile app lets you scroll to the
  side so you can see the entire battlefield at a reasonable scale." Scroll
  sideways before shrinking cards below recognisable.
- Hearthstone: "there is no text on the screen besides the tiny titles in the
  middle of the cards"; the player's side is drawn subtly larger "helping
  players feel more in control."

## What they agree on

1. **You are the bottom, and the biggest.** Every client puts your board
   at the bottom and gives it the most room (MTGO, untap Accordion, Forge
   Rows, Arena, Hearthstone). Opponents share what is above.
2. **Life is a plate or a row, never a band.** One compact element per
   player: on the avatar (MTGO), a seat plate (untap), a single thin stat row
   for the whole table (TableCommander). Nobody spends a strip of the screen
   per player on a number.
3. **Zones are counts that open, not furniture that stands.** Zone buttons
   with live counts (Forge), toggled zones (MTGO), a narrow right-hand rail
   (TableCommander), piles that open as a sheet over the board on a phone
   (untap). The library, graveyard and command zone cost a thumbnail each,
   not a row under the battlefield.
4. **Four is a grid, not four rows.** Quadrant (TableCommander), four-corner
   (SpellTable), Grid (Forge), and Cockatrice's failure the other way. Two
   players is a split, side by side on a wide screen and stacked on a tall
   one.
5. **The same three arrangements keep appearing.** One board at a time with
   a way to switch (untap Full, TableCommander Single, SpellTable focused);
   everybody at once (Quadrant, four-corner, Grid); you plus one (Split,
   Side-by-side). Those are the three views this app was asked for, under
   other names.
6. **Opponents you are not watching stay a line, not a blank.** The seat bar
   (untap), the stat row (TableCommander), the "(N new)" tab (Forge). Name,
   life and hand count are always on screen even when the board is not.
7. **Opponents' cards shrink to fit; yours do not.** MTGO resizes opponents'
   permanents and leans on zoom; Arena scrolls sideways before it shrinks
   your own. Detail on demand, by long press, is the rule at phone sizes.
8. **Free placement, with overlap.** TableCommander and the mat-style
   clients let cards land where dropped. Auto-arrange is a helper you can
   invoke, not the default.
9. **On a phone, controls are pinned to the bottom and the hand is tucked.**
   The game bar and seat panel stay put (untap); the hand peeks and opens on
   a tap (Arena).

## What that costs us today, measured

On a 390 by 844 phone at scale 1, with a 16 point safe inset each side:

- The life strip (two boxes, 6 of padding, a 15 point number and a 9 point
  name, plus a 12 point gap under it) is about 60 points for two players and
  a whole row per two more.
- The furniture row under your board (zone chips resting at 36, a library
  pile drawn at the 72 point card, 100 tall with its leaves, plus gaps) is
  about 150 points.
- The hand peeks at 34 and stands up to a fifth of the screen.
- A readable card is 72 wide and 100.6 tall. Two rows of cards with a gap and
  a label line need about 230 points of battlefield.

After the top bar (about 48) and insets, the screen has roughly 750 points
for everything under it. Spending 60 on a life band and 150 on furniture
leaves 540 for every battlefield together and the hand; with two players
that is under 230 each, which is one row of cards, which is what the
screenshot shows. Fold the life into a 28 point rail and the furniture into
a thumbnail rail beside your board, and the same screen has about 690 for
the boards: 345 each for two players (three rows), 230 for three (two rows),
and four needs the grid and a smaller card, exactly as every client above
found.
