---
id: DESIGN-007
title: Onboarding sequence and in-app help
status: Accepted
started: 2026-06-07
accepted: 2026-06-07
owners: ["kengu"]
related_code:
  - lib/main.dart
  - lib/views/main_screen.dart
  - lib/views/program_view.dart
  - lib/services/brief/brief_renderer.dart
  - lib/services/notification_service.dart
  - lib/views/map_view.dart
  - lib/data/drill_file.dart
  - lib/models/numbering.dart
related_designs:
  - brief-template.md
  - 006-program-tab-consolidation.md
  - exercise-player.md
related_adrs:
  - 0022-markdown-content-as-files.md
  - 0034-configurable-numbering-formats.md
  - 0008-persistent-program-library-and-catalog.md
  - 0029-live-activity-and-foreground-service.md
---

# Onboarding sequence and in-app help

> This document is in English. Code symbols and identifiers are English, Norwegian UI labels are quoted from the `nb` localization. Entity naming follows [[feedback_post_station_terminology]] (*station* / "post") and the Program-tab vocabulary from [DESIGN-006](./006-program-tab-consolidation.md).

## TL;DR

A new user needs one idea first: teams rotate through posts, one round at a time, and everyone advances together when the round ends. Onboarding teaches that idea and gets the user to first value fast. It has three layers. A single **concept primer** card on first launch teaches the ring with an illustration. A second primer card **primes the notification permission** in context — explaining that RingDrill alerts on every round change — before the OS dialog fires, and moves the notification request out of the eager boot path where it surprises the user today. A bundled **example plan** lets the user press play on a real rotation in seconds. **Teaching empty states** in the Program segments guide the build-your-own path, each saying what is missing and pointing at its create action. A first-run-only **"Start her"** cue marks the first FAB. A separate **Help / FAQ** surface ships bundled localized markdown, rendered through the existing `brief_renderer`, so it works offline. We do not build a coachmark wizard, and onboarding never blocks first value on a granted permission.

## Rationale

**The product is one concept.** Posts, teams, rounds, roles and the brief all hang off the ring rotation. Learn the rotation and the rest follows by analogy. Miss it and every screen feels arbitrary. So the best thing onboarding can do is teach the rotation, and the cheapest way to teach it is to show it moving.

**Conversion follows time-to-first-value.** Coachmark tours teach where buttons are, not why the app matters, and people dismiss them. The "aha" moment is watching a rotation run. A wizard that makes the user build before they get anything front-loads work before reward, which is where people drop off. A ready-made example plan gives value before effort, so the rest of the design leans on it.

**Just-in-time beats front-loaded.** An empty state explains the thing the user is already looking at, so the lesson lands with context and sticks. The app already uses empty states (`noActorsInRoster` and similar), so this extends a pattern rather than inventing one.

**Help has to work offline.** A new user mid-exercise is often without signal. Help that lives only on the docs site is gone when it is needed most. Bundling the content and rendering it through the markdown pipeline keeps it reachable offline. The docs site stays the canonical source the bundle is generated from.

## Goals

1. Teach the ring rotation on first launch, in one card, visually.
2. Prime the notification permission in context, with the "why", before the OS dialog fires — and stop firing it cold at boot.
3. Get a new user to a running exercise in seconds via a bundled example plan.
4. Guide the build-your-own path through teaching empty states, not a wizard.
5. Provide an offline Help / FAQ surface for the questions the domain actually raises.

## Non-goals

* **No coachmark tour.** No overlay that points at controls one by one. The single first-run "Start her" cue is the only pointer, and it never returns.
* **No account or login in first-open.** Onboarding state is device-local. Tying it to the account model would force login into first launch.
* **No permission wall.** The notification priming card is skippable like the rest of the primer, and "Åpne et eksempel" / "Start en tom plan" never depend on a granted permission. Priming raises the grant rate; it does not gate first value.
* **No location priming.** Location is already requested lazily and in context, on the map "locate me" tap (`Geolocator.requestPermission()` in `map_view.dart`). That is the right pattern, so onboarding leaves it alone. Only notifications move into the primer, because only notifications fire today before the user has any context.
* **No new permissions.** This adds no manifest/plist permission that is not already declared. Exact-alarm, full-screen-intent hardening, DnD-bypass and battery-optimisation exemptions are out of scope (see Deferred decisions), and camera / Bluetooth / calendar / contacts are not in play.
* **No new content model for help.** Help reuses the [ADR-0022](../adrs/0022-markdown-content-as-files.md) markdown-as-content approach and the `brief_renderer` pipeline. No CMS, no remote fetch, no new theme.
* **No screenshots in bundled help.** Bundled help is text only. Images grow app size, so any screenshots link out to the docs site.
* **No two-way sync of help content.** The bundled markdown is read-only and ships with the build.

