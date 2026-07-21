---
id: DESIGN-012
title: A unified cast pill on person/actor rows
status: Accepted
started: 2026-07-19
accepted: 2026-07-19
owners: ["kengu"]
related_code:
  - lib/views/widgets/cast_pill.dart
  - lib/views/widgets/face_badge_icon.dart
  - lib/views/station_screen.dart
  - lib/views/widgets/station_role_summary.dart
  - lib/views/roleplay_list_view.dart
  - lib/views/roleplay_screen.dart
related_designs:
  - 010-inline-preview-and-resolve-scope.md
  - 011-person-with-role-and-roster-model.md
---

# A unified cast pill on person/actor rows

> This document is in English. Status: **Accepted (implemented)** (2026-07-19).
> Refines DESIGN-010 (Post/Spill viewers) and DESIGN-011 (person-with-role
> model). Mockup: `docs/design/mockups/unified-cast-pill.html`.

Terminology, and the key distinction this whole change turns on: a **Person**
is the character in the scenario; an **Actor** (Norwegian "Markør", never
"marker") is the real person who *enacts* that character. A `RolePlay` is the
role/"spill"; "cast" means linking an `Actor` to a `RolePlay`. So a person is
**not** an actor — which is why the cast affordance uses the actor (face)
glyph, and `person`/`person_add` is reserved for the character.

## Problem

Two surfaces list the people on a post, and they diverged.

- **The Post list** (`station_list_view.dart` → `StationRoleSummary`): one row
  per `RolePlay`, showing effective identity (`role.*`) and **direct casting**
  via a trailing `person`/`person_add` icon → `openCastPickerAndApply`.

- **The Post detail viewer** (`station_screen.dart` → the Personer card): one
  row per `Person`, showing only **planned** person fields, with **no direct
  casting** — the trailing pill only opened the Spill viewer.

So a leader in the post's own context saw stale planned data and could not cast
without detouring through the Spill viewer (the actor's normative surface).

## Proposal

One shared trailing **cast pill** (`CastPill`), plus the icon convention
applied consistently.

### Icon convention

- Row leading glyph is what the row *is*: a **person** row → `Icons.person`
  (the character).
- The **actor** (who enacts it) → `Icons.face` (one concrete actor), shown in
  the cast pill / cast affordance — never `person`/`person_add`.
- The **list** of plays/actors (section header) → `Icons.theater_comedy`
  (two masks).
- Bare-icon "assign/remove an actor" slots (no room for a pill) use the
  face-badge glyphs **`AddFaceIcon`** / **`RemoveFaceIcon`**
  (`lib/views/widgets/face_badge_icon.dart`): a large face with a bold plus
  (add) or minus (remove) in the upper-left corner, no background — the actor
  counterpart to `person_add`/`person_remove`, which Material lacks.

### The three pill states

| State | Text | Icon | Tap |
|-------|------|------|-----|
| No `RolePlay` yet | "Legg til spill" / "Add role" | `+` (`Icons.add`) | Create the RolePlay |
| RolePlay, uncast | "Ingen markør" / "No actor" | face (`Icons.face`) | Open the cast picker |
| RolePlay, cast | **just the actor name** (`actor.realName`) | face (`Icons.face`) | Open the cast picker |

The cast state shows only the actor's name — the face icon already means
"enacted by", so no "Spilles av …" prefix. The **add** state keeps `+` (a face
there would be too close to the cast states). Casting always goes through the
shared `openCastPickerAndApply`. The row body's own tap opens the **spill
editor** when the person has a spill, else the person editor (Post detail), or
the role sheet (Post list).

### Effective identity everywhere

Rows show **effective** identity — the RolePlay's non-empty
`name`/`age`/`gender`/`signalement` override the linked person's (the same
`_effective` rule the Spill card applies; the list already had it via
`role.*`). A small accent dot **on the leading icon** (a corner badge, no
inline width) marks an overridden row. Cast status lives in the pill, so the
subtitle carries the person's own info (signalement).

Other read surfaces still showing raw `person.*` (the Lag viewer, map pin
labels) can adopt the effective rule in a follow-up.

## Affected pieces (implemented)

- `cast_pill.dart` — the shared `CastPill` (add/uncast/cast).
- `face_badge_icon.dart` — the composed `AddFaceIcon`/`RemoveFaceIcon` glyphs
  for bare-icon slots.
- `station_screen.dart` (Post detail Personer card) — effective identity,
  accent-dot badge, the three-state pill (cast → actor name); person leading
  icon; row tap opens the spill editor when a spill exists, else the person
  editor.
- `station_role_summary.dart` (Post list) — section label **"Markører" →
  "Spill"** (reuses `playSection`), leading icon **face → `Icons.person`** (the
  row is the character), the cast pill replacing the `person`/`person_add`
  trailing icon; header keeps the two-masks.
- `roleplays_view.dart` (Spill tab) — collapsed tile cast chip →
  `Icons.face` / `AddFaceIcon`; expanded cast section → the cast pill.
- `roleplay_screen.dart` (`_PlayCard`, Spill viewer) — cast quick action →
  `Icons.face` / `AddFaceIcon`; "Spilles av …" footer → face icon, made
  tappable (opens the cast picker). The footer sentence and the collapsed
  header keep `castedByLine` ("Spilles av …" / "SPILLES AV …") — they are
  sentence/kicker patterns, not chips.
