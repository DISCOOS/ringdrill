---
id: DESIGN-003
title: RolePlays tab
status: Accepted
started: 2026-05-23
accepted: 2026-05-23
revised: 2026-05-24
owners: ["kengu"]
related_code:
  - lib/views/main_screen.dart
  - lib/views/roleplay_form_screen.dart
  - lib/views/roleplay_screen.dart
  - lib/views/actor_form_screen.dart
  - lib/views/station_screen.dart
  - lib/views/widgets/station_expansion_tile.dart
  - lib/views/widgets/role_expansion_tile.dart
  - lib/views/map_view.dart
related_designs:
  - exercise-player.md
  - stations-tab.md
related_adrs:
  - ../adrs/0018-roleplayer-data-model.md
  - ../adrs/0019-roleplayer-participant-role.md
---

# RolePlays tab

> Terminology note (Norwegian UI). In SAR practice, a *markørordre* is the briefing document for one role at one location, the role half of what this design covers. A *markør* is the human enacting that order. The model maps cleanly: **`RolePlay`** is the digital markørordre (publishable, scenario fields), **`Actor`** is the markør (local, PII). The Norwegian UI follows a simple rule:
>
> - **"Markørordre"** is used when the surface names a single `RolePlay` entity: section labels on the expanded tile, form titles ("Ny markørordre", "Rediger markørordre"), and creation affordances ("Legg til markørordre").
> - **"Markører"** is used for lists, counts, navigation and other colloquial references. The tab name, the cast-roster sheet title, section headers above lists of role briefs, and empty-state counts all use the plural colloquial form ("Ingen markører ennå", "5 markører på denne posten").
> - **"Markør"** (singular) stays reserved for direct references to the human (`Actor`) and the actions that operate on them: cast picker title, "Velg markør", "Rediger markør", "Fjern markør", "Allerede markør for {role}", "Markør for: {roles}".
> - **"Spilles av"** is used as a relation label on the expanded tile's Cast section, because the section answers the question "who plays this role" rather than naming an entity. English uses "Played by". This is the one place a relation phrase wins over the entity term.
>
> English UI and all code use **"RolePlay"** and **"Actor"** without this distinction.

## TL;DR

A new **RolePlays** tab is added to the bottom navigation, becoming the fifth destination. Each row is one `RolePlay` (a markørordre). Tap the row body to open the role read view. The tile expands to show both halves of the entry: the **Role** section (publishable scenario fields from the `RolePlay`) and the **Cast** section (the locally-assigned `Actor`, or an "Add cast" affordance if none is yet linked). A filter FAB narrows the list to one exercise, mirroring the pattern from [DESIGN-002](./stations-tab.md). When the Exercise Player from [DESIGN-001](./exercise-player.md) eventually exists in code, the observer-player gains a **Role** tab that surfaces the same scenario fields for a participant who is enacting a role.

