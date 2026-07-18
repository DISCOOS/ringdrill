# Implement: "Ferdig" instead of "Lagre" for forms that commit to a parent

You are working in the RingDrill repository, on `design-010`. A form-chrome fix: a form whose save only commits to a **parent's in-memory working copy** (persisted later, by an outer save) should label its primary action **"Ferdig" / "Done"**, not "Lagre" / "Save" — because nothing is written to disk when it closes. Read `AGENTS.md` (rules 9, 12).

**Views (+ one ARB string) only.** No model/renderer/schema change.

## Why

Editor forms open via `openFormSurface` and **return a result** — they don't persist themselves. The call site either (a) applies the result and calls `ProgramService.save*` **immediately** (a real save), or (b) folds the result into its **own working copy**, which is persisted only when *that* outer form is later saved. So "nested vs committing" is a property of the **call site**, not the form: the same `PersonFormScreen` is a real save from the Post viewer (the caller persists at once) but a deferred commit from the station editor's Persons section (folded into the station's working copy). Labeling both "Lagre" is misleading in case (b); the author's edit isn't saved until the outer form is.

Kengu's decision: use **"Ferdig" / "Done"** for the deferred (commit-to-parent) case. The `×` close affordance is separate and unchanged.

## Mechanism (drive it per call site, via the existing boundary)

`openFormSurface` already wraps every such form (and re-provisions the resolve scopes). Add a `bool commitsToParent = false` parameter to it, exposed to the form subtree (a tiny inherited signal, e.g. `FormSurfaceScope`, or read directly in the chrome). The shared form chrome's primary action picks the label:

* `commitsToParent == false` (default): **"Lagre" / "Save"** — the caller persists on return (unchanged behaviour).
* `commitsToParent == true`: **"Ferdig" / "Done"** — the result is folded into a parent working copy.

Drive it per call site (not hardcoded in the form), since the same form is both depending on where it's opened.

## Classify every `openFormSurface` call site

Audit each `openFormSurface<…>` call and set `commitsToParent` correctly. **Verify against the code** — the rule is: does the caller call `ProgramService.save*` right after the form returns (→ false/"Lagre"), or does it merge the result into its own unsaved working copy (→ true/"Ferdig")?

Expected classification (confirm each):

* **Commit-to-parent → "Ferdig"**: `LocationFormScreen` / `PersonFormScreen` / the RolePlay form when opened from `StationFormScreen`'s Locations/Persons/markers sections (they fold into the station's working copy, persisted on the station's own save); any leaf/sub-form opened from within another unsaved form.
* **Real save → "Lagre"**: forms whose caller persists immediately — e.g. the exercise editor from the program view, and `LocationFormScreen`/`PersonFormScreen`/`RolePlayFormScreen` opened from the read-only viewers (`station_screen`, `roleplay_screen`) where the caller applies + saves on return.

(If the top-level station/exercise editor itself is the outer form whose save persists, it stays "Lagre".)

## Scope — three commits

### Commit 1. `openFormSurface` carries `commitsToParent` + chrome reads it

`open_form_surface.dart` gains the parameter and exposes it; the shared form chrome (`SectionNavigatedForm` / wherever the primary action button lives) shows "Ferdig"/"Done" when set, "Lagre"/"Save" otherwise. Add the ARB string (reuse a generic "Done"/"Ferdig" if one already exists; otherwise add `formDoneAction` to `app_en.arb` + `app_nb.arb` and run `make i18n`).

Commit: `feat(shell): "Ferdig" label for forms that commit to a parent working copy`.

### Commit 2. Set `commitsToParent` at the deferred call sites

Set `commitsToParent: true` on the `openFormSurface` calls classified above as folding into a parent working copy; leave the real-save call sites unchanged.

Commit: `feat(shell): mark nested sub-forms as commit-to-parent`.

### Commit 3. Tests

* A form opened with `commitsToParent: true` shows "Ferdig"/"Done"; the default shows "Lagre"/"Save".
* A representative deferred call site (e.g. Person form from the station editor) renders "Ferdig"; a real-save site (e.g. from the Post viewer) renders "Lagre".
* The `×` close affordance is present and unchanged in both.

`flutter analyze`, `flutter test test/views/`, then the single final gate: full `flutter test` + `dart build cli`.

Commit: `test(shell): cover the commit-to-parent form label`.

## Ground rules

* Views + test + one ARB string only. Two languages kept equivalent; ARB edit → `make i18n`, not `make build`.
* The label is driven per call site through `openFormSurface`, not hardcoded per form — the same form must be able to show either label.
* Behaviour-preserving otherwise: only the primary-action label changes; the `×` close and the return/persist logic are untouched.
* **Test-loop discipline (rule 9):** per commit `flutter analyze` + `flutter test test/views/`; full `flutter test` + `dart build cli` **once at the end**.

## Verification (final gate — run once)

1. `flutter analyze` clean; full `flutter test` no new failures (main's pre-existing failures aside).
2. `dart build cli` succeeds.
3. Manual smoke: open a Person from the station editor's Personer section → primary action reads **"Ferdig"**; open a Person from the Post viewer → it reads **"Lagre"**; the `×` closes in both. The edit from the "Ferdig" form is only persisted once the station is saved.
4. `git diff --stat` touches `lib/views/…`, `lib/l10n/…`, `test/…` only.
5. Clean tree.

## Deliverables

Conventional Commits (English) on `design-010`, clean tree, targeted tests per commit, one full-suite gate at the end (rule 9). Forms that only commit to a parent working copy read "Ferdig"/"Done"; forms whose caller persists immediately keep "Lagre"/"Save"; the label is chosen per call site via `openFormSurface`.
