---
id: DESIGN-006
title: Program tab consolidation and Roster layer
status: Accepted
started: 2026-05-31
accepted: 2026-05-31
owners: ["kengu"]
related_code:
  - lib/views/main_screen.dart
  - lib/views/program_view.dart
  - lib/views/station_list_view.dart
  - lib/views/roleplays_view.dart
  - lib/views/teams_view.dart
  - lib/views/stations_view.dart
  - lib/views/shell/master_detail_scope.dart
  - lib/models/program.dart
  - lib/models/team.dart
  - lib/models/role_play.dart
  - lib/models/actor.dart
  - netlify/functions/drills-upload.js
related_designs:
  - stations-tab.md
  - roleplays-tab.md
  - brief-template.md
  - wide-screen-layout.md
  - exercise-player.md
related_adrs:
  - 0018-roleplayer-data-model.md
  - 0019-roleplayer-participant-role.md
  - 0022-markdown-content-as-files.md
  - 0028-feature-first-views-layout.md
  - 0030-wide-screen-master-detail-layout.md
  - 0032-program-scoped-routing.md
supersedes:
  - DESIGN-002
  - DESIGN-003
---

# Program tab consolidation and Roster layer

> This document is in English. Code symbols and identifiers are English, Norwegian UI labels are quoted from the `nb` localization. Entity naming follows [[feedback_post_station_terminology]] (*station* / "post") and the markører convention (`RolePlay` / `Actor`). See [Terminology](#terminology).

## TL;DR

The five-tab bottom navigation (Exercises, Map, Stations, RolePlays, Teams) collapses to **three tabs**: **Program**, **Map**, and **Roster**. The Program tab gains a **segmented switcher** with four lenses over the published plan: **Øvelser** (grouped, today's expandable exercise cards), **Poster** (flat station list), **Markører** (flat role list), and **Team** (flat team list). Above the switcher sits a **collapsing read-only overview** that summarizes the active plan (team count plus the program-level brief intro fields). The new **Roster** tab (`nb` "Bemanning") is the local people layer: a flat registry of real people assigned named roles, where today's `Actor` (markør cast) becomes one specialization alongside director, instructor and participant. The three-way split mirrors the publish boundary the server already enforces. Program is the publishable plan, Roster the local PII layer, Map the spatial lens.

## Rationale

Three problems converge.

**Navigation crowding.** Five root tabs is the ceiling M3 recommends, and the AppBar action row and the FAB are contested between tabs. Stations, RolePlays and Teams are all lenses on one plan, so giving each its own root destination spreads one coherent thing across the navigation instead of nesting it.

**Hidden people.** Today an `Actor` is reachable only by drilling into the cast section of the right `RolePlay` on the Markører tab. There is no surface that lists the real people involved in a plan. Cast assignment is a one-way street from the role. A dedicated people layer inverts that. You can start from the person and see or assign the roles they hold.

**An unexploited structural seam.** The server already strips `actors/` from a published `.drill` archive ([drills-upload.js](../../netlify/functions/drills-upload.js), [ADR-0018](../adrs/0018-roleplayer-data-model.md)). That strip is the real privacy boundary in the codebase. Exercises, stations, roleplays and teams survive publishing. Actor PII does not. Reorganizing the app around that boundary makes the privacy model legible in the navigation itself.

## Goals

1. Reduce the bottom navigation from five tabs to three without losing any current capability.
2. Make the FAB and AppBar actions contextual to the active view rather than contested across tabs.
3. Give the real people in a plan a first-class home so cast and staffing are no longer hidden inside role detail.
4. Align the navigation with the publish boundary already enforced server-side.

## Non-goals

* **No detail-view changes.** Only the master view changes. The detail/context-sheet flow (`ContextSheet`, `MasterDetailPane`) and every form screen are untouched. Editing happens exactly where it does today.
* **No new data-model fields in this design.** The overview renders the existing program-level brief field from [DESIGN-004](./brief-template.md) (`program.briefIntroMd`) read-only, but adds no new fields and no editor. The Roster "person with role" generalization is described as a direction, not built here.
* **No bidirectional editing.** The overview is a read-only projection, consistent with DESIGN-004's stance that entities are the source of truth and the brief is a projection.

## Information architecture

Three tabs, each a distinct layer:

| Tab           | Layer                          | Publish status                     | Route          |
|---------------|--------------------------------|------------------------------------|----------------|
| **Program**   | The publishable plan           | Survives publish                   | `/program`     |
| **Map**       | Spatial lens over the plan     | n/a (view)                         | `/map`         |
| **Roster** (`nb` "Bemanning") | Local people / staffing layer | Stripped on publish (PII) | `/roster`   |

The Program tab holds the four structural sets of the plan, viewable one at a time through a segmented switcher. Map is unchanged from today's behaviour (it keeps its own internal split per [DESIGN-005](./wide-screen-layout.md)). Roster is new.

### Why Team is a Program segment, not a Roster entry

`Team` is structural, not a person. The model carries `name`, `numberOfMembers` (a count) and an optional `position`, with no PII. It is published, and `numberOfTeams` on the exercise drives the ring rotation, so it belongs with the published plan alongside stations and roles. The people who *fill* the teams are the Roster concern.

## Program tab anatomy

```
┌───────────────────────────────────────────────┐
│  AppBar: <plan name>            [brief?]  ⋮    │
├───────────────────────────────────────────────┤
│  ┌─ overview (collapses on scroll) ─────────┐  │
│  │  <plan description / brief intro>        │  │  ← read-only
│  │  Les mer ▾                               │  │
│  └──────────────────────────────────────────┘  │
│  ┌─ pinned ─────────────────────────────────┐  │
│  │  [ Øvelser | Poster |  Spill   | Team ]  │  │  ← segmented switcher
│  └──────────────────────────────────────────┘  │
│                                                 │
│   <segment body: list for the active lens>      │
│                                                 │
│                                          ┌───┐  │
│                                          │ + │  │  ← contextual FAB
│                                          └───┘  │
├───────────────────────────────────────────────┤
│   ⬜ EXECUTION · Round 2/5      06:42      ⏹   │  ← mini player (DESIGN-001)
├───────────────────────────────────────────────┤
│   [ Program ]   [ Map ]   [ Roster ]            │
└───────────────────────────────────────────────┘
```

### Collapsing overview

A region at the top of the master pane showing read-only context for the active plan. It hides as the user scrolls the active list down and reappears on scroll up, so the list gets the full height when it needs it.

Content, all read-only:

* The active plan's `description` when set.
* A compact preview of the program-level brief intro (`program.briefIntroMd`) when present. Rendered in plain Material style, **not** the `BriefTheme` docs-site look from [ADR-0023](../adrs/0023-brief-theme-tokens.md), so that palette stays confined to the brief sheet.
* A **"Les mer" / "Vis mindre"** toggle at the bottom, shown only when the prose is long enough to be truncated, that expands and collapses the full text.

There is no plan-counts summary line. An earlier revision showed a "team count · segment count" line, but it added little and was removed.

The brief is reached from the **`Icons.menu_book` AppBar action**, present on every segment (it renders the whole plan), not from the overview. An earlier revision moved it into the overview, but it looked out of place there, so it was returned to the AppBar.

The overview is read-only. Plan rename stays on the AppBar title tap, and field editing happens in the relevant form. `briefIntroMd` exists on the model and loads at runtime (`program/intro.md`, [ADR-0022](../adrs/0022-markdown-content-as-files.md)); editing it is the DESIGN-004 stage 4 markdown editor on `ProgramFormScreen`, not part of this surface. When the plan has no description or brief intro, the overview is empty and collapses to nothing, and the switcher below is always present.

### Segmented switcher

The switcher is **pinned** below the overview as a `SliverPersistentHeader`, so the user can always change lens even after the overview has scrolled off. It is an M3 `SegmentedButton`, chosen over a `TabBar` because a TabBar signals swipeable peer tabs and would compete visually with the bottom navigation. The segments read as lenses on one dataset, the same "two lenses on the same entity" framing DESIGN-002 used for Map vs Stations, now extended to four.

The four segments are three lenses on the exercise tree plus the team set:

| Segment (`nb`) | Lens                                              | Source view today            |
|----------------|---------------------------------------------------|------------------------------|
| **Øvelser**    | Grouped: the exercise→station tree, expandable    | `ProgramView` (current)      |
| **Poster**     | Flat list of every station                        | `StationListView`            |
| **Spill**      | Publishable scenario elements (roles; see note)   | `RolePlaysView` (role part)  |
| **Team**       | Flat team list                                    | `TeamsView`                  |

Øvelser, Poster and Spill are three flatten-levels of the same `exercise → station → roleplay` tree, with increasing granularity. Team is a parallel set rather than a deeper level, an acceptable asymmetry.

**Script layer (Spill).** The Spill segment is the publishable scenario layer of the plan. Its current content is **Markører** (`RolePlay`) — a flat list of roles (no cast, no actor PII). A future sibling is **Tause vitner** (`SilentWitness`): a scenario element with description/story/purpose/info and position, but no actor assignment; details are out of scope for this design. Consider a shared scenario-element base when `SilentWitness` lands. The segment is named Spill (en "Script") rather than Markører to make the second content type a natural addition, not an exception.

**Markører shows roles only.** `RoleExpansionTile` ([DESIGN-003](./roleplays-tab.md)) already splits the Role section from the Cast section inside each tile. This design folds the Role section into the Spill segment and leaves cast binding to the Roster tab. The seam the tile already drew internally becomes the seam between the two tabs.

#### Open UX question: four labeled segments in a narrow master pane

On a phone the Program tab is full width and four short labels fit. In the wide layout the master pane is only 320 px (medium) or 420 px (expanded) per [ADR-0030](../adrs/0030-wide-screen-master-detail-layout.md), and four text segments are tight at 320. Candidate resolutions, to settle at implementation:

1. Icon + label on compact, **icon-only with tooltips** in the narrow master pane.
2. Keep labels and let the `SegmentedButton` shrink, accepting truncation at 320.
3. Drop to a different control (a leading dropdown or a scrollable segment row) when width is below a threshold.

Leaning toward option 1, since the four icons already exist (`Icons.update`, `Icons.place`, `Icons.theater_comedy`, `Icons.group`).

### Contextual FAB and actions

This is where the crowding is actually solved. With one tab, the FAB follows the active segment, and the AppBar carries the segment's own actions plus a constant brief action:

| Segment   | FAB           | Segment AppBar action(s)        |
|-----------|---------------|----------------------------------|
| Øvelser   | "Ny øvelse"   | —                                |
| Poster    | —             | Exercise filter                  |
| Spill     | "Ny rolle"    | Exercise filter, cast roster     |
| Team      | —             | —                                |

The **brief** (`Icons.menu_book`) is a constant action on **every** segment, pinned rightmost next to the status badge, because it renders the whole plan and is segment-independent. The exercise **filter** is an AppBar action on **both** Poster and Spill (the same badge + banner + picker pattern from DESIGN-002), keeping the FAB slot free for "create" actions. Earlier the Poster filter was a body FAB and only the Markører/Spill segment's was an action; they were unified to an action so the design matches and the FAB no longer covers the filter banner.

### Sliver structure

The master pane becomes a single `CustomScrollView`:

1. Overview sliver (`SliverToBoxAdapter` or a collapsing `SliverAppBar`-style region) that scrolls off.
2. Pinned `SliverPersistentHeader` carrying the `SegmentedButton`.
3. `SliverList` rendering the active segment's content. Switching segment swaps the list body. Expansion and filter state are per-segment view state, not persisted, matching the current `_expandedExerciseUuid` / filter conventions.

## Wide-screen behaviour

Only the master pane changes (see [Non-goals](#non-goals)). The collapsing overview and pinned switcher live inside the master column. The detail pane, rail and docked mini player are unchanged, and the collapse applies on both narrow and wide layouts.

The one knock-on change is the empty-pane mapping in `_emptyPaneBuilderForCurrentTab`, which moves from per-tab to per-segment for Program (exercise / station / role / team), with a single Roster empty pane.

## Roster tab

The local people layer (`nb` "Bemanning"). A flat registry of the real people involved in a plan, each assigned one or more named roles.

### Person with role, Actor as a specialization

Today `Actor` is the only "real person" entity (`realName`, `phone`, `notes`, PII, local-only). The direction is to generalize it: a person assigned a role, where **markør is one role** and **director, instructor and participant** are others. `Actor` becomes the markør specialization of a general person-with-role model.

This is a deferred data-model expansion, reserved like the overview's brief fields. The navigation and the concept are settled now, the model work follows later.

### Three role axes that must not collapse

Naming the staffing roles "øvelsesleder / veileder / deltaker" collides with two existing concepts. They must relate cleanly without merging:

| Axis                | Concept                              | Defined in           | Norwegian labels                                |
|---------------------|--------------------------------------|----------------------|-------------------------------------------------|
| **Roster** (new)    | Which real person is what            | this design          | Markør, Øvelsesleder, Veileder, Deltaker        |
| **Brief audience**  | Which document version a reader sees | [DESIGN-004](./brief-template.md) | Deltaker, Veileder, Øvelsesleder    |
| **Session role**    | What a device does live              | [ADR-0019](../adrs/0019-roleplayer-participant-role.md) | coordinator / observer / roleplayer |

A person's Roster role maps to brief audience (an øvelsesleder reads the øvelsesleder brief) but the two stay distinct axes. [ADR-0019](../adrs/0019-roleplayer-participant-role.md) deliberately kept audience orthogonal to session role, and this design adds a third axis without merging any of them.

### Privacy boundary

Roster holds real people, so the whole tab is the stripped-on-publish PII layer. When the person-with-role model arrives, its storage follows the `actors/` precedent ([ADR-0022](../adrs/0022-markdown-content-as-files.md), [ADR-0018](../adrs/0018-roleplayer-data-model.md)).

## Terminology

* **Roster** (`nb` "Bemanning") is the new tab and the people layer. "Roster" is not the literal translation of "bemanning" (that is "staffing" or "manning"), but it reads better as a label and is continuous with the "cast roster" already used in [DESIGN-003](./roleplays-tab.md) for the list of `Actor` records, which this tab promotes to a destination. The earlier "ikke Bemanning" note in [[feedback_roleplay_actor_terminology]] rejected "Bemanning" only as a name for the markør role list, which still holds.
* **Spill** (`en` "Script") is the third Program-tab segment — the publishable scenario layer. **Markører** stays the name of the role list *inside* the Spill segment. The segment is no longer called Markører to leave room for `SilentWitness` as a future second scenario element. This doc uses "Spill segment" for the segment itself and "the Markører role list" or "Markørrolle" for the content entity.
* Code and English prose keep `RolePlay` / `Actor` / `Station` / `Team`. No `Person` or `RolePlayer` in the model layer.

## Relationship to other designs

* **Supersedes [DESIGN-002](./stations-tab.md) (Stations tab).** The flat station list, the exercise filter (badge + banner + picker), the mutex expansion and the `StationExpansionTile` / `StationMiniMap` shared widgets all survive, relocated into the Poster segment. The standalone `/stations` root tab and its label are retired.
* **Supersedes [DESIGN-003](./roleplays-tab.md) (RolePlays tab).** The role list moves into the Spill segment (as the Markør/Markørrolle roster), the cast side moves to Roster.
* **Extends [DESIGN-004](./brief-template.md).** Adds the master-pane overview as a new read-only surface previewing `program.briefIntroMd`. No change to DESIGN-004's fields, renderer or storage, and the brief is still reached from its AppBar action.
* **Works within [DESIGN-005](./wide-screen-layout.md) / [ADR-0030](../adrs/0030-wide-screen-master-detail-layout.md).** Master pane only.
* **Precedes [ADR-0028](../adrs/0028-feature-first-views-layout.md).** The `lib/views/` feature-first refactor is deferred until DESIGN-006 is complete, because this design moves the feature boundaries the refactor would group by (Stations and RolePlays become segments, Roster is new). DESIGN-006 is built on the current flat structure, and ADR-0028 then runs once against the settled shape, with its grouping plan reviewed against this outcome first.

DESIGN-002 and DESIGN-003 are Superseded by this doc as of acceptance (2026-05-31).

## Deferred decisions

1. **Person-with-role model.** The generalization of `Actor` into a staffed person is a future data-model design. Reserved, not built.
2. **Team members vs. count.** Whether the Team segment ever surfaces the people filling a team (which would touch Roster) or stays a structural list. Today `numberOfMembers` is a count, so the structural view is enough.
3. **Editing the brief fields from the overview.** The overview renders `briefIntroMd` read-only (the field exists and loads). In-app editing of it depends on the DESIGN-004 stage 4 markdown editor on `ProgramFormScreen` and is out of scope for the overview.
4. **Segmented switcher control at narrow master width.** See the open UX question above.

## Open questions

1. **Map's place in three tabs.** Map stays a root tab. Confirm it should not also become a Program segment. The current thinking is no, because Map is a lens with its own internal split (DESIGN-005) and pulls markers from every set at once, not one structural set.
2. **Tab order.** `[Program, Map, Roster]` versus `[Program, Roster, Map]`. Map sat at index 1 historically, so keeping it there is the low-surprise choice.
3. **What "Ny rolle" creates from the Spill segment** given roles are station-anchored. Likely the same flow as today, just relocated.

## Implementation notes

Sequenced so each stage is shippable and reviewable on its own.

**Delivery.** Work proceeds on `main` with local commits, no feature branch. Stage 1 on its own is an awkward user-facing state (the segmented Program tab coexists with the still-present Stations, RolePlays and Teams tabs, so the surfaces are duplicated), so **stages 1 and 2 are one release unit**: nothing is pushed to GitHub until both are complete and the navigation is clean. Stages 3 and 4 are additive and main-safe on their own, so they push as normal once 1+2 have landed. The ADR-0028 views refactor is deferred until after DESIGN-006 (see the relationship note above), so it does not contend for `main_screen.dart` during this work.

**Stage 1 — Segmented Program tab.** Wrap `ProgramView` in a `CustomScrollView` with the pinned `SegmentedButton` and the four segment bodies (reusing `ProgramView`'s list, `StationListView`, the role list and `TeamsView` bodies). Make the FAB and AppBar actions follow the active segment. No navigation change yet, the other tabs still exist.

**Stage 2 — Collapse the navigation.** Remove the Stations, RolePlays and Teams root destinations, reducing the navigation to **Program + Map** (`routes` becomes `[routeProgram, routeMap]`). The Roster tab is **not** introduced here — it arrives in stage 4 once it has a body, so stage 2 leaves a clean two-tab navigation rather than an empty Roster tab. Adopt the program-scoped routing scheme from [ADR-0032](../adrs/0032-program-scoped-routing.md): every program-scoped path carries `/program/:uuid/`, rendering it activates that program, and the old un-prefixed paths (`/stations/...`, `/teams/...`, `/roleplays/...`) become back-compat redirects that forward to the canonical path. Resolving an old un-prefixed entity path is active-program-relative, matching today's semantics (those links never carried a program uuid), not a cross-program scan. Update `_buildDestinations`, `_pages`, `_initTab`, `_onDestinationSelected` and the empty-pane builder.

**Stage 3 — Overview.** Add the read-only overview above the switcher (`description` and the `briefIntroMd` preview, with a "Les mer" / "Vis mindre" toggle, no counts summary line). Collapse it on scroll while keeping the switcher visible. The brief is a constant AppBar action on every segment. Implemented as a manual collapse (overview hides on scroll-down, reappears on scroll-up) with the segment body kept as an `IndexedStack`, rather than a pinned `SliverPersistentHeader` — the sliver forced a fixed switcher height and an opaque background that did not match the master pane, and its active-only body dropped per-segment state.

**Stage 4 — Roster tab (view shell).** Shipped 2026-06-02. Adds the third bottom-nav tab (`Icons.badge`, `rosterTab` / "Bemanning"). Route `/program/:uuid/roster`, fallback `/roster` redirects to the canonical path. `RosterController extends ScreenController` owns the FAB ("New actor" / "Ny markør") and exposes `reloadSignal` (`ValueNotifier<int>`) so the view refreshes after actor CRUD without a `ProgramService` event. `RosterView` is a standalone widget (not a refactor of `CastRosterSheet`) with a `Dismissible` list, swipe-to-delete with cast-guard (`castDeleteBlocked` SnackBar), and tap-to-edit via `openFormSurface<ActorFormResult>` → `ActorFormScreen`. The cast-roster sheet in the Spill segment remains unchanged. Empty state shows `noActorsInRoster`. Wide layout: `RosterDetailEmpty` (`Icons.badge`, `detailEmptyRoster`) on the detail pane; tapping a row opens `ActorFormScreen` as a modal form.

**Stage 5 — Person-with-role model (deferred).** Generalize `Actor` into a staffed person with named roles. Separate design.

## Changelog

* 2026-05-31 — Drafted from design dialogue and **Accepted** the same day. Captures the three-tab navigation, the four-segment Program switcher, the read-only overview, per-segment FAB and actions, and the Roster people layer (`nb` "Bemanning"). DESIGN-002 and DESIGN-003 superseded on acceptance. Open items carried into implementation: narrow-master switcher control, tab order, Map's place.
* 2026-06-02 — Stage 3 review revisions. `briefIntroMd` already exists in code, so the overview previews it rather than shipping description-only. The overview collapse is a manual hide-on-scroll with the switcher as an always-visible row and the body kept as an `IndexedStack`, replacing a pinned `SliverPersistentHeader` that forced an enlarged switcher, a mismatched opaque background and an active-only body that lost per-segment state. The brief returns to its AppBar action on the Øvelser lens after the overview "Åpne brief" affordance read poorly.
* 2026-06-02 — Action/FAB rationalization. The brief becomes a constant AppBar action on every segment (it renders the whole plan, so scoping it to one lens was illogical). The Poster filter moves from a body FAB to an AppBar action, matching Markører, so both filter the same way and the FAB slot is reserved for "create"; this also fixes the filter FAB covering the filter banner. The Markører "Ny rolle" create FAB renders inside the view body above the filter banner (not as a Scaffold FAB), so the banner pushes it up instead of being covered.
* 2026-06-02 — Overview content trimmed. Dropped the "team count · segment count" summary line (it rendered as bare nouns and added little) and added a "Les mer" / "Vis mindre" toggle that expands and collapses the description/brief-intro prose, shown only when the text is long enough to truncate. New `showMore` / `showLess` localization keys.
* 2026-06-02 — Third segment renamed from **Markører** to **Spill** (`en` "Script", `ProgramSegment.script`). The segment is the publishable scenario layer of the plan; Markører (`RolePlay`) is its current content. `SilentWitness` ("Tause vitner") is reserved as a future sibling scenario element. `rolePlaysTab` l10n key and all `RolePlay*` code remain unchanged — only the segment label and enum identifier were renamed.
* 2026-06-02 — Stage 4 shipped. Roster tab added as the third bottom-nav destination. `RosterView` + `RosterController`, route `programRosterPath`, `RosterDetailEmpty` empty pane, `rosterTab` / `detailEmptyRoster` l10n keys. Cast-roster sheet in the Spill segment unchanged. Open question 2 (tab order) resolved as `[Program, Map, Roster]` — Map stays at index 1.
