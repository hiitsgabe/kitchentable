# Benchmark: settings screens, and what a theme is supposed to reach

Settings today is one flat list: a name field, three TURN fields, a Sources
row and a Background row, with no sections and no hierarchy. Two of its
features also do not work: picking a colour changes only the background, and
"your own picture" has no way to pick a picture.

## How settings screens are built

Sources: [Android settings patterns](https://developer.android.com/design/ui/mobile/guides/patterns/settings),
[Toptal, settings UX](https://www.toptal.com/designers/ux/settings-ux),
[setproduct, why users can't find what they need](https://www.setproduct.com/blog/settings-ui-design),
[Uxcel, mobile settings](https://uxcel.com/lessons/mobile-settings-745)

1. **Group by proximity, and name the groups in plain language.** "Place
   related settings close together and keep unrelated ones apart... write
   category headings in plain language and skip technical terms that only
   developers know."
2. **Do not present settings as one continuous list.** "Avoid presenting
   settings as one continuous list or relying too heavily on divider lines;
   break dense pages into clear sections with descriptive headings and use
   white space as a natural divider."
3. **Four or five top-level categories.** "Keep the number of top-level
   categories to four or five." And: "for 15 or more settings, group related
   settings under a subscreen."
4. **Progressive disclosure.** "Primary settings visible to everyone that
   cover common needs; advanced settings hidden under Advanced Settings."
5. **People scan rather than read**, so hierarchy decides what is found.

## How games group them

Sources: [Game UI Database, settings menus](https://www.gameuidatabase.com/index.php?scrn=26),
[Indieklem, intuitive in-game menus](https://indieklem.com/9-creating-an-intuitive-in-game-menu/)

- The standing categories are Gameplay, Display, Audio, UI and Accessibility,
  Language. Ours has no audio and no controls, so the shape that fits is
  **who you are, how it looks, where the cards come from, and the network**.
- "Group related menu items together... keep fewer than 6 or 7 items at the
  top level."
- "Enhance visual recognition with icons representing different categories."
- Progressive disclosure again: reveal advanced options gradually.

## What a colour choice is supposed to reach

This is the author's complaint, and it is a correctness question rather than
a taste one: "mudar de cor só muda o fundo, não muda bordas e etc durante
menus e jogo".

Read against the code, they are right and the cause is structural:

- `Palette` is a set of `static const` colours. `accent` is the literal pink
  `0xFFFF2E88`, and so are `focusWash` and `tileFocused`, which are the pink
  bled into a fill.
- The colour picker writes `BackdropStyle.top` and `bottom`, and the only
  widget that reads those is `Backdrop`, the thing painted behind everything.
- So every focus ring, every selected row, the Play button, the room's accent
  border, the player's own board edge, the counters and the chips stay pink
  whatever is picked. Picking "Teal on black" paints a teal background behind
  a pink app.

There are 321 `Palette.` references across 37 files, but only **45** across
20 files are the accent family (`accent`, `focusWash`, `tileFocused`). The
greys are neutral and work under any accent; the accent family is exactly
what the author means by "bordas e etc". That is the part that has to become
live, and it is small enough to do properly rather than with a global
mutable.

## What "your own picture" does today

`BackdropKind.image` renders `_Picture`, which reads `style.imagePath` and
calls `Image.file`. Nothing anywhere in the app ever sets `imagePath`: the
backdrop screen offers the effect and six colour swatches and no file row at
all. So the option can be chosen, stores nothing, and silently falls back to
the flat gradient. On the web it falls back by construction, since
`Image.file` has no file system to read.

A picker is the missing half. It has to work on the web, where the app is
actually being used today, which means bytes rather than a path.
