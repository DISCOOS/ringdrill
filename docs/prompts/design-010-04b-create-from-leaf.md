# Implement DESIGN-010 follow-up: inline create from leaf fields

You are working in the RingDrill repository, on `design-010`. Completes the one item stage 4 (`design-010-04-leaf-fields.md`) deferred: **inline entity creation** from the scenario leaf fields. Stage 4 made `Location.place`/`note` and `Person.name`/`signalement`/`notes` token-aware for *referencing existing* variables/locations/persons; this adds the picker's "Create «x»" path from inside those fields. References: `docs/design/009-scenario-locations-and-persons.md` §"Inline creation and write-back", ADR-0047. Read `AGENTS.md` rule 9.

DESIGN-010 is already Accepted — this is a deferred convenience, not a status change. No renderer/schema change.

## What's missing today

The leaf token fields don't wire `onCreateVariable` / `onCreateLocation` / `onCreatePerson`, so the picker hides its "Create «x»" entries there. An author must create the variable/location/person first (in the plan or station editor) and only then reference it from a leaf field. Every other token editor (station, roleplay, exercise, program) already offers inline create; the leaf fields should too.

## The mechanism (established pattern — follow it)

Per DESIGN-009 §"Inline creation and write-back" (ADR-0047): an editor that hosts token fields resolves newly-created entities against a **working copy it holds** (so the inserted chip resolves immediately), and on save returns — besides its own entity — a **`PlanAdditions`-shaped write-back payload** of entities targeting owners it does not itself hold. The `openFormSurface` call site that owns the plan applies the entity change and the additions together in one save. It is a Dart 3 named record (e.g. `({Location location, PlanAdditions additions})`), not a bespoke class. This is exactly what the station and roleplay editors already do; mirror it.

Owners:

* `var.*` → `Program.variables`.
* `station.loc.*` / `station.person.*` → the **station that owns the leaf entity** (the station whose locations/persons list the new one joins — the call site knows it).

The self-reference rule from stage 4 is unchanged; create entries are subject to the same scope availability (a `var.*` create needs a `PlanScope`; `station.loc/person` create needs a `StationScope`, both already re-provided across `openFormSurface`).

## Scope — four commits

### Commit 1. `LocationFormScreen` returns a write-back result

`location_form_screen.dart`: change the return from a bare `Location` to a named record `({Location location, PlanAdditions additions})` (or the file's existing result idiom). Hold a working copy so an inline-created entity resolves in the field's chips immediately; wire the create hooks the location fields can use (`onCreateVariable`; `onCreateLocation`/`onCreatePerson` where a `StationScope` is present), recording each into the pending `PlanAdditions`.

Commit: `feat(views): inline-create write-back from the location form's token fields`.

### Commit 2. `PersonFormScreen` carries `PlanAdditions`

`person_form_screen.dart`: extend `PersonFormResult` to carry a `PlanAdditions` payload (fold the existing `newLocation` into it, or carry it alongside), and wire `onCreateVariable`/`onCreateLocation`/`onCreatePerson` on `name`/`signalement`/`notes`.

Commit: `feat(views): inline-create write-back from the person form's token fields`.

### Commit 3. Apply the write-back at every call site

Update the `openFormSurface` call sites that open these two forms to apply the returned `PlanAdditions` to the owners (new `var.*` → active `Program`, new `station.loc/person.*` → the target station), reusing the existing apply helper (e.g. `applyVariableAdditionsToActiveProgram` / the `PlanAdditions` apply path). Call sites include `station_screen.dart` (`_addLocation`/`_addPerson`), `roleplay_screen.dart` (its person picker), `station_form_screen.dart`'s Locations/Persons sections, and `persons_section.dart`'s `_openForm` (`PersonsSection.onSave` may need to forward the additions to the plan-owning caller).

Commit: `feat(views): apply inline-create additions when a leaf form returns`.

### Commit 4. Tests

* From a location field, typing `{{var.<new>}}` offers "Create «…»"; choosing it inserts the token, and on save the new variable is applied to the program (and resolves).
* Same for a person field creating a `var.*` and a `station.loc.*` (the location lands on the target station).
* Referencing an existing entity and the self-reference rule are unaffected (no regression to stage 4).

`flutter analyze`, `flutter test test/views/`, then the single final gate: full `flutter test` + `dart build cli`.

Commit: `test(views): cover inline create-from-leaf write-back`.

## Ground rules

* Views + test only; reuse existing "Create «x»" ARB strings (no new strings — the other editors already have them). If one is genuinely missing, add to both `app_en.arb`/`app_nb.arb` and run `make i18n`.
* Follow the existing `PlanAdditions` named-record write-back pattern; don't invent a parallel mechanism.
* Behaviour-preserving for reference-existing + the self-reference rule (stage 4).
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + `flutter test test/views/`; full `flutter test` + `dart build cli` **once at the end**.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures (main's pre-existing failures aside).
2. `dart build cli` succeeds.
3. Manual smoke: in a location's `place` and a person's `name`, type `{{var.` + a new name → "Create «…»" appears; pick it, save → the variable exists in the plan and the token resolves. In a person field, create a `{{station.loc.…}}` → the new location lands on that person's station.
4. `git diff --stat` touches `lib/views/…`, `test/…` (and `lib/l10n/…` only if a string was unavoidable).
5. Clean tree.

## Deliverables

Conventional Commits (English) on `design-010`, clean tree, targeted tests per commit, one full-suite gate at the end (rule 9). Inline create works from the leaf fields via the standard `PlanAdditions` write-back; reference-existing and the self-reference rule are unchanged. This closes the create-from-leaf item DESIGN-010 stage 4 deferred.
