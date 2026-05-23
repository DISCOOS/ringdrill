---
id: DESIGN-001
title: Exercise Player
status: Accepted
started: 2026-05-23
accepted: 2026-05-23
owners: ["kengu"]
related_code:
  - lib/services/exercise_service.dart
  - lib/views/coordinator_screen.dart
  - lib/views/main_screen.dart
  - lib/views/exercise_control_button.dart
  - lib/views/phase_tile.dart
  - lib/views/phase_widget.dart
  - lib/views/phase_headers.dart
mockups:
  - mockups/coordinator-oversikt.html
  - mockups/coordinator-poster.html
  - mockups/coordinator-lag.html
  - mockups/mini-player.html
  - mockups/observer-lag.html
  - mockups/observer-post.html
  - mockups/wide-screen.html
---

# Exercise Player

## TL;DR

When an exercise is running, RingDrill exposes it as a **persistent player** that follows the user across the Program, Stations and Teams tabs, instead of locking them to a single "run" screen. The player has two visual states:

* A **mini-player** strip that lives above the bottom navigation on mobile and along the bottom edge on wide screens. Always visible while an exercise is active or pending.
* A **full-player** sheet that slides up from the mini-player on demand. The full-player takes one of three forms depending on the user's role: the **coordinator player** (with the Overview, Posts and Teams tabs), the **observer player for teams** (following one team), and the **observer player for posts** (following one post).

The model is borrowed from Spotify. `ExerciseService` is already a singleton that runs one exercise at a time and keeps running while you navigate around. Today that fact has no surface in the UI. The player gives it one.

## Goals

