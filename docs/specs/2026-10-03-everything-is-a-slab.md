# Everything is a slab

What the app looks like, after reading Balatro's own screens. The reading is
in `docs/benchmarks/2026-10-03-balatro-ui.md`; this is what was built from
it.

The complaint being answered is one sentence: "tá muito com cara de AI". It
was right, and it was not about any one screen. Thin borders that only appear
on focus, one pink tinting four states, translucent surfaces, a sans serif at
three weights, correct spacing everywhere. Every screen looked like a
settings pane.

## The three pieces

**A slab** is anything you can press. Flat saturated fill, a near black
outline two points wide, and a darker strip of its own colour along the
bottom. The strip is the illusion: it reads as the side of a tile with a
thickness, so the control is an object lying on a surface. Pressing it slides
the face down into its own ledge, which is why the press is felt. Focus is a
white outline, not the only thing that makes the control visible.

**A tray** is the opaque thing everything stands in: dark slate, a light two
point border, a big radius, a soft shadow under it. It ends where its
contents end.

**A well** is a hole cut in a tray, for anything read rather than pressed: a
text box, a group of facts, the number in a stepper, the QR square. Slabs go
up off the surface and wells go down into it, so the surface means something.

## What this settles about the background

The swirling paint runs at nearly full contrast. An afternoon went into
dimming it so that thin text could be read over it, which was the wrong end
of the problem: the reference's background is louder than ours and its
interface is perfectly legible, because its interface is solid. The shader is
back at the lighting the original port had, and the trays are what make it
readable.

## Colour is a role

The reference gives each important button its own saturated colour rather
than tinting one accent four ways. No two things you might press by accident
look alike.

| Tone | Where |
| --- | --- |
| choice | Play, Make the room, Pick your deck, Look, the wizard's Next and Done. Takes the colour the player chose. |
| cool | Join, Send the link, Start, Sources, a source that works |
| warm | Back, Settings |
| hot | reserved for something that cannot be undone |
| plain | everything else |

Exactly one slab per screen carries `choice`. If a screen has two dominant
actions it has none.

## Type

Pixelify Sans by Eifetx, SIL Open Font License, in `fonts/`. It is a variable
font, so its weight is an axis and `FontWeight` does nothing to it at all:
`pixel()` in `lib/ui/tokens/lettering.dart` is the only thing that knows
that. Sizes round to whole points, because a pixel font at 13.4 points has
its grid resampled and goes soft.

Letters on a slab are white, heavy, and carry three hard shadows in the slab
edge colour, which reads as an outline at this size and costs nothing. Titles
and buttons are capitals. Names people typed are not.

## What changed where

Four screens were in scope and none of them was rewritten. They share
`ScreenFrame`, `MenuRow` and `TextFieldBox`, so the work was three atoms, two
new ones and a palette:

- `ui/atoms/slab.dart`, `ui/atoms/tray.dart` (tray, label and well)
- `ui/tokens/lettering.dart`, and the second half of `ui/tokens/palette.dart`
- `MenuRow` became a slab, `TextFieldBox` became a well, `ScreenFrame` grew a
  tray and moved Back to a slab along the bottom where the reference puts it

Two things were found on the way and are worth keeping:

- A `Border` with one thick side cannot carry a `borderRadius` in Flutter. In
  a debug build it says so; in a release build it draws something else. The
  well's left bar is a box behind the hole, not a border on it.
- `Slab` separates `enabled` from `dimmed`. The seat stepper has to look dead
  at the end of its range while still calling its own clamp, because a button
  that refused to call it would hide a broken clamp behind a disabled button.
