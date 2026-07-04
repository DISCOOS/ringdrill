# DESIGN-008 completion summary

**Date:** 2026-07-04

DESIGN-008 (plan variables and the section-navigated editor) is done on
`design-008`, end-to-end QA'd (`design-008-e2e-qa.md`), and both ADR-0046
and DESIGN-008 are flipped to `Accepted`.

## What shipped

* **Model** (Stage 1): `DrillVariable`, `Program.variables`,
  `variableOverrides` on `Exercise`/`Station`, folded into
  `computeContentHash`, additive/backward-compatible, no schema bump.
* **Resolution** (Stage 2, follow-up 05): `BriefRenderer` resolves
  `{{var.<name>}}` through the station → exercise → program scope chain,
  in both long-form markdown fields and names/descriptions, with a visible
  placeholder for an undeclared reference and silent-empty for a
  declared-but-empty one.
* **Section-navigated editors** (Stage 3, follow-ups 06/07): `Program`,
  `Exercise`, `Station` and `RolePlay` all edit through one switcher model
  (dropdown on compact, master/detail rail on wide), replacing the single
  long scroll.
* **Token-aware fields** (Stage 4/5, follow-ups 01–03): `TokenTextEditingController`
  chip rendering (known/empty/unknown), the `/` and `{{` insertion menu,
  inline variable creation, the `VariablesSection` declaration/override
  surfaces, plan-wide rename-rewrite, and reference-blocked delete — all
  driven by `PlanScope` rather than a hand-threaded `variables:` list.
* **Live-UI resolution** (follow-up 09): `PlanScope` now wraps the
  program-scoped live-app routes; `RingDrillText` resolves names/
  descriptions in list tiles, the coordinator, the drill player, map
  labels and share text; `RingDrillTextField` gets its first call
  sites (every editor's name field, plus `Program`/`Station` descriptions).
* **Flag removed** (follow-up 08): `RINGDRILL_PLAN_VARIABLES` is gone —
  the feature is unconditional in all four editors.
* **End-to-end QA and a fix** (follow-up 10): a full-gate pass plus a
  scripted walkthrough on one fixture plan across every rule ADR-0046 and
  DESIGN-008 specify, which surfaced and fixed one real defect —
  `plan_variable_refs.dart`'s rename/delete-reference tracking had never
  been extended to names/descriptions, so a variable referenced only in a
  name was invisible to the delete guard and silently orphaned by rename.

## Deferred, intentionally

1. **Variable creation from sub-editors.** DESIGN-008's `VariablesSection`
   spec gives `Exercise`/`Station`'s override surface its own
   "+ Ny variabel" action with a record-based result contract (create,
   then drop focus into the new variable's default value). That
   surface-level create action was not built; the create paths that did
   ship are `Program`'s declaration surface and the slash-menu's inline
   "Opprett variabel «x»", both reachable from every editor's token-aware
   fields including `Exercise`/`Station`/`RolePlay`.
2. **Local-only variables.** ADR-0046 option B — declaring a variable
   visible only within one exercise or station's subtree, instead of
   always at plan level. Revisit if the plan-level list grows noisy with
   single-use variables; not needed for v1.

Both are noted in the docs (ADR-0046's second addendum, DESIGN-008's
follow-up 10 note) as open, not abandoned.

## Ready to merge

`design-008` is ready to merge into `main`. There is no feature flag left
to flip — merging makes plan variables and the section-navigated editors
live for every user immediately.

## Related

* [ADR-0046](../adrs/0046-plan-variables.md)
* [DESIGN-008](../design/008-plan-variables-and-section-navigated-editor.md)
* [DESIGN-008 end-to-end QA pass](./design-008-e2e-qa.md)
