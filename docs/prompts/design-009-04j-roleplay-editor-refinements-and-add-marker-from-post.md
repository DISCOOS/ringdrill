# Implement DESIGN-009 — Prompt 4j: RolePlay editor refinements and authoring markers from the post editor

You are working in the RingDrill repository, on `design-009`. This is a follow-up to prompt 4i (which shipped the effective-identity card, the position card, and the `loc` rename). It refines that editor from the review that followed, and adds the ability to author a marker from the post editor's Persons section — so an author never needs the read-only Post view to build one. [ADR-0047](../adrs/0047-scenario-locations-and-persons.md) and `docs/design/009-scenario-locations-and-persons.md` ("RolePlay editor" and "Authoring a marker from the post editor") are authoritative. Read `AGENTS.md` rule 9.

**Visual reference:** `docs/design/mockups/roleplay-editor.html` (the refined identity/position cards, four frames) and `docs/design/mockups/post-editor-persons.html` (the post editor's Persons section with the marker inline).

**Scope of change.** Mostly views + l10n. Commit 4 extends the existing inline-create write-back payload (`PlanAdditions`) to carry a new roleplay from the post editor to the plan owner — additive, no schema bump, `KNOWN_SCHEMA_MAX` unchanged. Several of these changes **supersede 4i's shipped UI** (the "Følger person" labels and per-field reset); that is intended.

## Changes

### 1. Static app-bar title

The RolePlay editor's title is the static type name, not the marker's name (which already sits in the identity card). Use the existing ARB keys: `editRolePlayTitle` for an existing marker, `newRolePlayTitle` for a new one. Change the `nb` values from "markørordre" to "spill": `editRolePlayTitle` → **"Endre spill"**, `newRolePlayTitle` → **"Nytt spill"** (verb "Endre" matches the "Endre post" norm). English stays "Edit role" / "New role". This nb→en asymmetry is **intentional and conceptually equivalent** — `nb` standardizes on "spill", `en` keeps "role"; do not "align" the words. In `roleplay_form_screen.dart` the title currently falls back to `widget.rolePlay.name`; switch the non-new branch to `l.editRolePlayTitle`. Prefer a real create-vs-edit signal if one exists; otherwise the existing name-empty heuristic is acceptable (a preset-new marker then reads "Endre spill", which is fine).

### 2. Post selector as a compact card

Replace the full-width Post dropdown with a compact card row: the station-code badge, the post name, and a discreet **"Endre"** action (opens the existing post picker as a dialog/sheet). Changing a marker's post after creation is rare, so it should read as context, not a prominent control. Reuse the existing picker behind the "Endre" affordance; only the closed-state presentation changes.

### 3. Identity and position card refinements

On the effective-identity card (`roleplay_form_screen.dart`):

* **Remove all "Følger person(en)" text and every per-facet label.** A field the author does not touch simply reads as it is. No "follows" chips in the panel, no "follows" line in the collapsed footer.
* The **"Tilpass" disclosure is the only toggle** — a chevron (down closed / up open) that opens and closes the override panel. Drop "Tilpass for denne markøren", "N felt tilpasset" and "Skjul".
* Replace the per-field "Tilbakestill" with a **single collective "Tilbakestill"** at the panel foot that resets *all* overrides at once. (This also removes the gap where `age` had no reset.)
* When the name is overridden, the collapsed card's source line reads **"Tilpasset fra {navn}"** (not "Portretterer"), naming the underlying person; an override marker (small dot) sits by the name.
* Keep: the panel auto-expands on open when an override already exists; effective values stay persisted denormalized (ADR-0047).

On the position card: **drop the "Følger personens lokasjon" label.** Show the location by name (e.g. "Bosted") with its coordinate and the "Sett egen" override action — the location name already reads as the source. No "Følger …" text.

Remove any now-unused ARB keys/labels left by the above.

### 4. Author a marker from the post editor's Persons section

In the post editor (`station_form_screen.dart`), both the **Persons** and **Locations** sections adopt the app's **card-per-item** list style — bordered, rounded, spaced cards with a leading avatar (persons) or kind-colored icon (locations), swipe-to-delete only (ADR-0031, no overflow menu, no pencil in rows — swipe is the app's one established row-delete affordance) — replacing today's flat rows (see `post-editor-persons.html`). The bottom chrome (search field + "Ny …", and the section switcher) is unchanged.

The **Persons** section additionally gains the marker inline, on the same row as the name (right-aligned, not a separate line):

* Each person shows its enacting marker inline — **"Spilles av {navn}"**, no chevron (the row itself is the tap target) — tapping it opens that roleplay in the RolePlay editor.
* A person **without** a marker offers **"Legg til spill"** in that same spot, which opens the RolePlay editor via `openFormSurface` with the **post and person pre-set** (so the author lands on the play and position, not the person picker).
* Saving the RolePlay editor **returns to the post editor**, where the person now shows the marker inline. The new roleplay is held in the post editor's **working copy** and written back on save, so an aborted post edit never leaves a half-saved marker.
* A brand-new person-and-marker in one step is already covered by the RolePlay editor's own person selector (inline create, 4/4e); "+ Person" then "Legg til spill" is the two-step path.