## Layers

### Layer 1 — Concept primer (first launch)

One full-screen card, shown once on first launch, before the Program tab. See [the mockup](./mockups/onboarding-concept-primer.html).

* Three progress dots and a **"Hopp over"** affordance on top. The primer is skippable everywhere, since many users are exercise leaders who know the domain.
* A **ring illustration**: three posts labelled `2a` / `2b` / `2c` (the configurable numbering from [ADR-0034](../adrs/0034-configurable-numbering-formats.md), not synthetic `A1` labels), in a ring, with rotation arrows between them. Team chips sit **on the arrows**, so they read as "on the way to" the next post. The ring is the biggest thing on the screen because it is the lesson.
* A heading and one line of copy: *"Lagene roterer. Hvert lag er på vei til neste post. Når runden er over, rykker alle videre samtidig. Det er hele RingDrill."*
* Two buttons. Primary **"Åpne et eksempel"**. Secondary **"Start en tom plan"**.

The concept primer is **one card**. The three progress dots leave room for the sequence: the second dot is the notification priming card below, and a third is still free for "you can share the plan" or "this is how you run it" if review wants it — not more rotation talk.

#### Ring figure (`RingRotationFigure`)

The illustration is a `CustomPainter` widget, not an image or an SVG asset. No new dependency (`flutter_svg` is not in the project) and no asset to bundle. Light/dark is automatic because the painter takes its colours from `Theme.of(context).colorScheme`, not baked-in fills, which is where a multi-colour SVG asset gets awkward (a `ColorFilter` tints one colour, it cannot swap several). It stays sharp at any size as true vector. The mockup SVG maps almost one-to-one onto `Canvas`: the dashed ring is a `drawCircle` with a dashed path, the rotation arrows are `drawArc` plus a small arrowhead `Path`, the posts are `drawCircle`, the team chips are rounded rects, and labels draw with `TextPainter`. It is one reusable widget taking colours and size, used by both the primer and the "Slik fungerer RingDrill" entry in Help. Not animated in v1.

### Layer 1b — Notification priming (first launch)

A second primer card, shown right after the concept card, that explains *why* RingDrill wants to notify before the OS dialog ever appears. RingDrill is a timer: it alerts on every round change, and can run a full-screen alarm over the lock screen when the round ends ([ADR-0029](../adrs/0029-live-activity-and-foreground-service.md)). A user who is told that, with the ring still fresh on screen, grants far more readily than one hit by a bare "RingDrill would like to send you notifications" at cold launch.

The card reuses the primer chrome: the same progress dots and **"Hopp over"**, a short heading and one line of copy, and a single primary button that triggers the real OS permission request. Copy, roughly: *"RingDrill varsler deg når runden skifter, så du slipper å følge med på klokka. Vil du slå på varsler?"* Primary **"Slå på varsler"** fires the request; the dots' **"Hopp over"** (and a secondary **"Ikke nå"**) advances without asking. Whatever the user picks, onboarding continues — this is priming, not a wall (see Non-goals).

**This replaces an eager boot-time request, it does not add one.** Today `_startNotificationService()` runs in `RingDrillApp.initState` (`lib/main.dart`) and, through `NotificationService.init`, calls `requestNotificationsPermission()` on Android and `requestPermissions(...)` on iOS/macOS the moment the app starts — before the user has seen anything. The priming card moves that first request behind a deliberate tap. Boot still initializes the notification *service* (channels, plugin, listeners) so scheduling works; it just stops being the thing that pops the system dialog. On platforms and OS versions where notifications need no runtime grant (older Android), priming is a no-op explainer and the card can be skipped outright.

The notification toggle in Settings stays the source of truth for whether RingDrill *uses* notifications; the priming card only governs *when* the OS is first asked. Re-prompting after a denial is the OS's job, not ours — if the user skips or denies, the Settings toggle and the system settings deep-link are the recovery path, and onboarding does not nag.

### Layer 2 — Example plan

A small bundled `.drill` the user can open and run at once. Big enough to show the rotation, small enough to grasp: about **three posts, three teams, two rounds**, plus a couple of markører (`RolePlay`) and a short brief, so the Roster tab and the brief action are not empty when the user explores. Posts use `2a` / `2b` / `2c` for continuity with the primer. Content is localized: Norwegian in `nb`, English in `en`.

