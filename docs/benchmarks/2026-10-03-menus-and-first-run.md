# Benchmark: main menus, and what happens the first time somebody opens the app

The menu today is five rows of equal weight, three of them greyed out with
"needs a source", and the only thing you can press is Sources, labelled
"start here". That is the whole first run: a wall of disabled rows and an
instruction. This reads how games and apps do both halves.

## Main menus

Sources: [Procreator, best practices for game UI](https://procreator.design/blog/best-practices-for-game-ui-design/),
[AAA Game Art Studio, mobile game UI/UX](https://aaagameartstudio.com/blog/mobile-games-ui-ux),
[Indieklem, creating an intuitive in-game menu](https://indieklem.substack.com/p/9-creating-an-intuitive-in-game-menu)

1. **One dominant action.** "The main call to action to play, start, battle,
   or begin a new game should be the most dominant in your Main Menu UI. The
   PLAY button should be large and distinctive enough for players to easily
   find it." Ours has five rows at the same size and weight, so nothing is
   the way in.
2. **Hierarchy by size, colour and placement**, not by order alone. "Use
   size, color contrast, and placement to emphasize key buttons."
3. **Simplicity, and no deep nesting.** "Always opt for the simplest solution
   possible... deeply nested menus frustrate players." A row that exists to
   configure a data source is not a peer of the row that starts a game.
4. **Progressive disclosure on phones.** "Show essential options upfront and
   keep advanced settings hidden under expandable menus." Sources is an
   advanced setting by this rule: you touch it once, ever.
5. **Consistency of placement**, so the eye learns the screen.

## First run

Sources: [Eleken](https://www.eleken.co/blog-posts/mobile-app-onboarding-best-practices),
[Userpilot](https://userpilot.com/blog/app-onboarding-best-practices/),
[Appcues](https://www.appcues.com/blog/essential-guide-mobile-user-onboarding-ui-ux),
[Storyly](https://www.storyly.io/post/app-onboarding-best-practices-key-to-increase-app-engagement)

1. **Get to the first real outcome fast.** "The best onboarding flows focus
   on getting users to their first meaningful outcome as quickly as possible
   by reducing signup friction, personalising, revealing features gradually."
2. **Cut every step that does not move toward that outcome.** "Remove any
   step that does not directly move the user toward the first value. Profile
   completion, notification setup, and feature tours can all come later."
3. **Let people skip.** "Most mobile apps let users skip onboarding steps so
   they can jump straight into what they came to do."
4. **Ask at the moment of intent.** "Prompts land best when timed to intent.
   Asking for camera at the moment someone taps scan earns more trust than
   asking on launch."
5. **Do not overload.** "Only highlight core features at the beginning."

## Arriving on a link, the first time

Sources: [Airbridge, deferred deeplink for onboarding](https://www.airbridge.io/en/blog/deferred-deeplink-for-onboarding),
[Expensify PR 101558](https://github.com/Expensify/App/pull/101558),
[gamify-todo issue 61](https://github.com/lilmuckers/gamify-todo/issues/61),
[fart-app issue 3](https://github.com/drawmeanelephant/fart-app/issues/3)

1. **The link is the intent; onboarding must not eat it.** "A deferred
   deeplink restores context after install by holding the intended in-app
   destination, then delivering the user there on first open instead of
   dropping them on a home screen."
2. **Park it, then replay it.** From a real bug fix: "Deep links captured
   while signed out were sometimes discarded after onboarding; the solution
   is to park the pending navigation in memory and let post-onboarding logic
   replay it before choosing its own destination." This is exactly the
   "somebody opens a room link and has never used the app" case.
3. **A shared link gets a lighter first run than a cold open.** "Someone
   opening a shared link on their first visit sees a small dismissible
   banner instead of the full splash, so shared links aren't hijacked."
4. **Sixty seconds, and joining should feel like clicking a link rather than
   configuring software.**

## What this means here

- The menu is **Play, Join, Decks, Settings**. Play is the dominant row, not
  one of five. Sources moves inside Settings: it is configuration, touched
  once, and it has no business being the brightest thing on the first screen.
- The first run is a **wizard, not a wall**: your name, a source, and
  optionally a first deck, with every step skippable except the one that
  makes the app able to do anything (a source).
- Arriving on a room link with no setup runs the **same wizard, then lands in
  the room**, because the link is the intent and the wizard is in the way of
  it. The room code is parked before the wizard starts and replayed after.
- Greying rows out and writing "needs a source" on them is the opposite of
  all of this: it explains a wall instead of removing it.
