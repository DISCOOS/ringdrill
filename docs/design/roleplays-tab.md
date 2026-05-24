---
id: DESIGN-003
title: RolePlays tab
status: Accepted
started: 2026-05-23
accepted: 2026-05-23
owners: ["kengu"]
related_code:
  - lib/views/main_screen.dart
  - lib/views/roleplay_form_screen.dart
  - lib/views/actor_form_screen.dart
  - lib/views/widgets/station_expansion_tile.dart
  - lib/views/map_view.dart
related_designs:
  - exercise-player.md
  - stations-tab.md
related_adrs:
  - ../adrs/0018-roleplayer-data-model.md
  - ../adrs/0019-roleplayer-participant-role.md
---

# RolePlays tab

> Terminology note: Norwegian UI uses **"Markører"** (the colloquial SAR term for *anyone* on the role/actor side). English UI and all code use **"RolePlay"** (the publishable role) and **"Actor"** (the local human, PII). The tab itself is named *RolePlays* in code and *Markører* in the Norwegian localization. See [[feedback_roleplay_actor_terminology]] in the project memory for the rule that drives this.

## TL;DR

A new **RolePlays** tab is added to the bottom navigation, becoming the fifth destination. Each row is one `RolePlay` (role to be enacted). Tap the row body to open the role read view. The tile expands to show both halves of the entry: the **Role** section (publishable scenario fields from the `RolePlay`) and the **Cast** section (the locally-assigned `Actor`, or an "Add cast" affordance if none is yet linked). A filter FAB narrows the list to one exercise, mirroring the pattern from [DESIGN-002](./stations-tab.md). When the Exercise Player from [DESIGN-001](./exercise-player.md) eventually exists in code, the observer-player gains a **Role** tab that surfaces the same scenario fields for a participant who is enacting a role.

## Rationale

[ADR-0018](../adrs/0018-roleplayer-data-model.md) introduced `RolePlay` and `Actor` at the data model level, but gave them nowhere to live in the UI. [ADR-0019](../adrs/0019-roleplayer-participant-role.md) added the runtime role *roleplayer* to the session model, but a roleplayer can only check in if the role exists in the program first. Both ADRs assume an authoring surface.

The RolePlays tab is that authoring surface. Authors create roles, fill in signalement and behaviour, optionally cast a person from the local roster, and during a run the same data feeds the player and the map.

The tab also acts as the natural roster manager. Actors are program-scoped (one cast pool, reused across exercises), so the tab needs to expose adding a person without forcing a separate top-level destination just for that.

## Goals

1. Give RolePlays a first-class home in the navigation, on equal footing with Exercises, Map, Stations and Teams.
2. Keep the **Role** and **Cast** halves of an entry visually adjacent but operationally separated. Editing the role is publishable; editing the cast is local-only.
3. Reuse the expandable-tile and filter-FAB pattern from [DESIGN-002](./stations-tab.md) so users have one mental model for browsing scoped lists.
4. Make casting a one-tap affordance from the tile rather than a hidden form deep in a sub-screen.
5. Specify the role-tab content the observer-player will surface during a run, so the player work and the tab work can happen in either order without re-design.

## Non-goals

* **No role-timing.** Behaviour fields stay free-text in this iteration. A later design may introduce a structured timeline (`escalate to hypothermia at +30 min`) but that requires extending `RolePlay`. Out of scope here.
* **No coordinator-to-roleplayer messaging.** Ad-hoc instructions during a run go via the operational radio. Adding a chat or instruction patch would require a new session patch kind and a fresh ADR.
* **No status tracking** ("found", "evacuated", "transported"). The user has explicitly deferred this. The RolePlays tab inspects and edits structural data, not run state.
* **Does not build the observer-player shell.** The shell belongs to [DESIGN-001](./exercise-player.md). This doc specifies what slots into it once it exists.
* **No structural changes to the set of roles from anywhere except the Exercises tab.** Add and remove are exercise-setup operations, mirroring the rule for stations from [DESIGN-002](./stations-tab.md). The RolePlays tab inspects and edits role properties.

## Navigation

The bottom navigation gets a fifth destination. Order follows the planning workflow: Exercises define the structure, the Map shows the layout, Stations and RolePlays describe what is at each location, Teams describe who runs through.

