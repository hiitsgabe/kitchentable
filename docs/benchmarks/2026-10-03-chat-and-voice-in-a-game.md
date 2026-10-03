# Benchmark: putting chat and voice inside a game

What other people do with a text box and a microphone on a screen that is
mostly game, read before building either.

## Text chat on a phone

Sources: [Board Game Arena's mobile guide](https://en.doc.boardgamearena.com/Your_game_mobile_version),
[BGA forum on chat](https://forum.boardgamearena.com/viewtopic.php?t=13395),
[Discord server activities](https://discord.com/blog/server-activities-games-voice-watch-together),
[Roll20 integrated A/V](https://help.roll20.net/hc/en-us/articles/360041544734-Integrated-Voice-and-Video)

**Board Game Arena is the closest thing to this app** and the one worth
copying: a turn based table, four players, on a phone. Chat is a docked
panel opened from a button, not a log that is always there. Your own
messages sit on the right and everybody else's on the left, consecutive
messages from one person collapse into a block, and the panel is capped: a
four player layout "must not occupy more than 1/4 of the screen". The chat
outlives the game, so people keep talking after the last card.

**The card games do not have chat at all.** Hearthstone, Magic Arena and
Pokemon have no text panel on the play screen, only a small fixed set of
emotes. Nothing covers the board.

**Discord, which is a chat company, keeps chat off the game.** An activity
runs in a frame and Discord's own text, voice and roster stay outside it in
the client, a swipe away on a phone.

So: collapsed by default behind one entry point, a numeric unread badge on
that entry point, a drawer or a panel no bigger than a quarter of the screen
when open, and nothing floating over the table.

## The rule about not blocking play

The one source with real numbers is
[Microsoft's guidelines for chat over gameplay](https://learn.microsoft.com/en-us/xbox/playfab/community/voice-communications/party-speech-to-text-ux-guidelines),
written for voice transcription and exactly applicable:

- **Close after about fifteen seconds of quiet.** "The speech-to-text window
  closes after 15s of inactivity. This number is based on the time it would
  take a user to read one message of 280 characters."
- **Newest at the bottom, and scroll it yourself.** "A manual scrollbar would
  require shifting controller focus, which can be disruptive during active
  gameplay."
- **Do not make it look like the game.** "The Chat overlay must possess
  unique attributes that clearly separate it from the game UI."
- "Avoid presenting too much text on-screen at one time", avoid clashing with
  other controls, avoid hiding anything that matters.
- "There is no value to keeping an empty chat window open when players aren't
  chatting."

There is no sourced rule for a number of lines. Microsoft frames that as
something to measure against your own game rather than a constant, and it is
worth saying so rather than inventing one.

## Why the card games use canned emotes, and why that is not us

Sources: [why Hearthstone has no text chat](https://www.pcgamesn.com/why-hearthstone-should-never-ever-get-text-chat),
[Hearthstone emotes](https://hearthstone.fandom.com/wiki/Emote),
[on Arena's limited set](https://mtgrocks.com/this-small-change-could-make-mtg-arena-a-whole-lot-more-fun/)

Blizzard "wants everybody to be able to play Hearthstone free from
harassment", and keeps a small positive emote set with a per match squelch.
Arena's reasoning as reported: "with young players playing against internet
randos, the best way to avoid a moderation nightmare is to not allow chat".

Every stated reason is about **strangers**: harassment, moderation load,
protecting minors. None of it applies to a private room of invited friends
who are probably already on a call. So free text is the right default here,
and the thing worth borrowing is the hedge rather than the restriction: a few
quick reactions beside the text box for speed mid turn, and a per person
mute.

## Voice

Sources: [Discord's game overlay](https://support.discord.com/hc/en-us/articles/217659737-Game-Overlay-101),
[Among Us proximity voice](https://trtc.io/blog/details/among-us-online-gaming-voice-chat),
[Roll20 A/V](https://help.roll20.net/hc/en-us/articles/360041544734-Integrated-Voice-and-Video)

- **Speaking is a ring.** Discord puts "a green border around the avatar when
  someone speaks". Among Us rings the player green when their voice is
  working and red when it is not. Zoom and Meet do the same thing. It is the
  universal idiom and there is no reason to invent another.
- **Mute is a badge on the avatar**, a crossed out microphone, per person.
- **Joining is one explicit action.** Roll20 makes you click "Join voice and
  video" on your own token. Nothing auto joins.
- **Roll20's mistake is worth avoiding:** that join prompt floats over the
  map and players complain it covers the board. The affordance belongs in the
  player panel, never on the table.
- Push to talk exists everywhere as an option and is awkward on a
  touchscreen, so voice activity is the right default on a phone.

## Asking for the microphone

Sources: [Android permissions guidance](https://developer.android.com/topic/performance/issues/permissions),
[web permissions](https://web.dev/articles/permissions-best-practices),
[permission priming](https://www.appcues.com/blog/mobile-permission-priming),
Apple's Human Interface Guidelines on requesting permission

Never at launch. Ask at the moment somebody taps the thing that needs it, and
put your own screen in front of the system one: a line saying what it is for,
with your own way to decline. Somebody who says no to your screen has not
spent the single system prompt, so you can ask again later. Deferring the ask
is reported to raise the grant rate substantially.

Apple's rule for the string in the system dialog: "a brief, complete sentence
that's straightforward, specific, and easy to understand", sentence case,
active voice, ending in a full stop. A missing one is an App Store rejection.

## A voice toggle in the room

Sources: [Roblox voice](https://create.roblox.com/docs/chat/voice-chat),
[Halo Infinite voice settings](https://progameguides.com/halo/how-to-turn-voice-chat-on-or-off-in-halo-infinite-multiplayer/)

**Nobody defaults voice on.** Roblox makes it a per experience setting that
is off, plus an account level opt in. Halo puts it in lobby settings as a
labelled checkbox. Fortnite defaults it off for accounts under eighteen. A
tabletop game in the same shape as this one keeps a voice button in the
lobby that "by default is always off".

So: a plain toggle in the room settings called Voice chat, one line under it
saying what it does, off, set before the game starts.

## When voice does not work

Among Us rings a player red when their voice is not connected, so the table
can see whose is down at a glance. The documented failures are the opposite:
banners that say "No available microphone" while a microphone is plainly
working, and a "not connected" state with no cause and no fix.

Three causes need three different sentences: permission refused, no
microphone found, and cannot reach the other person. Each needs to say what
to do next. The failure belongs on that player's own seat and nowhere else,
and the table should see something calm rather than an error.

**And nothing about voice may take the game or the text chat down with it.**

## What this means here

1. Chat is collapsed behind one button with an unread count, opens as a
   drawer no taller than a quarter of the screen, own messages right, others
   left, grouped by sender, newest at the bottom.
2. The latest line may peek over the table and fade after about fifteen
   seconds. The full log stays behind the button.
3. Free text, because these are invited friends and every argument for
   canned emotes is an argument about strangers.
4. Voice is a toggle in the room settings, off, and it is the host's.
5. Speaking is a ring on the seat that is already drawn. Mute is a badge on
   it.
6. The microphone is asked for when somebody joins voice, behind our own
   sentence first, never at launch.
7. Voice failing is that player's problem to see and nobody else's to be
   alarmed by, and the game and the chat carry on.