Opening it sets up an active program and drops the user into a populated Program tab, one tap from the Exercise Player ([DESIGN-001](./exercise-player.md)). This is the fastest path from cold launch to a moving ring.

### Layer 3 — Teaching empty states

Every Program segment shows a teaching empty state when it has no content, instead of a bare "nothing here". All four share one component, matching [the mockup](./mockups/onboarding-empty-state.html): a circular tinted icon badge, a title, then one or two muted body lines, with the segment's create affordance when it has one. Today three segments have a bare one-line text and Team has none at all (its list renders blank), so this gives all four a consistent surface.

The copy differs per segment by design. Øvelser names the precondition for a run, while Poster, Spill and Lag explain they are derived from exercises and point back to Øvelser. The smallest runnable plan is one exercise with `numberOfStations` and `numberOfTeams` set, so the Øvelser copy points at exactly that.

| Segment (key stem) | Icon | `nb` title | `nb` body | `en` title | `en` body |
|---|---|---|---|---|---|
| Øvelser (`emptyExercises`) | `Icons.update` | Ingen øvelser ennå | En øvelse trenger antall poster og antall lag for å kunne kjøres. Legg til den første for å se ringen i arbeid. | No exercises yet | An exercise needs a number of stations and a number of teams before it can run. Add your first to see the ring in motion. |
| Poster (`emptyStations`) | `Icons.place` | Ingen poster ennå | Poster legges til inne i øvelsene dine. Opprett en øvelse først, så dukker postene opp her. | No stations yet | Stations are added inside your exercises. Create an exercise first and they will show up here. |
| Spill (`emptyRoles`) | `Icons.theater_comedy` | Ingen spill ennå | Spill beskriver det markørene skal gjøre på posten. Opprett en øvelse først, og legg deretter til spillene den trenger. | No plays yet | A play describes what the roles do at the station. Create an exercise first, then add the plays it needs. |
| Lag (`emptyTeams`) | `Icons.group` | Ingen lag ennå | Lag kommer fra antall lag i øvelsene dine. Opprett en øvelse først, så dukker lagene opp her. | No teams yet | Teams come from the team count in your exercises. Create an exercise first and they will show up here. |

The segment's create FAB ("Ny øvelse" on Øvelser, "+" / "Nytt spill" on Spill) is unchanged from [DESIGN-006](./006-program-tab-consolidation.md), except Spill hides its creator until the plan has at least one exercise. Poster and Lag have no own creator, so they point back to Øvelser. A first-run-only **"Start her"** pill sits next to the first FAB (stage 4 below).

#### "Start her" cue rules

* Shown **only the first time** the user sees an empty Program segment, and **only on the first FAB**.
* Removed for good once the user creates anything or taps it. It never comes back, on any segment.
* It is an inline pill, not an overlay, scrim, or tooltip. If review finds it too tutorial-like, the empty-state copy carries the path alone and the pill is dropped.

### Help / FAQ surface

A scrollable help screen reached from **Settings**, and maybe also from an AppBar overflow item. Content is bundled, localized markdown (one file per topic, or one document with anchors), rendered with `brief_renderer` in **plain Material style, not `BriefTheme`** ([ADR-0023](../adrs/0023-brief-theme-tokens.md) keeps that palette in the brief sheet, and help is not a brief).

FAQ topics target the real confusions, not generic "how to make a plan":

* **Why are posts separate from rounds?** The decoupling from [ADR-0017](../adrs/0017-decouple-stations-from-rounds.md) (own `numberOfStations`, rounds as a multiplier with a soft warning) trips people up, so it comes first.
* **What is a markør, and what is an actor?** And what gets stripped on publish (the PII boundary from [ADR-0018](../adrs/0018-roleplayer-data-model.md) / [DESIGN-006](./006-program-tab-consolidation.md)).
* **What do the three tabs mean?** Program / Map / Roster as plan, spatial lens, and local people layer.
* **How do participants join a live exercise?** The coordinator / observer / roleplayer roles ([ADR-0019](../adrs/0019-roleplayer-participant-role.md)).
* **What works offline?**

## Persistence

