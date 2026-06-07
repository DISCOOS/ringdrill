You are working in the RingDrill repository. Implement **stage 3 of DESIGN-007** ("Onboarding sequence and in-app help"): the **bundled example plan** and wiring the concept primer's **"Åpne et eksempel"** button to import and activate it. The authoritative spec is:

- `docs/design/007-onboarding-and-help.md` (DESIGN-007, Accepted) — read *Layer 2 — Example plan*, *Implementation notes → Stage 3*, *Deferred decisions* (item 4), and *Non-goals*. Skim *Layer 1 — Concept primer* so the example stays continuous with the primer artwork.

Read it in full first. If this prompt contradicts it, the spec wins; stop and ask.

Stage 2 has landed: the primer (`lib/views/concept_primer_screen.dart`, `lib/views/widgets/concept_primer_content.dart`), the `/welcome` route, the `AppConfig.keyOnboardingSeen` flag, and `RingRotationFigure`. **"Åpne et eksempel" is currently a stub** — `ConceptPrimerScreen.onOpenExample` just marks onboarding seen and goes to the (empty) Program tab, with a `// TODO(DESIGN-007 stage 3)`. Stage 3 replaces that stub with a real import.

## What stage 3 is, and is not

Stage 3 ships a small bundled `.drill` the primer can open and activate in one tap, so a cold-launched user lands in a populated Program tab, one tap from the Exercise Player. It is the fastest path from first open to a moving ring.

**In scope:**

- A **small, purpose-built example plan**, bundled as a localized `.drill` asset and loaded offline. Per the spec: about **three stations, three teams, two rounds**, plus a couple of markører (`RolePlay`) and a short brief, so the Roster tab and the brief action are not empty when the user explores. Stations use **`2a` / `2b` / `2c`** for continuity with the primer (see *Numbering continuity* below). Content is localized: Norwegian content in `nb`, English content in `en`. Schema is current (`DrillFile.drillSchemaCurrent`, today `1.2`), not the legacy `1.0` the screenshot demos use.
- **Asset wiring:** the `.drill` file(s) under `assets/`, declared in `pubspec.yaml`, loaded via `rootBundle`, parsed with `DrillFile.fromBytes`.
- **Button wiring:** `onOpenExample` loads the locale-matched asset, installs and activates it via `ProgramService().installFromFile(file, activate: true)`, marks `keyOnboardingSeen`, and navigates to the active program path. On any failure (missing asset, parse error) it falls back to the existing empty-plan path and does **not** show a brand-new user a scary error — log it, degrade gracefully.

**Out of scope (do not touch):**

- **No "Start her" cue** (stage 4) and **no Help / FAQ** (stage 5).
- **No change to the screenshot demos.** `tools/screenshots/demo-no.drill` / `demo-en.drill` are store-screenshot fixtures (five exercises, four teams, schema 1.0, no markører, no brief) and stay where they are, used by the `tools/screenshots` flow. Do **not** bundle them as the onboarding example — wrong shape and wrong schema (see *Delivery* for why the generator behind them is still the right tool).
- **No new import mechanism.** Reuse `DrillFile` + `ProgramService` exactly. Do not add a parallel loader.
- **No `BriefTheme`, no analytics/Sentry calls beyond an existing-pattern debug log.**
- **No data-model fields, no codegen** beyond the l10n regeneration that editing the `.arb` files triggers.

## Ground rules

Read `AGENTS.md` and follow every numbered rule. The ones that bite here:

- **Localize every user-visible string.** Any new UI string (e.g. a fallback snackbar, if you add one) goes in both `app_en.arb` and `app_nb.arb`; run `make build`. The example plan's *content* is localized by shipping one asset per language, not via `.arb`. Norwegian for *station* stays "post"/"poster" ([[feedback_post_station_terminology]]).
- **Markører = `RolePlay` enacted by `Actor`** ([[feedback_roleplay_actor_terminology]]). The example carries a couple of `RolePlay`s (publishable roles). Per [ADR-0018](../adrs/0018-roleplayer-data-model.md), an asset shipped in the build may include `actors/` or not, but keep it minimal — the teaching point is that the Roster/Markører surfaces are not empty, not a full cast.
- **CLI must stay Flutter-free.** The loader is widget/service layer; nothing the CLI imports may pull in `rootBundle`.
- **Mobile-safe imports.** No `dart:html` / `package:web`. `rootBundle` and `DrillFile.fromBytes` are fine on all targets including web.
- **Match existing Dart style.** No new lint suppressions without an inline reason.
- **Verify before claiming green.** `flutter analyze` and `flutter test` at the end of each step.

