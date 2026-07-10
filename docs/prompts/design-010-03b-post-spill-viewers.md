# Implement DESIGN-010 — Prompt 3b: the Post and Spill viewer redesign

You are working in the RingDrill repository, on `design-010` (3a landed: the read surfaces now resolve the full cascade). This stage rebuilds the two read-only detail sheets — the **Post** (station) viewer and the **Spill** (roleplay) viewer — as the rollup made concrete: resolved narrative, scenario data on the map and in lists, and the schedule. `docs/design/010-inline-preview-and-resolve-scope.md` ("Detail sheets — the Post and Spill viewers") is authoritative and `docs/design/mockups/station-and-roleplay-viewers.html` is the visual spec. Read `AGENTS.md` rule 9.

**Visual reference:** `docs/design/mockups/station-and-roleplay-viewers.html` — build to it.

**No model or schema change.** This is a view rebuild on top of 3a's resolver and DESIGN-009's scenario data.

## Shared behavior

* Both sheets render according to the **role selected in settings** (default director), not an in-view toggle — role-gated blocks (the DESIGN-004 audiences, e.g. `directorNotes`) appear per that role, shown with the small "Kun øvelsesleder" pill in the mockup.
* All narrative is resolved via 3a's `resolveScopedField` / `BriefMarkdown` — tokens render exactly as the brief. The sheets are wrapped in the scopes 3a set up.
* The map card is the shared `StationPositionPanel` / `RolePositionPanel` (map, then a "Posisjon" coordinate strip, chevron → interactive map), fed the scenario markers as `MapMarkerSpec` styled by `LocationKind` ([ADR-0020](../adrs/0020-map-label-and-marker-clutter.md)) plus a **legend** through a slot — not a bespoke map (the same domain-agnostic slot mechanism the position field uses for its overlay actions).
* Cards use the app's elevated `Card` look; a card header is an icon + uppercase title (+ optional count/action), matching the mockup and the existing Persons/Locations cards.
* A pencil in the AppBar opens the corresponding editor; tapping a rollup section jumps into that section of the editor (as in stage 2's rollup).

## Post viewer (`station_screen.dart`)

Per the mockup, top to bottom:

1. **Postbeskrivelse card** — the resolved rollup: the lead description then the labeled sections (Situasjon, Oppdrag, role-gated notes …), markdown-rendered. "Trykk en seksjon for å redigere."
2. **Map card** — `StationPositionPanel` fed the station's position plus its scenario markers (locations, and a person's home), styled by `LocationKind`, with the legend slot and the coordinate strip.
3. **Personer card** — one row per `Person` (name · age · gender, signalement summary). The portraying marker is shown **inline on the person** ("Spilles av <Actor/roleplay>") — one card, not a separate marker list; a person with no marker shows "+ Legg til markør". A "+ Person" action in the header.
4. **Lokasjoner card** — one row per `Location` (kind icon + label + place/UTM), "+ Lokasjon" in the header.
5. **Tidsplan card** — the per-team schedule table (team rows × øve/eval/rull columns) from `Exercise.schedule` (the actual round clock times); teams not running this station are muted/struck through, the acting team highlighted.

## Spill viewer (`roleplay_screen.dart`)

Per the mockup, top to bottom:

1. **Station context card** — parent post (code + name + one-line), chevron to the post.
2. **Effective identity card** — avatar, name, "age · gender", signalement (the effective identity resolved through the person), and "Spilles av <Actor>" in the footer.
3. **Markørordre card** — the play: Atferd, Bakgrunn, Rekvisitter, markdown-resolved.
4. **Posisjon card** — `RolePositionPanel`: the marker's position (which follows the portrayed person's location), the "Posisjon" strip labeled with the source location, chevron.
5. **Når aktiv card** — the schedule row(s) for when this marker is active (same table shape as the Post viewer's Tidsplan, scoped to the acting team).

## Scope

Four commits.

### Commit 1. Post viewer: rollup + map cards

The card scaffolding, the resolved Postbeskrivelse rollup card, and the `StationPositionPanel` map card with scenario markers + legend. Role-gating via the settings role.

Files: `station_screen.dart`, `station_position_panel.dart` (legend slot if not present), a small card widget if warranted, ARB for new labels. `flutter analyze` + `flutter test test/views/`. Commit: `feat(views): rebuild the Post viewer rollup and map cards`.

### Commit 2. Post viewer: persons, locations, schedule cards

Personer card (rows, marker inline per person), Lokasjoner card, Tidsplan card from `Exercise.schedule`.

Files: `station_screen.dart`, a schedule-table widget, ARB. `flutter analyze` + `flutter test test/views/`. Commit: `feat(views): add persons, locations and schedule to the Post viewer`.

### Commit 3. Spill viewer rebuild

Station-context, effective-identity, Markørordre, Posisjon (`RolePositionPanel`), and Når-aktiv cards.

Files: `roleplay_screen.dart`, `role_position_panel.dart` if needed, ARB. `flutter analyze` + `flutter test test/views/`. Commit: `feat(views): rebuild the Spill viewer as the marker's order`.

### Commit 4. Tests

* Post viewer: the rollup renders resolved lead + sections; a role-gated section is hidden for a non-director role and shown for director; the map card receives the scenario markers; a person that a roleplay portrays shows "Spilles av …" inline (one card); the schedule table shows the acting team's times.
* Spill viewer: effective identity renders (inherited + overridden); Markørordre resolves tokens; the position card reflects the portrayed person's location.
* Role gating driven by the settings role (not an in-view control).

`flutter analyze`, `flutter test test/views/`, then the single final gate: full `flutter test` + `dart build cli`.

Files: test files under `test/views/`. Commit: `test(views): cover the Post and Spill viewers`.

## Ground rules

* Build to the mockup; reuse `StationPositionPanel`/`RolePositionPanel`, `MapMarkerSpec` + `LocationKind` styling, `BriefMarkdown`, `resolveScopedField`, and the settings viewer-role. Do not invent a new map or a second resolver.
* Role gating uses the existing `BriefAudience` (DESIGN-004) driven by the settings role; no per-sheet audience switch.
* The schedule table reads `Exercise.schedule` (already computed); do not duplicate the rotation math.
* User-visible strings via ARB, then `make i18n`.
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + `flutter test test/views/`; `make i18n` only on ARB change; full `flutter test` + `dart build cli` **once at the end**.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures.
2. `make i18n` idempotent; `dart build cli` succeeds.
3. Manual smoke (narrow and wide, nb and en, and switching the settings role): the Post viewer shows the resolved rollup, the map with scenario markers + legend, persons with inline markers, locations, and the schedule; the Spill viewer shows the effective identity, the play, the person-derived position, and when-active; role-gated notes appear only for director.
4. `git diff --stat` touches `lib/views/…`, `lib/l10n/…`, `test/…` only. No model or schema change.
5. Clean tree; localizations committed with ARB changes.

## Deliverables

Conventional Commits (English) on `design-010`, clean tree, targeted tests per commit, one full-suite gate at the end (rule 9). The final commit body notes the Post and Spill viewers are rebuilt as the resolved rollup made concrete — narrative resolved, scenario data on the shared map and in lists, the schedule from `Exercise.schedule`, role-gated by the settings role — completing DESIGN-010's read side.

DESIGN-010 and the mockup are authoritative. This finishes stage 3; leaf fields are **stage 4**. If the shared position panels need more than a legend/marker slot to carry the scenario markers, stop and report rather than forking a bespoke map.
