# Settings, grouped, and the two features that did not work

Built on [the benchmark](../benchmarks/2026-10-03-settings-screens.md).

## The screen

One flat list became groups, which is the benchmark's first rule and its
fourth: "break dense pages into clear sections with descriptive headings",
"keep the number of top-level categories to four or five", "for 15 or more
settings, group related settings under a subscreen".

- **YOU**: your name, inline, because it is one field and the one people
  change.
- **THE APP**: Look, Sources, Network, and a way to run the first-run setup
  again. Four rows, each a subscreen.

Network is the progressive-disclosure case: three TURN fields nobody fills in
unless the room has told them to, and they were half of the settings screen.
They have their own screen now, with the sentence explaining when they matter
and a pointer at `deploy/coturn`.

## The colour now reaches the app

The complaint: "mudar de cor só muda o fundo, não muda bordas e etc durante
menus e jogo". True, and structural. `Palette.accent` was the literal pink
`0xFFFF2E88`, a `static const`; the colour picker wrote `BackdropStyle.top`,
which only the `Backdrop` widget read. Picking teal painted a teal background
behind a pink app.

`AppPalette` is a `ThemeExtension` carrying the three colours that are the
accent family: `accent`, `focusWash` and `tileFocused`, the last two derived
by dragging the accent most of the way back into the dark, which is what the
hand-written pink ones were. `app.dart` builds the theme from the picked
colour, so Flutter rebuilds what depends on it.

Of the 321 `Palette.` references, 45 across 20 files were the accent family
and those became `context.palette`. The greys stayed `const`: they are
neutral and read the same under any accent, and 276 more call sites changed
for no visible gain is how a refactor breaks something. The one site with no
`BuildContext` is the dice painter, which is handed the colour instead.

## "Your own picture" can now be given a picture

`BackdropKind.image` drew `Image.file(style.imagePath)` and nothing in the
app ever set `imagePath`. The option could be chosen, stored nothing, and
fell back to the flat gradient in silence.

The backdrop screen now offers a chooser, a preview of what was picked, and a
way to remove it. The picture is stored as the bytes rather than a path:
a browser hands out a handle to a file, not a name, and the handle dies with
the tab. It is drawn into a canvas at no more than 1600 on its longest side
and read back as JPEG first, because a photo straight off a camera would fill
the preference store on its own.

The chooser is the conditional export this codebase already uses for the
catalog, the gunzip and the launch URL: the browser's file input on web,
and on a phone build `canPickImage` is false and the screen says the chooser
is web-only rather than drawing a button that opens nothing. That is the
honest state: a phone chooser is a plugin this app does not carry, and
adding it pulls nine packages for one feature.

## Still open

- A phone build cannot pick a picture. It needs a file-chooser plugin.
- The colour choice is six presets. A full picker was judged "a lot of screen
  for a decision most people make once" and that still holds.
