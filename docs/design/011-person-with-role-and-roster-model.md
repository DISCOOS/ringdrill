---
id: DESIGN-011
title: Person-with-role and the Roster model
status: Accepted
started: 2026-07-10
accepted: 2026-07-10
owners: ["kengu"]
related_code:
  - lib/models/actor.dart
  - lib/models/role_play.dart
  - lib/models/session_participant.dart
  - lib/views/roster_view.dart
  - lib/views/actor_form_screen.dart
related_designs:
  - 006-program-tab-consolidation.md
  - 009-scenario-locations-and-persons.md
  - brief-template.md
related_adrs:
  - 0018-roleplayer-data-model.md
  - 0019-roleplayer-participant-role.md
  - 0022-markdown-content-as-files.md
---

# Person-with-role and the Roster model

> This document is in English. Model, field and helper names are English throughout. Norwegian strings are the user-facing labels the app ships in `nb`. **Status: Accepted** (2026-07-10) — naming, scope, wire and UI decisions are settled; ready for an implementation prompt. The only deferred item is a role→audience/session mapping helper (advisory only, built when a consumer needs it).

## TL;DR

DESIGN-006 stage 5, reserved as a "separate design", is this: generalize `Actor` (today only the human who plays a marker) into **`Staff`** (`nb` "Stab") — a person on the exercise who is *not a participant*, assigned one or more roles, where *markør* is one and *øvelsesleder / veileder* are others. Participants ("deltakere") are not rostered individually; they stay a Team count. The tab ("Bemanning", shipped in DESIGN-006 stage 4) already manages these records; this gives them roles beyond casting. The work is additive on the existing `actors/` folder and keeps the PII-stripped-on-publish boundary (ADR-0018). Names and scope are now settled (below); the remaining calls are small.

## Where this sits after DESIGN-009

DESIGN-009 firmed up a clean three-layer separation that this design must not disturb:

* **`Person`** — a *fictional scenario character* (the missing person, a witness), station-owned, **no PII**, portrayed by a `RolePlay` (`personRef`, effective identity). Published freely.
* **`RolePlay`** — the *roleplay script* (publishable role/"Spill", en "Script"): what the marker does, resolved in the brief and on the map.
* **`Actor`** — the *real human* who plays a marker, **PII**, local-only, stripped on publish. Linked from a `RolePlay` by `actorUuid` (casting).

The mental model reads cleanly: **a real person (`Actor`) plays a roleplay script (`RolePlay`) that portrays a character (`Person`)**. Stage 5 generalizes only the **`Actor`** layer — the real people — from "the human cast to a marker" to "any real person with a role in the exercise". It leaves `Person` and `RolePlay` untouched. Critically, `Person` (fictional) and the generalized real-person entity are *different things*; the naming must keep them distinct.

## The name and the scope (decision 1 — settled: `Staff` / "Stab")

DESIGN-006 ruled out `Person` and `RolePlayer`, and DESIGN-009 has since taken `Person` for the fictional character, so the generalized real-person entity needs a different name. The chosen name is **`Staff`** (Dart/English), **"Stab"** (`nb`) — the domain term for *everyone on an exercise who is not a participant*: markers, directors, instructors and other supporting people. One entity with a `roles` field, **not** a class hierarchy (`Actor`-as-specialization is over-structured).