## Delivery — resolved: bundled localized asset

Deferred decision 4 is resolved to a **bundled asset**, not a built-in catalog entry and not a programmatic in-Dart factory: it is simplest and offline by default, and the repo already has the machinery to author one deterministically.

**Author it by extending the existing generator,** `tools/screenshots/make_demo_drills.py`. That script already emits deterministic `.drill` zips (fixed nanoid seed, `metadata.json` + `program.json` + `exercises/` + `teams/`) — the exact format `DrillFile` reads. Add an onboarding target to it that emits the small example per locale at schema `1.2`, including `roleplays/` and the brief markdown files (`program.json` brief fields / `.md` entries per [ADR-0022](../adrs/0022-markdown-content-as-files.md) — inspect a current-schema `.drill` exported from the app, or `lib/data/drill_file.dart`, for the exact member layout, since the screenshot demos predate markører and brief). Commit the generated `.drill` outputs as the bundled assets and keep the generator change so they can be regenerated without churn. If extending the Python generator proves awkward for the 1.2 members, an acceptable alternative is a tiny Dart tool/test that builds a `Program` and writes bytes via `DrillFile.fromProgram` — pick whichever reproduces a valid current-schema file with the least new surface, and record the choice in the handoff.

Suggested asset layout: `assets/example/onboarding-example.nb.drill` and `assets/example/onboarding-example.en.drill`. Pick the asset by the current content locale (fall back to `en` for any non-`nb` locale).

### Numbering continuity (decide explicitly)

The primer artwork hardcodes **`2a` / `2b` / `2c`** (`RingRotationFigure` uses `exerciseNumber: 2`), and the spec asks the example to match. Station labels derive from the exercise's number, so a single-exercise plan would render `1a` / `1b` / `1c`, not `2a` / `2b` / `2c`. Resolve one of:

