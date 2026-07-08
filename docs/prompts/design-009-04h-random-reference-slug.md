# Implement DESIGN-009 — Prompt 4h: random reference slugs

You are working in the RingDrill repository, on `design-009`. A small, **views + util + test** follow-up that changes how a scenario reference (`slug`) is generated. Today `generateSlug` derives the slug from the display name/label ("Anne Glemsk" → `anne_glemsk`). A slug derived from any editable field feels wrong the moment that field changes — the slug is frozen at creation, so it drifts out of sync with the name. Switch to a short **random** id, derived from nothing, for both `Location` and `Person`. [ADR-0047](../adrs/0047-scenario-locations-and-persons.md) and `docs/design/009-scenario-locations-and-persons.md` (Concepts, Behavior, Deferred — all updated for this) are authoritative. Read `AGENTS.md` rule 9.

**No model change, no schema bump.** The `slug` field, its `^[a-z][a-z0-9_]*$` rule, and the wire format are unchanged — only how the value is generated at creation. Existing locations/persons keep their current (name-derived) slugs; nothing migrates. This is why the reference can never drift and why reference rename is unnecessary (ADR-0047).

## Behavior

* A new reference is a short random id: **~6 characters from `[a-z0-9]`, first character a letter** so it satisfies `^[a-z][a-z0-9_]*$`. Unique within the station — retry (generate again) on collision via the existing `isTaken` callback. It is **not** derived from the name, label, kind or any other field.
* Reuse the `nanoid` package (already a dependency, `^1.0.0`) with a lowercase-alphanumeric custom alphabet; guarantee the letter-first rule (e.g. one letter from `[a-z]` plus the rest from `[a-z0-9]`, or regenerate until it matches).
* The UI is unaffected: the reference is still hidden ("Referanse"), the picker shows names, and every existing `{{station.loc/person.<slug>}}` keeps resolving.

## Ground rules

* Replace the name-derivation in `lib/utils/slug.dart`. The function no longer needs the input text — introduce `randomSlug(bool Function(String candidate) isTaken)` (drop the `input` parameter and the ASCII-folding / slugify logic), and update every call site to stop passing the display text. Keep it pure and Flutter-free.
* Call sites (all pass only `isTaken` now): `lib/views/person_form_screen.dart`, `lib/views/location_form_screen.dart`, `lib/views/station_form_screen.dart` (the two inline creators), `lib/views/roleplay_form_screen.dart` (auto-creating a `Person` for `personRef`).
* Views + util + test only. No model, renderer, or ARB change. No change to the `slug` rule or the `.drill` format.
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + targeted tests (`flutter test test/utils/ test/views/`); full `flutter test` + `dart build cli` **once at the end**.

## Scope

Two commits.

### Commit 1. Random generator + call sites + unit test

Replace `generateSlug` with `randomSlug(isTaken)` in `slug.dart`; update the four call-site files to drop the display-text argument. Rewrite `test/utils/slug_test.dart`: assert the result matches `^[a-z][a-z0-9_]*$`, that repeated calls against an accumulating `isTaken` set are all distinct, and that a collision forces a fresh value (not a `_2` suffix). Remove the old name-derivation assertions.

Files: `lib/utils/slug.dart`, the four call sites, `test/utils/slug_test.dart`. `flutter analyze` + `flutter test test/utils/`. Commit: `refactor: generate random reference slugs instead of deriving from the name`.

### Commit 2. Fix view tests that assumed derivation

The DESIGN-009 follow-up 3b widget tests assert a reference "auto-generated from the name" and that "two same-named entries get distinct references". Update those to the new contract: adding a location/person yields a valid (`^[a-z][a-z0-9_]*$`), unique reference that is **not** derived from the name; editing the display name still leaves the reference unchanged. Do not assert a specific random value.

Files: the relevant `test/views/` files. `flutter analyze` + `flutter test test/views/`, then the single final gate: full `flutter test` + `dart build cli`.

Commit: `test(views): assert random, non-derived references`.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures.
2. `dart build cli` succeeds. (`make i18n` not needed — no ARB change.)
3. Manual smoke: creating a location/person gives an opaque reference (e.g. `k3f9x2`), not a name-derived one; the picker still shows the display name and inserts a working `{{station.loc/person.<slug>}}`; editing the name never changes the reference; existing plans load with their old slugs intact and still resolve.
4. `git diff --stat` touches `lib/utils/…`, `lib/views/…`, `test/…` only. No model, renderer, ARB, or schema change.
5. Clean tree.

## Deliverables

Conventional Commits (English) on `design-009`, clean tree, targeted tests per commit, one full-suite gate at the end (rule 9). The final commit body notes references are now short random ids generated at creation (via `nanoid`, letter-first, unique per station), derived from no field, so a reference never drifts and rename is unnecessary; existing slugs are untouched and the format is unchanged.

ADR-0047 and DESIGN-009 are authoritative. Renaming the `homeSlug`/`.home` facet, the person scenario-role field, and the preview/rollup work are all out of scope. If dropping the `input` parameter ripples beyond the four call sites, stop and report.
