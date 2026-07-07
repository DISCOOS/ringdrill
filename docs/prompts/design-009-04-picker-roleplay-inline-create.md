# Implement DESIGN-009 — Prompt 4: token picker, RolePlay editor, inline create + write-back

You are working in the RingDrill repository, on `design-009`. This is the heaviest prompt of DESIGN-009. [ADR-0047](../adrs/0047-scenario-locations-and-persons.md) and `docs/design/009-scenario-locations-and-persons.md` are authoritative. Prompts 1–3 shipped: the model, the renderer resolution, and the Locations/Persons sections + map. Read those, `AGENTS.md` rule 9 (test-loop discipline), and the DESIGN-008 authoring machinery you will extend: `RingDrillTextField`/`RingDrillTextArea`, `TokenTextEditingController`, the token insertion menu, `EditorToken` (`VariableToken`/`PlanFieldToken`), and `PlanScope`.

This prompt makes `station.loc.*` / `station.person.*` first-class in the editor (chips + picker), builds the RolePlay editor's person binding, and delivers **inline creation with write-back** for variables, locations and persons — which un-defers DESIGN-008's parked "create a variable from a sub-editor". No feature flag.

**Scope boundary:** save-time blocking on unresolved tokens, and rename/delete reference integrity (rewrite + guards) and re-link handling, are **prompt 5**. Here, tokens render their state (blue/amber/red) and the picker/inline-create work; enforcement and integrity come next. Note the boundary in code comments.

## Ground rules