- **(a, recommended, no shipped-code change):** give the example **two exercises** — a short intro exercise (#1) and the showcased rotation as exercise **#2** with three stations, three teams, two rounds and `alpha` station format, so its posts read `2a` / `2b` / `2c` exactly like the primer. A realistic plan having more than one exercise is fine and even reinforces progression.
- **(b, alternative):** keep the example a single exercise and change the primer + mockup to `1a` / `1b` / `1c`. This re-touches stage 2 artifacts (`RingRotationFigure`, `onboarding-concept-primer.html`), so only do this if Kengu prefers a single-exercise example.

Adopt (a) unless told otherwise. Whichever you pick, the primer figure and the example's showcased exercise must show the **same** labels — note the choice in the handoff.

## Investigate before you wire (do this first, no commit)

1. **The stub.** `ConceptPrimerScreen` (`lib/views/concept_primer_screen.dart`) — `onOpenExample` calls `_dismiss(context)` with the stage-3 TODO. `_dismiss` writes `keyOnboardingSeen` and `context.go(routeProgram)`. Stage 3 makes `onOpenExample` do the import first, then dismiss.
2. **The right import call.** Confirm `ProgramService().installFromFile(file, activate: true)` (`lib/services/program_service.dart`) is the path that installs the incoming program **as-is** (preserving its uuid, name, brief, `rolePlays`, teams) and sets it active — not `importProgram`, which ensures a default-named active program and merges only the incoming *exercises* into it. The example should arrive as its own named, active plan, so use `installFromFile`. Verify what event it emits and that the Program tab rebuilds off `ProgramService().events` (it already listens — see `MainScreen`).
3. **Asset loading on all targets.** `rootBundle.load(...)` returns a `ByteData`; `DrillFile.fromBytes(fileName, bytes)` takes `List<int>`. Confirm the conversion (`bytes.buffer.asUint8List()`), and that this works on web (the app already loads template assets via `rootBundle` in `brief_renderer`).
4. **Locale selection.** Find how the app reads the current locale at this point (e.g. `Intl.getCurrentLocale()` as `NotificationService` does, or the `BuildContext` locale). Choose `nb` vs `en` asset accordingly with an `en` fallback.
5. **The `.drill` member layout at schema 1.2.** Read `lib/data/drill_file.dart` (the decode path around lines 60–160 reads `program.json`, `exercises/`, `teams/`, `roleplays/`, `actors/`, and brief `.md` members) so the generated asset has exactly the members a current build expects. The screenshot demos omit `roleplays/` and brief md — your example must include them.

Append a short note of what you found to `docs/prompts/DESIGN-007-stage-3-handoff.md` (create it) before step 1.

## Commits

Conventional Commits, scope `onboarding`. One commit per step, `git status` clean between steps (commit every changed file each step, including the generated `.drill` assets, the generator change, regenerated l10n and any test files). Do not squash. There are unrelated uncommitted changes in `lib/views/roleplay_form_screen.dart` and `lib/views/roleplays_view.dart` that are **not** part of DESIGN-007 — do not stage, commit, revert, or build on them.

## Steps

### Step 1 — `feat(onboarding)`: author and bundle the example plan

Extend the generator (or add the small Dart builder) to emit the localized example per *Delivery* and *Numbering continuity*, write the `.drill` asset(s) under `assets/example/`, and declare them in `pubspec.yaml`. Add a test that loads each bundled asset through `DrillFile.fromBytes` and asserts it parses at the current schema with the expected shape (≈3 stations `2a`/`2b`/`2c` on the showcased exercise, 3 teams, 2 rounds, ≥1 `RolePlay`, a non-empty brief). No button wiring yet.

Gates green. Commit.

### Step 2 — `feat(onboarding)`: wire "Åpne et eksempel" to import and activate

Replace the `onOpenExample` stub: load the locale-matched asset, `installFromFile(file, activate: true)`, mark `keyOnboardingSeen`, navigate to the active program path. Wrap in try/catch — on failure, fall back to the current empty-plan dismissal and log via the existing debug pattern (no Sentry add, no scary UI for a first-run user). Remove the `// TODO(DESIGN-007 stage 3)`.

Gates green. Commit.

### Step 3 — `test(onboarding)`: cover the example-open flow

Widget/integration tests under `test/`: tapping "Åpne et eksempel" installs and activates the example so the active program becomes the named example with a non-empty Program tab (exercises present), `keyOnboardingSeen` is written, and the route leaves `/welcome`; locale selection picks the right asset (`nb` vs `en`/fallback); a missing/corrupt asset falls back to the empty-plan path without throwing. Reuse the test harness style in `test/views/concept_primer_screen_test.dart` (mock prefs, `buildRouter`, `ProgramService().init()`).

Gates green. Commit.

## When you finish or get stuck

- Append a closing entry to `docs/prompts/DESIGN-007-stage-3-handoff.md` summarizing the landed state: asset paths, how they are generated, the numbering-continuity choice, and the import call used — so stage 4/5 and future maintainers can regenerate the example.
- Off-scope findings go to `docs/prompts/DESIGN-007-followups.md` (one line each). New defects become their own numbered follow-up, not extra steps here ([[feedback_new_findings_own_prompt]]).
- If a step is blocked by an ambiguous spec or unmet precondition, stop and write a one-paragraph note to `docs/prompts/DESIGN-007-stage-3-blockers.md`, then exit rather than guessing.
- Smoke-test a fresh install: clear `shared_preferences` (or `Upgrader.clearSavedSettings` in debug), launch, tap "Åpne et eksempel", and confirm the named example plan opens active with a populated Program tab and posts labelled to match the primer, before pushing.