**Write-back.** The RolePlay editor already returns a `RolePlayFormResult` ( `rolePlay` + `additions`, applied by `applyRolePlayAdditions`). Extend the post editor's save so a marker created/edited here rides its `PlanAdditions` write-back to the plan owner alongside the station's own additions — the same mechanism used for inline-created persons/locations/variables, extended to roleplays. **If carrying a new roleplay to the plan owner needs more than extending the existing payload and its apply site, stop and report** before widening scope.

Removal stays here too (the app's swipe-to-delete, ADR-0031), not in the read-only viewer — but marker delete-guard/removal wiring beyond what already exists is **out of scope** for this prompt; add the add/edit path only.

## Ground rules

* Reuse existing widgets and the post picker, the `openFormSurface` route, `RolePlayFormResult` / `applyRolePlayAdditions`, and the `PlanAdditions` write-back. New UI is the Post card, the collective-reset row, and the Persons-section inline-marker row (mirroring `post-editor-persons.html`).
* **Both languages, conceptually equivalent.** Every added or changed user-facing string gets an entry in *both* `app_nb.arb` and `app_en.arb`, saying the same thing idiomatically in each language (not a word-for-word calque), followed by `make i18n`. Never change one language and leave the other stale. New pairs (nb / en): "Endre" / "Edit", "Legg til spill" / "Add role" (mirrors editRolePlayTitle/newRolePlayTitle's nb "spill" / en "role"; superseded "Legg til markør" / "Add marker"), "Spilles av {navn}" / "Played by {name}", "Tilbakestill" / "Reset", "Tilpasset fra {navn}" / "Customized from {name}", "Tilpass" / "Customize". Reuse an existing key when one already fits. Remove retired strings from both files.
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + `flutter test test/views/`; `make i18n` only on ARB change; full `flutter test` + `dart build cli` **once at the end**.

## Scope

Five commits.

1. **Static title.** `editRolePlayTitle`/`newRolePlayTitle` nb values → "Endre spill"/"Nytt spill"; title uses `editRolePlayTitle` for existing markers. `make i18n`. Commit: `feat(views): give the roleplay editor a static type title`.
2. **Post card.** Replace the dropdown with the compact card + "Endre" picker affordance. Commit: `feat(views): show the roleplay post as a compact card with an edit action`.
3. **Identity/position refinements.** Remove all "Følger person" text/labels, single collective reset, "Tilpass"+chevron only, "Tilpasset fra {navn}" on override, position card by location name; retire unused ARB. Commit: `feat(views): simplify the roleplay identity and position cards`.
4. **Card-per-item lists + add marker from the post editor.** Persons and Locations sections to card-per-item; Persons-section inline marker + "Legg til spill" preset flow + roleplay write-back into the post editor's save. Commit: `feat(views): card lists and author markers from the post editor's persons section`.
5. **Tests.** Commit: `test(views): cover the roleplay editor refinements and post-editor add-marker`.

### Tests

* **Title.** New marker → "Nytt spill"; existing → "Endre spill"; not the marker's name.
* **Post card.** The post shows as a card; "Endre" opens the picker and changes the post.
* **Identity/position.** No "Følger person(en)" string anywhere; the panel toggles on "Tilpass" + chevron; a single "Tilbakestill" clears all overrides (including age); an overridden name shows "Tilpasset fra {navn}"; the position card shows the location name, no "Følger …".
* **Add marker.** From the post editor's Persons section, "Legg til spill" opens the RolePlay editor with post and person pre-set; saving returns and the person shows the marker inline; the new roleplay round-trips through the post editor's save (write-back), and is absent if the post edit is cancelled.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures.
2. `make i18n` idempotent; `dart build cli` succeeds.
3. Manual smoke against both mockups: title "Endre spill"; Post card with "Endre"; identity card with no "Følger person" text, one "Tilbakestill", "Tilpass" chevron; position card by location name; and the post editor's Persons section adding a marker end-to-end without visiting the read-only view.
4. `git grep -n "Følger person"` finds nothing in `lib/` (the label is gone); `git diff --stat` touches only `lib/views/…`, `lib/l10n/…`, `test/…`, and the write-back plumbing.
5. Clean tree; regenerated localizations committed with ARB changes.

## Deliverables

Conventional Commits (English) on `design-009`, clean tree, targeted tests per commit, one full-suite gate at the end (rule 9). The final commit body records that the roleplay editor got a static title, a compact post card, and a simplified identity/position card (no "Følger person" text, one collective reset), and that markers can now be authored from the post editor's Persons section with the post and person pre-set, written back through `PlanAdditions`.

ADR-0047 and DESIGN-009 are authoritative. If the roleplay write-back needs more than extending the existing `PlanAdditions` payload and its apply site, stop and report rather than widening this prompt.
