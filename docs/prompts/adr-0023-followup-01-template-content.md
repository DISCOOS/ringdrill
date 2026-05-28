# ADR-0023 Follow-up 01 — Template content polish

You are working in the RingDrill repository. This is a follow-up to ADR-0023 ("Render the Brief view with a dedicated `BriefTheme` token set ...") which has already landed end-to-end (commits `971707e` → `b3c4f2e` plus the `setupLabel` patch in `fbff101`). The visual rework is in. The template content is not yet faithful to the LSOR booklet.

This prompt corrects five issues surfaced after the initial implementation, all driven by comparing the rendered brief against the LSOR Word document the brief is supposed to replace:

1. The `**Tid:** {{durationLabel}}` station-level inline-bold demotion in ADR-0023 Step 3 was a mistake. The LSOR booklet shows "Varighet" as a real `#### ` section heading at station level on equal footing with Utstyrsbehov / Situasjon / Oppdrag etc. The original outline-pollution concern is solved by filtering the sidebar TOC to H2+H3, not by demoting the heading.
2. The current `_durationLabel` helper returns the same value (`4 x 15 min.`) at both exercise and station levels. The LSOR booklet distinguishes:
   * **Exercise-level "Tid"** as clock-time span (`17:00–19:00`) and a separate **"Varighet"** as duration breakdown (`2 timer (30 min pr oppdrag)`). "Tid" in this codebase is reserved for clock-time; "Varighet" for duration.
   * **Station-level "Varighet"** as the per-round duration with phase breakdown (`30 min (15 | 10 | 5)`).
3. The exercise-level markdown table (`| Tid | {{durationLabel}} |` etc., currently with an empty `| | |` header row) is cramped, breaks on `setupLabel`'s `<br>` inside cells, and does not match the booklet's section-heading layout. The booklet renders each metadata field as a standalone `####` section.
4. The Organisering block has fields the current renderer does not derive: "Før hver post" prose (a fixed LSOR instruction set that applies to every exercise in a program). This needs a new program-level field `Program.beforeRoundMd`.
5. Station headings render as `### 1a – 1a) Turgåer` because `station.name = "1a) Turgåer"` already contains the prefix. Strip the prefix in `_buildStationContext` as a temporary workaround pending a separate data-cleanup round.

The rotation-block format already exists in `lib/utils/exercise_share_format.dart` as a Slack/Teams paste format. Per [[feedback_rotation_share_format]] that exact format is locked down. Refactor a shared helper out of it so the brief renderer reuses the same data assembly without duplicating the round-by-round logic.

## Ground rules

Read `AGENTS.md` and follow every numbered rule. The non-negotiable ones for this change:

* `Program.beforeRoundMd` is a new markdown content field, same shape as `briefIntroMd` and `commsMd`. Follow ADR-0022 ("Store long-form markdown content as `.md` files in the drill archive"). The field is `@JsonKey(includeFromJson: false, includeToJson: false)`, stored as `program/before-round.md`, included in `ProgramX.computeContentHash`.
* The new field bumps no schema. `.md` paths are part of the archive surface that schema 1.2 already permits.
* CLI must stay Flutter-free. The new shared rotation helper extracted from `exercise_share_format.dart` must not introduce a Flutter import along the way. `lib/utils/exercise_share_format.dart` is already Flutter-free (only `AppLocalizations` which is a code-generated locale class, not a widget); preserve that.
* Mobile-safe imports. Nothing this prompt touches reaches into web-only code.
* Match existing Dart style. Run `dart format` before each commit. No new lint suppressions.
* Localize. The new field gets a label in the template (Norwegian) and a hint string in the form (if added later — out of scope for this round). No new ARB keys needed because labels live in the mustache file directly per existing convention.
* `test/widget_test.dart` is the known-broken default-template smoke test. Flag it as such at the end.

## Commits

Five logical commits, in order, on the same working branch. Use Conventional Commits with scope `brief` (or `data` for the model commit). Suggested subjects:

1. `feat(data): add Program.beforeRoundMd markdown file field`
2. `refactor(utils): extract rotation-block formatter shared by brief and share`
3. `feat(brief): split duration helpers and add exercise-time and organisation helpers`
4. `feat(brief): rewrite nb template, restore Varighet heading, filter TOC to H2+H3`
5. `docs(brief): amend ADR-0023 revisions and update DESIGN-004 fields`

### Commit discipline (non-negotiable)

* After every step below, run `git status` and `git diff --stat` and confirm there are no untracked or unstaged paths before claiming the step done. Untracked files count as failure.
* Each step lists the **files expected in that commit**. The commit must include every listed path. Anything beyond the list also belongs in the commit unless explicitly punted. If you see a path you do not recognize in `git status`, do not delete it. Inspect it, then either include it or stop and ask.
* Regenerated files from `make build` (`*.freezed.dart`, `*.g.dart`, `app_localizations*.dart`) are part of the commit that triggered them. Do not park them in a "regen" follow-up commit.
* Never close a step with `git stash` or `git restore`. If something is in the working tree, it ships with the commit.
* The final Verification gate requires `git status` to print a clean tree on the working branch with no untracked or unstaged files. The work is not done until this is true.

## Scope

Five steps. Do them in order. Each step is one commit.

### Step 1. `Program.beforeRoundMd` field

Edit `lib/models/program.dart`. Add a new freezed field alongside `briefIntroMd` and `commsMd`:

```dart
@JsonKey(includeFromJson: false, includeToJson: false) String? beforeRoundMd,
```

Add it to `ProgramX.computeContentHash`. The existing canonical-map builder already covers `briefIntroMd` and `commsMd` (see the `'briefIntroMd': briefIntroMd, 'commsMd': commsMd,` block around line 149). Insert `'beforeRoundMd': beforeRoundMd,` next to those entries so the hash includes the field's content.

Run `make build` to regenerate `program.freezed.dart` and `program.g.dart`.

Edit `lib/data/drill_file.dart`. Two changes:

* In the reader (`program()`), follow the existing handling for `program/intro.md` (`programBriefIntroMd`) and add a parallel `programBeforeRoundMd` variable that captures the content of `program/before-round.md`. Pass it into the `Program(...)` constructor as `beforeRoundMd: programBeforeRoundMd`.
* In the writer (`fromProgram`), follow the existing `_writeMd(archive, 'program/intro.md', program.briefIntroMd);` call and add `_writeMd(archive, 'program/before-round.md', program.beforeRoundMd);`.

Update tests under `test/data/drill_file_*` (look for the program-level roundtrip test that already covers `briefIntroMd` / `commsMd`) to include `beforeRoundMd` in the constructed program and assert the same roundtrip and the same hash behaviour.

Files expected in this commit:

* `lib/models/program.dart`
* `lib/models/program.freezed.dart` (regenerated)
* `lib/models/program.g.dart` (regenerated)
* `lib/data/drill_file.dart`
* `test/data/drill_file_*.dart` (the test file that already covers program-level markdown fields)

Run `git status`. Confirm only those paths are staged. Commit: `feat(data): add Program.beforeRoundMd markdown file field`.

### Step 2. Extract shared rotation-block formatter

Look at `lib/utils/exercise_share_format.dart` lines 91–119 ("Rotation block"). That logic — the per-round line assembly with `(neste)` / `(retur)` suffixes — is what the brief renderer needs to reuse. Per [[feedback_rotation_share_format]] the format is locked down at `HHMM | HHMM | HHMM (neste/retur)`.

Extract a new top-level helper in a new file `lib/utils/rotation_block.dart` (or, if you prefer, alongside the existing function in the same file — make a judgment call based on import economy). The shape:

```dart
/// One round in the rotation block. `index` is 1-based.
/// `timesText` is the pre-formatted `"HHMM | HHMM | HHMM"` joined string.
/// `suffix` is the resolved `(neste)` / `(retur)` label from l10n,
/// without the parentheses.
class RotationRound {
  const RotationRound({
    required this.index,
    required this.timesText,
    required this.suffix,
  });
  final int index;
  final String timesText;
  final String suffix;
}

List<RotationRound> rotationRounds(Exercise exercise, AppLocalizations l10n);
```