| # | Norwegian | English   | Icon                  | Route          |
|---|-----------|-----------|-----------------------|----------------|
| 0 | Øvelser   | Exercises | `Icons.update`        | `/program`     |
| 1 | Kart      | Map       | `Icons.map`           | `/map`         |
| 2 | Poster    | Stations  | `Icons.place`         | `/stations`    |
| 3 | Markører  | RolePlays | `Icons.theater_comedy`| `/roleplays`   |
| 4 | Lag       | Teams     | `Icons.group`         | `/teams`       |

`Icons.theater_comedy` reads as "performance" without crossing into the medical or military glyph space that other tabs already use. Placement between Stations and Teams groups the scenario-side entities (Stations + RolePlays) before the participants (Teams).

Five tabs is the upper bound for a Material bottom navigation before icons start losing their labels on narrow phones. We are now at that bound. A sixth tab would force a different chrome and should not be added without revisiting this design.

## List structure

**Flat list, not grouped.** One row per `RolePlay`. The Exercises tab already provides a grouped view of the program, so grouping here would duplicate.

**Sorting.** First by exercise order, then by the role's `index` within the exercise.

**Roster access.** A small persistent action in the AppBar (icon-button, `Icons.people_outline`, tooltip "Cast roster" / "Markører") opens a separate sheet listing all `Actor` records in the program. Add, edit, and remove happen there. The Cast roster is not its own tab because it is supporting infrastructure for casting, not a destination users navigate to on its own.

## Filtering

A **filter FAB** in the bottom-right corner narrows the list to one exercise, mirroring [DESIGN-002](./stations-tab.md):

* **Inactive (default):** plain FAB, no badge. The list shows roles from every exercise.
* **Active:** the FAB carries `Badge.count(count: 1, child: fab)`, and a slim banner above the bottom navigation reads "Showing roles in: <Exercise name>" with a "Show all" recovery button.

Tap the FAB → modal bottom sheet with a radio selector and an "All exercises" row. Single-select, applies on selection. State does not persist across process restarts.

## Tile anatomy

Each row is an expandable tile based on the shared `RoleExpansionTile` widget (see *Shared widgets*).

**Collapsed:**

* Leading: compact role-code square showing `exerciseNumber.roleNumber` (1-based), parallel to the station code from [DESIGN-002](./stations-tab.md).
* Title: role name (e.g. "Anna Hansen, savnet turgåer").
* Subtitle: `Exercise: <name>`.
* Trailing: a small cast indicator. A filled `Icons.person` chip if cast, an outlined `Icons.person_add` chip if not. Tap on the chip opens the cast picker directly. Chevron sits next to it for expand/collapse.

**Expanded adds two stacked sections, in this order:**

### Role section (`RolePlay` fields, publishable)

A label "Role" with a subtle book-marker icon (`Icons.menu_book`). Body:

* Age (if set), rendered inline next to the name as "Anna Hansen, 67".
* **Signalement.** Free-text, paragraph rendering. Empty placeholder "Ingen signalement" / "No description" when blank.
* **Background.** Free-text, paragraph rendering. Empty placeholder "Ingen bakgrunn" / "No background" when blank.
* **Behavior.** Free-text, paragraph rendering. Empty placeholder "Ingen oppførsel" / "No behaviour" when blank.
* Station row. If `stationIndex` is set, a chip "Post: <station name>" linking to `StationScreen`. If not, "Ingen post" / "No station".
* Mini-map if `position` is set. Reuses `StationMiniMap` from [DESIGN-002](./stations-tab.md) (the widget is already domain-agnostic per [[feedback_mapview_domain_agnostic]]; we pass a marker, not a domain flag). Tap → bottom-sheet map. Empty case: no mini-map slot.

### Cast section (`Actor` fields, local-only)

A label "Cast" / "Markør" with a subtle `Icons.person` icon. Visually subdued (slightly less weight than the Role section) so the publishable/private boundary reads at a glance. Body branches on `RolePlay.actorUuid`:

* **Cast set** (`actorUuid != null`): shows the cast actor's `realName` and `phone` (tap-to-call), plus `notes` if any. A trailing overflow menu offers "Edit cast" / "Rediger markør" (opens `ActorFormScreen`) and "Clear cast" / "Fjern markør" (sets `actorUuid = null`).
* **Not cast** (`actorUuid == null`): a single full-width button "Add cast" / "Velg markør" with a `+` icon. Opens the cast picker.

