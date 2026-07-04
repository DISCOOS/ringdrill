# DESIGN-008 follow-up 11 — resolve variables in AppBar titles and modal surfaces (QA fix)

You are working in the RingDrill repository. This is a QA fix surfaced while running follow-up 10 on `design-008`. Read [ADR-0046](../adrs/0046-plan-variables.md) and the follow-up-09 work (`RingDrillText`, `PlanScope`) first. Variables resolve in editor fields, markdown, list tiles and the brief *body*, but two title surfaces still show raw `{{var.name}}`, and the cause of the second one is a scope gap that likely affects every modal surface.

## The two findings

1. **Main tab AppBar title (missed conversion).** In `lib/views/main_screen.dart`, `_buildAppBarTitle` renders the plan-name title as a plain `Text(pageTitle)` on compact, and the rail-mode secondary line uses `ProgramService().activeProgram?.name` raw in `SheetTitle`. These sit inside the `PlanScope` provided at line ~298, so they just need to become variable-resolving.

2. **Modal surfaces escape `PlanScope` (root cause).** The brief opens as a modal bottom sheet (`showRingdrillViewerSheet` → `showModalBottomSheet`), pushed on the root navigator's overlay — **outside** the `PlanScope` that wraps `MainScreen`. So `RingDrillText` inside any modal (the brief's chrome title, and likely the `SheetTitle` of detail screens and pickers opened via `openFormSurface`/the sheet helpers) finds no scope and degrades to raw. The brief *body* resolves only because `BriefRenderer` substitutes names itself (follow-up 05); the brief's own app-bar title `Text(exercise?.name ?? program.name)` does not. The follow-up-09 `SheetTitle` tests passed because they wrap in `PlanScope` manually; the running app does not.

## Fix strategy

* Convert the missed titles to resolving widgets (they are already in scope).
* Provide `PlanScope` at the modal-surface choke points so anything pushed as a sheet/dialog inherits the active plan's variables. The unified helpers in `lib/views/widgets/ringdrill_sheet.dart` / `context_sheet.dart` (`showRingdrillViewerSheet`, `showRingdrillActionSheet`, `showRingdrillFormDialog`, and `openFormSurface`) are the single choke points — wrap the built child there in a `PlanScope` seeded from `ProgramService().activeProgram?.variables ?? const []`. The brief renders an explicit program (its `programUuid`), which may differ from the active one, so wrap the `BriefScreen` body in its **own** `PlanScope` from `widget.program.variables` rather than relying on the active-program default.
* Cross-program pickers (library/import/export) deliberately do not use `RingDrillText` (follow-up 09), so a default `PlanScope` around them is harmless — they simply don't read it. Do not start resolving them.

## Ground rules

* Reuse `RingDrillText`, `PlanScope`, `substitutePlanVariables`, `effectivePlanVariables`. No new resolution logic.
* `RingDrillText` must still degrade to plain text where there is genuinely no scope; the fix is to ensure a scope exists, not to make the widget throw.
* No model or renderer changes. Views only.
* No new lint suppressions. `flutter analyze` and `flutter test` before green.

## Scope

Four steps.

### Step 1. Main tab AppBar title

In `main_screen.dart` `_buildAppBarTitle`, render the plan-name title with `RingDrillText` (compact `Text(pageTitle)` when the tab title is the plan name, and the `SheetTitle` `secondary` plan-name line in rail mode). Where the title is a fixed section label (not the plan name), leave it plain. Confirm the `PlanScope` at line ~298 actually encloses the `AppBar` (it should, wrapping the `Scaffold`); if not, hoist it so it does.

Commit: `fix(views): resolve variables in the main tab AppBar title`.

### Step 2. PlanScope inside the modal choke points

Wrap the child built by `showRingdrillViewerSheet`, `showRingdrillActionSheet`, `showRingdrillFormDialog` (and `openFormSurface` if it doesn't route through them) in a `PlanScope` seeded from `ProgramService().activeProgram?.variables ?? const []`, so detail screens, pickers and action sheets inherit the active plan's scope. Keep `updateShouldNotify` cheap.

Commit: `fix(views): provide PlanScope inside modal sheets and dialogs`.

### Step 3. Brief chrome title

Wrap the `BriefScreen` body in a `PlanScope` seeded from `widget.program.variables`, and render the slim-app-bar title (`exercise?.name ?? program.name`) with `RingDrillText` (overrides = `effectivePlanVariables(program, exercise: exercise)` scope, matching how the body resolves the same name). Now the brief chrome matches its body.

While here, audit the program-overview inline brief preview (the "Generelt om spill og øvingsledelse" block on the Program tab that currently shows `{{var.year}}` raw). If it renders those markdown sections through a path that bypasses resolution, resolve them the same way the brief body does (via the renderer or `substitutePlanVariables` on the section content). If that turns out non-trivial (markdown-rendered), note it and split it into its own finding rather than expanding this fix.

Commit: `fix(views): resolve variables in the brief chrome title`.

### Step 4. Tests

* A widget test that **pushes a real modal** (the brief, and a detail sheet via the helper) — not a hand-wrapped `PlanScope` — and asserts a plan name containing `{{var.year}}` resolves in the modal's title.
* A test for the main tab AppBar title resolving under `PlanScope`.
* Guard: a modal opened with no active program still renders (empty scope, plain text, no throw).

Run `flutter analyze`. `flutter test`. Then the full suite.

Commit: `test(views): cover title resolution in modal surfaces and the main AppBar`.

## Verification

1. `flutter analyze` clean; `flutter test` no new failures.
2. Manual QA: a plan named `LSOR Eidene {{var.year}}` with `year` = 2026 shows "LSOR Eidene 2026" in the Program and Bemanning tab AppBars, in the brief's title bar (matching its H1), and in detail-screen titles — not the raw token.
3. `dart build cli` succeeds; `make i18n` idempotent.
4. Cross-program pickers still show whatever they showed before (not resolved against the wrong plan).
5. Clean tree gate and diff sanity.

## Deliverables

Conventional Commits (English) on `design-008`, clean tree. The final commit body notes the root cause (modal surfaces escaped the `MainScreen` `PlanScope`) and that it is fixed at the sheet/dialog choke points plus the brief's own scope, with the two raw titles converted. After this, resume follow-up 10 (end-to-end QA + Accept). If the program-overview markdown preview turns out to need its own resolution path, record it as a separate finding.

ADR-0046 and DESIGN-008 are authoritative. Contained fix; no new ADR.
