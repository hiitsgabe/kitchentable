# A table you can invite people to

## What the entry does today, and why it is backwards

Menu, Play, pick a deck, and a table exists. The table is **created by choosing
a deck**, which means there is never a moment where a room exists and nobody is
playing yet. There is nothing to share and nothing to join: the only table you
can reach is the one you just made by yourself.

The order has to be the other way round. A room is a place. You make the place,
you invite people to it, and then everybody brings a deck.

## What it becomes

**Start a table.** You configure it: format and how many seats, starting life,
your name, and a name for the room. The room now exists and has a code. You get
a link and a QR code for it. Then you pick your deck and sit down.

**Join a table.** You paste a link or open one, or scan the QR. You see the
room's name and who is already in it. You pick your deck and sit down.

The link is `<origin>/#room=<code>`, which the design settled: it carries a
**name rather than an address**, so it needs no DNS of ours, no tunnel, no open
port and no server, and it works in both directions and more than once.

A code is short and typable, because somebody will read it out loud across a
kitchen table rather than send it. Case insensitive, and from an alphabet with
no character that can be misheard or misread as another.

## The wire, which is the actual work

`apply(TableState, TableAction)` is already a pure reducer, and every id and
every die roll is minted by the caller rather than inside it. That is what
makes replication possible at all: the same action applied to the same state
gives the same state on every device, so peers exchange **actions**, not
screens.

**Nothing in `lib/table/` serializes today.** That is the first task and the
backbone of the rest: a wire format for every `TableAction`, and one for
`TableState` so a peer arriving late can be handed the game so far.

The risk in it is not writing it, it is the version after: a peer running an
older build must be told so rather than silently dropping a verb it has never
heard of. The format carries a version, and an unknown verb is an error that
says so, not a no-op.

## Rendezvous and mesh

Nostr for introductions, WebRTC for the game, per the design. The relay sees a
handshake and never sees a table.

Whoever made the room is the host. The host **stamps** each peer with a
monotonic number at handshake, and succession reads that stamp rather than
anything a peer says about itself, because a peer that gets to describe its own
seniority can claim to be first and take the table.

## What this slice does not do, and must say so on the screen

The design's answer for hidden information is two layers deep: hands encrypted
to their owner, and a library nobody can read including its owner, shuffled by
the neighbours on each side.

**None of that is in this slice.** Everything replicates in the clear. A peer
holds every hand and every library, and `ZoneVisibility` is what stops them
being drawn on screen, which is a decision made by software running on somebody
else's phone.

That is a fine way to play with friends and it is not what a security promise
sounds like, so the room screen says it in one plain line rather than leaving
it to be assumed. The alternative is shipping something that looks private and
is not, which is worse than shipping something honest and limited.

## What cannot be tested in here

Two phones on two networks. No widget test proves a WebRTC connection, and a
green suite is not evidence that anybody connected.

What the tests do cover: the wire format both ways, the room code and the link,
the join flow, the succession order, and the mesh's own logic driven through a
fake transport. What has to be checked by hand, on two real devices, is the
connection itself, and the plan says so at the step where it becomes true.
