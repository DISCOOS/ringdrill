# Implement DESIGN-010 — Prompt 1: field resolver + resolve-context scope cascade

You are working in the RingDrill repository, on a fresh branch off `main` (DESIGN-009 is merged/accepted). This is the **foundation** stage of DESIGN-010: extract a reusable field resolver and set up the scope cascade that later stages (preview, rollup, `RingDrillText`, leaf fields) consume. **No visible change** ships here — it is plumbing plus tests. [ADR-0048](../adrs/0048-flutter-free-field-resolver.md), `docs/design/010-inline-preview-and-resolve-scope.md` and [ADR-0032](../adrs/0032-program-scoped-routing.md) are authoritative. Read `AGENTS.md` rule 9.

**No model, no schema, no format change.** This is a behaviour-preserving refactor of `BriefRenderer` plus new/extended `InheritedWidget` scopes.

## Background

Full token resolution (`{{var.*}}` → `{{station.loc/person.*}}` → the mustache cross-references `program.*`/`exercise.*`/`station.*`/`roleplay.*`) lives only inside `BriefRenderer._resolveField` / `_resolveFieldOnce` (fixpoint, bounded by `_maxResolvePasses`). Later DESIGN-010 stages need that exact resolution from the widget layer, over the author's unsaved state, fed by scopes rather than by a full `render()`. Stage 1 makes that possible without wiring any consumer yet.

## Scope

Four commits.

### Commit 1. Extract the Flutter-free field resolver (ADR-0048)

Move `_resolveField`, `_resolveFieldOnce` and `_maxResolvePasses` out of `lib/services/brief/brief_renderer.dart` into a reusable, Flutter-free unit (e.g. `lib/services/brief/field_resolver.dart`). Its public entry takes a field string plus an explicit resolution context — the same inputs the private method has today: the effective `vars` map, the `refContext` maps (`program`/`exercise`/`station`/`roleplay`), and the optional `scenarioStation` + `scenarioRolePlays` for `station.loc/person.*`. `BriefRenderer` keeps assembling that context exactly as now and delegates each field to the resolver.

* Behaviour-preserving: **do not** change resolution semantics. The renderer's existing tests must pass unchanged — that is the parity guarantee.
* No new `package:flutter/*` import. Keep whatever `AppLocalizations` (or placeholder-string) dependency the current code already has; do not add Flutter coupling.

Files: `lib/services/brief/brief_renderer.dart`, new `lib/services/brief/field_resolver.dart`. `flutter analyze` + `flutter test test/services/`. Commit: `refactor(brief): extract a reusable field resolver (ADR-0048)`.

### Commit 2. Extend PlanScope with program facets; add ExerciseScope

Mirror the renderer's `refContext` cascade in the widget tree (DESIGN-010 "The resolve-context cascade"):

* **`PlanScope`** (`lib/views/widgets/plan_scope.dart`) — keep the name; in addition to `variables`, carry the program's cross-reference facets (`program.name`, `program.description`). There is no separate `ProgramScope`. Provide/extend it at the program-scoped route ([ADR-0032](../adrs/0032-program-scoped-routing.md)) where the active program is known, so it sits high in the tree.
* **`ExerciseScope`** (new, `lib/views/widgets/exercise_scope.dart`) — carry the exercise facets (`exercise.*`, the same set `PlanFieldTokens.exercise` already lists) plus this exercise's variable overrides. Provide it in the exercise editor's subtree.
* `StationScope` is unchanged (DESIGN-009).

These scopes only **carry** the data in stage 1; no widget reads them for resolution yet (that is stage 2+). Keep `maybeOf` graceful-null, like `PlanScope`/`StationScope` today.

Files: `lib/views/widgets/plan_scope.dart`, new `lib/views/widgets/exercise_scope.dart`, the program-route and exercise-editor wiring. `flutter analyze` + `flutter test test/views/`. Commit: `feat(views): carry program facets on PlanScope and add ExerciseScope`.

### Commit 3. Re-provide the resolve scopes across openFormSurface

`openFormSurface` (`lib/views/shell/open_form_surface.dart`) pushes a new route/dialog under `Navigator`, which an `InheritedWidget` ancestor does not cross. Make it **capture** the ancestor `PlanScope`, `ExerciseScope` and `StationScope` (whichever are present, via `maybeOf`) at call time and **re-wrap** the pushed child with equivalent providers, seeded from the same data. This is generic (it also serves non-DESIGN-009 forms) and is the single mechanism DESIGN-009 leaf fields (stage 5) and the preview will both rely on. A snapshot at push is correct — these surfaces are modal.

Files: `lib/views/shell/open_form_surface.dart`. `flutter analyze` + `flutter test test/views/`. Commit: `feat(views): re-provide resolve scopes across openFormSurface`.

### Commit 4. Tests

* **Resolver parity (services):** a direct unit test of the extracted resolver over a representative field (nested `{{var.*}}` inside a cross-reference, a `station.loc/person.*` facet, the fixpoint terminating at `_maxResolvePasses`), plus confirmation the full brief suite is unchanged.
* **Scope presence (views):** a probe widget under the exercise editor reads `ExerciseScope.maybeOf` (non-null) and `PlanScope` exposes the program facets; a form opened through `openFormSurface` from under those scopes still sees them (non-null `maybeOf` inside the pushed surface), and a form opened with no ancestor scopes sees null (graceful).

`flutter analyze`, `flutter test test/services/ test/views/`, then the single final gate: full `flutter test` + `dart build cli`.

Files: test files under `test/services/` and `test/views/`. Commit: `test: cover the field resolver and the resolve-scope cascade`.

## Ground rules

* Behaviour-preserving for the brief — the renderer keeps its output; its tests are the regression net. If the extraction forces a semantic change, stop and report.
* Views + services + tests only. No model, renderer-output, ARB, or schema change. (`make i18n` not needed.)
* Keep the resolver Flutter-free; keep the scopes' `maybeOf` graceful-null.
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + targeted tests; full `flutter test` + `dart build cli` **once at the end**.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures (note the count).
2. `dart build cli` succeeds.
3. No visible change: the app and the brief render exactly as before (spot-check a brief).
4. `git diff --stat` touches `lib/services/brief/…`, `lib/views/…`, `test/…` only. No model, ARB, or schema change.
5. Clean tree.

## Deliverables

Conventional Commits (English), clean tree, targeted tests per commit, one full-suite gate at the end (rule 9). The final commit body notes the field resolver is now reusable and Flutter-free (ADR-0048), `PlanScope` carries program facets, `ExerciseScope` is added, and `openFormSurface` re-provides the resolve scopes — all plumbing, no visible change, the foundation for DESIGN-010 stages 2–5.

ADR-0048 and DESIGN-010 are authoritative. Preview (stage 2), rollup (stage 3), the `RingDrillText` upgrade (stage 4) and leaf fields (stage 5) are out of scope here. If extracting the resolver ripples into brief output, stop and report.
