# Implement DESIGN-008 — Follow-up 12: section-editor polish (variable override list + wide chrome)

You are working in the RingDrill repository. Two views-only refinements to the section-navigated editor (DESIGN-008), no model change. [`docs/design/008-plan-variables-and-section-navigated-editor.md`](../design/008-plan-variables-and-section-navigated-editor.md) ("Follow-up 12") and [ADR-0030](../adrs/0030-wide-screen-master-detail-layout.md) are authoritative. Read `AGENTS.md` rule 9.

**Visual reference:** `docs/design/mockups/variable-overrides.html` (the override list) and `docs/design/mockups/post-editor-wide.html` (the wide master/detail chrome). These apply to the section-navigated editor across **all** entities (Program/Exercise/Station/RolePlay), not just the post editor.

**Scope of change.** Views + a little l10n. No model, renderer, or schema change.

## Part A — variable override list as card-per-item

The exercise/station variable **override** surface (today flat underline rows) becomes card-per-item, matching the DESIGN-009 Persons/Locations lists:

* One card per declared variable: the variable **name** (monospace) with its **inherited default value in parentheses** after it — `year (2026)` — no "Arvet"/"Standard" label. An empty inherited value shows no parentheses.
* Below the name, the **local-value field**: placeholder "Lokal verdi" when empty; the entered value when set.
* When a local value is set (an override), the field gets an **accent border** and the card shows a per-variable **"Tilbakestill"** that clears the local value back to the inherited default.
* The card standard matches the Persons/Locations cards (bordered, rounded, spaced, subtle shadow). The bottom search / "+ Ny …" chrome and the section switcher are unchanged.

This is the same "default in parentheses" the mockup shows, and it keeps both values visible (parentheses = inherited, field = local) without a cramped two-column layout.

## Part B — wide master/detail chrome

On wide (the section-navigated editor as a modal dialog with a master rail + detail pane, ADR-0030), three fixes. **Compact is unchanged** (the AppBar dropdown stays the section title).

1. **No duplicated section title.** The rail already shows the selected section highlighted, so **drop the section-title heading in the detail pane**. Also drop the `‹ ›` previous/next arrows on wide (the rail is the navigation). The `⋮` section-actions (remove) menu appears **only on a removable section**, as a compact top-right button — a base/non-removable section shows **no header band at all** (not an empty band with a disabled `⋮`, which reads as an empty "appbar" and costs a whole row).
2. **Bottom bar = the compact bar, adapted.** Do **not** invent a new treatment. Reuse the **same** bottom search / "+ Ny …" bar the compact layout already uses (its `bg-2` surface, top divider, magnifier + placeholder, accent-text "+ Ny …"), spanning the detail pane. The current wide layout let this bar blend into the background; matching the compact bar is the fix.
3. **Integrated rail.** Put the master rail on the **same surface palette** as the rest (a step off the page background, e.g. `bg-2` with a divider against the detail pane), not the near-black it uses today. The selected section gets the **accent-background** highlight, exactly like the compact section switcher's selected row.

## Ground rules

* Views only. Reuse the existing card styling from the Persons/Locations sections for Part A, and the existing compact bottom-bar and compact-switcher-selected styling for Part B (this is about applying styles that already exist, not new components).
* Any new/changed user-facing string goes in **both** `app_nb.arb` and `app_en.arb`, conceptually equivalent, then `make i18n`. (Part A likely reuses "Lokal verdi" / "Tilbakestill" already present; add only what is missing.)
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + `flutter test test/views/`; `make i18n` only on ARB change; full `flutter test` + `dart build cli` **once at the end**.

## Scope

Three commits.

1. **Override list cards.** The exercise/station override surface to card-per-item with the parenthesized inherited default and per-variable reset. Commit: `feat(views): show variable overrides as cards with inherited value in parentheses`.
2. **Wide chrome.** Drop the detail-pane duplicated title and `‹ ›`; reuse the compact bottom bar in the detail pane; put the rail on the surface palette with an accent-highlighted selection. Commit: `feat(views): tidy the wide section-editor chrome`.
3. **Tests.** Commit: `test(views): cover the override cards and wide section-editor chrome`.

### Tests

* **Override cards.** A declared variable renders as a card with its inherited default in parentheses and an empty local field; setting a local value shows the accent state and a "Tilbakestill"; reset clears it back to inherited; an inherited-empty variable shows no parentheses.
* **Wide chrome.** On a wide layout the detail pane shows no section-title heading and no `‹ ›` (only `⋮`); the rail's selected section is accent-highlighted; the bottom bar uses the compact bar's styling. On compact, the AppBar dropdown title and the bottom bar are unchanged.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures.
2. `make i18n` idempotent; `dart build cli` succeeds.
3. Manual smoke against both mockups: the override list reads `year (2026)` with a local field and per-variable reset; on wide, the section title appears only in the rail, the rail matches the surface palette with an accent selection, and the bottom bar looks like the compact one.
4. `git diff --stat` touches only `lib/views/…`, `lib/l10n/…`, `test/views/…`.
5. Clean tree; localizations committed with any ARB change.

## Deliverables

Conventional Commits (English), clean tree, targeted tests per commit, one full-suite gate at the end (rule 9). The final commit body records that variable overrides are now card-per-item with the inherited value in parentheses, and that the wide section-editor drops the duplicated title and redundant arrows, reuses the compact bottom bar, and integrates the master rail into the surface palette — compact unchanged.

DESIGN-008 Follow-up 12 and ADR-0030 are authoritative. These are style/layout reuses; if any of it requires more than applying existing styles and dropping redundant chrome, stop and report.