Plus a phase-line helper:

```dart
/// "15 | 10 | 5" for the exercise phase breakdown.
String rotationPhaseBreakdown(Exercise exercise);
```

Both are pure functions, Flutter-free apart from the `AppLocalizations` parameter (which is generated code, not a widget).

Refactor `formatExerciseForShare` to call `rotationRounds` and `rotationPhaseBreakdown` instead of inlining the round loop and the phase pipe-join. The visible output of `formatExerciseForShare` MUST NOT change. Run its golden test (search for it under `test/utils/`) and confirm the output is byte-identical.

Files expected in this commit:

* `lib/utils/rotation_block.dart` (new) — or an extension of `exercise_share_format.dart` if you co-locate, list both paths in that case
* `lib/utils/exercise_share_format.dart` (refactored)
* `test/utils/exercise_share_format_test.dart` (or wherever the existing golden test lives — assertions unchanged but the test file may move if you reorganize)

Run `git status` and verify only those paths are staged. Commit: `refactor(utils): extract rotation-block formatter shared by brief and share`.

### Step 3. Renderer helpers

Edit `lib/services/brief/brief_renderer.dart`.

Replace `_durationLabel(exercise)` with three helpers:

```dart
/// Clock-time span for the exercise: "17:00–19:00".
/// "Tid" in our copy is reserved for clock-time, never duration.
String _exerciseTimeLabel(Exercise exercise) { ... }

/// Total duration plus per-round breakdown for the exercise:
/// "2 timer (30 min pr oppdrag)" when total > 60 min,
/// "90 min (30 min pr oppdrag)" when 60 < total <= 120 min,
/// "60 min" when single round (no per-oppdrag suffix needed).
String _exerciseDurationLabel(Exercise exercise) { ... }

/// Per-round duration with phase breakdown for a station:
/// "30 min (15 | 10 | 5)".
String _stationDurationLabel(Exercise exercise) { ... }
```

Round duration in minutes is `exercise.executionTime + exercise.evaluationTime + exercise.rotationTime`. Total duration is `numberOfRounds * roundDuration`. For "2 timer", convert minutes to hours when divisible (`120 min` → `2 timer`); fall back to `N min` otherwise. The "pr oppdrag" suffix is the localized form of "pr oppdrag" — add a new ARB key `briefPerStation` (`"pr oppdrag"` / `"per station"`) since this is rendered text the audience reads.

Add an organisation-block helper that returns the full Organisering markdown block as a string:

```dart
/// Renders the Organisering markdown block:
///
///     **Ringløype:** {numberOfRounds} x ({execTime} | {evalTime} | {rotTime})
///     _({phaseLegend})_
///
///     {{{program.beforeRoundMd}}}     // when non-null, rendered inline
///
///     **Rullering (klokkeslett)**
///
///     - Runde 1: 1700 | 1715 | 1725 _(neste)_
///     - ...
///
/// All Norwegian labels come from the existing rotation ARB keys
/// ([l10n.rotationShareTitle] etc.); the only new pieces are the
/// `**bold**` and `_italic_` markdown wrappers.
String _organisationBlock(
  Program program,
  Exercise exercise,
  AppLocalizations l10n,
) { ... }
```

Uses `rotationRounds` and `rotationPhaseBreakdown` from Step 2. The per-round bullet is `'- ${l10n.round(1)} ${r.index}: ${r.timesText} _(${r.suffix})_'`. The "Ringløype" prefix comes from a new ARB key `briefRingRoute` (`"Ringløype"` / `"Ring route"`).

`BriefRenderer.render(...)` gains a `required AppLocalizations l10n` parameter. Update `BriefScreen` to pass `AppLocalizations.of(context)!`. The renderer forwards `l10n` to `_buildExerciseContext` and from there to the new helpers.

