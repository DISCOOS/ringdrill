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
* **No new data-model fields in this design.** The overview reserves space for the program-level brief fields from [DESIGN-004](./brief-template.md) (`program.briefIntroMd`, `program.commsMd`) but does not introduce them. The Roster "person with role" generalization is described as a direction, not built here.
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
│  │  4 lag · 5 poster                        │  │
│  │  <briefIntro preview, when present>      │  │  ← read-only projection
│  │  [Åpne brief]                            │  │
│  └──────────────────────────────────────────┘  │
│  ┌─ pinned ─────────────────────────────────┐  │
│  │  [ Øvelser | Poster | Markører | Team ]  │  │  ← segmented switcher
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

A sliver header at the top of the master pane summarizing the active plan. It scrolls away as the user moves down a long list, so the list gets the full height when it needs it.

Content, all read-only:

* Plan summary line: team count (`numberOfTeams`) and a count for the active segment (e.g. station count).
* A compact, truncated preview of the program-level brief intro (`program.briefIntroMd`) when present. Rendered in plain Material style, **not** the `BriefTheme` docs-site look from [ADR-0023](../adrs/0023-brief-theme-tokens.md). That palette stays confined to the brief sheet so it does not clash with the working surfaces around it.
* An "Åpne brief" affordance that opens the brief sheet (`/brief/program/:programUuid`).

Because the overview is read-only, editing routes out the way it does today. Tapping the summary opens the relevant form (the exercise edit form, or `ProgramFormScreen` for the brief fields once they exist).

