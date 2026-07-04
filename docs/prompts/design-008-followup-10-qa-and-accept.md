# DESIGN-008 follow-up 10 — end-to-end QA and Accept

You are working in the RingDrill repository. Final follow-up to DESIGN-008. Read [ADR-0046](../adrs/0046-plan-variables.md) and `docs/design/008-plan-variables-and-section-navigated-editor.md`. By now the whole feature is implemented on `design-008`: model, renderer resolution (fields + names/descriptions), section-navigated editors for all four entities, override tables on Exercise/Station, token-aware fields including names/descriptions, live-UI resolution, and the flag is gone. This closes the work: one end-to-end pass and flipping the docs to Accepted.

## Scope

Three steps.

### Step 1. End-to-end verification

Run the full gate and record the result in a note (`docs/notes/design-008-e2e-qa.md`, matching the note convention):

* `flutter analyze` clean, `flutter test` all green (record the count), `dart build cli` succeeds, `make i18n` idempotent.
* A scripted or test-driven walkthrough of the whole feature on one fixture plan: declare a variable on the plan; reference it in a program markdown field, an exercise field, a station field, a roleplay field, and in an exercise name; override its value on an exercise and again on a station; render the brief for all three audiences and confirm the cascade (program default → exercise → station) resolves correctly in both fields and names; confirm the live UI (list, coordinator, player, share) shows resolved values; rename the variable and confirm references rewrite across the plan; try to delete it while referenced (blocked) and after removing references (succeeds); confirm save is blocked on an undeclared token and on an empty declared token it is not.
* A `.drill` round-trip: save, reload, and re-render, confirming `variables` and `variableOverrides` survive and the content hash changed when a variable changed.

Fix anything that fails before proceeding. If a defect is non-trivial, stop and report it as its own finding rather than patching blindly.

Files expected: `docs/notes/design-008-e2e-qa.md` (and any fixes the pass surfaced).

Run `git status`. Commit: `test: end-to-end QA pass for DESIGN-008 plan variables`.

### Step 2. Flip ADR-0046 and DESIGN-008 to Accepted

Update the front matter and index entries:

* `docs/adrs/0046-plan-variables.md`: `status: proposed` → `status: accepted`; keep the addendum. Update the row in `docs/adrs/README.md` from `Proposed` to `Accepted`.
* `docs/design/008-plan-variables-and-section-navigated-editor.md`: `status: Proposed` → `Accepted`, add an `accepted:` date; update the row in `docs/design/README.md` to `Accepted`.

Add a short dated line to each recording that the feature shipped on `design-008` with the deferred items still deferred (variable creation from sub-editors; local-only variables).

Files expected: the two docs and the two README index tables.

Run `git status`. Commit: `docs: accept ADR-0046 and DESIGN-008`.

### Step 3. Final summary

Write the branch's closing summary in the commit body (or a short `docs/notes/` wrap-up): what shipped, the two deferred items (sub-editor variable creation with the record-based result contract; local-only variables / ADR-0046 option B), and that the branch is ready to merge (merging makes the feature live, since there is no flag).

Run `git status`. Commit: `docs: DESIGN-008 completion summary`.

## Verification

1. Full suite green; build clean; i18n idempotent.
2. Both docs read `Accepted` in front matter and in both index tables.
3. No `RINGDRILL_PLAN_VARIABLES` / `planVariables` references anywhere (the flag stayed removed).
4. Clean tree gate and diff sanity.

## Deliverables

Conventional Commits (English) on `design-008`, clean tree, feature complete and documented as Accepted. Note in the summary that the deferred items (sub-editor creation + result-object contract; local-only variables) are the only DESIGN-008 scope not built, both intentionally.

ADR-0046 and DESIGN-008 are authoritative.
