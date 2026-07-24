# Refactor: rename `Program` → `Plan` (full) and `signalement` → `description`

You are working in the RingDrill repository, on `design-013` (this ships in the same release — do not branch off). Two model-naming cleanups, done as **clean breaking renames with no back-compat aliases** (nothing is published against these yet, per the maintainer). References: DESIGN-010 § "Naming (`Program` → `Plan`), separate refactor". Read `AGENTS.md` (rules 1, 9, 12, 13).

This is a large, mostly-mechanical rename (~800+ identifier touch points + file renames + codegen). Use tooling rename + `make build` + `make i18n`, then drive `flutter analyze` to zero and the full suite green. Split into commits per part below.

## Part A — `Program` → `Plan` (full)

Rename the model type **and** everything `Program*` in Dart to `Plan*` so code matches the UI (which already says "Plan"). Regenerate freezed/`json_serializable` with `make build` — never hand-edit `*.freezed.dart`/`*.g.dart`.

Rename (types + files):

* `Program` → `Plan`; `lib/models/program.dart` → `lib/models/plan.dart`.
* `ProgramMetadata` → `PlanMetadata`, `ProgramSource` → `PlanSource`, `ProgramDiff` → `PlanDiff` (and `ProgramSource.local/imported/catalog` **factory names stay** — they are the JSON union discriminator, see frozen list).
* `ProgramService` → `PlanService` (`program_service.dart` → `plan_service.dart`); `activeProgram`/`activeProgramUuid` → `activePlan`/`activePlanUuid`; `getProgram`/`saveProgram`/… → `getPlan`/`savePlan`/… .
* `ProgramRepository` → `PlanRepository` (`program_repository.dart` → `plan_repository.dart`).
* `ProgramView` → `PlanView` (`program_view.dart` → `plan_view.dart`); `ProgramFormScreen` → `PlanFormScreen` (`program_form_screen.dart` → `plan_form_screen.dart`); `ProgramPageController`/`Base` → `PlanPageController`/`Base` (`program_page_controller.dart` + `lib/web/program_page_controller.dart` → `plan_page_controller.dart`); `program_diff_widgets.dart` → `plan_diff_widgets.dart`; `ProgramSegment` → `PlanSegment`.
* Tests: rename `program_*_test.dart` → `plan_*_test.dart` and update references.

### URLs and routes — rename `/program/` → `/plan/` too

No external permanent links exist yet, so the whole `program` URL segment moves to `plan`. (The in-app `/program/:uuid/…` routes are client-only — not in AASA, the apex proxy, or the deep-link handler; the `/brief/program/:uuid` brief link is interim (ADR-0041) and none have been shared.)

* **In-app program-scoped routes (ADR-0032):** path strings `/program/:uuid/…` → `/plan/:uuid/…`, and rename the constants/helpers: `routeProgram`→`routePlan`, `programPath`→`planPath`, `programSegmentPath`→`planSegmentPath`, `programMapPath`→`planMapPath`, `programRosterPath`→`planRosterPath`, `programSegmentDefaultSlug`/`programSegmentFromSlug`→`plan*`.
* **External brief link `/brief/program/:uuid` → `/brief/plan/:uuid`:** update `netlify.toml` (the `/brief/program/*` redirect, ~line 147), the brief endpoint/handler, the app's brief-link generation, and `docs/api.md`. The `/d/`, `/i/`, `/o/` deep-links contain no "program" and are untouched.
* **Amend ADR-0032** (route namespace `/program/`→`/plan/`) and note the brief-path change against ADR-0041, in this change set (rule 11).

### FROZEN — must NOT change (wire only)

* **`.drill` archive root `program.json`** (ADR-0007) — the file name inside the archive stays `program.json`. JSON field keys (`uuid`/`name`/`exercises`/…) are unaffected by a Dart class rename — confirm with a round-trip.
* **`PlanSource` union discriminator** — keyed by the **factory names** (`local`/`imported`/`catalog`), not the class name, so serialized values are unchanged. Verify.
* **CLI** stays Flutter-free (rule 7); `Plan` is a plain model, so this holds.

### l10n

Update user-facing label **text** that says "Program" to "Plan"/"plan" where it names the plan concept (`nb` and `en`). ARB **keys** named `program*` for the model concept may be renamed to `plan*` for consistency (both languages, then `make i18n`); keep route/other unrelated keys as they are.

## Part B — `signalement` → `description` (clean break)