A "Private — never published" subtitle accompanies the Cast section header on the first expanded tile per session (a one-time hint after install, dismissible). The hint exists to make the privacy boundary explicit, given that users coming from chat-thread-based casting do not have an existing mental model for "this stays on my device".

**Tap targets are split:**

* Row body → push `RolePlayScreen` for the role (read view).
* Cast chip in the collapsed row → open cast picker.
* Chevron → toggle expand/collapse.
* Mini-map → open the map bottom sheet (does not navigate).
* Swipe-left on the row → open `RolePlayFormScreen` for the role (edit form). Same `Dismissible` pattern as [DESIGN-002](./stations-tab.md).

**Mutex expansion.** At most one tile is open at a time, same shape as the Stations tab.

## Cast picker

The cast picker is a `showModalBottomSheet`. Top: drag handle, title "Cast: <role name>" / "Markør: <rollenavn>", and a search field. Body: list of every `Actor` in the program's roster.

Each actor row shows `realName` and (small, secondary) `phone`. A subtitle annotation marks actors who are already cast in another role for *the same exercise*: "Already cast as <other role name>". They are still selectable, but the warning surfaces the working assumption from [ADR-0018](../adrs/0018-roleplayer-data-model.md) (one actor per role per exercise) without making it a hard rule.

Top of the list, above the actor rows: a sticky "New actor" / "Ny markør" tile. Tap → `ActorFormScreen` in modal mode. On save, the new actor is added to the roster and immediately cast to the current role.

Selecting an actor row sets `RolePlay.actorUuid` and closes the sheet. The expanded tile updates inline.

## Cast roster sheet

Opened from the AppBar action. Lists every `Actor` in the program. Each row:

* `realName` and `phone`.
* A small footer listing roles this actor is currently cast to ("Cast as: <role 1>, <role 2>" / "Markør for: <rolle 1>, <rolle 2>"). Empty when uncast.
* Tap row → `ActorFormScreen` for edit.
* Swipe-left → confirm deletion. Deletion is allowed only when the actor is uncast in every role; otherwise the swipe shows "Cast in <N> role(s). Clear before deleting" / "Markør i <N> rolle(r). Fjern først" and snaps back.

A "New actor" FAB lives in this sheet only.

## Map marker glyph

Per [ADR-0019](../adrs/0019-roleplayer-participant-role.md), live roleplayer positions render with a distinct marker shape from team broadcasters. The chosen glyph:

* Shape: a square with rounded corners (vs the team marker's circle), so the silhouette differs at a glance.
* Glyph inside: small `Icons.theater_comedy` matching the tab icon.
* Colour: derived from the role's station colour if the role has a `stationIndex`. Otherwise a neutral roleplayer accent (proposed: `colorScheme.tertiary`).
* Label: the role name from local `rolePlays` lookup. No actor identity ever appears here ([ADR-0019](../adrs/0019-roleplayer-participant-role.md) display alternative 1).

Stale positions follow the same dimming rule as team broadcasters ([ADR-0012](../adrs/0012-position-sharing-and-team-aggregation.md)).

A static role position (`RolePlay.position` set on the model, no live broadcaster) renders with the same shape but a "pinned" border weight and no staleness state. The mini-map inside an expanded tile uses this static marker.

## Role tab inside the observer-player

Scope reminder: the observer-player shell does not exist in code yet. [DESIGN-001](./exercise-player.md) is Accepted on paper. This section specifies the role-specific slot **so that whoever builds the observer-player shell has the spec ready**.

For a participant whose `SessionParticipant.rolePlayUuid != null`, the observer-player swaps its existing tabs to:

| Tab    | Contents                                                                                    |
|--------|---------------------------------------------------------------------------------------------|
| Role   | The role brief, exact same fields as the expanded tile's Role section. Read-only here.      |
| Post   | The station the role is tied to (if any). Same shape as the observer-player Post tab.       |

The Team tab from [DESIGN-001](./exercise-player.md)'s lag/post split is **dropped** for roleplayers. A roleplayer follows their role, not a team.

A "Del posisjon" / "Share position" toggle lives in the role tab footer, gating the local position broadcaster per [ADR-0012](../adrs/0012-position-sharing-and-team-aggregation.md) consent rules. The toggle text is tailored to the markør context: "La leteleder se hvor du er" / "Let the operator see your position".

## Behaviour

| Gesture                          | Result                                                                  |
|----------------------------------|-------------------------------------------------------------------------|
| Tap tile body                    | Push `RolePlayScreen` (read view).                                      |
| Tap chevron                      | Toggle expansion. Mutex collapses any previously open tile.             |
| Tap cast chip (collapsed)        | Open cast picker.                                                       |
| Tap "Add cast" (expanded)        | Open cast picker.                                                       |
| Tap cast row (expanded, set)     | No-op on the row body. Use the overflow menu for edit/clear.            |
| Tap mini-map                     | Open the map bottom sheet.                                              |
| Swipe-left on the row            | `confirmDismiss` pushes `RolePlayFormScreen`, returns false, row snaps. |
| Tap filter FAB                   | Open the exercise picker bottom sheet.                                  |
| Tap "Show all" in filter banner  | Clear filter.                                                           |
| Tap roster action in AppBar      | Open the cast roster sheet.                                             |

## Empty states

* **No roles in the program:** "No roles yet. Add a role from the Exercises tab." Mirrors the Stations tab empty state.
* **Filter excludes everything:** banner stays visible with "Show all" recovery. List area: "No roles in this exercise."
* **No actors in the roster** (during cast picker): the sticky "New actor" row is the only option, no message needed beyond the empty list.

## Relationship to the Exercise Player

The RolePlays tab is run-agnostic. It inspects and edits regardless of whether a session is active. The Exercise Player (per [DESIGN-001](./exercise-player.md)) draws roleplayer state during a run, but the editing surfaces stay here.

During a run a roleplayer participant on the player is not the same affordance as a `RolePlay` row in the tab. The tab shows authored data; the player shows live participants enacting that data. They share the `rolePlayUuid` as the link.

## Shared widgets

### `RoleExpansionTile`

`lib/views/widgets/role_expansion_tile.dart`.

Built on the same slot-based pattern as `StationExpansionTile` (from [DESIGN-002](./stations-tab.md)). Slots:

| Slot       | Type    | Notes                                                          |
|------------|---------|----------------------------------------------------------------|
| `leading`  | Widget  | Compact role-code square.                                      |
| `title`    | Widget  | Role name (and inline age).                                    |
| `subtitle` | Widget? | Optional. RolePlays tab uses `Exercise: <name>`.               |
| `trailing` | Widget? | Cast chip + chevron in this tab. Other surfaces may differ.    |
| `body`     | Widget  | Caller-supplied expanded content (Role + Cast for the tab).    |

Tap targets are split exactly as `StationExpansionTile`. The widget owns no domain state; consumers wire it.

### `RoleMiniMap`

Skipped. `StationMiniMap` from [DESIGN-002](./stations-tab.md) is already domain-agnostic — we pass it a `LatLng` and a marker spec, no role-aware logic needed.

## Deferred decisions

* **Behaviour timing.** Free-text only for now. Structured time-driven cues (`escalate at +30 min`) are a model extension and need their own design.
* **Field markers (mobile roleplayers).** Per the user, mobile markers are allowed but their consequences are deferred. The current spec assumes a roleplayer is tied to one station at a time. When mobility lands, the Role tab gains an itinerary slot.
* **Run-state on roles.** "Found", "evacuated", "transported" deferred. Adding these would require a session patch kind and a fresh ADR.
* **Coordinator-to-roleplayer messaging.** Out of scope. Radio remains the channel.

## Implementation notes

Scope per Alternative X (additive to [DESIGN-001](./exercise-player.md)). Implementation order is open: a contributor may land the RolePlays tab against the Exercises tab first (with no observer-player work) and the role tab inside the player later when DESIGN-001 builds the shell. Nothing in this design forces a particular order.

Localization keys land in `lib/l10n/app_en.arb` and `app_nb.arb` together. Norwegian uses "Markører" (tab name and roster), "Rolle" (Role section) and "Markør" (Cast section, singular) per the terminology rule.

`lib/views/main_screen.dart` gains the fifth route and the bottom-navigation entry. The route name in code is `/roleplays`. `lib/views/widgets/role_expansion_tile.dart` is the new shared widget. `RolePlayScreen` and `RolePlayFormScreen` are new screens at `lib/views/`. `ActorFormScreen` is new and is the only screen that touches `Actor` records.
