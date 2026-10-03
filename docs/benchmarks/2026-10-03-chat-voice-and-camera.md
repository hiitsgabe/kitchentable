# Can this thing carry chat, voice and a camera?

The question is whether the app's own network can carry text chat, voice and
video, under the rule that the author runs no server, ever.

The short answer is that text is free, voice is possible but not without
somebody else's infrastructure, and camera video is not worth attempting.

## What the network actually is today

The README still says the game runs over WebRTC in a star with no relay.
That has not been true since the relay transport landed: `lobby.dart` builds
a `RelayTransport`, and every move travels as a signed Nostr event through
three public relays. `WebRtcTransport` is still in the tree and nothing
constructs it.

That matters here, because it means the P2P link people assume exists is the
one piece that was taken out for not working, and voice is the one feature
that would need it back.

## What the relays will take

Read off the three relays the app uses, by asking them (NIP-11):

| Relay | software | max_message_length | max_subscriptions |
| --- | --- | --- | --- |
| relay.damus.io | strfry 1.1.0 | 1,000,000 | 200 |
| nos.lol | strfry 1.1.3 | 131,072 | 20 |
| relay.primal.net | strfry 1.0.3 | 1,000,000 | 20 |

All three run [strfry](https://github.com/hoytech/strfry/blob/master/strfry.conf),
whose config caps a single event at `maxEventSize = 65536` separately from
the websocket frame. So **64 KB is the number to design against**, not the
megabyte two of them advertise.

Measured against that, by building the envelope the app actually sends:

| What | Bytes on the wire |
| --- | --- |
| One game move today | 641 |
| A hundred character chat line, plaintext | 580 |
| The same line, NIP-44 encrypted | 705 |
| The same line, NIP-17 gift wrapped | about 1,200, and one event per person |
| Three seconds of Opus at 24 kbps, base64 | about 12,000 |
| A 640x480 JPEG photo, base64 | about 45,000 |

Four hundred and eighty of those 641 bytes are the signature, the id and the
public key. The payload is the small part.

**Size is not the constraint. Rate is.** strfry ships with no rate limiting
and every operator adds a plugin:
[noteguard](https://github.com/damus-io/noteguard) counts notes per minute
per IP, [strfry-ratelimit](https://github.com/kojira/strfry-ratelimit) bans
per pubkey and **singles ephemeral events out for a tighter bucket of their
own**, and [strfrui](https://github.com/jiftechnify/strfrui)'s example allows
two events a second with a burst of five.
[nostr-rs-relay](https://github.com/scsibug/nostr-rs-relay/blob/master/config.toml)
offers `messages_per_sec = 5`. Nobody publishes damus's real number, and the
app has already been rate-limited and banned by it, so the working budget is
**a couple of events a second, shared by everything the room sends.**

Ephemeral kinds are not a loophole. NIP-01 gives them no special size or rate
treatment, and one of the two popular limiter plugins treats a flood of them
as the thing to ban.

## Text chat

Yes, now, over what is already there. A line costs about the same as a move,
and people type far less often than they tap cards.

One thing has to change with it. **Everything in a room is plaintext on
public relays today.** Nothing in `lib/net/` encrypts anything; the room code
is the only secret, and it is in the `d` tag of every event in the clear. A
stranger subscribing to kind 25050 sees every move at every table. For card
moves that is boring. For what people type to each other it is not, so chat
should be sealed, and the honest thing is to seal the whole room.

[NIP-04 is deprecated](https://github.com/nostr-protocol/nips/blob/master/17.md);
the current pair is [NIP-44](https://github.com/nostr-protocol/nips/blob/master/44.md)
for the encryption and [NIP-59](https://github.com/nostr-protocol/nips/blob/master/59.md)
gift wrap for hiding who is talking to whom. Gift wrap doubles the size and
costs one event per recipient, which at a four seat table is three events per
line, against a budget of two a second. NIP-44 alone over a key derived from
the room code costs 705 bytes and one event, and hides the content from
everybody who is not at the table. That is the right trade here: the room
code is already the secret that lets you in.

## A collision worth knowing about

The app's `roomDataKind` is **25050**. That is the same kind the
[NIP-RTC draft](https://ngengine.org/docs/nip-drafts/nip-RTC/) reserves for
WebRTC signalling, used by the Nostr Game Engine. Two unrelated protocols are
sharing a kind on the same public relays. The `d` tag filter means the app
never acts on theirs, but it reads them off the wire, and anything they do to
that kind's reputation lands on this app.

## Voice

**It cannot ride the relays.** Opus at 24 kbps is 3 KB a second, which in
one-second chunks is four events a second from every person talking, against
a budget of about two for the whole room. The only project that genuinely
pushes audio through relays,
[Nostr-Voice-Chat](https://github.com/Giszmo/Nostr-Voice-Chat), is an
unencrypted proof of concept. Every production Nostr voice and video app,
[HiveTalk](https://github.com/hivetalk/hivetalksfu) included, moves the media
to WebRTC or an SFU and keeps relays for signalling.

**So it has to be WebRTC media, which is the path that already failed here.**
Published measurements put the share of connections that need a TURN relay at
[around 20 to 25 percent](https://getstream.io/resources/projects/webrtc/advanced/stun-turn/),
[about 22 percent of conferences](https://webrtchacks.com/usage-stats/), and
[anywhere from nothing to half depending on the user base](https://bloggeek.me/webrtc-turn/),
with symmetric NAT and mobile carriers driving the high end. That is the same
wall the data path hit.

**Audio is not easier to connect than video.** They share one ICE negotiation
and one five-tuple under BUNDLE, so whatever fraction fails, fails for both.
Audio is only cheaper once connected.

The bandwidth is genuinely small. Four people on voice for two hours is about
0.35 GB of media, 0.7 GB if every stream is relayed. The relays that would
carry it:

| | Free | Then | Account needed |
| --- | --- | --- | --- |
| [Cloudflare Realtime](https://developers.cloudflare.com/realtime/sfu/platform/pricing/) | 1 TB a month | $0.05/GB | yes, with API issued short-lived credentials |
| [Metered Open Relay](https://www.metered.ca/tools/openrelay/) | 20 GB a month, 0.5 GB without a card | $0.40 down to $0.10/GB | yes |
| [Xirsys](https://xirsys.com/pricing) | 500 MB a month | paid tiers | yes |
| [Twilio](https://www.twilio.com/en-us/stun-turn/pricing) | none | $0.40/GB | yes |

So the money is not the problem: a whole evening of voice is half a gigabyte
and every one of these would carry it for nothing. **The account is the
problem.** Every one of them needs the author to hold one and to ship
credentials inside the app, where anybody can take them. That is not a server
the author runs, and it is not nothing either.

The app already has a TURN field in Settings, and that is the honest shape:
a user who has one gets voice that works, everybody else gets voice that
works about four times in five. The
[NIP-AC drafts](https://github.com/nostr-protocol/nips/pull/2301) for voice
over Nostr propose exactly this, that the user picks the relay rather than
the app shipping one.

The client side is ready, for what it is worth. The app already depends on
[flutter_webrtc 1.6.2](https://pub.dev/packages/flutter_webrtc), which lists
audio, video and data channels on web, Android and iOS, and on the web it is
a thin wrapper over the browser's own WebRTC, so capture genuinely works
where the browser supports it. Safari is the weak spot, as usual. Nothing in
the package is the obstacle.

## Push to talk, which is the interesting middle

Three seconds of Opus is 12 KB base64, a fifth of the event cap, and it is
**one event instead of four a second**. That fits the relay budget, needs no
WebRTC, no TURN, no account, and works for everybody the game already works
for.

It is a walkie-talkie and not a call, and that is a real difference. But it
is the only voice this architecture can carry on its own.

## Camera

No.

- A four person mesh means every phone encodes three outbound video streams.
  Field reports put [unoptimised mesh video at four peers already CPU bound](https://nat.io/blog/scaling-webrtc-applications),
  and four to six is the practical ceiling.
- Four people on 720p for two hours is about 16 GB of media, up to 32 GB if
  it relays. That is every free tier gone in a single evening.
- It needs the same TURN that voice needs, for the same fraction of people.

A still photograph is a different question and the answer there is yes: a
640x480 JPEG is 45 KB base64, under the cap, one event. "Show me your board"
is reachable. A camera window is not.

## What everybody else in this category does

This is the part that should decide it.

- **Owlbear Rodeo** has no voice chat. Its
  [own README](https://github.com/owlbear-rodeo/owlbear-rodeo-legacy) uses
  WebRTC for one thing, moving custom images between players, and says of it:
  "in order to navigate some networks you must define a STUN/TURN server".
  They also report it being blocked by VPNs, antivirus and ISPs. That is a
  second tabletop app reaching the same conclusion about WebRTC that this one
  did, for data, not even for media.
  [Their audio project](https://github.com/owlbear-rodeo/kenku-fm) is for the
  host to share music into Discord, not for talking.
- **Foundry VTT** ships no hosted audio or video. Its popular voice modules,
  [Speaking Status](https://foundryvtt.com/packages/speaking-status) and
  [Discord Rich Presence](https://foundryvtt.com/packages/discord-rich-presence),
  do not carry voice at all: they read a Discord channel to show who is
  talking.
- **Roll20** runs [its own hosted WebRTC voice and video](https://help.roll20.net/hc/en-us/articles/360041544734-Integrated-Voice-and-Video),
  and [then partnered with Discord](https://www.enworld.org/threads/roll20-announces-discord-activity-integration.703877/)
  so the tabletop runs as a Discord Activity using Discord's audio, because
  most groups were on Discord anyway.
- **Tabletop Simulator** has proximity voice built in, and
  [its own players call it borderline useless](https://steamcommunity.com/app/286160/discussions/0/3180107161581784627/)
  and tab out to Discord.

The normal answer in this category is either not to build it, or to build it
and watch people use Discord regardless. Both tools that built it are now
routing through somebody else's voice. **No tabletop tool was found that
delivers working voice while its developer runs nothing.**

### And meet.jit.si is not the loophole

Embedding meet.jit.si in another app
[stopped being supported in April 2023](https://community.jitsi.org/t/important-embedding-meet-jit-si-in-your-web-app-will-no-longer-be-supported-please-use-jaas/123003),
and since 18 May 2023 an embedded call **disconnects after five minutes**,
because embedding is "only meant for demo purposes". A web view is therefore
out. Opening `meet.jit.si/<room code>` in the system browser is a different
thing and still works, but then it is an external link exactly like telling
people to use Discord, not a feature of the app. Their terms are also as-is
and withdrawable without notice, and
[the terms page itself](https://jitsi.org/meet-jit-si-terms-of-service/)
assumes third party integrations exist only to require their branding be
shown for fifteen seconds.

## "Serverless" always means somebody else's server

Worth saying plainly, because the apps that advertise it are the ones a
search turns up first:

- **Jami** is peer to peer over a DHT, and ships a default bootstrap node and
  a [default TURN relay](https://docs.jami.net/en_US/developer/going-further/setting-up-your-own-turn-server.html),
  both run by Savoir-faire Linux, used whenever direct fails.
- **Tox** uses a DHT plus TCP relay nodes run by volunteers, so it works as
  well as the volunteer set is doing that month.
- **Keet**, the loudest "serverless video" claim, hole-punches over
  [HyperDHT](https://docs.pears.com/building-blocks/hyperdht), falls back to a
  blind relay, and depends on three public bootstrap nodes operated by
  Holepunch. Reviewers report calls "don't always go through, you'll get
  through in 1-3 tries". Its only Dart binding,
  [flutter_pear](https://pub.dev/packages/flutter_pear), is unofficial, below
  1.0, and runs its logic in a native JavaScript runtime that does not exist
  in a browser, so there is no web story at all.
- **Session**, which onion routes its messages, does not onion route its
  calls: [they are plain WebRTC through a foundation-operated STUN and TURN](https://getsession.org/faq),
  which also means the call hands your address to the other side. Calls are
  beta and off by default.
- **Briar** is the honest one: it is text only and has no voice or video.

None of these is a counterexample. They are all the same arrangement this app
would be making: not the author's server, but a server.

## What this adds up to

1. **Text chat, over the relay, encrypted.** Costs nothing new and the
   architecture already carries it. Encrypting it means encrypting the room,
   which is overdue anyway.
2. **Push to talk, over the relay.** The only voice this network can carry by
   itself, for everybody, with no account anywhere.
3. **Live voice, over WebRTC, best effort, off by default**, using the TURN
   field that already exists. No credentials shipped. It will work for most
   pairs and say so plainly when it does not, which is what the app already
   does about connections.
4. **No camera.** A photograph of the table, maybe. A video call, no.
