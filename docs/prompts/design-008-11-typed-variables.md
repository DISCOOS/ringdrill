# Implement DESIGN-008 — Follow-up 11: typed plan variables

You are working in the RingDrill repository. This lifts DESIGN-008's non-goal #4 / deferred decision #2: plan variables gain a **type** that drives a type-aware input with validation and formatting, and a canonical stored value. [`docs/design/008-plan-variables-and-section-navigated-editor.md`](../design/008-plan-variables-and-section-navigated-editor.md) ("Follow-up 11 — Typed variables") and [ADR-0046](../adrs/0046-plan-variables.md) are authoritative. Read `AGENTS.md` rule 9.

**Visual reference:** `docs/design/mockups/typed-variables.html` (declaration with a type per variable, the type picker, and the type-specific value inputs) and `docs/design/mockups/variable-overrides.html` (the override surface, default value shown in parentheses).

**Scope of change.** Model + views + resolver, all **additive** (no schema bump, `KNOWN_SCHEMA_MAX` unchanged): `DrillVariable.type` defaults to `string`, so every existing variable loads and renders exactly as today.

## The types

Six types in v1:

* **string** — free text, the default, no validation.
* **number** — integer or decimal; numeric validation; rendered with the plan's number formatting where one applies.
* **time** — 24-hour `HH:MM`; a time picker; stored normalized; rendered `HH:MM`.
* **date** — a date picker; stored ISO (`yyyy-MM-dd`); rendered as a localized date.
* **duration** — a span entered and stored as **minutes** (an integer); rendered `"45 min"` / `"1 t 30 min"`.
* **location** — a place with a coordinate: the geo shape of a `Location` (DESIGN-009) **minus `kind`**. The input accepts a decimal lat/lng **or** a UTM string (typed or pasted), offers the map picker and address geocoding, and stores the canonical `LatLng` plus the place text. It exposes the same facets as a `Location`: `.place`, `.utm`, `.latlng`; the bare token renders place + UTM.

Scalar types render **bare** (no facets in v1). Only `location` is faceted — reuse the existing Location coordinate parsing, UTM formatting, geocoding (`osm_nominatim`) and map picker rather than reimplementing any of it.

## Behaviour

* The type is declared once on the **plan** declaration surface (a type chip/picker per variable; the default-value field renders type-aware). The **exercise/station override** surfaces render the same type-aware input for the local value, with the inherited default shown in parentheses after the name (per `variable-overrides.html`), formatted for its type — a time as `12:00`, a location as its UTM.
* Slash-menu previews and the brief format the value the same way (canonical → formatted).
* An **invalid value blocks save**, exactly as an unknown token does (ADR-0046) — surface it inline on the offending field.
* Inline-created variables default to `string`; the type is changed afterward on the declaration.
* Changing a variable's type revalidates its default and any overrides; an incompatible existing value surfaces as invalid rather than being silently dropped.

## Ground rules

* **Both languages, conceptually equivalent** (see the i18n rule): every added string gets an `nb` and an `en` entry meaning the same idiomatically, then `make i18n`. Type-label pairs (nb / en): "Tekst" / "Text", "Tall" / "Number", "Tid" / "Time", "Dato" / "Date", "Varighet" / "Duration", "Lokasjon" / "Location". Validation messages likewise in both.
* Reuse the DESIGN-009 Location machinery for `location` (coordinate parse of lat/lng and UTM, `PositionFormField` / map picker, `osm_nominatim` geocode, the `.place`/`.utm`/`.latlng` facet resolution in `station_scenario_tokens.dart` / `brief_renderer.dart`). Do not fork it.
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + the relevant `flutter test` subset; `make build` only on the model commit; `make i18n` only on ARB change; full `flutter test` + `dart build cli` **once at the end**.

## The one model decision

Scalar values stay the ADR-0046 string `value`, canonically encoded per type (number as a decimal string, time as `HH:MM`, date as ISO, duration as an integer-minutes string). **`location` carries more than a scalar** (place text + coordinate). The recommendation is a small **structured location sub-value** on `DrillVariable` — additive, `@Default` empty (e.g. an optional `LatLng` plus a place string) — kept alongside the string `value` and used only when `type == location`. This is a model shape decision that may warrant an **ADR-0046 amendment**. **If honouring the location value needs anything beyond an additive `@Default` field (i.e. a schema bump or a non-additive change), stop and report before proceeding.**

## Scope

Four commits.

1. **Model.** Add `VariableType` (enum: `string`, `number`, `time`, `date`, `duration`, `location`; unknown → `string`) and `DrillVariable.type` (`@Default(VariableType.string)`); add the additive structured location value. `make build`; extend the content hash; `DrillFile` read/write round-trip. No schema-max change. Commit: `feat(model): add a type and location value to plan variables`.
2. **Typed inputs + validation.** Declaration surface: type picker per variable, type-aware default-value field. Override surface: type-aware local-value field, inherited default in parentheses. Location input reuses `PositionFormField`/map picker + geocode + lat-lng/UTM parse. Save blocks on an invalid value. ARB (type labels + validation messages), `make i18n`. Commit: `feat(views): render type-aware variable inputs with validation`.
3. **Formatting + location facets in resolution.** The field resolver / `BriefRenderer` formats each type canonically for display (parentheses default, slash preview, brief), and resolves `location` facets `.place`/`.utm`/`.latlng` (bare = place + UTM) through the shared Location facet code. Commit: `feat(brief): format typed variables and resolve location facets`.
4. **Tests.** Commit: `test: cover variable types, validation, formatting and location facets`.

### Tests

* **Model round-trip.** Each type persists and reloads; a legacy variable with no `type` loads as `string`; the location value round-trips place + coordinate.
* **Validation.** A non-numeric `number`, a malformed `time`/`date`, and an unparseable `location` each block save with an inline message; a valid value saves.
* **Location input.** A decimal lat/lng and a UTM string both parse to the same `LatLng`; the map picker and address geocode fill it; `.place`/`.utm`/`.latlng` resolve and the bare token renders place + UTM.
* **Formatting.** A time renders `12:00`, a date localized, a duration `"1 t 30 min"`, a number per the plan format; the parenthesized inherited default is formatted per type.
* **Back-compat.** An existing plan with string variables renders unchanged.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures.
2. `make build` / `make i18n` idempotent; `dart build cli` succeeds.
3. Manual smoke against `typed-variables.html`: declare a `location` variable by pasting a UTM string, reference `{{var.x.utm}}` and `{{var.x}}` in a brief field, confirm both resolve; set a `time` variable and confirm the picker + `HH:MM` render; override a typed variable at station scope and see the parenthesized default formatted per type.
4. `git diff --stat` touches models, `lib/views/…`, the brief/resolver, `lib/l10n/…`, and tests; no schema-max change.
5. Clean tree; generated files committed with their sources.

## Deliverables

Conventional Commits (English), clean tree, targeted tests per commit, one full-suite gate at the end (rule 9). The final commit body records that plan variables are now typed (string/number/time/date/duration/location), with type-aware inputs, validation that blocks save, per-type formatting, and location facets reusing the DESIGN-009 machinery, all additive with `string` as the back-compatible default.

DESIGN-008 Follow-up 11 and ADR-0046 are authoritative. If the location value cannot be carried as an additive `@Default` field without a schema bump, stop and report rather than bumping the schema in this prompt.
