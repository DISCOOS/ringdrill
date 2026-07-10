# Implement DESIGN-010 — Prompt 3a: display-surface resolver migration

You are working in the RingDrill repository, on `design-010` (stages 1–2 landed: the Flutter-free `field_resolver`, the scope cascade, `resolveScopedField`, and the editor preview/rollup). This stage closes the **read-side** gap: display surfaces still resolve only `{{var.*}}` via `substitutePlanVariables` (or `RingDrillText`, which wraps it), so cross-references like `{{station.position.utm}}` render as literal text — visible in the station detail sheet today. Route the read surfaces through the full resolver. [ADR-0048](../adrs/0048-flutter-free-field-resolver.md), `docs/design/010-inline-preview-and-resolve-scope.md` ("RingDrillText upgrade") are authoritative. Read `AGENTS.md` rule 9.

This is the **mechanical** half of stage 3. The Post/Spill viewer redesign is **3b**, on top of this.

**No model, renderer, or schema change.** This swaps a var-only resolver for the stage-1/2 field resolver on read surfaces.

## Background

`resolveScopedField(context, content, {overrides, roleplayFacets})` (stage 2, `lib/views/widgets/resolve_scoped_field.dart`) resolves a field against whatever scopes are above it in the tree (`PlanScope` → `ExerciseScope` → `StationScope`), degrading gracefully when a scope is absent. `RingDrillText` (`lib/views/widgets/ringdrill_text.dart`) today calls `substitutePlanVariables` (var-only). Direct `substitutePlanVariables` callers on display surfaces: `station_screen.dart`, `roleplay_screen.dart`, `station_list_view.dart`, `program_view.dart`, `coordinator_screen.dart`, `stations_view.dart`, `roleplays_view.dart`, `station_mini_map.dart`, and a few others (`team_*`, `shell_notifications`, `exercise_picker_sheet` — these are var-only surfaces and can stay as-is unless trivially in scope).

## Scope

Three commits.

### Commit 1. RingDrillText → full resolver

Switch `RingDrillText` from `substitutePlanVariables` to `resolveScopedField`, so every `RingDrillText` resolves the full cascade available at its location (var + program everywhere `PlanScope` exists; exercise/station/loc-person where those scopes exist). Keep its rendering contract (plain `Text` of the resolved string; markdown rendering stays `BriefMarkdown`'s job). Graceful when scopes are absent — same output as today for a var-only context.

Files: `lib/views/widgets/ringdrill_text.dart`. `flutter analyze` + `flutter test test/views/`. Commit: `feat(views): resolve RingDrillText through the full field resolver`.

### Commit 2. Provide scopes on the single-entity read sheets; migrate their text

The **Post** sheet (`station_screen.dart`) and the **Spill** sheet (`roleplay_screen.dart`) are single-entity read surfaces where the fix is clean: wrap each in the scope(s) it needs — a `StationScope` for the station (its locations/persons + own facets), `ExerciseScope`/`PlanScope` from the ancestry (they render inside the program route), and for the Spill sheet the roleplay's own facets via `resolveScopedField`'s `roleplayFacets`. Then replace the `substitutePlanVariables` calls that render body text (notably `station_screen.dart`'s `description` in the `SelectableText`) with `RingDrillText` / `resolveScopedField`, so `{{station.position.utm}}` and the other cross-references resolve. This fixes the literal-token bug in the current sheet layout (3b rebuilds the layout).

Migrate the other display callers that sit under a usable scope (`station_list_view`, `program_view`, `coordinator_screen`, `stations_view`, `roleplays_view`) to the shared resolver, resolving what their scope offers. Where a surface lists many entities and giving each row its own station context is more than a small change, resolve what is in scope (var + program) and note it — per-row station scopes are not required here.

Files: `station_screen.dart`, `roleplay_screen.dart`, and the display callers above. `flutter analyze` + `flutter test test/views/`. Commit: `feat(views): resolve cross-references on the read sheets and lists`.

### Commit 3. Tests

* The Post sheet renders `{{station.position.utm}}` (and a `{{station.loc/person.*}}` facet) resolved, not literal — a regression test for the reported bug.
* `RingDrillText` under a station/exercise scope resolves `{{station.name}}`/`{{exercise.name}}`; with only `PlanScope` it resolves `{{var.*}}`/`{{program.name}}`; with no scope it degrades to the raw text (no crash).
* The Spill sheet resolves the roleplay's own facets and the linked station's `station.*`.

`flutter analyze`, `flutter test test/views/`, then the single final gate: full `flutter test` + `dart build cli`.

Files: test files under `test/views/`. Commit: `test(views): cover full resolution on the read surfaces`.

## Ground rules

* One resolution path: reuse `resolveScopedField`/`RingDrillText`; do not add a second resolver or resolve tokens by hand.
* View + test only (no ARB expected). No model, renderer, or schema change.
* Do not redesign the sheets here — only make their existing text resolve. Layout is 3b.
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + `flutter test test/views/`; full `flutter test` + `dart build cli` **once at the end**.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures.
2. `dart build cli` succeeds.
3. Manual smoke: the Post detail sheet shows the description with `{{station.position.utm}}` resolved to the UTM (the reported bug is gone); names/subtitles across lists still render correctly; nothing that previously resolved now regresses.
4. `git diff --stat` touches `lib/views/…`, `test/…` only. No model, renderer, or schema change.
5. Clean tree.

## Deliverables

Conventional Commits (English) on `design-010`, clean tree, targeted tests per commit, one full-suite gate at the end (rule 9). The final commit body notes `RingDrillText` and the single-entity read sheets now resolve the full cascade (closing the literal `{{station.position.utm}}` bug), through the shared stage-1/2 resolver, with no second resolution path.

ADR-0048 and DESIGN-010 are authoritative. The Post/Spill viewer **redesign** (cards, persons/locations lists, timing table, map+legend, effective identity) is **3b** — out of scope here. If wrapping a sheet in its scope needs more than providing `StationScope`/`ExerciseScope` and calling `resolveScopedField`, stop and report.