The brief fields do not exist in code yet (`program.dart` has only `description`), so the overview ships with the summary line and `description` and grows to include the brief preview later (see [Deferred decisions](#deferred-decisions)). The `*Md` fields are omitted when empty, so a fresh plan's overview may be just the summary line. The header must collapse gracefully when nearly empty, and the switcher below is always present.

### Segmented switcher

The switcher is **pinned** below the overview as a `SliverPersistentHeader`, so the user can always change lens even after the overview has scrolled off. It is an M3 `SegmentedButton`, chosen over a `TabBar` because a TabBar signals swipeable peer tabs and would compete visually with the bottom navigation. The segments read as lenses on one dataset, the same "two lenses on the same entity" framing DESIGN-002 used for Map vs Stations, now extended to four.

The four segments are three lenses on the exercise tree plus the team set:

| Segment (`nb`) | Lens                                              | Source view today            |
|----------------|---------------------------------------------------|------------------------------|
| **Øvelser**    | Grouped: the exercise→station tree, expandable    | `ProgramView` (current)      |
| **Poster**     | Flat list of every station                        | `StationListView`            |
| **Markører**   | Flat list of every role (roles only, not cast)    | `RolePlaysView` (role part)  |
| **Team**       | Flat team list                                    | `TeamsView`                  |

Øvelser, Poster and Markører are three flatten-levels of the same `exercise → station → roleplay` tree, with increasing granularity. Team is a parallel set rather than a deeper level, an acceptable asymmetry.

**Markører shows roles only.** `RoleExpansionTile` ([DESIGN-003](./roleplays-tab.md)) already splits the Role section from the Cast section inside each tile. This design folds the Role section into the Markører segment and leaves cast binding to the Roster tab. The seam the tile already drew internally becomes the seam between the two tabs.

#### Open UX question: four labeled segments in a narrow master pane

On a phone the Program tab is full width and four short labels fit. In the wide layout the master pane is only 320 px (medium) or 420 px (expanded) per [ADR-0030](../adrs/0030-wide-screen-master-detail-layout.md), and four text segments are tight at 320. Candidate resolutions, to settle at implementation:

1. Icon + label on compact, **icon-only with tooltips** in the narrow master pane.
2. Keep labels and let the `SegmentedButton` shrink, accepting truncation at 320.
3. Drop to a different control (a leading dropdown or a scrollable segment row) when width is below a threshold.

Leaning toward option 1, since the four icons already exist (`Icons.update`, `Icons.place`, `Icons.theater_comedy`, `Icons.group`).

### Contextual FAB and actions

This is where the crowding is actually solved. With one tab, the FAB and AppBar actions follow the active segment instead of being contested across tabs:

| Segment   | FAB                    | Notable AppBar action            |
|-----------|------------------------|----------------------------------|
| Øvelser   | "Ny øvelse"            | Brief (or fold into overview)    |
| Poster    | Exercise filter        | —                                |
| Markører  | "Ny rolle" / filter    | —                                |
| Team      | "Nytt lag"             | —                                |

The Poster filter keeps the existing badge + banner + picker pattern from DESIGN-002. The existing brief action (`Icons.menu_book`) on the Exercises AppBar can move into the overview's "Åpne brief" affordance, reclaiming an AppBar slot.

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
* **Markører** stays the name of the role list and the Program-tab segment. To keep it distinct from the **Roster** tab, this doc avoids the bare word "roster" for the markør list and calls it the role list or the Markører segment.
* Code and English prose keep `RolePlay` / `Actor` / `Station` / `Team`. No `Person` or `RolePlayer` in the model layer.

## Relationship to other designs

* **Supersedes [DESIGN-002](./stations-tab.md) (Stations tab).** The flat station list, the exercise filter (badge + banner + picker), the mutex expansion and the `StationExpansionTile` / `StationMiniMap` shared widgets all survive, relocated into the Poster segment. The standalone `/stations` root tab and its label are retired.
* **Supersedes [DESIGN-003](./roleplays-tab.md) (RolePlays tab).** The role list moves into the Markører segment, the cast side moves to Roster.
* **Extends [DESIGN-004](./brief-template.md).** Adds the master-pane overview as a new read-only surface for `program.briefIntroMd` / `commsMd`, and "Åpne brief" as an entry point. No change to DESIGN-004's fields, renderer or storage.
* **Works within [DESIGN-005](./wide-screen-layout.md) / [ADR-0030](../adrs/0030-wide-screen-master-detail-layout.md).** Master pane only.
* **Lands with [ADR-0028](../adrs/0028-feature-first-views-layout.md).** The `lib/views/` feature-first refactor is the natural moment to relocate the station / roleplay / team views into Program-tab segments.

DESIGN-002 and DESIGN-003 are Superseded by this doc as of acceptance (2026-05-31).

## Deferred decisions

1. **Person-with-role model.** The generalization of `Actor` into a staffed person is a future data-model design. Reserved, not built.
2. **Team members vs. count.** Whether the Team segment ever surfaces the people filling a team (which would touch Roster) or stays a structural list. Today `numberOfMembers` is a count, so the structural view is enough.
3. **Brief fields in the overview.** Depend on DESIGN-004 stages 1b/4. Until then the overview shows the summary line and `description`.
4. **Segmented switcher control at narrow master width.** See the open UX question above.

## Open questions

1. **Map's place in three tabs.** Map stays a root tab. Confirm it should not also become a Program segment. The current thinking is no, because Map is a lens with its own internal split (DESIGN-005) and pulls markers from every set at once, not one structural set.
2. **Tab order.** `[Program, Map, Roster]` versus `[Program, Roster, Map]`. Map sat at index 1 historically, so keeping it there is the low-surprise choice.
3. **What "Ny rolle" creates from the Markører segment** given roles are station-anchored. Likely the same flow as today, just relocated.

## Implementation notes

Sequenced so each stage is shippable and reviewable on its own. Aligns with the [ADR-0028](../adrs/0028-feature-first-views-layout.md) refactor.

**Stage 1 — Segmented Program tab.** Wrap `ProgramView` in a `CustomScrollView` with the pinned `SegmentedButton` and the four segment bodies (reusing `ProgramView`'s list, `StationListView`, the role list and `TeamsView` bodies). Make the FAB and AppBar actions follow the active segment. No navigation change yet, the other tabs still exist.

**Stage 2 — Collapse the navigation.** Remove the Stations, RolePlays and Teams root destinations. Reduce `routes` to `[routeProgram, routeMap, routeRoster]`. Adopt the program-scoped routing scheme from [ADR-0032](../adrs/0032-program-scoped-routing.md): every program-scoped path carries `/program/:uuid/`, rendering it activates that program, and the old un-prefixed paths (`/stations/...`, `/teams/...`, `/roleplays/...`) become back-compat redirects that resolve the owning program and forward to the canonical path. Update `_buildDestinations`, `_pages`, `_initTab` and the empty-pane builder.

**Stage 3 — Overview sliver.** Add the read-only overview above the switcher. Team count and `description` first. Wire "Åpne brief" to the brief sheet and move the brief AppBar action into it.

**Stage 4 — Roster tab (view shell).** Add `/roster` and a flat list of `Actor` entries as the people registry. Read and edit via the existing actor flow. This already fixes the hidden-actor problem before the person-with-role model exists.

**Stage 5 — Person-with-role model (deferred).** Generalize `Actor` into a staffed person with named roles. Separate design.

## Changelog

* 2026-05-31 — Drafted from design dialogue and **Accepted** the same day. Captures the three-tab navigation, the four-segment Program switcher, the read-only overview, per-segment FAB and actions, and the Roster people layer (`nb` "Bemanning"). DESIGN-002 and DESIGN-003 superseded on acceptance. Open items carried into implementation: narrow-master switcher control, tab order, Map's place.
