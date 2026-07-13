# Implement DESIGN-010 stage 4: token-aware scenario leaf fields (DESIGN-009 4e)

You are working in the RingDrill repository, on `design-010`. The final DESIGN-010 stage: make the scenario **leaf fields** token-aware, on top of the scope cascade that stages 1–3 already put in place. References: `docs/design/010-inline-preview-and-resolve-scope.md` (§"DESIGN-009 leaf fields (follow-up 4e) as a consumer", stage 4) and `docs/design/009-scenario-locations-and-persons.md` (§"Leaf fields are token hosts too", §"Self-reference rule"). Read `AGENTS.md` (esp. rules 9 and 12 — docs in English, i18n).

**No model, renderer, or schema change.** This is pure field wiring: the scopes, resolver and `openFormSurface` re-provision already exist. No new brief output; a token injected through a leaf value is caught by the next pass of the existing fixpoint (`_resolveField`, `_maxResolvePasses`).

## What becomes token-aware

Five leaf free-text fields:

* **`Location`** (`location_form_screen.dart`): `place` and `note`.
* **`Person`** (`person_form_screen.dart`): `name`, `signalement`, `notes`.

Both forms open through `openFormSurface` (from `station_screen.dart` / `roleplay_form_screen.dart`), so `PlanScope` **and** `StationScope` are already re-provided in their subtree (stage 1). No scope plumbing is needed here — only the field wiring.

## The wiring (mirror the existing token-aware fields)

For each of the five fields, swap the plain `TextFormField` for the token-aware `RingDrillTextField` / `RingDrillTextArea` exactly as the station/roleplay editors already do:

* `tokenAware: true`, backed by a `TokenTextEditingController` (chip rendering + the insertion menu).
* Feed the picker from the ambient scopes: plan variables (`var.*`) from `PlanScope`, and `station.loc.*` / `station.person.*` from `StationScope`. These come through the same `planFields` / `stationLocations` / `stationPersons` the other editors pass.
* **Red unresolved token blocks save** (ADR-0047): reuse the same validator the other token-aware fields use, so an unknown slug renders as a red token and prevents saving.
* **Preview:** if the form uses the section-navigated chrome with the per-section eye, wire the preview toggle for the token-aware section as elsewhere; if these forms are plain (no section chrome), the chip rendering + insertion menu are enough — do not add section chrome just for this.

## The self-reference rule (DESIGN-009)

A field never offers a token that reads **the same free-text field it is editing**, because that value contains the token being typed and would recurse through the fixpoint. Applied per field — the caller withholds the self token from the lists it passes to that field (the same way the roleplay `name`/`signalement` fields already withhold their own facets, 4d):

* `Location.place` field: withhold this location's own `station.loc.<self>.place` **and** the bare `station.loc.<self>` default (which embeds place + utm). Its short/derived facets (`label`, `utm`, `kind`) stay offered.
* `Location.note` field: withhold `station.loc.<self>.note` (and the bare default if it embeds the note).
* `Person.name` field: withhold `station.person.<self>.name` and the bare `station.person.<self>` default (name). Short facets (`age`, `gender`, `loc.*`) stay.
* `Person.signalement` field: withhold `station.person.<self>.signalement`.
* `Person.notes` field: withhold `station.person.<self>.notes`.

A field may freely reference **other** locations/persons and variables — only the self field's own token is withheld.

## Inline create from a leaf field

A leaf field may want to create a `var.*` (→ owned by `Program`) or, for a person field, a `station.loc.*` (→ owned by the linked station). Wire the picker's create hooks (`onCreateVariable` / `onCreateLocation`) consistent with the sibling editors, routing new entities through the existing `PlanAdditions` write-back payload (ADR-0047). **If** a leaf form's result type does not already carry a write-back payload (e.g. `LocationFormScreen` currently returns a bare `Location`), either extend it minimally following the ADR-0047 named-record pattern, **or** — if that turns out non-trivial — offer only existing-entity references from the leaf fields for now and note the create-from-leaf deferral. Reference-existing + self-reference is the non-negotiable core; create-from-leaf is the judgment call.

## Scope — four commits

### Commit 1. Location leaf fields token-aware

`location_form_screen.dart`: `place` + `note` become token-aware with the self-reference withholding above.

Commit: `feat(views): token-aware place and note on the location form`.

### Commit 2. Person leaf fields token-aware

`person_form_screen.dart`: `name` + `signalement` + `notes` become token-aware with self-reference withholding.

Commit: `feat(views): token-aware name, signalement and notes on the person form`.

### Commit 3. Tests

* Each leaf field renders `{{…}}` as a chip and offers the picker; a `var.*` and a cross-`station.loc/person.*` token resolve in preview (or in a `resolveScopedField` check if the form has no preview).
* The self token is **not** offered on its own field (e.g. the person name field's menu excludes `station.person.<self>.name`) but other entities' tokens are.
* An unknown slug is a red token that blocks save.
* A token entered in a leaf value resolves in the brief/`RingDrillText` (fixpoint catches it) — no renderer change needed.

`flutter analyze`, `flutter test test/views/`, then the single final gate: full `flutter test` + `dart build cli`.

Commit: `test(views): cover token-aware leaf fields and the self-reference rule`.

### Commit 4. Close out DESIGN-010

Flip the statuses now that the arc is complete: `docs/adrs/0048-flutter-free-field-resolver.md` and `docs/design/010-inline-preview-and-resolve-scope.md` → **Accepted**; note DESIGN-009 4e as delivered in the DESIGN-009 doc's implementation notes. Docs only.

Commit: `docs(design): mark DESIGN-010 and ADR-0048 accepted (stage 4 landed)`.

## Ground rules

* Views + docs + test only. No model/renderer/schema/ARB change beyond any picker string already covered (reuse existing token strings; if a new string is genuinely needed, add it to `app_en.arb` + `app_nb.arb` and run `make i18n`, both languages kept equivalent).
* Self-reference is per field — withhold only the self field's own token, keep everything else offered.
* Behaviour-preserving otherwise: these forms are unchanged except the five fields gaining chips/menu/preview.
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + `flutter test test/views/`; full `flutter test` + `dart build cli` **once at the end**.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures.
2. `dart build cli` succeeds.
3. Manual smoke: in a location form, type `{{` in `place` → the picker offers variables and other locations/persons but **not** this location's own place; insert a `{{var.*}}`, save, open the brief → it resolves. Same for a person's `name`/`signalement`/`notes`. An unknown slug shows red and blocks save.
4. `git diff --stat` touches `lib/views/…`, `docs/…`, `test/…` (and `lib/l10n/…` only if a new string was unavoidable).
5. Clean tree.

## Deliverables

Conventional Commits (English) on `design-010`, clean tree, targeted tests per commit, one full-suite gate at the end (rule 9). On landing, DESIGN-010 is complete and Accepted (stages 1–4), ADR-0048 Accepted, and DESIGN-009 4e delivered. Flag the one open judgment call (create-from-leaf write-back) rather than expanding scope silently.