Creation of roles happens on the **Station screen** (the post), not in this tab and not in the exercise form. The post is where a markørordre is physically distributed in the field, and the same place is where it is authored digitally. See [Creating roles](#creating-roles).

## Rationale

[ADR-0018](../adrs/0018-roleplayer-data-model.md) introduced `RolePlay` and `Actor` at the data model level, but gave them nowhere to live in the UI. [ADR-0019](../adrs/0019-roleplayer-participant-role.md) added the runtime role *roleplayer* to the session model, but a roleplayer can only check in if the role exists in the program first. Both ADRs assume an authoring surface, but neither commits to where.

In SAR practice the markørordre belongs to the post. Operators print or hand a brief to the person playing the role at the location where they will enact it, so the post is where authors think about who is there and what they are doing. Mirroring that into the app, creation of a `RolePlay` happens from the Station screen, where the markørordre conceptually lives. Multiple roles per post are allowed because real scenarios pair a missing person with a witness, a casualty with a bystander, an interview subject with their family member.

The RolePlays tab is the cross-cutting inspect and cast-management surface. It lists every role across every post and exercise, lets the operator cast actors from the local roster, and acts as the natural roster manager (Actors are program-scoped and reused across exercises). It does not own structural changes to the set of roles. That ownership sits with the Station screen.

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
* **No structural changes to the set of roles from the RolePlays tab.** Add and remove are post-level operations and happen on the Station screen ([Creating roles](#creating-roles)). The RolePlays tab inspects role properties and manages cast.
* **No creation of station-less roles in this iteration.** Wandering or scenario-only `RolePlay`s (no `stationIndex`) are allowed by the data model but have no creation affordance yet. A follow-up may add an "unattached role" entry point if a real use case appears. The current Station-screen flow always sets `stationIndex` on creation.

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

**Roster access.** A small persistent action in the AppBar (icon-button, `Icons.recent_actors`, tooltip "Played by" / "Spilles av") opens a separate sheet listing all `Actor` records in the program. The icon depicts a row of silhouettes, matching the semantic "list of castable people". The tooltip uses the same "Spilles av" relation phrase as the Cast section label on the expanded tile, which reinforces that this button gives access to the same data the tile displays. Add, edit and remove happen inside the sheet. The Cast roster is not its own tab because it is supporting infrastructure for casting, not a destination users navigate to on its own.

**Actor icon family.** The casting surfaces use a small icon hierarchy:

* `Icons.recent_actors` — the AppBar action that opens the list of actors. Plural silhouette row, list-level.
* `Icons.face` — leading icon on individual actor rows inside the cast roster sheet and the cast picker sheet. Single face, row-level.
* `Icons.person` (filled) and `Icons.person_add_outlined` (outlined) — the cast affordance family. Used on the cast chip on Markører-tab tiles and Station-screen Markører rows, and on the Cast section header next to the "Spilles av" label inside the expanded tile (the section header marks the affordance that the chip controls, so it belongs to the same family). Material does not ship a `face_add` companion; keeping the section header and the chip pair on `Icons.person` preserves visual symmetry.

The action's tooltip carries a different message when the action is disabled (no active program): `localizations.noActiveProgramHint` so a long-press explains why the button is greyed out. See [Active-program gating](#active-program-gating).

The Markører-tab icon stays `Icons.theater_comedy`, distinct from `Icons.recent_actors`, so the tab in the bottom-nav (the role briefs / markørordrer) and the AppBar action (the people / markører) are visually unambiguous.

## Filtering

A **filter FAB** in the bottom-right corner narrows the list to one exercise, mirroring [DESIGN-002](./stations-tab.md):

* **Inactive (default):** plain FAB, no badge. The list shows roles from every exercise.
* **Active:** the FAB carries `Badge.count(count: 1, child: fab)`, and a slim banner above the bottom navigation reads "Showing roles in: <Exercise name>" with a "Show all" recovery button.

Tap the FAB → modal bottom sheet with a radio selector and an "All exercises" row. Single-select, applies on selection. State does not persist across process restarts.

## Tile anatomy

Each row is an expandable tile based on the shared `RoleExpansionTile` widget (see *Shared widgets*).

**Collapsed:**

* Leading: compact role-code square showing `exerciseNumber.roleNumber` (1-based), parallel to the station code from [DESIGN-002](./stations-tab.md).
* Title: role name, with `age` appended as `, <age>` when set, and the cast actor's `realName` appended as ` (<realName>)` when the role is cast (`actorUuid != null`). Example: "Anna Hansen, 67 (Kari Nordmann)". The cast suffix is shown **only** on this tile (the Markører tab). Other surfaces — form AppBar, `RolePlayScreen` read view, Station-screen Markører row — already convey cast status through their own affordances (dedicated Cast section, read view, trailing chip) and duplicating the cast name in the title there would clutter the surface.
* Subtitle: `Post: <station name>` / `Station: <station name>` when `stationIndex` is set. Falls back to `Øvelse: <name>` / `Exercise: <name>` when stationIndex is null (rare since DESIGN-003 defers station-less creation, but possible for legacy data). The post is the role's operational home and is what the operator wants to see at a glance; the exercise is already encoded in the leading code badge ("1.5" → exercise 1) and filterable via the FAB.
* Trailing: a small cast indicator. A filled `Icons.person` chip if cast, an outlined `Icons.person_add_outlined` chip if not. Tap on the chip opens the cast picker directly. Chevron sits next to it for expand/collapse.

**Expanded adds two stacked sections, in this order:**

### Role section (`RolePlay` fields, publishable)

A label "Role" / "Markørordre" with a subtle book-marker icon (`Icons.menu_book`). Body:

* Age (if set), rendered inline next to the name as "Anna Hansen, 67".
* **Signalement.** Free-text, paragraph rendering. Empty placeholder "Ingen signalement" / "No description" when blank.
* **Background.** Free-text, paragraph rendering. Empty placeholder "Ingen bakgrunn" / "No background" when blank.
* **Behavior.** Free-text, paragraph rendering. Empty placeholder "Ingen oppførsel" / "No behaviour" when blank.
* Station row. If `stationIndex` is set, a chip "Post: <station name>" linking to `StationScreen`. If not, "Ingen post" / "No station".
* Mini-map if `position` is set. Reuses `StationMiniMap` from [DESIGN-002](./stations-tab.md); the widget is already domain-agnostic, so we pass a marker rather than a domain flag. Tap → bottom-sheet map. Empty case: no mini-map slot.

### Cast section (`Actor` fields, local-only)

A label "Played by" / "Spilles av" with a subtle `Icons.person` icon. The label is a relation phrase, not the entity name, because the section answers *who plays this role* rather than naming the human. Visually subdued (slightly less weight than the Role section) so the publishable/private boundary reads at a glance. Body branches on `RolePlay.actorUuid`:

* **Cast set** (`actorUuid != null`): shows the cast actor's full record — `realName` as the primary line, `phone` directly below with `tel:` tap-to-call (suppressed when null), and `notes` as a third line when non-empty. A trailing overflow menu offers "Edit cast" / "Rediger markør" (opens `ActorFormScreen` and persists the returned `Actor`) and "Clear cast" / "Fjern markør" (sets `actorUuid = null`).
* **Not cast** (`actorUuid == null`): a single full-width button "Add cast" / "Velg markør" with a `+` icon. Opens the cast picker.

A "Stays on this device" / "Lagres lokalt" subtitle accompanies the Cast section header at all times. The hint is short and informative enough to stay persistent without becoming visual noise; framing it positively ("stays here") rather than negatively ("never published") matches what the user actually needs to know. It exists because users coming from chat-thread-based casting do not have an existing mental model for "this stays on my device".

**Tap targets are split:**

* Row body → push `RolePlayScreen` for the role (read view).
* Cast chip in the collapsed row → open cast picker.
* Chevron → toggle expand/collapse.
* Mini-map → open the map bottom sheet (does not navigate).
* Swipe-left on the row → open `RolePlayFormScreen` for the role (edit form). Same `Dismissible` pattern as [DESIGN-002](./stations-tab.md).

**Mutex expansion.** At most one tile is open at a time, same shape as the Stations tab.

## Form anatomy

`RolePlayFormScreen` is reached from three surfaces (the Markører-tab row swipe, the Station-screen row swipe, and the Station-screen "+ Legg til markørordre" action). The AppBar mirrors the list-row anatomy so the form feels like a continuation of the row you came from, not a context switch.

* **Leading position** (inside the title slot, before the back button is handled by the framework's automatic leading): `RoleCodeBadge` showing `${exerciseNumber}.${role.index + 1}`. For a draft role that has not been saved yet, the same expression still works because the draft is constructed with the correct `index` before the form is pushed.
* **Title line**: the role's `name`. When the form is opened in create mode the name starts empty; the title falls back to `localizations.newRolePlayTitle` ("Ny markørordre" / "New role") until the user types a name.
* **Subtitle line**: same format as the Markører-tab row subtitle. `Post: <station name>` when `stationIndex` is set, falling back to `Øvelse: <name>` when null. The exercise context is always available via the `exercise` constructor parameter.

The layout follows the same Row + Column pattern used by `_MapSheetHeader` in `lib/views/widgets/station_mini_map.dart`. Reuse that shape; do not invent a parallel one.

## Cast picker

The cast picker is a `showModalBottomSheet`. Top: drag handle, title "Cast: <role name>" / "Markør: <rollenavn>", and a search field. Body: list of every `Actor` in the program's roster.

Each actor row shows `realName` and (small, secondary) `phone`. A subtitle annotation marks actors who are already cast in another role for *the same exercise*: "Already cast as <other role name>". They are still selectable, but the warning surfaces the working assumption from [ADR-0018](../adrs/0018-roleplayer-data-model.md) (one actor per role per exercise) without making it a hard rule.

Top of the list, above the actor rows: a sticky "New actor" / "Ny markør" tile. Tap → `ActorFormScreen` in modal mode. On save, the new actor is added to the roster and immediately cast to the current role.

Selecting an actor row sets `RolePlay.actorUuid` and closes the sheet. The expanded tile updates inline.

## Cast roster sheet

Opened from the AppBar action on the Markører tab (the action lives on the tab itself, not inside the sheet). Presented via `showModalBottomSheet` with `showDragHandle: true` so the drag handle at the top of the sheet is the dismiss affordance.

**No AppBar inside the sheet.** The sheet's layout is a `Scaffold` body composed of a header row plus a list, with a "New actor" FAB anchored at the bottom-right by the Scaffold. The header row sits at the top of the body, padded, and renders the sheet's title ("Markører" / "Cast roster") as `titleLarge`. No back button, no leading icon. The phrase "Opened from the AppBar action" in this design refers to *how* the sheet is launched, not to having one inside.

Lists every `Actor` in the program. Each row:

* `realName` and `phone`.
* A small footer listing roles this actor is currently cast to ("Cast as: <role 1>, <role 2>" / "Markør for: <rolle 1>, <rolle 2>"). Empty when uncast.
* Tap row → `ActorFormScreen` for edit.
* Swipe-left → confirm deletion. Deletion is allowed only when the actor is uncast in every role; otherwise the swipe shows "Cast in <N> role(s). Clear before deleting" / "Markør i <N> rolle(r). Fjern først" and snaps back.

Empty state (no actors yet): a padded multi-line hint reading "Ingen markører ennå. Trykk + Ny markør for å legge til." / "No actors yet. Tap + New actor to add one." Uses `bodyMedium` with `onSurfaceVariant`. The hint sits in the list body, not as floating centred text; the FAB carries the same "Ny markør" label and the hint points to it.

A "New actor" FAB lives in this sheet only.

## Creating roles

A `RolePlay` is the digital form of a markørordre. The Station screen is where one is authored, because the post is where the markørordre is distributed to the person playing it in the field. Routing creation through the Station screen also enforces that every role created this way has a `stationIndex` set, which is the common case and keeps the operator's mental model anchored on locations.

### Station screen "Markører" section

The Station screen gains a "Markører" / "Roles" section below the existing station fields (name, description, position). The section lists every `RolePlay` where `exerciseUuid` matches the station's owning exercise and `stationIndex` matches this station's index.

Each row is a compact variant of the RolePlays-tab tile, intended to fit several rows in a screen without scrolling:

* Leading: a small theatre glyph (`Icons.theater_comedy`).
* Title: role name.
* Trailing: cast chip (`Icons.person` filled when cast, `Icons.person_add` outlined when not).
* No expansion. Tap row body → push `RolePlayScreen` (read view). Tap cast chip → open cast picker.
* Swipe-left → push `RolePlayFormScreen` for edit, same `Dismissible` pattern used elsewhere.

**Deletion is not supported in this iteration.** See [Deletion and templating](#deletion-and-templating).

A section-header action "+ Legg til markørordre" / "Add role" sits to the right of the section title. Tap opens `RolePlayFormScreen` in create mode with `exerciseUuid` and `stationIndex` pre-filled from the station context. On save, the new `RolePlay` is appended to `Program.rolePlays` and the section refreshes inline.

### Multiple roles per post

Multiple roles at the same post are allowed and expected. A "missing person at the cabin" scenario typically pairs the person with a witness, a relative, or a casual bystander. Each is its own `RolePlay` with the same `stationIndex`. No model change is required, since [ADR-0018](../adrs/0018-roleplayer-data-model.md) does not constrain `stationIndex` uniqueness.

The section list has no enforced order beyond stable insertion order. Operators who care about a specific reading order can rename the roles to encode it ("01 Anna", "02 Witness").

### Edit from either surface, create only from the Station screen

Both surfaces offer edit (swipe-left → `RolePlayFormScreen`). Only the Station screen offers create. The RolePlays tab continues to expose cast operations (cast picker, clear cast) and the cast roster sheet, but the "+" button is absent there. Structural changes (the set of role briefs at a post) funnel through the post.

### Deletion and templating

Deletion of `RolePlay` records is **not** supported in this iteration, on either the Station screen or the RolePlays tab. The reasoning:

* `Program.rolePlays` is already a flat, program-scoped list. That structure is a natural foundation for treating a markørordre as a **template** that can be reused across posts and exercises later. Adding destructive deletion now would force us to choose between hard-delete (loses reuse potential) and soft-delete (drags lifecycle state into the model). Neither is the right call before templating itself is designed.
* In SAR practice, an authored markørordre rarely becomes wholly invalid. The common operations are "move to another post" (handled by editing `stationIndex`) and "don't use this brief in this exercise" (not yet expressible in the model).
* No real user has asked for deletion. Adding it speculatively pre-empts the templating design.

If the operator authored a role by mistake, the practical workaround is to edit and rename it, or to leave it. Stale role briefs at the bottom of `Program.rolePlays` carry no runtime cost: nothing references them unless they have a `stationIndex` and `exerciseUuid` placing them at a post, and even then they only render on the post screen and the Markører tab.

A future iteration may introduce:

* **Template instantiation.** A markørordre authored once, then referenced from multiple `(exercise, station)` pairs. Requires either an indirection field on `RolePlay` or a separate template record. The current single-`exerciseUuid` field implies one-instance-per-brief, which the templating work will need to resolve.
* **"Don't use here anymore".** A post-level disassociation that removes the role from one location without destroying the brief. Likely surfaces as a row action on the Station screen.
* **Hard delete.** Only meaningful after templating exists, since today every `RolePlay` is already its own instance.

Until then, the design is intentionally append-only on this axis. See [Deferred decisions](#deferred-decisions).

### Empty state on the Station screen

When the post has no roles, the section header still renders with the "+ Legg til markørordre" action, and the body shows a thin one-line hint: "Ingen markører på denne posten" / "No roles at this post". The hint disappears once the first role is added.

### Empty state on the RolePlays tab

The previous wording ("Add a role from the Exercises tab") is wrong under this revision. The corrected language:

* **No roles in the program:** "Ingen markører ennå. Åpne en post i Poster-fanen for å legge til en." / "No roles yet. Open a post in the Stations tab to add one." ARB key: `noRolesInProgram` (existing key, content revised).

## Station-expansion summary

Two surfaces render stations as expandable rows in addition to the dedicated Station screen: the coordinator screen's station list (the operator's primary view during a run) and the Stations tab's flat list (the cross-cutting browser). Both expansion bodies currently render description + position panel. They get a third inline section: a **read-only** Markører summary.

Behaviour:

* When the station has no role attached, the section is **omitted entirely**. No header, no empty-state hint. Surfaces that historically showed only description + position panel keep that exact layout when no roles exist.
* When one or more roles are attached, a small header row reads "Markører (<count>)" with a leading `Icons.theater_comedy` glyph, followed by one compact row per role.
* Each row: leading `Icons.theater_comedy` (size ~18), title is `role.name` only, trailing is a **non-interactive** cast-state chip (`Icons.person` filled when cast, `Icons.person_add_outlined` when not). Tap on the row body opens `RolePlayScreen` (the read view).
* The cast chip is purely a state indicator on these surfaces. It does not open the cast picker; that affordance lives on the Markører tab and the Station screen.
* No "Legg til markørordre" action, no swipe-edit, no delete, no overflow menu. Authoring stays on the dedicated Station screen per [Creating roles](#creating-roles).

Title rendering on these rows omits both the age suffix and the cast-actor parens. Those belong to the Markører-tab tile per [Tile anatomy](#tile-anatomy); other surfaces stay clean.

Implementation lives in a shared widget `lib/views/widgets/station_role_summary.dart` that takes `(Exercise exercise, int stationIndex)` and renders the section or `SizedBox.shrink()`. Both expansion callers drop the widget in without local gating logic. The widget reads from `ProgramService` on each build; it does not subscribe to mutation events. Refresh on role mutation elsewhere requires collapsing and re-expanding the row, which is acceptable for a browse surface.

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

* **No active program:** "Ingen aktiv øvelsesplan. Velg eller opprett en i Øvelser-fanen." / "No active program. Open or create one in the Exercises tab." Takes precedence over the other empty states on this tab — when no active program is set, the Markører tab body shows only this message. The cast-roster AppBar action stays visible but is **disabled** (greyed out, no-op on tap, tooltip carries the same message). The filter FAB is omitted entirely. See [Active-program gating](#active-program-gating) for the wider rule.
* **No roles in the program:** "No roles yet. Open a post in the Stations tab to add one." See [Creating roles](#creating-roles) for the full wording and ARB key.
* **Filter excludes everything:** banner stays visible with "Show all" recovery. List area: "No roles in this exercise."
* **No actors in the roster** (during cast picker): the sticky "New actor" row is the only option, no message needed beyond the empty list.
* **No actors in the cast roster sheet:** "Ingen markører ennå. Trykk + Ny markør for å legge til." See [Cast roster sheet](#cast-roster-sheet).

## Active-program gating

The Markører tab and every casting surface require an active program. Since actors can only be added from the cast roster sheet, and that sheet is opened only via the cast-roster AppBar action on the Markører tab, gating that one action also blocks every path to creating actors when no plan is active.

When `ProgramService.activeProgramUuid` is null:

* The Markører tab body shows the "no active program" empty state.
* The cast-roster AppBar action stays visible but is **disabled** (greyed out, no-op on tap). A tooltip carries the same "Ingen aktiv øvelsesplan..." message so a long-press explains why. Disabled (rather than hidden) preserves discoverability — the user sees that the affordance exists and what gates it.
* The filter FAB is omitted. Material's FAB convention is that a visible FAB is always actionable.
* The Station-screen "Markører" section is unreachable through normal navigation in this state, since opening a post requires opening an exercise, which requires an active program.

On app startup, the app does **not** auto-create a program. A fresh install lands the user in the no-active-program state and guides them to the Øvelser-fanen, rather than surprising them with a "Default plan" they did not author. A previously stored active reference is honored: when SharedPreferences contains the active-program key on launch, the app calls `ProgramService.ensureActiveProgram(localizations)` to validate or recover that reference. When the key is absent, no startup call runs.

`ProgramService.saveActor` and `saveRolePlay` do **not** include the auto-create-on-write behaviour that `saveExercise` does. The casting surfaces rely on the UI gating above to prevent saves without an active program. This keeps the casting paths honest: a save that would have failed surfaces as a blocked UI state, not a quietly auto-created program.

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
* **Deletion of markørordrer.** Not supported in this iteration. See [Deletion and templating](#deletion-and-templating). The current `Program.rolePlays` shape is a natural foundation for treating briefs as reusable templates; designing destructive deletion before that templating direction is settled would force a premature choice between hard-delete and soft-delete.
* **Templating.** `Program.rolePlays` is flat and program-scoped, which is exactly the shape needed for one-brief-many-instances. The design step is open: either an indirection field on `RolePlay` or a separate template record. Not in scope here. The point is that the current model does not block it.
* **Station-less role creation.** Allowed by the data model (`stationIndex` is optional) but has no creation affordance. Defer until a real use case appears.

## Implementation notes

Scope is additive to [DESIGN-001](./exercise-player.md). Implementation order is open: a contributor may land the RolePlays tab, the Station-screen authoring section and the observer-player role tab in any sequence. Nothing in this design forces a particular order.

Localization keys land in `lib/l10n/app_en.arb` and `app_nb.arb` together. Norwegian follows the terminology rule from the note at the top: **"Markører"** for the tab name, the cast roster sheet, the Station-screen section header, and empty-state counts. **"Markørordre"** as the Role section label on the expanded tile, in form titles ("Ny markørordre", "Rediger markørordre") and in creation affordances ("Legg til markørordre"). **"Markør"** stays for the cast picker title and action affordances ("Velg markør", "Rediger markør", "Fjern markør", "Allerede markør for {role}", "Markør for: {roles}"). **"Spilles av"** is the Cast section header on the expanded tile (relation phrase, not entity name).

`lib/views/main_screen.dart` gains the fifth route and the bottom-navigation entry. The route name in code is `/roleplays`. `lib/views/widgets/role_expansion_tile.dart` is the new shared widget. `RolePlayScreen` and `RolePlayFormScreen` are new screens at `lib/views/`. `ActorFormScreen` is new and is the only screen that touches `Actor` records.

`lib/views/station_screen.dart` (existing) gains the "Markører" section described in [Creating roles](#creating-roles). The section reads from `Program.rolePlays` filtered on `exerciseUuid` and `stationIndex`. The section's edit/delete actions write back through the same `ProgramService` path the existing station fields use.