1. Let the coordinator check stations and teams without losing track of where in the exercise they are.
2. Separate "editing an exercise" (today's `CoordinatorScreen`) from "playing back an exercise" (the player). The two have different needs and deserve different shells.
3. Reuse most existing widgets. `_buildStationList` and `_buildTeamList` from `CoordinatorScreen` work as the Posts and Teams tabs without being rewritten.
4. Provide a home for a future "Overview" view that the coordinator currently lacks.

## Non-goals

* Does not change the `ExerciseService` mechanics. The clock still drives the phases, and no pause/skip buttons are introduced as part of this design.
* Does not change the data model. The number of teams, stations and rounds stays as is. The design assumes the team count never exceeds the station count (one team per station per round, no "waiting" row).
* Does not touch notifications, exports or sharing. The player is a visual layer, not a new service.

## Rationale: why the "player" metaphor?

`ExerciseService` has three properties that map to Spotify almost 1-to-1:

| Spotify                       | RingDrill                                       |
|-------------------------------|-------------------------------------------------|
| One active song               | One active exercise (singleton service)         |
| Plays while you navigate      | The timer keeps running across tab switches    |
| Album / playlist              | Plan (the program the exercise belongs to)     |
| Track progress                | `phaseProgress` / `roundProgress`              |
| Next up                       | Next phase or next round                        |
| Now-playing bar               | Mini-player                                     |
| Now-playing view              | Full-player                                     |

The user recognized the pattern instantly. A persistent bar above the navigation is a convention we can borrow without explanation. The stop button (round, red) signals "stop playback" the same way it does in a music app.

## Anatomy

```
┌─────────────────────────────────────────────┐
│   App content (Program / Stations / Teams)  │
│                                             │
├─────────────────────────────────────────────┤
│  ▍▍▍▍▍▍▍▍▍▍                      ←  phase progress
│  ⬜ EXECUTION · Round 2/5   06:42  ⏹       │ ← MINI-PLAYER
├─────────────────────────────────────────────┤
│   Bottom Navigation                         │
└─────────────────────────────────────────────┘

                  tap mini
                     ▼

┌─────────────────────────────────────────────┐
│  ⌄        Forest Fire 2026         ⋮        │ ← FULL-PLAYER
│                                             │   (bottom sheet)
│  [ Overview ]  Posts   Teams                │ ← segmented control
│                                             │
│  ┌──────┐   06:42       NEXT                │
│  │ EXEC │   LEFT        ▤ EVAL  14:34       │
│  │      │   done 14:34  ▤ ROLL  14:37       │
│  └──────┘                                   │
│                                             │
│  CURRENT-ROUND PROGRESS                     │
│  ████████|████  ▓▓▓▓  ░░                    │
│                                             │
│  ROUND TIMELINE                             │
│  [R1] [R2] [R3] [R4] [R5]                   │
│                                             │
│  POSTS   ROUND   ⏹    TIME LEFT   TEAMS     │
│   4     2 of 5        42:18         5       │
└─────────────────────────────────────────────┘
```

## Mini-player

The persistent strip that signals "an exercise is running" wherever the user is in the app.

**Where it lives:**

* **Narrow screen:** A 56 px tall strip between content and the `NavigationBar`. It shares its border with the navigation and sits as a fixed layer just above it.
* **Wide screen:** Spans the full width along the bottom, also across the `NavigationRail`. The layout is three-column (info / control / lens), described under [Wide-screen behavior](#wide-screen-behavior).

**What it shows:**

* A color-coded 36 × 36 square on the left with a phase icon (same square concept as the hero in the full-player, just smaller).
* Phase label (EXECUTION / EVAL / ROLL) as a chip.
* Round indicator (Round 2 / 5).
* The name of the active exercise (or the active exercise title, if one is set).
* Countdown in tabular-nums (06:42).
* Round red stop button (36 × 36).
* A thin 3 px progress bar along the top edge showing `phaseProgress`.

**Pending state:** When the exercise has been started but its scheduled start time has not yet been reached (`ExercisePhase.pending`), the phase chip is replaced with "STARTING IN" and the countdown shows time until start. The colored square becomes neutral (gray) until the execution phase begins.

**Interactions:**

* Tap on the bar (but not on the stop button): open the full-player as a bottom sheet.
* Tap the stop button: show a confirmation snackbar (the `stopExerciseFirst` pattern already exists in `ExerciseControlButton`).
* Swipe down on the bar: no action. Stopping must be deliberate.

Mockup: [`mockups/mini-player.html`](./mockups/mini-player.html)

## Full-player

A `showModalBottomSheet` with `isScrollControlled: true` and `useSafeArea: true`. It slides up from the mini-player and covers most of the screen, with a chevron at the top that closes it back to the mini-player without stopping playback.

For the coordinator, the full-player has three tabs via a segmented control at the top:

* **Overview** – aggregated status and progress (new view).
* **Posts** – station list with the rotation strip (reuses `_buildStationList`).
* **Teams** – team list with the rotation strip (reuses `_buildTeamList`).

These tabs are at the same zoom level. All three see the whole exercise, just through a different lens.

### Tab choice: why these three

An earlier sketch had "Overview | Team 3 | Station A2" as segments, where the two latter were specific entities. That mixed two levels: Overview looked at the whole exercise, while Team 3 and Station A2 focused on a single entity. The pattern was confusing for the coordinator because the coordinator never wants to see only one team or only one station at a glance. The coordinator wants to switch between the whole team list and the whole station list.

Single entities (one team, one station) belong in the Teams and Stations tabs of the bottom navigation (`TeamScreen`, `StationScreen`), not in the coordinator player.

## Overview tab

This is the new part. It replaces today's "live status row" in `CoordinatorScreen` and fills it with more information than a single line of phase and time.

Mockup: [`mockups/coordinator-oversikt.html`](./mockups/coordinator-oversikt.html)

### Anatomy

From top to bottom:

1. **Top chrome** (chevron, plan name, more button).
2. **Segmented control** (Overview selected).
3. **Hero row** (three columns):
   * **Phase square** 92 × 92 on the left. Solid fill per phase (Drill green `#1D9E75`, Eval blue `#378ADD`, Roll amber `#BA7517`). Icon (ti-flame / ti-clipboard-check / ti-arrows-shuffle) above a short phase label in capitals. Functions as the "album cover".
   * **Countdown column** centered. 44 px large number (`06:42`), tabular-nums. Below it: "PHASE LEFT" as a small label, then "done 14:34" in a tertiary color.
   * **NEXT column** on the right. Two stacked 36 × 36 mini-squares for the two upcoming phases, each with an icon and a phase label plus start time and duration (`14:34 · 3 min`).
4. **CURRENT-ROUND PROGRESS** – a 6 px tall three-segment strip with the same color codes as the hero. A vertical marker shows the exact "you are here" within the active segment. Labels below: "Drill 7 min · Eval 3 min · Roll 2 min".
5. **ROUND TIMELINE** – five equally wide pills across the full width, each with a start time below it. The active round has an outline and is filled proportionally to its progress; completed rounds are filled and muted; future rounds are empty.
6. **Bottom control row** – five cells:
   * **POSTS** (station count), centered at the far left.
   * **ROUND** "2 of 5", right-aligned next to the stop button.
   * **Stop button**, 60 × 60 round red button at the center.
   * **TIME LEFT** "42:18", left-aligned next to the stop button.
   * **TEAMS** (team count), centered at the far right.

### Design choices

**The countdown is the phase's, not the exercise's.** A coordinator acts within phases ("we have 6 minutes left before evaluation starts"), not within the whole exercise ("we have 42 minutes left in total"). Total remaining time has been moved to the bottom row as "TIME LEFT", where it is available as background information without competing with the phase countdown.

**The NEXT column is a mini-queue.** It always shows the two upcoming phases, regardless of whether they belong to the same round or the next round. While in Roll on round 2, NEXT shows "DRILL · R3" and "EVAL · R3". In the final phase of the final round, the column goes empty.

**The color coding is consistent.** The phase square, the NEXT squares, the phase strip and the round-timeline fill use the same three colors consistently. The user never needs to remember a legend. Green is Drill everywhere, blue is Eval, amber is Roll.

**The bottom row balances around the stop button.** ROUND and TIME LEFT hug the stop button and read together with it, because they are time-related. POSTS and TEAMS are capacity anchors at the far edges, centered in their own cells. That produces two visual rhythms in the same row without competing.

**Vertical "you are here" marker on the phase strip.** A 12 px tall tick that moves from left to right through the active segment. It is more precise than pure fill, especially for short phase durations where percentage fill jumps in minute steps.

## Posts tab

Builds on `_buildStationList` from `CoordinatorScreen` with only minor adjustments to fit the player shell.

Mockup: [`mockups/coordinator-poster.html`](./mockups/coordinator-poster.html)

Existing behavior that is preserved:

* Each station is an `ExpansionTile` with its name, a mini horizontal rotation strip (team numbers per round, the active round highlighted in blue), and an expanded body with one `PhaseTile` per round.
* **Per-round progress in the expanded body reuses `PhaseTile` + `PhasesWidget` directly.** This is the existing "DRILL | EVAL | ROLL" cell strip that fills from the left based on `event.phaseProgress`, where the active round has a `blueAccent` fill and white text. We do not invent a new per-round visualization. The mockup draws simplified three-segment bars to save space and communicate structure, but production code must render the existing `PhaseTile`.
* The active station (the one assigned a team in the current round) is auto-expanded and highlighted with `primaryContainer` color and `Icons.play_circle_fill` as the leading icon.
* `PageStorageKey` per station preserves expanded/collapsed state across exercise-event updates.

Adjustments for the player shell:

* The list gets the full width to itself instead of sharing with the team list.
* A small header element "STATION ROTATIONS" + "N stations" sits directly below the segmented control, with the same typography as the section labels in the Overview tab (CURRENT-ROUND PROGRESS, ROUND TIMELINE).
* The active row gets the phase's green border color (`#1D9E75`) and a light green fill (`#E1F5EE`), not the coordinator screen's generic `primaryContainer`. This ties "active post" directly to the phase color that dominates the hero.

The footer row (POSTS · ROUND · STOP · TIME LEFT · TEAMS) is shared across all three tabs and stays visible at the bottom.

## Teams tab

Builds on `_buildTeamList` from `CoordinatorScreen` with one change in the auto-expand policy.

Mockup: [`mockups/coordinator-lag.html`](./mockups/coordinator-lag.html)

Existing behavior that is preserved:

* Each team row is an `ExpansionTile` with its name, a "→ Station name" subtitle showing where the team is right now, and a mini horizontal rotation strip (station codes per round, the active round highlighted in blue).
* The expanded body shows one `PhaseTile` per round with the station name as the title. Same `PhaseTile` reuse as in the Posts tab — we do not render a new per-round progress widget.

Changes in the player shell:

* **Auto-expand for the observed team.** In today's `CoordinatorScreen`, no team auto-expands, because every team always has an active station (a naive "isLive" check would expand every row). In the player, we take one step further and auto-expand the team that the coordinator has the "observation context" on, if such a context exists. The source can be the team row the coordinator last expanded manually, the team they last navigated to via `TeamScreen`, or a default choice. If no context exists, the list starts collapsed, matching today's behavior.
* **The expanded row is colored purple.** The active team row gets a purple border color (`#534AB7`) and a light purple fill (`#EEEDFE`), not green. Purple is the observer player's "team" color, so the coordinator immediately sees "this is the team someone is following" rather than "this is an active station". The color-semantic split — green for phase status, purple for team identity — is consistent across the whole player model.

The footer row is identical to Overview and Posts.

## Observer player

For users who do not coordinate the whole exercise but follow one specific entity, there is a separate variant of the full-player. It has no segmented control because the observer always has one lens at a time. Two roles share the same template:

* **Observer player for teams** – the user follows a specific team through the rotations.
* **Observer player for posts** – the user stands at a specific post and watches teams rotate through.

Mockups: [`mockups/observer-lag.html`](./mockups/observer-lag.html) and [`mockups/observer-post.html`](./mockups/observer-post.html).

### Shared structure

The observer player uses the same visual template as the coordinator player, with the following elements pulled directly from the Overview tab:

* Top chrome (chevron, plan name, more button).
* Phase square 92 × 92 on the left of the hero, centered countdown in the middle, NEXT column on the right.
* The CURRENT-ROUND PROGRESS strip with the same three phase colors and "you are here" marker.
* The 5-cell bottom row around the stop button, with the same typography.

Differences from the coordinator player:

* **A perspective pill replaces the segmented control.** A single pill element at the top shows which entity the observer is following, with an icon in purple (`#534AB7`) on the left and a chevron-down on the right. Tapping the pill opens a picker in a bottom sheet to switch entity. The icon is `ti-user-circle` for the team variant and `ti-map-pin` for the post variant.
* **Title strip below the hero.** A dedicated row between the hero and the phase strip displays the observer's "now playing" context, parallel to Spotify's song title below the album cover. For the team variant: station name in large type + "Team X is here now" subtitle. For the post variant: team name in large type + "At your post now · Arrived HH:MM" subtitle.
* **The NEXT column shows the perspective's queue, not the phase queue.** For the team variant: the two upcoming stations the team will visit (purple tiles with post codes). For the post variant: the two upcoming teams arriving at the post (purple tiles with team numbers). Purple is reserved for "your perspective's queue" and is distinct from the phase colors that dominate the hero square.
* **A queue list replaces the round timeline.** A vertical list of 3-N rows gives the observer more detail per entry than the coordinator's horizontal 5-pill strip, because the observer has only one sequence to display.
  * Team variant: header "UP NEXT FOR TEAM X" with "N stations left" on the right. Rows: round number + purple post tile + post name + "Starts HH:MM".
  * Post variant: header "UP NEXT AT AX" with "N teams left" on the right. Rows: round number + purple team tile + "Team N" + "Arrives HH:MM".
* **The bottom row adapts its outer cells.** ROUND, STOP and TIME LEFT are identical to the coordinator. The outer cells are field-agnostic and show the perspective's progress:
  * **DONE** (left): the number of stations the team has visited (team variant) or the number of teams the post has served (post variant).
  * **LEFT** (right): the number of stations the team has remaining (team variant) or the number of teams the post still has to serve (post variant).
  * The labels contain no "post" or "team", so the same field template is reused across the two observer roles.

### Stop button

The stop button is in the same position and uses the same red fill as the coordinator's, for visual consistency. Functionally it is role-dependent:

* **Offline:** anyone (including observers) can stop an exercise. This flexibility is wanted because devices are often not connected, and a local stop must always be possible.
* **Online (synchronized):** only the coordinator should be able to trigger a stop. For observers, the button should be disabled (`onPressed: null`) when synchronization is active. The implementation can lean on the `ExerciseService` online/offline state to determine this.

## Wide-screen behavior

`NavigationRail` (left) + main content (center) + mini-player (full width at the bottom, like Spotify desktop).

* The mini-bar spans the full width, also across the rail. This signals that the player is global, not bound to a column.
* Three-column layout inside the mini-bar:
  * **Left:** Now-playing info (phase square, chip, round number, exercise name).
  * **Center:** Time and control (countdown, stop button).
  * **Right:** Lens info (role label, "Switch perspective" button, expand-to-full-player button).
* The "Expand" button opens the full-player as a modal that covers the center. The rail stays visible but is disabled, similar to Spotify's queue view on desktop.

Mockup: [`mockups/wide-screen.html`](./mockups/wide-screen.html)

## Color tokens for phases

Phase colors are defined as constants in a single place (proposed: `lib/views/exercise_player/phase_colors.dart` or via a theme extension) and used consistently in:

* Mini-player square
* Full-player hero square
* NEXT squares
* The phase strip (CURRENT-ROUND PROGRESS)
* The round timeline (the active round's fill follows the active phase)

| Phase      | Hex       | Icon                  | Label       |
|------------|-----------|-----------------------|-------------|
| Execution  | `#1D9E75` | `ti-flame`            | EXECUTION   |
| Evaluation | `#378ADD` | `ti-clipboard-check`  | EVAL        |
| Rotation   | `#BA7517` | `ti-arrows-shuffle`   | ROLL        |

The icons must be mapped from Tabler in the mockup to Material Icons or another set in the Flutter implementation. Suggestion: `Icons.local_fire_department`, `Icons.fact_check`, `Icons.swap_horiz`.

## Open questions

Raised during design and parked, not closed:

* **Tab choice by role.** The coordinator player has three tabs, the observer player has no segmented control, only a perspective pill. These are different shells over the same underlying structure. Resolved.
* **`PhaseTile` color semantics.** Today's `PhaseTile` (and `PhasesWidget`) uses `Colors.blueAccent` uniformly for "active" — both on the title cell, the phase background and the progress fill. The player shell, on the other hand, uses three different phase colors (green for execution, blue for evaluation, amber for rotation) in the hero square, the NEXT tiles and the phase strip. Letting `PhaseTile` keep `blueAccent` creates a visual break where the expanded body does not "speak the same language" as the rest of the player. Three options:
  1. Keep `PhaseTile` as is. Accept that the expanded body has its own local color scheme. No code change needed.
  2. Update `PhasesWidget` to use the phase colors per phase cell (Drill cell green, Eval blue, Roll amber) when the round is active. More work but produces consistency.
  3. Have each phase cell always be colored in its phase color, and use the fill (`phaseProgress`) to mark progress over the colored cell. Most information in the least space.
  
  Likely option 2, but the choice is parked until we move to code.
* **Tappable cells in the ROUND TIMELINE.** Should tapping "R3" jump the Posts or Teams tab to that round in a "preview" mode so the coordinator can see what will happen? For now no, but it is a low-cost extension.
* **Tappable NEXT tiles.** Should tapping the EVAL tile preview how the phase strip and round timeline will look once evaluation starts? Same question, same answer.
* **The role of `CoordinatorScreen` once the player exists.** Proposal: it becomes a pure "edit before start" screen. All "playback" functionality moves to the player. `CoordinatorScreen` would then hold only the exercise form, team and station editing, and a large "Start" button that actually opens the player.
* **Capitalization of phase labels.** The mockup uses `EXECUTION` / `EVAL` / `ROLL` in caps. The existing code uses `event.getState(localizations).toUpperCase()`. Consistent as is, but worth reconsidering when the localizations are translated (DRILL / EVAL / ROLL in Norwegian?).
* **Norwegian vs English phase names.** This is a Norwegian app, but the phase names have drifted to English through server dialog and code. Decide on one direction.

## Implementation notes

These are starting points for the engineer who picks up the work, not a binding plan.

### Suggested widget tree

```
ExercisePlayerScaffold        (Scaffold-ish container)
├── ExerciseMiniPlayer        (the strip, visible whenever ExerciseService.isStarted)
└── (on demand)
    ExercisePlayerSheet       (DraggableScrollableSheet or showModalBottomSheet)
    └── one of:
        ├── CoordinatorPlayerBody
        │   ├── PlayerSegmentTabs (Overview | Posts | Teams)
        │   ├── (selected tab body)
        │   │   ├── OverviewTab
        │   │   ├── PostsTab      (wraps existing _buildStationList logic)
        │   │   └── TeamsTab      (wraps existing _buildTeamList logic)
        │   └── PlayerFooter      (POSTS · ROUND · STOP · TIME LEFT · TEAMS)
        └── ObserverPlayerBody
            ├── PerspectivePill   (Following Team X / Following Post AX)
            ├── PlayerHero        (shared with the Overview tab)
            ├── ObserverTitleStrip(role-specific "now playing")
            ├── PhaseProgressStrip(shared)
            ├── ObserverQueueList (team-stations or post-teams)
            └── PlayerFooter      (DONE · ROUND · STOP · TIME LEFT · LEFT)
```

`PlayerHero`, `PhaseProgressStrip` and `PlayerFooter` should be shared widgets across the coordinator and observer players. The content of `PlayerFooter` is parameterized by outer-cell data so the same widget can render POSTS/TEAMS (coordinator) or DONE/LEFT (observer).

### Data source

All player state comes from `ExerciseService().events` (a broadcast stream of `ExerciseEvent`). Both the mini-player and the full-player subscribe to the same stream and rebuild on every event. No new service is needed.

`ExerciseEvent` already exposes everything the design needs:

* `exercise` (for name, station count, team count, schedule)
* `phase` + `getState(localizations)` (for the phase chip and square label)
* `currentRound` (for "Round 2 of 5")
* `remainingTime` (for the countdown — in minutes, must be displayed as mm:ss)
* `phaseProgress`, `roundProgress`, `totalProgress` (for the progress strips)
* `when` (for "done 14:34" — `when + remainingTime`)

### Things to extract

To keep the existing `CoordinatorScreen` and the new `CoordinatorPlayerBody` from drifting, `_buildStationList` and `_buildTeamList` should be refactored out of `_CoordinatorScreenState` into top-level widgets (for example `CoordinatorStationList` and `CoordinatorTeamList`) that take `Exercise` and `ExerciseEvent` as parameters. Both screens can then call the same widgets.

`_buildExerciseStatus` (the compact live status row in `CoordinatorScreen`) is replaced by the mini-player and can be deleted once the player is adopted.

### Routing

The mini-player is global, not per route. It is therefore placed in `MainScreen` between `body` and `bottomNavigationBar` (narrow) or in a `Column` after the `Row` with rail and content (wide). The full-player is a modal and does not affect the routing tree.

### Tests

* Widget test for the mini-player verifying that it is shown when `ExerciseService.isStarted` is true and hidden otherwise.
* Widget test for `OverviewTab` with a fake `ExerciseEvent` per phase, confirming that the square color and the NEXT order are correct.
* Existing tests on `CoordinatorScreen` must be updated to reflect that the status row no longer lives there.

## Related ADRs

* [ADR-0011: Synchronized exercise control](../adrs/0011-synchronized-exercise-control.md) — establishes that the phases are clock-driven and synchronized. The player respects this and introduces no pause/skip buttons.

## Changelog

* 2026-05-23 — Draft created after design dialog with kengu.
* 2026-05-23 — Added the Observer-player section with team and post variants. Updated "Suggested widget tree" to cover `ObserverPlayerBody`. Resolved the open question about tab choice per role. Added two new mockups: `observer-lag.html` and `observer-post.html`.
* 2026-05-23 — More detailed description of the Posts tab and the Teams tab, with dedicated mockups (`coordinator-poster.html` and `coordinator-lag.html`). Change: the Teams tab auto-expands the team the coordinator has observation context on. Color semantics: green for "active post", purple for "observed team". The data set in the mockups is tightened to 4 teams + 4 posts + 5 rounds to respect `teams <= posts`.
* 2026-05-23 — Explicit note that per-round progress in the expanded body reuses the existing `PhaseTile` + `PhasesWidget`. The mockup's mini-bars are simplified illustration. Open question on `PhaseTile` color semantics (blueAccent vs the phase colors) added.
* 2026-05-23 — Status bumped to **Accepted**. The design is locked as the direction for implementation. The mockups are frozen as reference. Open questions under "Open questions" are not blocking for the code architecture — they are decided as the implementation proceeds.