`Person.signalement` and `RolePlay.signalement` → `description`. No alias, no back-compat: old `.drill` files simply won't carry the field (acceptable — nothing real is published with it). `description` is unambiguous here because it sits on the person/role.

* Models: `Person.signalement` → `Person.description`, `RolePlay.signalement` → `RolePlay.description`; `make build`.
* **Tokens:** `{{station.person.<slug>.signalement}}` → `.description`. Update the resolver and facet completion (`field_resolver.dart` / `station_scenario_tokens.dart` / `resolvePersonFacet` and the picker's facet list: `signalement` → `description`), and the roleplay own-facet `roleplay.signalement` → `roleplay.description`. Update the effective-identity merge (`_EffectiveIdentityCard._effective(rolePlay.signalement, person.signalement)`).
* **l10n:** rename the field's label. Keep the `nb` **label text** as "Signalement" if you like — it is a valid Norwegian word — but the field/key and the **`en`** label become "Description". (Decision: `en` = "Description"; `nb` label may stay "Signalement".) Rename `signalement`-named ARB keys accordingly, both languages, `make i18n`.
* **Docs:** update DESIGN-009 and the token/facet reference docs (glossary/ui-conventions if they mention it) to `.description`.
* **Test fixtures:** any `.drill` / JSON fixture under `test/` carrying `signalement` must be updated to `description` so the round-trip and resolver tests pass. No schema-marker bump (clean break, no in-the-wild data).

## Scope — commits

1. `refactor(models): rename Program to Plan` — model types + files + `make build`, callers compile.
2. `refactor(services): rename ProgramService/Repository to Plan*` — service/repo + `activePlan*`.
3. `refactor(views): rename Program views/controllers/segment to Plan*` — views, `PlanPageController`, `PlanSegment`, file renames.
4. `refactor(routing): move the /program/ URL namespace to /plan/` — route path strings + helpers (`routePlan`, `planSegmentPath`, …); the `/brief/program/`→`/brief/plan/` redirect in `netlify.toml` + the brief handler + the app's brief-link generation + `docs/api.md`; amend ADR-0032.
5. `refactor(l10n): Plan labels/keys` — label text + optional key renames + `make i18n`.
6. `refactor(models): rename person/roleplay signalement to description` — Part B (model + tokens + l10n + fixtures + docs).
7. `test: cover the Plan rename and description field` — update/verify tests, including the wire round-trip.

(Grouping is a guide; keep each commit compiling. Run `make build`/`make i18n` only when a step changed a `@freezed`/`@JsonValue`/`.arb` source.)

## Ground rules

* Clean breaking renames — no aliases, no dual-read.
* Only the FROZEN list stays: the `.drill` archive's `program.json` file name, its JSON field keys, and the `PlanSource` union discriminators. Everything else renames — Dart identifiers, files, the `/program/` URL namespace, and the `/brief/program/` redirect.
* Regenerate, never hand-edit generated files (rule 1/2). Two languages kept equivalent (rule 4); ARB edits → `make i18n`.
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + targeted tests; the full `flutter test` + `dart build cli` **once at the end**.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` green; `dart build cli` succeeds.
2. **Wire round-trip (proves Program→Plan is wire-invisible):** save a `Plan` to a `.drill` and reload it; assert the archive still contains `program.json`, the JSON keys are unchanged, and a `PlanSource.catalog(...)` round-trips (discriminator intact). A drill authored before the rename (a committed fixture) still imports.
3. **`description`:** `{{station.person.<slug>.description}}` resolves; `.signalement` no longer exists anywhere (`grep -ri signalement lib test` returns nothing but incidental prose); the person/role editors and viewers show the field under its new label.
4. `git diff --stat` touches `lib/…`, `test/…`, `lib/l10n/…`, `docs/…`, and `netlify.toml` + the brief handler (only for `/brief/program`→`/brief/plan`). `grep -rn "/program" lib netlify` finds no URL segment — only the `program.json` archive name and incidental prose.
5. Clean tree.

## Deliverables

Conventional Commits (English) on `design-013`, clean tree, one full-suite gate at the end (rule 9). `Program`/`Program*` is gone from Dart identifiers and the `/program/` URL namespace moved to `/plan/` (including the `/brief/program/` redirect); `signalement` is gone; only the `.drill` internals (`program.json` + JSON keys) stay frozen — the Plan rename is wire-invisible there, `description` is cleanly breaking. Ships in the same release as the rest of `design-013`.