A single device-local flag records that onboarding has been seen. `shared_preferences` is enough, and it is already a dependency. `buildRouter(bool isFirstLaunch)` already threads a first-launch signal into the router, so the wiring exists. The flag gates the primer (show once) and the "Start her" cue (show once), and stays one-way: re-entry to the primer is through Help, not by clearing it. It is not part of the program or account model. The "Start her" dismissal can share this flag or use a sibling key, decided at implementation.

The notification priming card needs no flag of its own — it is part of the primer, gated by the same seen flag, so it shows once on first launch with the rest. What it *does* change is the boot order: `_startNotificationService()` in `RingDrillApp.initState` still initializes the service so scheduling and channels are ready, but the first OS permission request moves out of `NotificationService.init` and behind the priming card's button. Concretely, `init` gains a way to set up without prompting (the request becomes an explicit call the priming card makes), so first launch no longer pops the notification dialog before the user has seen the primer. Subsequent launches are unchanged: the service initializes as before and the OS already holds the grant decision.

## Terminology

* **Concept primer** is the first-launch card, not a "tutorial" or "walkthrough", to keep it distinct from the coachmark tour we are not building.
* **Teaching empty state** is an empty state that carries a lesson and a create action.
* **Example plan** (not "demo" or "sample data") is the bundled runnable `.drill`. `nb` copy may call it "et eksempel".
* Posts in onboarding artwork and the example plan use the `2a` / `2b` / `2c` numbering from [ADR-0034](../adrs/0034-configurable-numbering-formats.md).

## Deferred decisions

1. **One primer card vs. three.** Leaning to one. If three, the extras are "share" and "run", not more rotation.
2. **Help entry points.** Settings is certain. An AppBar overflow "Hjelp" item is open.
3. **Help content structure.** One file per topic vs. one document with anchors. Depends on how `brief_renderer` handles in-doc navigation on narrow screens.
4. **Example plan delivery.** Bundled asset imported on demand vs. a built-in catalog entry ([ADR-0008](../adrs/0008-persistent-program-library-and-catalog.md)). Bundled asset is simpler and offline by default.
5. **Animating the ring.** The illustration is static here. Moving the team chips along the arrows would reinforce "rotation" but is not needed for v1.
6. **Priming location too.** Left lazy on the map tap, which is the right pattern. A primer card for location is possible but unjustified while it works in context, so it is not planned.
7. **Exact-alarm reminders.** `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` are commented out and `zonedSchedule` is unused. If pre-exercise reminders ship, Android 13+ needs `USE_EXACT_ALARM` (allowed) or the special-access `SCHEDULE_EXACT_ALARM`, and that ask could join the priming sequence. Out of scope until the feature exists.
8. **Full-screen-intent hardening.** `USE_FULL_SCREEN_INTENT` is declared and gated behind a Settings toggle (off by default). Android 14+ restricts it for non-alarm apps and Play review may push back. Whether to keep it, and whether to surface it in onboarding, is a separate decision.
9. **DnD bypass and battery-optimisation exemption.** `ACCESS_NOTIFICATION_POLICY` is declared but needs a system-settings grant, not a runtime dialog, and a battery-optimisation exemption is an even heavier ask. Both improve alarm reliability for a timer app but are deferred; if pursued, they belong in Settings with a clear explanation, not in first-open onboarding.

## Resolved (2026-06-07)

1. **Primer placement: a top-level route, not an overlay.** `buildRouter(bool isFirstLaunch)` already threads the first-launch signal into the router, and the redirect already does conditional routing (install links `/i/`, open-file `/o/`, legacy redirects). The primer gets its own top-level route (e.g. `/welcome`), reached when the redirect sees first launch at the root path. It lives over the root navigator like the brief routes, not inside the `IndexedStack` shell, so it does not fight the shell. On dismiss we set the flag and navigate to the active program path. Since the guard only routes to the primer from the root on first launch, it does not re-trigger once on a program path, so the captured `isFirstLaunch` bool is enough and the flag need not be a live listenable.
2. **Re-entry from Help, flag stays one-way.** The primer is reachable again through a "Slik fungerer RingDrill" entry in Help that reuses the same ring illustration and copy, rather than by clearing the seen flag. The primer content becomes a reusable widget shown both at first launch and from Help.
3. **No new ADRs needed.** The seen flag is not a new persistence mechanism (`shared_preferences` is already a dependency). Help as markdown is covered by [ADR-0022](../adrs/0022-markdown-content-as-files.md), and bundled markdown already has precedent in `assets/templates/`. The example plan reuses the existing `.drill` import pipeline, so it is not a new mechanism either. If review wants formality, a single small ADR covering "bundled starter content as assets" could group both help and example plan, but it is not required.

