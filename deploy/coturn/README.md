# A relay for the connection, for when the networks will not let two phones through

Two phones on one Wi-Fi reach each other on their own. A phone on a
carrier's network against a home router usually cannot, whatever either
phone does: the carrier's NAT hands out a different port for every
destination and the home router only lets in what it saw go out. The room
screen says exactly this when it happens ("no route was found between the
two phones"), and the fix is a TURN server: a machine on the internet both
phones can reach, which forwards the encrypted bytes between them and sees
nothing else.

One player's server is enough for a room. Put it in Settings, under
Network, on that player's phone; the room announces it and every other
phone makes its links through it.

This folder runs one. Any VPS with a public address will do; a small one
is plenty, a game is a few kilobytes a second.

## Run it

```
cp turnserver.conf.example turnserver.conf
$EDITOR turnserver.conf     # realm, the public address, the user
docker compose up -d
```

Open UDP and TCP 3478 on the machine's firewall, and UDP 49160 to 49200
for the relayed traffic (the range is set in the config; widen it for
more than a handful of rooms at once).

## Put it in the app

In Settings, under Network:

- URL: `turn:your.host.example:3478`
- username and password: the `user=` line in the config

The room screen's TURN line goes away on the next link, and "Ours:" in a
failure sentence, if there ever is one again, will count a `relay`
candidate.
