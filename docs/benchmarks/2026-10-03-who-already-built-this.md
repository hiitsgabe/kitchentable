# Somebody already built our network, and we can read it

Looking for open source peer to peer video to borrow from turned up
something better than a video app: a library that is doing the exact thing
this app does, has been doing it longer, and has already hit every wall we
hit.

## Trystero

[Trystero](https://github.com/dmotz/trystero), MIT, JavaScript, last commit
27 September 2026, version 0.25.4. It makes WebRTC connections between
browsers with no server, by using somebody else's network as the place peers
find each other. It offers seven of those: BitTorrent trackers, **Nostr**,
MQTT, IPFS, Firebase, Supabase, and a websocket relay you host.

That is our architecture, written down by somebody who has maintained it for
five years.

It also does media. The whole of the API for a video call is:

```js
const stream = await navigator.mediaDevices.getUserMedia({audio: true, video: true})
room.addStream(stream)
```

Underneath, `peer.ts` is four lines of the thing everybody makes sound hard:

```js
addStream: stream => stream.getTracks().forEach(track => pc.addTrack(track, stream))
```

We cannot use it directly. It is JavaScript, and this app is Flutter on web
**and** phones; interop would cover half the targets. What we can use is
everything it knows.

## What it knows that we did not

These come from `packages/nostr/src/index.ts`, and every one of them is a
thing this app currently gets wrong. They matter whether or not voice is ever
built, because they are about the transport that already carries the game.

### 1. The event kind should come from the room, not be a constant

```js
const topicToKind = topic => (kindCache[topic] ??= strToNum(topic, 10_000) + 20_000)
```

Every room lands on its own kind, spread across the whole ephemeral range.
We send everything on a fixed **25050**, which is also the kind the
[NIP-RTC draft](https://ngengine.org/docs/nip-drafts/nip-RTC/) reserves for
WebRTC signalling. So we read every unrelated app's signalling off the wire
and filter it out by tag, and we pile every room in the world onto one kind.
Deriving the kind from the room code fixes both at once.

### 2. The busy relays are the wrong relays

Trystero ships **thirty** default relays and connects to
`defaultRedundancy = 5` of them. The list is worth reading: no damus, no
nos.lol, no primal. It is `nostr.purpura.cloud`, `relay.froth.zone`,
`schnorr.me`, `relay.mwaters.net`, thirty small ones nobody is fighting over.

We use the three busiest relays on the network, which is exactly why we have
been rate limited and banned by damus. The fix is not to be cleverer about
the budget. It is to stop queueing behind the whole of social media.

### 3. A refusal has a reason, and the reason decides what to do

It parses the prefix on `OK: false` and `CLOSED`:

- `rate-limited:` backs that relay off, starting at a minute and doubling to
  `maxRelayBackoffMs = 15 * 60_000`, fifteen minutes.
- `blocked:`, `restricted:`, `auth-required:`, `pow:` **retire the relay for
  good** and close the socket.
- `duplicate:` is swallowed silently, because it is not an error.

We learned the first half of this the hard way, that `OK: false` is a no and
not a yes. We do not yet do anything different depending on which no it is.

### 4. A repeated announcement needs a nonce

```js
// Relays deduplicate IDs, and created_at only has second precision. An
// intentional discovery retry must remain distinct from the previous send.
toJson({...payload, nonce: genId(8)})
```

Two identical beacons inside one second hash to the same event id, and the
relay drops the second as a duplicate. The retry that was supposed to find a
peer never leaves. We send presence beacons and we do not nonce them.

### 5. Announce rarely, and let arrivals do the work

`steadyAnnounceIntervalMs = 60_000`, with the comment: "Newcomers announce
immediately and wake subscribed incumbents, so the fast cadence is only
needed during startup." Presence is a heartbeat once a minute as a fallback,
not a poll.

### 6. Subscriptions get batched

`maxTopicsPerSubscription = 250`, with filters chunked across subscriptions.
We measured nos.lol and primal advertising `max_subscriptions: 20`. A client
that opens one subscription per thing it cares about runs out.

## What it does about the thing that cannot be solved

Its default ICE list is three Google STUN servers and Cloudflare's. **No
TURN.** The README says plainly that some networks will not allow a direct
connection and that you configure a TURN server yourself, listing Cloudflare
and Open Relay as hosted options and coturn, Pion, Violet and eturnal as
things you can run.

And when a connection fails, it looks at its own config before it blames the
network:

```js
`could not connect to peer ${peerId} after exchanging SDP; ${
  hasTurnServer(config)
    ? 'check that your TURN server URLs and credentials are reachable by both peers'
    : 'configure TURN servers with turnConfig or rtcConfig.iceServers'
}`
```

That is the same answer the rest of the research arrived at, from a library
with real users rather than from a judgement call: ship STUN, let the player
bring a relay, and say which case you are in. This app already has the field
for it in Settings, and a README that promises exactly this behaviour.

## The Flutter situation is better than it looked

There is no Dart Trystero, but there are two Flutter apps doing voice and
video calls signalled over Nostr, which is nearer still.

[**noscall**](https://github.com/sanah9/noscall) is the one to read. MIT,
29 stars, last pushed 16 September 2026, Flutter on five platforms, built on
`flutter_webrtc` and a Nostr library. Its `lib/call/` is laid out almost
exactly as ours would be:

| File | What it is |
| --- | --- |
| `web_rtc_handler.dart` | the peer connection: offer, answer, ICE, tracks |
| `calling_nostr_signal_sender.dart` | turning WebRTC signalling into Nostr events |
| `calling_controller.dart` | the state machine: ringing, accept, reject, hang up |
| `ice_server_manager.dart` | STUN and TURN configuration |

It is one to one, not a group. But it is MIT, it is alive, and it is the
same two libraries we already have.

[**0xchat**](https://github.com/0xchat-app/0xchat-app-main) is the one with
real users: a shipping Flutter Nostr messenger, funded, with calls that ring
like phone calls. The app is MIT but the part worth reading,
`0xchat-core`, is **LGPL-3.0**, and this project is MIT, so that one is to
learn from rather than lift.

Also worth knowing:

- [**peerdart**](https://pub.dev/packages/peerdart) is a PeerJS port with
  data and media, but PeerJS assumes a broker server.
- [**send_z**](https://github.com/semutKecil/send_z) signals over Nostr and
  moves files. GPL-3.0, data channel only.
- [**flutter_webrtc**](https://pub.dev/packages/flutter_webrtc) is already a
  dependency here and already lists audio, video and data on web, Android and
  iOS. Everything above sits on it.
- The clearest small group mesh in any language is still JavaScript:
  [anoek/webrtc-group-chat-example](https://github.com/anoek/webrtc-group-chat-example),
  one HTML file, a peer connection per other person. Its licence is reported
  as public domain and I could not confirm that from the API.
- Picking a draft is unavoidable. **NIP-100** is the older one and what 0xchat
  speaks; **NIP-AC** is newer, not compatible with it, and what noscall and
  Amethyst speak. Neither is a settled standard.

So the work, if it is ever done, is: Trystero's Nostr strategy for the relay
behaviour, noscall's `lib/call/` for the Flutter call mechanics, and
`flutter_webrtc` underneath. Not a rewrite. A reading list.

## The best Flutter reference also proves the TURN problem

`ice_server_manager.dart` in noscall opens like this:

```dart
List<ICEServerModel> get defaultICEServers => [
      url: 'turn:0xchat:Prettyvs511@52.76.210.159:5349',
      url: 'turn:0xchat:Prettyvs511@13.213.17.140:5349',
      url: 'turn:0xchat:Prettyvs511@15.222.242.167:5349',
```

A username, a password and three bare addresses, hardcoded in a public MIT
repository, pointing at relays somebody else is paying for. It does let the
player supply their own, and falls back to these.

That is exactly the outcome the rest of this research predicted, found in the
wild, in the most on-target app there is. The question was never whether
voice can be built without a server. It is what you do about the one piece
that needs one, and the honest answers are a credential anybody can read out
of your source, or asking the player to bring their own. This app already has
the field for the second.

## What to actually do with this

Six of the findings above are bugs in the transport that carries the game
today, and none of them has anything to do with voice:

1. Derive the kind from the room code, off the fixed 25050.
2. Replace the three busiest relays with a wide list of quiet ones, and
   connect to five.
3. Act on the refusal reason: back off a rate limit, retire a block.
4. Nonce repeated beacons.
5. Slow the steady announcement to a minute.
6. Batch subscriptions against a limit of twenty.

Those are worth doing on their own. Whether voice follows is a separate
decision, and the answer to it has not changed: the connection is the hard
part, nobody has solved it without somebody else's relay, and the honest
shape is to let the player bring one.
