# Benchmark: how games run a waiting room, and how people get invited to one

The room screen has grown to about twenty blocks and the author's verdict is
that most of it is noise: "código é irrelevante, só QR code e link é", "a
dinâmica de escolher o deck é até bacana, mas precisa ser melhor explicada",
"tem muita informação à toa". This reads how the established party and board
games do the same screen.

## The products

### Jackbox
Source: [How to play](https://www.jackboxgames.com/how-to-play)

- The lobby is the code and the players, and nothing else. "All games start
  in a lobby with the room code displayed on screen", four letters, top of
  screen, high contrast.
- "Upon successfully joining, the player's chosen nickname and a randomly
  assigned character avatar will pop up on the host's main screen." The
  arrival is the feedback; there is no status log.
- "The first player to join is designated the VIP and is given the on-screen
  button to start the game." One person starts, and it is obvious who.
- The code is big **because the host's screen is a television across the
  room** and the guests type it on their own phones. That is the opposite of
  our case: our host screen is the same phone that sends the link.

### Among Us
Source: [Lobby](https://among-us.fandom.com/wiki/Lobby),
[Start](https://among-us.fandom.com/wiki/Start)

- The lobby shows "the current room code, the number of players in the
  lobby, and a chat box", and the players standing in the room.
- The start button exists only for the host and is gated: "there must be at
  least four players in the lobby", and the player counter is coloured red,
  yellow, green to say how close you are. The gate explains itself with a
  number, not with a disabled grey.
- Pressing start runs a five second countdown visible to everybody.

### Board Game Arena
Source: [Forum: configuring a new table](https://forum.boardgamearena.com/viewtopic.php?t=14782)

- Making a table and waiting at it are two screens: "Create a new table",
  then "Configuring a new game table" where the options are set.
- The waiting table shows the seats and how many are open, and that count is
  what other people browse by. Seats, not diagnostics.

### What current lobby implementations converge on
Sources: [arkanoid-multiplayer PR 26](https://github.com/Guisardo/arkanoid-multiplayer/pull/26),
[issue 101](https://github.com/Guisardo/arkanoid-multiplayer/issues/101),
[Modern-Trivia PR 202](https://github.com/sfigas01/Modern-Trivia/pull/202),
[the-system PR 4](https://github.com/sidharth18jam/the-system/pull/4)

- "The host's Start button should be disabled until every player marks
  ready", and the disabled state carries its reason: "Need at least 2
  players".
- "A 220px QR code on a white tile; the white border is needed for
  scanning", plus "a Share invite link button that opens the native share
  sheet and falls back to the clipboard".
- The guest's side says "Waiting for host to start…" and nothing else.
- Seats carry a status each: Ready, Reconnecting, Offline.
- A code arriving in the link is pre-filled and focus moves past it: "Code
  filled in from your invite. Just add a nickname to join."

### The mobile invite rule
Source: [an invite-flow issue stating it plainly](https://github.com/mentria-ai/website/issues/1180)

> "On phones, the two real invite flows are missing: the OS share sheet (send
> the link straight to any messenger) and a QR code (two people in the same
> room, scan, done). Copying a URL and switching apps to paste it is the
> highest-friction path."

That sentence is the author's complaint, from the other direction. We lead
with the highest-friction path (a code to read out, a URL printed as text,
a Copy row) and bury the two that work.

### Room names
Sources: [adjective-noun room names PR](https://github.com/IHTFY/Empire/pull/77),
[Empire's generator](https://www.brightful.me/blog/random-word-generator/)

- The pattern is a curated pair of lists, "about 130 friendly adjectives and
  130 easy-to-picture nouns (animals, food, everyday things)", giving
  `worried-hamster`, `tiny-narwhal`. Pronounceable, memorable, never empty.
- The point is that **nobody is ever asked to name a room**. A name is there
  when the screen opens and can be typed over.

## What they agree on, and what it means here

1. **The lobby is the people.** Jackbox pops avatars in, Among Us stands them
   in the room, BGA counts the open seats. Our chairs list is buried under
   ten lines of transport diagnostics. The chairs go to the top.
2. **One invite action, not three.** Share sheet first, QR second for the
   person sitting opposite. The code is a fallback for reading out loud, and
   belongs small. The raw URL as printed text serves nobody: it is too long
   to read out and worse to retype.
3. **The start button carries its own reason.** "Waiting for Carla to pick a
   deck" beats a grey button, and a count beats both.
4. **The guest's screen is almost empty**: who is here, what the host set up,
   and what is being waited on.
5. **Diagnostics are not lobby furniture.** Nobody shows a STUN line. One
   line of state, and the detail only when something fails.
6. **A room is named before you arrive at it**, and the name is editable.

## What this costs us today, counted

The host's room screen renders, in order: the code block, the raw link, a
Copy row, the QR, the relay fact, a refusal fact, the STUN fact, a fact per
open peer, a fact per seen peer, a fact per failed peer, the TURN
paragraph, the guest answer note, the chairs, the build stamp, a
five-line paragraph about privacy, a full-room note, a dealt note, the deck
row, the start row, and the fill-chairs row. Twenty blocks, of which two are
the invitation and one is the thing you came to do.

On a 390 by 844 phone the chairs sit at about 1300 points down a scrolling
page: below the fold, under the QR, under five lines of prose. The first
thing a host wants to see when a friend joins is the thing furthest from
their eye.
