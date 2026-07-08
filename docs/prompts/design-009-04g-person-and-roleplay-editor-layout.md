# Implement DESIGN-009 — Prompt 4g: Person and RolePlay editor layout polish

You are working in the RingDrill repository, on `design-009`. A small, **views + l10n** follow-up that fixes a few awkward layout choices in the Person editor and the RolePlay ("Ny markørordre") editor, and relabels one field. [ADR-0047](../adrs/0047-scenario-locations-and-persons.md) and `docs/design/009-scenario-locations-and-persons.md` are authoritative. Read `AGENTS.md` rule 9.

**Visual reference:** `docs/design/mockups/scenario-location-person-editor.html` (phone 3 shows the updated Person form).

**No model change, no schema bump.** Field order and one label only. The `homeSlug` field and the `.home` facet keep their internal names; this changes only the nb UI label.

## Changes

### Person editor (`person_form_screen.dart`)

Today: `Navn` full width, then `Alder` + `Kjønn` share a row (an age number paired with a gender control reads oddly). Change to:

* **`Navn` (flex) + `Alder` (narrow, ~84px) on one row** — same pairing the RolePlay editor already uses.
* **`Kjønn` (the segmented control) on its own row** beneath.
* `Signalement` as today.
* The home picker's label changes from **"Bopel" to "Lokasjon"** (nb). It is a person's single associated location, not necessarily a residence, so the generic term reads better. Keep the inline "+ Ny lokasjon" affordance. Internal `homeSlug` / the `.home` facet are unchanged.
* `Notater` as today.

### RolePlay editor / "Ny markørordre" (`roleplay_form_screen.dart`)

Today the Post selector sits in the middle, and the identity fields are split around it. Reorder the default section to:

1. **Post** selector (top) — it is the most structural choice (which post the marker is on).
2. **Navn + Alder** on one row (the effective identity, inherited).
3. **Person** selector + **Kjønn** (segmented) on one row.
4. **Signalement**.
5. **Posisjon** (the existing `PositionFormField` row variant — unchanged).

Drop the explicit **"Effektiv identitet:"** heading: with the identity fields now interleaved with the selectors, the per-field "Arvet fra person" hints carry the inherit/override meaning on their own. Keep those hints.

`behavior`, `background`, `propsMd` and the Actor casting are unchanged.

## Ground rules

* Reuse the existing widgets (the segmented gender control, `PositionFormField`, the Post/Person dropdowns, `RingDrillTextField`/`Area`); this is layout reordering and one label, not new components.
* On a narrow width, if `Person` (a dropdown) + `Kjønn` (a 3-segment control) is too tight on one row, let them wrap gracefully rather than overflow — the intent is one row where it fits.
* The "Bopel" → "Lokasjon" change is a label swap in ARB (nb). Reuse an existing "Lokasjon"/location string if one already fits; otherwise add/adjust. `make i18n`.
* Views + l10n only. No model, renderer, or schema change. No change to `homeSlug` or the `.home` facet.
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + `flutter test test/views/`; `make i18n` only on ARB change; full `flutter test` + `dart build cli` **once at the end**.

## Scope

Two commits.

### Commit 1. Person editor layout + "Lokasjon" label

`Navn` + `Alder` on one row, `Kjønn` on its own row, relabel the home picker to "Lokasjon". Update ARB; `make i18n`.

Files: `lib/views/person_form_screen.dart`, `lib/l10n/*.arb` + regenerated localizations. `flutter analyze` + `flutter test test/views/`. Commit: `feat(views): pair name+age and relabel the person location field`.

### Commit 2. RolePlay editor reorder

Reorder the default section to Post → Navn+Alder → Person+Kjønn → Signalement → Posisjon; drop the "Effektiv identitet:" heading, keep the per-field "Arvet fra person" hints.

Files: `lib/views/roleplay_form_screen.dart`. `flutter analyze` + `flutter test test/views/`. Commit: `feat(views): reorder the roleplay editor with post first and paired rows`.

### Tests (fold into each commit's run; final gate once)

* Person editor: name and age render on one row; the gender segmented control is on its own row; the location picker's label reads "Lokasjon" (not "Bopel"); saving still round-trips `homeSlug`.
* RolePlay editor: the Post selector is the first field; Person and Kjønn share a row; Navn+Alder share a row above them; no "Effektiv identitet" heading; the inherit/override hints still show and effective identity still resolves.

`flutter analyze`, `flutter test test/views/`, then the single final gate: full `flutter test` + `dart build cli`.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures.
2. `make i18n` idempotent; `dart build cli` succeeds.
3. Manual smoke: Person editor shows Navn+Alder on one line, Kjønn on its own, and "Lokasjon" for the location picker; the RolePlay editor leads with Post, then Navn+Alder, then Person+Kjønn on one line, then Signalement and Posisjon, with no "Effektiv identitet" heading.
4. `git diff --stat` touches only `lib/views/…`, `lib/l10n/…`, `test/views/…`. No model, renderer, or schema change.
5. Clean tree; localizations committed with ARB changes.

## Deliverables

Conventional Commits (English) on `design-009`, clean tree, targeted tests per commit, one full-suite gate at the end (rule 9). The final commit body notes the Person and RolePlay editors were realigned (name+age paired, gender on its own row, post-first, person+gender paired) and the person's location field relabelled "Lokasjon", with no model or facet change.

ADR-0047 and DESIGN-009 are authoritative. Renaming the `homeSlug`/`.home` facet to a location-generic name is a **separate** model/facet change (wire-compat cost) and is out of scope here — this prompt is layout and the nb label only.