* Reuse and extend the DESIGN-008 field/menu/controller; do not fork them. `var.*` chips and the picker already work; add `station.loc.*` / `station.person.*` alongside.
* A token field needs the in-scope station's location/person slugs to validate `station.*` chips and to offer them in the picker. Add a `StationScope` inherited widget mirroring `PlanScope` (carrying the station's `locations`/`persons`, or just their slugs + display for the picker), provided by the station editor and by the RolePlay editor (for the roleplay's linked station). The **widget** reads `PlanScope` and `StationScope` and feeds the controller — the controller stays a pure `ChangeNotifier` (the DESIGN-008 rule: widget reads context, not the controller).
* RolePlay identity persists **denormalized effective** (ADR-0047): the editor's identity fields write the effective value; inherit = equals the Person, override = differs. `personRef` is required by the editor for new/edited roleplays (nullable on the wire).
* **Write-back contract:** an editor returns its entity **plus** a named-record payload of additions for owners it does not directly hold — `PlanAdditions` carrying new plan variables (→ `Program`) and new locations/persons for a target station (→ the roleplay's linked station; the station editor owns its own, so those need no write-back, only its new variables do). The caller that owns the plan applies the entity change and the payload atomically. Use a Dart 3 named record / `typedef`, not a bespoke result class.
* ARB + `make i18n` for new strings ("Create variable/location/person «x»", the person selector, inherit/override hints). Reuse `roleGender` (added in prompt 3) for the RolePlay editor's gender field.
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + targeted tests (`flutter test test/views/`); `make i18n` only when ARB changes; full `flutter test` + `dart build cli` **once at the end**.

## Scope

Five commits.

### Commit 1. StationScope + station.* chips

Add `StationScope` (inherited widget) exposing the in-scope station's location and person slugs (with display/value for the picker). Extend `TokenTextEditingController` (via the field reading `StationScope`) to recognise `{{station.loc.<slug>}}` and `{{station.person.<slug>}}` (with facets) and render them as chips: blue when the slug exists in scope, red when it does not, amber when it resolves empty — mirroring the `var.*` states. Non-`var`/non-`station.loc`/non-`station.person` `{{...}}` stays plain (unchanged). Keep the `{{var}}`/`{{station...}}` patterns in the shared `lib/utils/plan_variables.dart` where they already live.

Files: `lib/views/widgets/plan_scope.dart` sibling (`station_scope.dart`), `token_text_editing_controller.dart`, the field widgets, `lib/utils/plan_variables.dart` if a pattern is added. `flutter analyze` + `flutter test test/views/`. Commit: `feat(views): add StationScope and station.loc/person token chips`.

### Commit 2. Picker offers station tokens

Extend the insertion menu so, in station and roleplay fields, it offers `station.loc.*` and `station.person.*` (with their facets) alongside `var.*` and plan-fields, each with a value/label preview. Ensure the RolePlay editor's markdown fields (`behavior`, `background`, `propsMd`) are token-aware with the linked station's `StationScope`, so these tokens resolve there too.

Files: the menu widget, `roleplay_form_screen.dart` (field wiring), `station_form_screen.dart` if needed. `flutter analyze` + `flutter test test/views/`. Commit: `feat(views): offer station locations and persons in the token picker`.

### Commit 3. RolePlay editor person binding

In `RolePlayFormScreen`: add a **person** selector (`personRef`) over the linked station's `persons` (required for new/edited roleplays). Present the identity fields — `name`, `age`, `gender` (new, `roleGender`), `signalement` — as inherit-or-override: a field tracking the Person shows its value and stays in sync; a different value is an override; on disk each field holds the effective value (ADR-0047). Show a small effective-identity preview. `behavior`/`background`/`propsMd` and Actor casting unchanged. The roleplay's station derives from `personRef`'s owner (keep `stationIndex` consistent).

Files: `roleplay_form_screen.dart`, ARB + localizations if strings added. `flutter analyze` + `flutter test test/views/`. Commit: `feat(views): bind RolePlay to a Person with inherit/override identity`.

### Commit 4. Inline create + write-back

Add inline creation to the picker: when the filter matches nothing, offer "Create variable «x»", "Create location «x»", "Create person «x»" (only for namespaces in scope — `station.*` needs a station). Selecting creates the entity in a working copy the editor holds (so the chip resolves live, amber until filled) and inserts the token. On save the editor returns its entity plus `PlanAdditions` (new variables → `Program`; new locations/persons → the target station). Update the callers (`openFormSurface` sites for exercise/station/roleplay editors) to apply the entity change and the additions to the plan atomically. This makes `var.*` inline create work in every sub-editor — the DESIGN-008 un-defer — via the same payload.

Files: the menu widget, the editor forms (`exercise_form_screen.dart`, `station_form_screen.dart`, `roleplay_form_screen.dart`) and their call sites, a small `PlanAdditions` typedef. `flutter analyze` + `flutter test test/views/`. Commit: `feat(views): inline-create variables, locations and persons with plan write-back`.

### Commit 5. Tests

Widget/unit tests under `test/views/`:

* `station.loc`/`station.person` chips render blue (known), red (unknown-in-scope), amber (empty) via the controller + `StationScope`.
* The picker offers station tokens in a station field and a roleplay field; selecting inserts the token.
* RolePlay editor: selecting a `personRef` shows inherited identity; typing a different value makes an override; save writes the effective value; the effective preview matches.
* Inline create: "Create person «x»" adds a person to the (working) station and inserts the token (amber until filled); "Create variable «x»" from an exercise/station/roleplay editor returns it in `PlanAdditions` and the caller adds it to `Program`.
* Round-trip: saving an editor applies both its entity and the `PlanAdditions` to the plan.

`flutter analyze`, `flutter test test/views/`, then the single final gate: full `flutter test` + `dart build cli`.

Files: test files under `test/views/`. Commit: `test(views): cover station tokens, person binding and inline create/write-back`.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures.
2. `make i18n` idempotent; `dart build cli` succeeds.
3. Manual smoke: in a station md field and a roleplay field, `/` offers `station.loc/person` and `var`; unknown slugs show red, known blue; inline "Create …" adds the entity and resolves the chip; the RolePlay editor binds a Person with inherit/override and an effective preview; creating a variable from the Exercise or Station editor persists it to the plan on save.
4. `git diff --stat` touches `lib/views/…`, `lib/utils/…`, `lib/l10n/…`, `test/…` — no model-shape or `lib/services/` changes.
5. Clean tree; localizations committed with ARB changes.

## Deliverables

Conventional Commits (English) on `design-009`, clean tree, targeted tests per commit, one full-suite gate at the end (rule 9). The final commit body notes: station tokens are chipped and offered; the RolePlay editor binds a Person with inherit/override effective identity; inline create + `PlanAdditions` write-back works for variables, locations and persons and un-defers DESIGN-008's sub-editor variable creation; and that save-blocking + rename/delete integrity + re-link are prompt 5.

ADR-0047 and DESIGN-009 are authoritative. The one thing to exercise judgment on is the write-back plumbing through `openFormSurface`; keep it a named record and apply atomically at the plan owner. If it ripples wider than the editor call sites, stop and report. No new ADR for this prompt.
