# Implement DESIGN-009 — Prompt 2: resolution

You are working in the RingDrill repository, on the `design-009` branch. Implement the renderer-resolution layer of DESIGN-009 ("Scenario locations and persons"). [ADR-0047](../adrs/0047-scenario-locations-and-persons.md) is authoritative; `docs/design/009-scenario-locations-and-persons.md` is the design. Prompt 1 (model + format) has shipped: `Location`, `Person`, `Station.locations`/`persons`, `RolePlay.personRef`/`gender` exist. Read those, and `AGENTS.md` rule 9 (test-loop discipline).

This prompt teaches `BriefRenderer` to resolve `{{station.loc.<slug>}}` and `{{station.person.<slug>}}` (with facets) inside markdown fields, at station-and-down scope, with the effective-identity rule and a visible placeholder for unknown slugs. **Reading path only** — no editor, map or integrity (prompts 3–5). It is not flag-gated (DESIGN-009 is additive and ships at merge).

## What resolves, and how

These extend the derived `station.*` context (the same place `{{station.position.utm}}` lives), scoped to the station a field belongs to — the station's own markdown fields, and the fields of a `RolePlay` on that station (`_buildStationContext` already resolves roleplay fields against the station's ref-context).

**Locations** — `{{station.loc.<slug>}}` and facets, resolved against the station's `locations`:

* `.place` — the `place` string.
* `.utm` — the formatted UTM (reuse `_formatUtm`), rendered as inline code like `station.position.utm` today; empty when no position.
* `.label` — the display `label`.
* bare `{{station.loc.<slug>}}` — a sensible default combining `place` and, when a position is set, the UTM (match how `station.position.utm` presents).

**Persons** — `{{station.person.<slug>}}` and facets, resolved against the station's `persons`:

* `.name`, `.age`, `.gender`, `.signalement`.
* `.home` (and `.home.<facet>`) — resolve the person's `homeSlug` to a `Location` on the same station, then its facets (`{{station.person.anne.home.utm}}`); bare `.home` = the location default.
* bare `{{station.person.<slug>}}` = the effective name.

**Effective identity.** A person facet resolves to the **portraying roleplay's** value when there is one and its field is non-empty, otherwise the `Person`'s own value. The portraying roleplay is the roleplay on this station whose `personRef == slug` (first, if several — v1). This makes the brief show what the marker actually plays (the denormalized effective identity from ADR-0047), falling back to the authored `Person` when nothing overrides.

**Unknown slug.** `{{station.loc.x}}` / `{{station.person.y}}` where the station has no such slug renders a visible localized placeholder (as an undeclared `{{var.x}}` does — ADR-0046), not empty and not the raw token. A slug that exists but whose facet is empty renders empty (valid state), not a placeholder.

## Ground rules

* Reuse the existing resolution pipeline. `var.*` is already substituted before the mustache pass (`substitutePlanVariables`); add `station.loc.*` / `station.person.*` to that pre-mustache substitution so unknown slugs become placeholders cleanly and the remaining `{{station.position.*}}` etc. stay on the mustache ref-context path. Do not build a second parser — one pre-pass for the registry-like tokens, mustache for the fixed derived context.
* `BriefRenderer` stays a pure function; keep it Flutter-free-compatible (it already is). Reuse `_formatUtm` and the shared `lib/utils/plan_variables.dart` helpers where they fit.
* ARB for the placeholder string (`app_en.arb`, `app_nb.arb`), then `make i18n`. Reuse `briefUnknownVariable` only if it reads correctly for a location/person; otherwise add `briefUnknownReference`.
* Names/descriptions are out of scope here — they resolve `var.*` only (DESIGN-008 follow-up 05). `station.loc/person` in a name is a later refinement; do not add it now.
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + `flutter test test/services/brief/`; run `make i18n` only in the commit that changes ARB; full `flutter test` and `dart build cli` **once at the end**.

## Scope

Two commits.

### Commit 1. Resolve station scenario tokens

In `lib/services/brief/brief_renderer.dart`, extend the pre-mustache substitution to resolve `{{station.loc.<slug>[.facet]}}` and `{{station.person.<slug>[.facet]}}` against the in-scope station (available in `_buildStationContext` for both station and roleplay fields), computing facets and the effective-identity fallback described above, and emitting the localized placeholder for an unknown slug. Add the placeholder ARB entry and run `make i18n`.

Files expected: `lib/services/brief/brief_renderer.dart` (and any small helper in `lib/utils/plan_variables.dart` if a shared substitution primitive fits), `lib/l10n/app_en.arb`, `lib/l10n/app_nb.arb`, regenerated `app_localizations*.dart`.

Per commit: `flutter analyze`; `flutter test test/services/brief/`. Commit: `feat(services): resolve station locations and persons in the brief`.

### Commit 2. Tests

Extend `test/services/brief/`:

* Location facets: `.place`, `.utm` (formatted), `.label`, and the bare default resolve from a station location.
* Person facets: `.name`/`.age`/`.gender`/`.signalement` resolve; `.home.utm` resolves through `homeSlug` to the location.
* Effective identity: a person portrayed by a roleplay whose `name` differs resolves to the roleplay's value; with no portraying roleplay (or an empty field) it falls back to the `Person`'s value.
* Scope: a roleplay field resolves `station.*` against its own station; a program/exercise field does not resolve `station.loc/person` (no station in scope).
* Unknown slug renders the placeholder, not the raw token; an existing slug with an empty facet renders empty.
* No-scenario regression: a plan with no locations/persons renders identically to before this prompt.

Run `flutter analyze`, `flutter test test/services/brief/`, then the single final gate: full `flutter test` + `dart build cli`.

Files expected: test files under `test/services/brief/`.

Commit: `test(services): cover station location/person resolution, facets and effective identity`.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures.
2. `make i18n` idempotent after commit; `dart build cli` succeeds (renderer stays Flutter-free).
3. No-scenario briefs unchanged from before (golden or manual diff).
4. `git diff --stat` touches only `lib/services/brief/…`, `lib/utils/…` (if used), `lib/l10n/…`, `test/services/brief/…`. No `lib/views/`, no model changes.
5. Clean tree; generated localizations committed with the ARB change.

## Deliverables

Conventional Commits (English) on `design-009`, clean tree, targeted tests per commit and one full-suite gate at the end (rule 9). The final commit body notes the renderer now resolves `station.loc.*` / `station.person.*` with facets and effective identity, reading-path only, and defers the editor sections + map (prompt 3), the token picker + RolePlay editor + inline-create/write-back (prompt 4) and integrity (prompt 5).

ADR-0047 and DESIGN-009 are authoritative. If the pre-mustache-vs-mustache split for `station.*` tokens causes a real problem (e.g. a field mixing `station.loc.x` and `station.position.utm`), resolve it so both render and note the approach; if it needs a larger change, stop and ask. No new ADR for this prompt.
