# Benchmark: Balatro's interface, read off its own screens

The author's complaint is that the app "tá muito com cara de AI": correct
spacing, thin borders, grey on grey, translucent panels, a sans serif at
three weights. Everything is a tasteful suggestion of a surface and nothing
is a thing. Balatro is the opposite and it is the reference, so this reads
its menu and its settings screen rather than describing the vibe.

## The screens read

- `menu_desktop.png`, 2560x1440: the title screen.
- `game_settings.png`, 1102x845: the in-game settings dialog.
- `menu_mobile.jpg`: the same title screen on a phone.

## What is actually on the title screen

The background is a loud red and blue paint swirl, nearly full contrast,
moving. It would destroy any interface drawn in loose text, and it does not
destroy this one, because:

1. **Nothing floats.** The buttons sit inside a grey rounded **tray**. The
   tray is opaque. The swirl stops at its edge.
2. **Every button is a slab**: one flat saturated colour, a near black
   outline a couple of pixels wide, square-ish corners at a generous radius,
   and a **darker strip of its own colour along the bottom**. That strip is
   the whole trick. It reads as the side of a physical tile sitting on the
   tray, so the button is an object with a thickness rather than a tinted
   rectangle.
3. **The colours are roles, not a palette.** Blue PLAY, green COLLECTION,
   orange OPTIONS, red QUIT. Saturated to the point a designer would call
   them crude. No two important buttons share a colour.
4. **The text is bold, white, uppercase, and outlined** in the same near
   black as the slab edge, in a pixel font. It is large relative to its
   slab: the slab is sized to the word plus a margin, not the word shrunk
   to fit a grid.
5. **Profile is its own tray**, with a small label above a lighter slab. A
   tray per group, and the group's name sits outside it.

## What is on the settings dialog

1. One **panel**: dark desaturated slate, a **light two pixel outer border**,
   a large radius, a soft shadow under it. Opaque. It is a card lying on the
   table, not a sheet of glass.
2. A row of **red slab tabs** across the top: Game, Video, Graphics, Audio.
   The chosen one is lighter, as if pressed up rather than in.
3. Each setting is a **centred label above its control**. Not a label on the
   left and a control on the right. Centred, bold, pixel font, white.
4. A stepper is `<` slab, value slab, `>` slab. A slider is a filled red bar
   with a value pill riding on it. A checkbox is a slab with a dark border
   and a red mark. Every control is built from the same slab.
5. The dialog closes with a **full width orange Back slab** along the bottom.
6. Spacing is generous and the type is big. There are maybe eight things on
   screen. Nothing is dense.

## The rule this gives us

> Everything is a slab: flat, outlined in near black, standing on a darker
> ledge with a soft shadow under it, so buttons read as objects sitting on a
> surface rather than tinted rectangles.

And the consequence that matters most here: **the loud background is only
affordable because the interface is solid.** I spent an afternoon dimming
the paint shader to make thin text readable over it. That was the wrong end
of the problem. Restore the shader and put the interface on trays.

## What this changes in our app

| Ours today | Balatro |
| --- | --- |
| Rows with a transparent fill and a 1pt border on focus | Slabs with a colour, an outline and a ledge, always |
| One pink accent for every state | A colour per role, pink reserved for the player's choice |
| Translucent surfaces so the backdrop shows through | Opaque trays so it does not |
| Left aligned label, value on the right | Centred label above its control |
| 24pt semibold sans title, left | Large bold pixel title |
| Soft radii, 1pt hairlines | Big radii, 2pt near black outlines |

Four screens are in scope: the main menu, settings, sources, and the room
you configure before playing. They already share `ScreenFrame`, `MenuRow`
and `TextFieldBox`, so the restyle is three atoms plus a palette, not four
screens rewritten.

## Typography

Balatro's own face is m6x11, which is not ours to ship. The font here is
**Pixelify Sans** by Eifetx, SIL Open Font License, a variable weight pixel
sans. It carries titles, labels, buttons and numbers. Paragraph text stays
in the system sans, because our app has explanatory sentences where Balatro
has none and a pixel font is unkind to them at thirteen points.