Expose the new helpers via the existing `@visibleForTesting` static wrappers so tests can call them without round-tripping the whole template.

Files expected in this commit:

* `lib/services/brief/brief_renderer.dart`
* `lib/views/brief_screen.dart` (one call-site update: pass `l10n` into `render`)
* `lib/l10n/app_en.arb` (new keys `briefPerStation`, `briefRingRoute`)
* `lib/l10n/app_nb.arb` (same)
* `lib/l10n/app_localizations*.dart` (regenerated)
* `test/services/brief/brief_renderer_test.dart` (cover the new helpers; existing snapshot tests will likely need updating in Step 4, not here)

Run `git status` and verify only those paths are staged. Commit: `feat(brief): split duration helpers and add exercise-time and organisation helpers`.

### Step 4. Template rewrite + TOC filter

Edit `assets/templates/ringdrill-standard-v1.nb.md.mustache`.

Drop the existing exercise-level metadata table (`| | |` / `|---|---|` / per-field rows). Replace each row with a standalone `####` section. Empty fields are omitted via the existing mustache `{{#field}}...{{/field}}` guards. The new shape for one exercise:

```mustache
## {{name}}

#### Tid
{{exerciseTimeLabel}}

#### Varighet
{{exerciseDurationLabel}}

{{#methodMd}}
#### Metode

{{{methodMd}}}
{{/methodMd}}
{{#learningGoalsMd}}
#### Læringsmål

{{{learningGoalsMd}}}
{{/learningGoalsMd}}
{{#trainingFocusMd}}
#### Øvingsmomenter

{{{trainingFocusMd}}}
{{/trainingFocusMd}}

#### Organisering

{{{organisationBlock}}}

{{#orderFormatMd}}
#### Ordreformat

{{{orderFormatMd}}}
{{/orderFormatMd}}
{{#executionTipsMd}}
#### Tips til gjennomføring

{{{executionTipsMd}}}
{{/executionTipsMd}}
{{#effectiveCommsMd}}
#### Samband

{{{effectiveCommsMd}}}
{{/effectiveCommsMd}}
```

For each station, replace the current `**Tid:** {{durationLabel}}` inline-bold (introduced in ADR-0023 Step 3) with:

```mustache
#### Varighet
{{stationDurationLabel}}
```

This reverses the ADR-0023 Step 3 decision and restores the `####` heading. The outline-pollution concern moves to the sidebar TOC filter below.

Update the renderer context (`_buildExerciseContext`) to expose the new keys:

* `exerciseTimeLabel` — from `_exerciseTimeLabel(exercise)`.
* `exerciseDurationLabel` — from `_exerciseDurationLabel(exercise)`.
* `organisationBlock` — from `_organisationBlock(program, exercise, l10n)`.

Update `_buildStationContext` to expose:

* `stationDurationLabel` — from `_stationDurationLabel(exercise)`.

Drop the now-unused `durationLabel` and `setupLabel` exposures from both contexts. Remove `_durationLabel` and `_setupLabel` (and their `@visibleForTesting` wrappers) from the renderer.

**Station name prefix strip.** In `_buildStationContext`, before exposing `name`, strip a leading `^[0-9]+[a-z]\)\s*` pattern from `station.name`. Define the regex as a top-level constant. The exposed `name` is the cleaned form. Document with a comment that this is a temporary workaround pending a separate data-cleanup round; the raw value remains on `Station.name` itself.

**Sidebar TOC filter (H2 + H3 only).** In `lib/views/brief_screen.dart`, inside the `TocWidget.itemBuilder`, after computing `level`, short-circuit when `level > 3`:

```dart
if (level > 3) return const SizedBox.shrink();
```

This hides every `####` heading from the sidebar without changing `markdown_widget` or the `TocController`. Verified earlier in the conversation that `level` is already extracted from `data.toc.node.headingConfig.tag`.

