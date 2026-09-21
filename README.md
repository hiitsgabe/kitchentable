# kitchentable

A card table for playing with friends who are somewhere else.

You bring the cards. The app brings the table, the shuffler, the dice and the
connection. Nobody runs a server, nobody makes an account, and nothing is sold.

## The idea

"Kitchen table" is what people call the version of a card game you play at home
with friends. No judge, no clock, no sanctioning. If a rule comes up, somebody
reads the card out loud and the table agrees on what it means. That is the game
this app is for.

So kitchentable does not know the rules, and that is a decision, not a gap. It
knows how to move a card from one pile to another, rotate it, flip it, put a
counter on it, attach something to it, shuffle a deck and deal a hand. Eleven
verbs, give or take. It turns out that is enough to play Magic, and enough to
play Pokemon, because every tabletop card game is piles of cards with state on
them.

Later, a rules engine can be plugged in behind the table as a referee. The
seam is there from the start. It is not there yet.

## What it is not

It is not a card database. The app ships empty and makes no network request
until you explicitly switch a source on. It has no cards bundled, no images
bundled, and no default that phones home.

It is not a store, a marketplace or a subscription. It never will be.

It is not affiliated with, endorsed by or approved by Wizards of the Coast,
Hasbro, The Pokemon Company or Nintendo. Card names, card text and card images
belong to their publishers. You point the app at a data source, and what
arrives on your device came from you asking for it.

## Where the cards come from

Nowhere, until you say so. The plan is to support importing a local dump and
pointing at a public data set, both switched on by hand, both off by default.
[MTGJSON](https://mtgjson.com/) and [Scryfall](https://scryfall.com/) for Magic,
[pokemon-tcg-data](https://github.com/PokemonTCG/pokemon-tcg-data) for Pokemon.

This is also why the app survives its data sources. The Pokemon TCG API is
scheduled to go offline in March 2027. The raw data behind it is a git
repository and will outlive the API. Importing instead of calling is not a
compromise here, it is the robust option.

## How two phones find each other

WebRTC, in a star. Whoever starts the game holds the state and every other
player connects to them, so a pod of four is three pairings instead of six. The
handshake is a short code or a QR, passed around however you already talk to
your friends.

There is no signaling server and no lobby service. About one connection in ten
lands behind a NAT that refuses to cooperate, and those need a relay. When that
happens you plug your own in, or one of you switches off mobile data. The app
will tell you which case you are in rather than spinning forever.

## Status

Early. Right now this repository contains a Flutter skeleton and an empty
screen that says it has no cards, which is honest. Nothing below is built yet:

- the table and its eleven verbs
- deck building with per format legality
- Commander pods, Standard and Pauper duels
- draft, with real booster odds and pack passing
- the direct connection between players

Commander, draft and Standard/Pauper are the formats that have to work before
this is worth installing. Pokemon comes after Magic works, so the shared parts
are shaped by two real games instead of one imagined one.

## Running it

Flutter 3.47.5 or newer.

```
flutter pub get
flutter run
```

Android, iOS and web are the configured targets. Desktop is not set up yet and
is a one line change when somebody wants it.

## License

MIT, see [LICENSE](LICENSE). That covers the code in this repository and
nothing else. It says nothing about the card data you choose to load, which is
not ours to license.