## Implementation notes

Sequenced so each stage ships on its own.

**Stage 1 — Teaching empty states.** Lowest risk, no new persistence. Replace the bare Program-segment empty states with the teaching variant (icon, title, precondition copy, create FAB). New `nb` / `en` keys.

**Stage 2 — Concept primer + seen flag.** Add the `shared_preferences` seen flag and a top-level primer route (e.g. `/welcome`), reached from the router redirect when the flag is unset at the root path, over the root navigator rather than inside the shell. Build the ring illustration as a reusable `CustomPainter` widget (`RingRotationFigure`, colours from `ColorScheme`, ported from the mockup SVG) so Help can show it too. Wire the buttons: "Start en tom plan" sets the flag and goes to an empty Program tab, "Åpne et eksempel" is stubbed until stage 3.

**Stage 3 — Example plan.** Bundle the localized `.drill` (three posts `2a`/`2b`/`2c`, three teams, two rounds, a couple of markører, a short brief). Wire "Åpne et eksempel" to import it and activate the program. Completes the activation path.

**Stage 4 — "Start her" cue.** Add the first-run-only pill on the first FAB, gated by the seen flag, removed for good on first create or tap.

**Stage 5 — Help / FAQ.** Bundle the localized help markdown, add the Settings entry, render through `brief_renderer` in plain Material style, write the FAQ entries above, and add the "Slik fungerer RingDrill" entry that reuses the primer widget. No new ADRs required (see Resolved).

**Stage 6 — Notification priming.** Depends on stage 2's primer scaffold. Split `NotificationService.init` so it can initialize channels/listeners *without* requesting the OS permission, exposing the request as an explicit call. Stop `_startNotificationService()` (`lib/main.dart`) from prompting at boot — it still initializes the service. Add the priming card as the primer's second step (reusing the chrome), wiring its primary button to the explicit request and "Hopp over" / "Ikke nå" to advance without asking. New `nb` / `en` keys for the card. Guard for platforms with no runtime grant (skip the card). Verify on a fresh install that no notification dialog appears before the primer, and that granting from the card still arms round-change alerts.

Mockups: [concept primer](./mockups/onboarding-concept-primer.html), [teaching empty state](./mockups/onboarding-empty-state.html).

## Changelog

* 2026-06-07 — Drafted from design dialogue. Locked: light variant over a coachmark wizard, one concept primer card teaching the ring with teams on the arrows ("on the way to"), `2a`/`2b`/`2c` post format, bundled example plan as the activation event, teaching empty states, first-run-only "Start her" cue, `shared_preferences` seen flag, and an offline Help/FAQ surface rendered through `brief_renderer` in plain Material style.
* 2026-06-07 — Resolved the three open questions. Primer is a top-level route gated in the router redirect (not a shell overlay), reusing the existing `buildRouter(bool isFirstLaunch)` signal. Re-entry is through a "Slik fungerer RingDrill" entry in Help, with the seen flag staying one-way. No new ADRs required.
* 2026-06-07 — Copy fix after first build. The Poster and Lag bodies said "Lag en øvelse først", where "Lag" reads as the noun (team) three times in the Lag string. Changed the verb to "Opprett en øvelse først" in both (`emptyStationsBody`, `emptyTeamsBody`), matching the existing `createExercise` ("Opprett øvelse"). English already used "Create".
* 2026-06-07 — Added the final per-segment empty-state copy (`nb` + `en`) for all four Program segments and noted that they share one component matching the mockup. Team had no empty state at all and gains one (new `emptyTeams` keys). Old single-line keys (`noExercisesYet`, `noStationsYet`, `noRolesInProgram`) are superseded.
* 2026-06-07 — Ring figure spec settled and doc **Accepted**. The illustration is a `CustomPainter` widget (`RingRotationFigure`) taking colours from `ColorScheme`, not an image or SVG asset, so light/dark is automatic and nothing is bundled. Not animated in v1.
* 2026-06-07 — Added notification permission priming (Layer 1b, stage 6). A second primer card explains the round-change alerts before the OS dialog, and the first notification request moves out of the eager boot path (`_startNotificationService` / `NotificationService.init`) behind a deliberate tap. Skippable, never gates first value, adds no new permission. Location stays lazy on the map tap (not primed). Exact-alarm, full-screen-intent hardening, DnD bypass and battery-optimisation exemptions catalogued as deferred decisions. No new ADRs; ADR-0029 added to related links for the alarm context.
