# Implement DESIGN-009 — Prompt 5 (stage 6): reference integrity

You are working in the RingDrill repository, on `design-009`. This is the **integrity** stage: keep `station.loc.*` / `station.person.*` references honest. Today an author can save a field with an unresolved scenario token, or delete a location/person that is still referenced, leaving a dangling reference that renders as the brief's placeholder. Close that. [ADR-0047](../adrs/0047-scenario-locations-and-persons.md) and `docs/design/009-scenario-locations-and-persons.md` ("Behavior") are authoritative. Read `AGENTS.md` rule 9.

This is the last DESIGN-009 stage before QA. It mirrors the existing `{{var.<name>}}` save-block (ADR-0046) for the scenario namespace.

**Scope note.** A reference (`slug`) is a short random, opaque id, derived from no field, so it never drifts and **there is no rename** — nothing needs rewriting across references (ADR-0047). This stage is therefore: (1) save-blocking on unresolved `station.*` tokens, (2) a delete-guard over the station-and-down set, and (3) re-link handling when a roleplay's `personRef` changes.

## What already exists

* `lib/utils/station_scenario_tokens.dart` — `stationScenarioTokenPattern` (group 1 `loc`/`person`, group 2 slug, group 3 facet path) and `stationScenarioTokenFacets`. Use this to find and classify scenario tokens in a field, exactly as `planVariableTokenPattern` is used for `{{var.*}}`.
* The `{{var.*}}` save-block to mirror: `StationFormScreen._sectionsWithUndeclaredTokens` / `_baseFieldLabelsWithUndeclaredTokens` / `_declaredVariableNames`, the `RolePlayFormScreen` equivalents, and the `programSaveBlockedUndeclaredVariable` snackbar.
* `StationScope` already carries the station's (or the roleplay's linked station's) `locations`/`persons`, so "which slugs resolve" is available in both editors.

A token is **unresolved** when its slug is not among the station's `locations` (for `loc`) or `persons` (for `person`). Facet paths do not need validation — the renderer's facet switch has a default fallback, and the editor's red-chip logic keys on the slug. Keep this stage slug-level.

## Scope

Three commits.

### Commit 1. Save-block on unresolved `station.*` tokens

Extend the save-block in `StationFormScreen` and `RolePlayFormScreen`: in addition to the existing undeclared-`{{var.*}}` check, scan every token-aware field with `stationScenarioTokenPattern` and flag any whose slug is absent from the working `locations`/`persons` (station editor: its own working lists; roleplay editor: the linked station's, via the same source `StationScope` uses). Block save and list the offending fields/sections, reusing the existing offending-labels plumbing. Add an ARB message parallel to `programSaveBlockedUndeclaredVariable` (e.g. `saveBlockedUnresolvedReference`) naming the broken reference(s). `make i18n`.

Files: `lib/views/station_form_screen.dart`, `lib/views/roleplay_form_screen.dart`, `lib/l10n/*.arb` + regenerated localizations. `flutter analyze` + `flutter test test/views/`. Commit: `feat(views): block save on unresolved station scenario references`.

### Commit 2. Delete-guard over the station-and-down set

In the station editor, guard deletion of a `Location`/`Person` while it is still referenced. Scan the **station-and-down set**:

* the station's own token-aware fields (name, description, the markdown sections),
* every `Person.homeSlug` (a location is referenced by a person's home),
* and the station's linked **roleplays** — their token-aware fields and, for a person, any `RolePlay.personRef` pointing at it.

To cover roleplays, pass the station's linked roleplays into `StationFormScreen` (read-only, filtered by `stationIndex` at the call sites — `station_list_view.dart` / `station_screen.dart`). If threading them through is more than a small constructor addition, stop and report rather than half-doing it.

When the target is referenced, block the delete and show a dialog listing the usages (which fields / which roleplay / "is a person's home"), rather than silently removing it. When it is not referenced, delete as today. Add ARB strings for the guard dialog and usage lines; `make i18n`.

Files: `lib/views/station_form_screen.dart`, `lib/views/widgets/locations_section.dart`, `lib/views/widgets/persons_section.dart`, the two call sites, `lib/l10n/*.arb` + localizations. `flutter analyze` + `flutter test test/views/`. Commit: `feat(views): guard location/person deletion while still referenced`.

### Commit 3. Re-link handling on `personRef` change

In `RolePlayFormScreen`, when the author re-points `personRef` to a person on a **different** station, the linked station's `locations`/`persons` change, so `station.*` tokens already in the roleplay's fields may no longer resolve. On the change, re-run the unresolved-reference check (commit 1) against the new linked station and surface which fields now have a broken reference — an inline warning at minimum, and save stays blocked by commit 1 until resolved. Do not auto-rewrite or auto-clear the author's text.

Files: `lib/views/roleplay_form_screen.dart`, ARB if a new string is needed. `flutter analyze` + `flutter test test/views/`. Commit: `feat(views): flag broken scenario references when a roleplay is re-linked`.

### Tests (fold into each commit's targeted run; final gate once)

* Save-block: a station/roleplay field with `{{station.loc.ghost}}` (no such location) blocks save and names the field; resolving or removing the token unblocks; a valid `{{station.person.kari}}` saves; a bare vs faceted token both key on the slug.
* Delete-guard: deleting a referenced location (from a section body, from a person's `homeSlug`, or from a roleplay field) is blocked with the usages listed; an unreferenced location deletes; same for a person (including one a roleplay `personRef` portrays).
* Re-link: re-pointing `personRef` to another station's person flags a now-unresolved `{{station.loc.*}}` in a roleplay field and keeps save blocked; re-pointing back clears it.

`flutter analyze`, `flutter test test/views/`, then the single final gate: full `flutter test` + `dart build cli`.

## Ground rules

* Reuse `stationScenarioTokenPattern` and the existing offending-labels / snackbar plumbing; do not invent a second scanner.
* Views + l10n only. No model change, no `brief_renderer.dart` change, no schema bump. The renderer already shows the placeholder for a broken reference; this stage stops the author from creating one, it does not change rendering.
* **No rename-rewrite** — not applicable (the slug is a random opaque id, never renamed), as above.
* User-visible strings via ARB, then `make i18n`.
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + `flutter test test/views/`; `make i18n` only on ARB change; full `flutter test` + `dart build cli` **once at the end**.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures.
2. `make i18n` idempotent; `dart build cli` succeeds.
3. Manual smoke: typing `{{station.loc.ghost}}` in a post/roleplay field blocks save with a clear message; deleting a location used by a section, a person's home, or a roleplay is blocked with the usages listed; deleting an unused one works; re-linking a roleplay to another station surfaces any now-broken reference and keeps save blocked until fixed.
4. `git diff --stat` touches `lib/views/…`, `lib/l10n/…`, `test/…` only. No model, renderer, or schema change.
5. Clean tree; localizations committed with ARB changes.

## Deliverables

Conventional Commits (English) on `design-009`, clean tree, targeted tests per commit, one full-suite gate at the end (rule 9). The final commit body notes that unresolved `station.*` references are now blocked at save, referenced locations/persons cannot be deleted from the station-and-down set, and re-linking a roleplay flags broken references — reusing the `{{var.*}}` save-block pattern, no rename-rewrite (the slug is a random opaque id, never renamed), no model or schema change.

ADR-0047 and DESIGN-009 are authoritative. DESIGN-009 leaf-field token-awareness (old 4e) is **DESIGN-010 stage 5**, and the preview/rollup are DESIGN-010 — both out of scope here. If the delete-guard's roleplay coverage needs more than passing the linked roleplays into the station editor, stop and report.
