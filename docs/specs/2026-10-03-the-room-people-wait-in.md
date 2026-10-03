# The room people wait in

Built on [the benchmark](../benchmarks/2026-10-03-waiting-rooms-and-invites.md):
Jackbox, Among Us, Board Game Arena, and what current lobby implementations
converge on. The author's verdict on the old screen: "código é irrelevante,
só QR code e link é", "a dinâmica de escolher o deck é até bacana, mas
precisa ser melhor explicada", "tem muita informação à toa".

## What it was

Twenty blocks, in this order: the code as a billboard, the raw URL as text,
a Copy row, the QR, the relay fact, a refusal fact, the STUN fact, a fact
per connected peer, a fact per seen peer, a fact per failed peer, the TURN
paragraph, a guest note, the chairs, the build stamp, five lines about
privacy, a full-room note, a dealt note, the deck row, Start, and the
fill-chairs row. The chairs, which are what a lobby is, sat thirteen blocks
down. Start, which is what a host came to press, was below the fold.

## What it is

**The chairs first**, as a card: a numbered row each, who is in it, and what
it is waiting for ("pick a deck to sit down", "waiting for somebody",
"ready"), with a count in the corner. Somebody who has connected and not yet
brought a deck has a row of their own, because an arrival is the thing a
host is waiting on. This is Jackbox's avatar popping in and Among Us's
player list: the lobby is the people.

**One invitation, in two forms that work on a phone.** A Send the link row
(copies it), then the QR square beside the code. The benchmark's words:
"the two real invite flows are the OS share sheet and a QR code; copying a
URL and switching apps is the highest-friction path". The code stays, small,
for reading out loud. The raw URL as printed text is gone: too long to read
out, worse to retype.

**The deck step, explained.** "Pick your deck: everybody brings their own.
Yours takes a chair, and the game starts once every chair has one." It is
the primary row and it is autofocused.

**Start carries its reason**, as it already did: "waiting on chairs 1, 2, 3
and 4" rather than a grey button with no explanation. Among Us colours a
count for the same reason.

**The connection is one line while it works**, and nothing once it does: a
relay that took the room is not news. It says more only when something is
wrong, and the failures keep their full sentences. No STUN line: nobody puts
one in a lobby.

**Privacy is one line**, not five.

## Room names

Nobody is ever asked to name a room. The name box opens holding one of a
hundred, in the app's voice: The Kitchen Table, The Back Room, Sunday Night,
Cold Pizza, One More Round, Shuffle Up, The Pod. The host can type over it.
An empty box asking for a name is the thing this exists to stop.

## Measured

On a 390 by 844 phone the chairs are the first thing under the title, the
invitation is one screen-third, and Start is on the first screen with four
chairs. It was at about 1300 points, below five paragraphs.

## The code is hidden, and the aside is a line

Two rulings from the author after the first pass:

- **The room is a link, so the code is noise.** "Não precisa mostrar código
  da sala, porque a sala é por link, não é por código." The code is off the
  screen: you send the link, or somebody scans the square. It survives in
  exactly one place, the build that is served nowhere and therefore has no
  link to send, where it is the only way in.
- **Filling the other chairs from this device is a line, not a row.** "Não
  precisa ser um botão... porque tá dando muita importância." As a row with
  an icon it stood level with Start and read as an equal way to play. It is
  now one underlined line, "Nobody coming? Play all 4 hands here", under
  everything else.

## Still open: there is no way to play without making a room

Found while answering what the fill-chairs row was for. `PlayDecksScreen` is
only ever opened from the room, so the single-deck path in it (`start(deck)`,
no lobby) is unreachable, and filling the chairs from one device is the de
facto solo mode, hidden inside a room it contradicts. The room should mean
other people on their own phones; playing by yourself, or several hands on
one device, wants its own way in from the menu.