That name carries a **scope decision**: since "stab" means *the non-participants*, the Staff roster does **not** individually list course participants ("deltakere"). Participants remain a **Team count** (`Team.numberOfMembers`), exactly as DESIGN-006 already treats them (deferred decision #2). So "deltaker" is not a Staff role. It stays a *brief audience* (a participant still reads the deltaker brief — that axis is untouched), just not a rostered person.

**Clean wire migration.** Nothing is published yet, so this is a straight rename with no alias — the same call made for `homeSlug`→`locSlug` this cycle: the Dart type `Actor` → **`Staff`**, the archive folder `actors/` → **`staff/`**, and `RolePlay.actorUuid` → **`staffUuid`**. The publish strip still targets one folder (now `staff/`) and the PII boundary is unchanged — only its name. This **amends ADR-0018** (the entity/folder/field names); the schema marker need not bump, since there are no in-the-wild files to stay compatible with. The tab relabels from "Bemanning" to **"Stab"** to match.

## The roles model (decision 2)

A Staff person carries a set of roles. With participants excluded (decision 1), the set is **markør, øvelsesleder, veileder**, plus an escape `other` — **not** deltaker (participants are a Team count, not staff). Two questions:

* **Is *markør* stored, or derived?** A person "is a markør" precisely when at least one `RolePlay.actorUuid` points at them — the casting link already exists. So markør can be **derived from casting** (single source of truth, no way for a `roles` flag to disagree with the actual cast), while the `roles` set stores only the *organizational* roles (director/instructor/other) that have no other home. **Settled: derived** (2026-07-10) — a stored markør flag could drift from the actual cast.
* **One role or many?** A person can be both (an instructor who also plays a marker on a quiet post). So `roles` is a **set**, and the derived markør role composes with it.

Sketch (additive, `@Default` empty so legacy records are valid):

```
enum StaffRole { director, instructor, other }   // markør is derived; no participant
Staff( … existing Actor fields …, @Default({}) Set<StaffRole> roles )   // JSON still under actors/
```

`markør` is intentionally absent from the stored enum — it is computed from casting — and so is `participant` (participants are a Team count, not staff). If decision 2 goes the other way, `markør` joins the enum and casting stays its detail.

## Three axes that must not collapse

DESIGN-006 already fixed this and it still holds — the draft only restates the mapping the model now needs to encode:

| Axis | Question | Defined in | Values |
|------|----------|-----------|--------|
| **Staff role** (this design) | which staff person is what | here | markør (derived), øvelsesleder, veileder |
| **Brief audience** | which document a reader sees | [DESIGN-004](./brief-template.md) | deltaker / veileder / øvelsesleder |
| **Session role** | what a device does live | [ADR-0019](../adrs/0019-roleplayer-participant-role.md) | coordinator / observer / roleplayer |

A roster role *maps to* a brief audience (an øvelsesleder reads the øvelsesleder brief; a markør reads their roleplay script and otherwise the deltaker brief) and *suggests* a default session role (a markør → roleplayer, an øvelsesleder → coordinator), but the three stay orthogonal — the mapping is a convenience default, never an identity. The model stores only the roster role; audience and session role remain their own axes as ADR-0019 insists.

## Privacy and format

The Staff roster is the PII layer: real names, phones, the roles they hold. It lives in `staff/` (renamed from `actors/`), stripped server-side on publish (ADR-0018), so role assignments never reach the catalog. Consistent with the decision that PII is shown freely in-app and gated only at publish — the roster shows and edits everything locally. The `roles` field itself is additive (defaults empty); the only non-additive part is the folder/field rename, done cleanly because nothing is published (so `KNOWN_SCHEMA_MAX` need not move).

## UI (Roster tab, already shipped as a shell)

The tab and its form exist (DESIGN-006 stage 4; `ActorFormScreen` → `StaffFormScreen`, tab "Bemanning" → "Stab"). Stage 5 adds:

* **List** — card-per-member with role chips on the name line (right); the markør role is a *derived* chip (from casting), the organizational roles are filled chips.
* **Editor** — a multi-select of the organizational roles (director/instructor/other), plus a read-only **"Spiller"** list: one row per marker the member plays, `"{name} på post {badge} {hh:mm–hh:mm}"`, with a lock (it is set by casting in the Spill segment, not here). The `{badge}` is the station's code rendered in the **plan's** numbering format (dotted `1.1` or alpha `2a`, `stationCode` per `Program.stationNumberFormat`), not a fixed string.
* **FAB** — "Nytt medlem" / "New member" (a *stabsmedlem*), following the app's "Ny X" FAB convention (`Ny markør`, `Ny øvelse`): extended on medium/expanded, a circular `+` on compact so it does not cover list rows.
* **No new PII fields** beyond roles.

**Empty-state teaching widget (must update).** The empty Staff list (and the wide detail-pane empty route, `RosterDetailEmpty`/`detailEmptyRoster`) carries a teaching empty state. With the rename it must stop being marker-only and match the app's short empty-state voice (title + one line), e.g. **"Ingen i staben ennå" / "Legg til øvelsesledere, veiledere og markører her."** — not a long definition. The add affordance is the FAB, not a centered CTA. Easy to miss in a mechanical rename, so it is called out here. Also update the ARB keys the rename touches: `newActor` → the "Nytt medlem" label, `emptyRosterTitle`/`emptyRosterBody`, `noActorsInRoster`, `detailEmptyRoster`. Mockup: `docs/design/mockups/staff-roster.html` (list, editor, empty state).

## Settled (2026-07-10)

* **Entity:** `Staff` / "Stab". Participants excluded — a Team count, not rostered.
* **markør:** derived from casting, not stored.
* **Tab label:** "Bemanning" → "Stab".
* **Wire:** clean rename `actors/`→`staff/`, `actorUuid`→`staffUuid`, `Actor`→`Staff` (no alias, nothing published; amends ADR-0018).
* **FAB / create action:** "Nytt medlem" / "New member" (a *stabsmedlem*), following the "Ny X" convention.

## Deferred

* **Role → audience/session mapping helper.** The default mapping (øvelsesleder → coordinator + øvelsesleder-brief, veileder → observer + veileder-brief, markør → roleplayer + roleplay script) stays **advisory** — described above, not coded. The axes are orthogonal (ADR-0019), so a helper is added only when a feature actually needs to derive an audience or session role from a staff role (decided 2026-07-10). Encoding it before there is a caller would imply a tighter coupling than intended.

## Non-goals

* No change to `Person` (fictional character, DESIGN-009) or `RolePlay`.
* No authentication/account model — roster people are local scenario staffing, not app users (that is the ADR-0024/0025 account track).
* No cross-plan roster library.
* **No individual participant records.** Course participants ("deltakere") are not `Staff` and are not rostered per-person; they remain a `Team` count (DESIGN-006 deferred #2). "Deltaker" survives only as a brief audience.
* No new brief audiences or session roles — this design adds the third axis's *values*, not new axes.

## Implementation sketch

Staged, each a PR: **(1) rename + model** — `Actor` → `Staff`, folder `actors/` → `staff/`, `RolePlay.actorUuid` → `staffUuid` (clean, no alias; amends ADR-0018), add the `StaffRole` enum and the `@Default({}) roles` field, `make build`, content hash, `DrillFile` round-trip; **(2) tab + editor** — "Bemanning" → "Stab" (`nb`), `StaffFormScreen` gains the role multi-select + derived markør chip, `nb`/`en` labels for the roles; **(3) staff list** — role display/grouping and the "Ny person" reconciliation (call 1); **(4) mapping helpers + tests** — staff-role → brief-audience/session-role defaults, kept orthogonal, with round-trip and back-compat tests. An ADR-0018 amendment records the rename.

## References

* [DESIGN-006](./006-program-tab-consolidation.md) — Roster tab, "person with role" direction, the three-axes table this design encodes.
* [DESIGN-009](./009-scenario-locations-and-persons.md) — `Person` (fictional) / `RolePlay` / `Actor` triad this design layers on.
* [ADR-0018](../adrs/0018-roleplayer-data-model.md) — `RolePlay`/`Actor` split, PII strip, schema 1.1. **Amended by this design:** `Actor` → `Staff`, `actors/` → `staff/`, `actorUuid` → `staffUuid` (clean rename, pre-publish).
* [ADR-0019](../adrs/0019-roleplayer-participant-role.md) — session role kept orthogonal to audience.
* [ADR-0022](../adrs/0022-markdown-content-as-files.md) — storage precedent for the PII layer.
