You are working in the RingDrill repository. Rename the Program tab's third segment from **Markører** to **Spill** (nb) / **Script** (en), turning it from "the markør roster" into the **scenario-script umbrella** that holds the role-plays today and silent witnesses later. The authoritative context:

- `docs/design/006-program-tab-consolidation.md` (DESIGN-006, Accepted) — the segmented Program tab.
- `docs/prompts/DESIGN-006-followups.md` — running follow-up list.

Read the DESIGN-006 *Program tab anatomy* and *Segmented switcher* sections before starting. If this prompt contradicts the spec, the spec wins; stop and ask.

## Concept

"Spill" (en "Script") is the staged scenario layer of the plan. It is publishable (Program tab), distinct from the local people layer (Roster/Bemanning, where `Actor` lives). The segment lists the scenario elements:

- **Markører** = `RolePlay` (existing) — a role enacted by an `Actor`. "Play" here means the role-play and is unchanged.
- **Tause vitner** = `SilentWitness` (a future entity: description/story/purpose/info + position, no actor) — **out of scope for this prompt**, reserve the seam only.

"Script" is chosen over "Play"/"Scenario" because it does not collide with `RolePlay`'s "Play" at any level and matches the practice field (manus). The Norwegian label is "Spill".

## What this is, and is not

**In scope:** rename the segment identifier, label and references from "Markører/roleplays" to "Spill/Script", keeping the current content (the `RolePlay` roster) unchanged.

**Out of scope:** the `SilentWitness` entity and any "Tause vitner" UI (future). Do not touch the `RolePlay` / `Actor` models, the Roster/Bemanning tab, or the cast flow. No behaviour change beyond the rename.

## Ground rules

Read `AGENTS.md`. The ones that bite:

- **Localize.** Add a new `scriptSegment` key (nb "Spill", en "Script") to `app_en.arb` and `app_nb.arb`, then run `make build` (gen-l10n). Do not hand-edit `app_localizations*.dart`. The switcher currently labels this segment with `rolePlaysTab`; point it at the new key. Leave `rolePlaysTab` itself in place (still used as the term "Markører" for the role roster inside the segment, e.g. empty states and the cast surfaces).
- **CLI Flutter-free, mobile-safe imports, no new Sentry.** Widget-layer only.
- **Match existing Dart style.** No new lint suppressions without an inline reason.
- **Verify before claiming green.** `flutter analyze` and `flutter test` at the end of each step.

## Steps

### Step 1 — `refactor(program)`: rename the segment enum and references

Rename `ProgramSegment.roleplays` to `ProgramSegment.script` in `lib/views/program_view.dart` and every reference: the `IndexedStack` ordering, the `buildFAB` and `buildActions` switches, and `_emptyPaneBuilderForCurrentTab` in `lib/views/main_screen.dart`. The `script` segment still renders `RolePlaysView` and still maps to `RolePlayDetailEmpty` for now — only the name changes. Keep the enum order (exercises, stations, script, teams) so `IndexedStack` indices and segment positions are stable. Update `test/views/program_view_test.dart` and any other test referencing `ProgramSegment.roleplays`.

Gates green. Commit.

### Step 2 — `feat(l10n)`: add the "Spill" / "Script" segment label

Add `scriptSegment` (nb "Spill", en "Script") to both arb files and run `make build`. Point the `script` segment in `_ProgramSegmentSwitcher` at `localizations.scriptSegment` instead of `rolePlaysTab`. The segment icon stays `Icons.theater_comedy`. Verify the switcher shows "Spill" (nb) / "Script" (en) and the role roster still renders underneath.

Gates green. Commit.

### Step 3 — `docs(design)`: record the Script layer in DESIGN-006

Update DESIGN-006 so the third segment reads **Spill** (en "Script") wherever the segment is named (the ASCII switcher row, the segment table, the FAB/actions table, prose). Keep "Markører" where it refers to the `RolePlay` roster *inside* the segment, not the segment itself. Add a short "Script layer" note: Spill is the publishable scenario layer; Markører (`RolePlay`) is its current content; Tause vitner (`SilentWitness`, description/story/purpose + position, no actor) is a reserved future sibling. Add a changelog line.

Gates green (markdown only). Commit.

## When you finish or get stuck

- Append a closing entry to `docs/prompts/DESIGN-006-script-rename-handoff.md`.
- Park the `SilentWitness` / "Tause vitner" entity as a new numbered item in `docs/prompts/DESIGN-006-followups.md` (description/story/purpose/info + position, no actor; publishable sibling of `RolePlay` under the Spill/Script segment; consider a shared scenario-element base).
- This is additive and post-release-unit, so it may be pushed once green.