- i18n (balanced nb/en): `noCastLine` shortened to **"Ingen markør" / "No
  actor"**. `castedByLine` is still used by `_PlayCard`; `playSection`
  ("Spill"/"Play") is reused for the Post-list header.

## Resolved decisions

- Row-body tap is context-specific: Post detail = the spill editor when a
  spill exists (else the person editor), Post list = the role sheet (viewer).
- Effective identity on the Lag viewer / map pin labels is left as a separate
  follow-up.

## Follow-up (implemented)

Reaching and editing the spill from the person list surfaced two gaps, both
addressed:

- **Edit the person from the spill editor.** The roleplay form's person picker
  (`showRingdrillPicker`) gained a per-row pencil that opens `PersonFormScreen`
  for that person and folds the result back into the editor's working copies —
  so a spill can edit its own people, alongside select and "+ Ny person".
- **Selector polish (person picker and cast picker read alike).** A leading
  person/actor icon per row; the currently-selected item shown by a leading
  `Icons.check` + row tint (dropping the cluttered trailing checkmark the cast
  picker used); a divider under the title so it reads as a header. The bespoke
  `CastPickerSheet` was restructured to match the shared `showRingdrillPicker`
  layout — actions ("Ny/Fjern markør") moved to **footer rows at the bottom**
  (not above the list), search shown only **past the threshold** (not always),
  and wrap-to-content height. Footer actions use **semantic icons**, not a bare
  `+`/`−`: "Ny person" → `person_add`; "Ny/Fjern markør" →
  `AddFaceIcon`/`RemoveFaceIcon`. (The person link is mandatory, so the person
  picker has no "remove person" counterpart to the cast picker's "Fjern
  markør".)
- **Delete a spill.** Removing a roleplay had a service method
  (`ProgramService.deleteRolePlay`) but no UI. `RolePlayFormScreen` gained a
  canonical form-delete, mirroring `ActorFormScreen`: `RolePlayFormResult` is
  now sealed (`RolePlayFormSave` | `RolePlayFormDelete`); a trash action in the
  `SectionNavigatedForm` AppBar (via a new optional `onDelete` slot) shows only
  for an existing roleplay (`isExisting`, set by the caller — not derived from
  the service, so the form stays testable), behind a `confirmDestructive` that
  names the cast actor being unassigned (the actor itself stays in the roster).
  All six callers apply the result; the Spill viewer also closes on delete. No
  referential guard is needed — nothing references a roleplay yet
  (`SessionParticipant`/ADR-0019 is not implemented).
- **Delete an exercise (parity with the spill form).** The same pattern was
  extended to the exercise editor: `ExerciseFormResult` is now sealed
  (`ExerciseFormSave` | `ExerciseFormDelete`), the form derives its
  existing-vs-new state from `widget.exercise != null` (no caller flag needed),
  and the trash action sits **next to "Lagre"** in the `SectionNavigatedForm`
  AppBar (order `[preview, delete, Lagre]`), never between preview and save.
  The three exercise-form callers (`program_view` add + add/edit,
  `coordinator_screen` edit) switch on the sealed result; the coordinator
  viewer closes (`pop(false)`) when its exercise is deleted.
- **Viewer chrome is responsive.** The exercise **viewer**
  (`CoordinatorScreen`) shows edit + delete as two side-by-side icons in
  medium/expanded (`WindowSizeClass.of(context).hasMasterDetail`) and keeps the
  `⋮` overflow menu in compact, where space is tight. The Spill viewer
  (`roleplay_screen.dart`) has a short title, so it shows both icons directly.

## Test coverage (create / delete / events)

- Spill form: `roleplay_form_screen_test.dart` — a new draft shows no delete
  action; an existing role pops `RolePlayFormDelete` after confirmation.
- Exercise form: `exercise_form_screen_delete_test.dart` — a new draft shows no
  delete action; an existing exercise pops `ExerciseFormDelete` after
  confirmation. `exercise_form_screen_create_test.dart` — a blank form → save
  lands the new exercise in the active plan's list.
- Service: `program_service_test.dart` (group "delete") — `deleteExercise`
  removes the exercise (and is a no-op on an unknown uuid); `deleteRolePlay`
  removes the role but leaves its cast actor in the roster (uncast, not
  deleted).

### The event-stream contract

Every StreamBuilder/`listen`-driven surface (Spill list, Roster, Post rows,
Map, Lag) refreshes on **any** `ProgramService.events` emission — none of them
filter by type. So every mutation must emit, or dependent widgets go stale.
Three did not and were fixed alongside this work: `deleteRolePlay`
(→ `rolePlayDeleted`), `saveActor` (→ `actorSaved`), `deleteActor`
(→ `actorDeleted`). Person / location / optional-section / variable-override
edits ride on `saveExercise` (→ `exerciseAdded`); global plan variables ride on
`replaceProgram` (→ `programRefreshed`); reorders emit `programRefreshed`. The
`program_service_test.dart` group "mutations emit events" guards the three that
regressed. (There is no `ProgramService.deleteTeam` yet — only a repo-level
one with no UI caller — so add its event when that surface is built.)