Update the snapshot/expectation tests under `test/services/brief/` to reflect the new template output. The diff should be substantial but localized to:
* No more `| | |` table at exercise level.
* `#### Tid` and `#### Varighet` sections at exercise level.
* `#### Organisering` containing the bulleted rotation block.
* `#### Varighet` instead of `**Tid:** ...` at station level.
* Cleaned station names with no `Nx)` prefix.

Add a test that the sidebar TOC filter hides H4 entries. Pump the screen with a fixture program at a wide breakpoint and assert that no `####`-derived text appears in the sidebar TOC.

Files expected in this commit:

* `assets/templates/ringdrill-standard-v1.nb.md.mustache`
* `lib/services/brief/brief_renderer.dart` (context exposure changes, regex constant, remove old helpers)
* `lib/views/brief_screen.dart` (the `level > 3` filter)
* `test/services/brief/brief_renderer_test.dart` (updated expectations)
* `test/views/brief_screen_test.dart` (TOC filter test)

Run `git status` and verify only those paths are staged. Commit: `feat(brief): rewrite nb template, restore Varighet heading, filter TOC to H2+H3`.

### Step 5. ADR-0023 revisions and DESIGN-004 update

Edit `docs/adrs/0023-brief-theme-tokens.md`. Append a new `## Revisions` section at the bottom, before the existing `## Links` section if it sits at the end, or at the very bottom otherwise. Format:

```markdown
## Revisions

* **2026-MM-DD** — Step 3's "demote one-line `#### Tid` to inline bold `**Tid:**`" template change is reversed. The LSOR booklet shows section headings ("Varighet", "Utstyrsbehov", "Situasjon", ...) on equal footing at station level. The original outline-pollution concern is addressed by filtering the sidebar TOC to H2+H3 in `BriefScreen` (`level > 3` short-circuits the itemBuilder), which keeps the headings without polluting the outline. See `docs/prompts/adr-0023-followup-01-template-content.md`.
* **2026-MM-DD** — The renderer's single `durationLabel` helper is replaced by three: `_exerciseTimeLabel` (clock-time span), `_exerciseDurationLabel` (duration breakdown), `_stationDurationLabel` (per-round duration with phase breakdown). "Tid" in copy is reserved for clock-time, "Varighet" for duration. This matches the LSOR booklet's terminology consistently.
* **2026-MM-DD** — The exercise-level markdown table is removed in favour of section-heading layout, matching the LSOR booklet's content column. The `setupLabel <br>`-in-table bug is dissolved by this change.
```

Replace `MM-DD` with today's date (use `date +%Y-%m-%d` if you need to be sure).

Edit `docs/design/brief-template.md`:

* In the "Summary of new fields" code block under "Field mapping", add `Program.beforeRoundMd`:

  ```dart
  // Program
  @JsonKey(includeFromJson: false, includeToJson: false) String? briefIntroMd;
  @JsonKey(includeFromJson: false, includeToJson: false) String? commsMd;
  @JsonKey(includeFromJson: false, includeToJson: false) String? beforeRoundMd;  // new
  ```

* In the "Program" field-mapping table, add a row for `beforeRoundMd`:

  ```
  | "Før hver post" prose             | `program.beforeRoundMd` (new)         | **new**  |
  ```

* In "Exercise" field-mapping table, update the "Tid (duration)" row to clarify it now uses `_exerciseTimeLabel` and `_exerciseDurationLabel`. The "Organisering" rows collapse into one referring to `_organisationBlock`.

* In the "Headings that produce outline entries" table (under "Visual design" → "Headings that produce outline entries"), the `inline bold "Tid", "Utstyrsbehov" (one-liner metadata)` row is removed; replace with a note: "All station-level metadata uses `####` headings; the sidebar TOC filters them out by gating on `level > 3` in `BriefScreen`'s `TocWidget.itemBuilder`."

* In "Stage 3 — Brief route" under Implementation notes, remove the trailing sentence about `**Tid:**` inline. Add a brief note that the Tid/Varighet helper split and the H2+H3 sidebar filter shipped in a follow-up to ADR-0023.

Files expected in this commit:

* `docs/adrs/0023-brief-theme-tokens.md`
* `docs/design/brief-template.md`

Run `git status` and verify only those paths are staged. Commit: `docs(brief): amend ADR-0023 revisions and update DESIGN-004 fields`.

## Verification

1. `flutter analyze` is clean.
2. `flutter test` produces no new failures. `test/widget_test.dart` remains broken (default counter template). Do not try to fix it. Report it as known-broken in the final write-up.
3. `node --test netlify/functions/__tests__/` is green (the schema 1.2 acceptance test from ADR-0022 still passes; `beforeRoundMd` rides on existing schema).
4. `make build` completes cleanly. Re-run `git status` after it. If any regenerated file is suddenly dirty after analyze and test passed, that file was missing from an earlier commit. Stop and amend the relevant commit before continuing.
5. **Clean tree gate.** `git status` prints `nothing to commit, working tree clean`. `git ls-files --others --exclude-standard` prints nothing. No untracked, no unstaged, no stashed work. Do not invoke `git stash` or `git restore` to satisfy it.
6. **Diff sanity.** Run `git log --stat origin/main..HEAD` and walk every changed path. Confirm each file appears in exactly the commit you intended.
7. Manual QA matrix:
   * **Exercise overview block.** Open the brief on a sample program. Confirm the exercise section starts with `#### Tid` showing `HH:MM–HH:MM`, then `#### Varighet` showing total + per-oppdrag, then `#### Metode` etc. No table. No empty header row.
   * **Organisering section.** Confirm the Organisering block contains `**Ringløype:** N x (a | b | c)`, an italic legend line, then (if `program.beforeRoundMd` is populated) the authored prose, then `**Rullering (klokkeslett)**` followed by per-round bullets. The "Rullering" sub-heading is bold inline, not a `####` (so it does not show up in the outline even without filtering).
   * **Station section.** Confirm each station opens with `#### Varighet` showing `N min (e | v | r)`, then the rest of the station sections in order. No `**Tid:** ...` inline bold anywhere.
   * **Sidebar TOC.** Confirm the wide-screen sidebar lists only exercise (H2) and station (H3) headings. No `Varighet`, `Utstyrsbehov`, `Metode`, etc. entries.
   * **Station-name dedup.** Confirm station headings render as `### 1a – Turgåer` (one prefix), not `### 1a – 1a) Turgåer`. Inspect the raw data to confirm `Station.name` itself is unchanged.
   * **Share format.** Run a copy-to-share on an exercise (existing UI). Confirm the output is byte-identical to what was produced before this round. The rotation-block helper refactor must not change share output.
8. No follow-up defects bundled in. If during the work you found anything that does not fit the five steps, record it at the bottom of the final commit body under a `## Follow-ups` heading and create fresh prompt files under `docs/prompts/` named `adr-0023-followup-NN-<slug>.md`. Do not silently bundle.

## Out of scope

* Form-side editing of `beforeRoundMd`. Stage 4 of DESIGN-004 (form editors) is still deferred. Authors populate the field by editing `program/before-round.md` in the archive manually for now, or via a future form round.
* Data cleanup of `Station.name`. The regex strip is a renderer-only workaround. A separate prompt will normalize the underlying data.
* Print stylesheet. Stage 5 of DESIGN-004.
* Any English template variant. The system still ships one template, locale `nb`.
* Re-styling the rotation block beyond the markdown shape described above. If `(neste)` italic looks off on screen, that is a follow-up.

## Deliverables

A series of five Conventional Commits as outlined above, all on the same working branch, with a clean tree at the end. The final commit body should include:

* A one-line summary of the user-visible change (Tid/Varighet split, Organisering content faithful to the LSOR booklet, sidebar TOC clean).
* The manual QA matrix filled out.
* A `## Follow-ups` section, even if empty.

ADR-0023 is the authoritative spec for the visual language. DESIGN-004 is the authoritative spec for what belongs in this round vs later stages. If you find yourself contradicting either, stop and ask. Do not write a new ADR.
