You are working in the RingDrill repository. Implement **stage 4 of DESIGN-007** ("Onboarding sequence and in-app help"): the first-run-only **"Start her"** cue on the first Program FAB. The authoritative spec is:

- `docs/design/007-onboarding-and-help.md` (DESIGN-007, Accepted) — read *Layer 3 — Teaching empty states* (especially the **"Start her" cue rules** subsection), *Implementation notes → Stage 4*, *Persistence*, and *Non-goals*.

Read it in full first. If this prompt contradicts it, the spec wins; stop and ask.

Stages 1–3 have landed: teaching empty states (`lib/views/widgets/teaching_empty_state.dart`, wired into all four Program segments), the concept primer + `AppConfig.keyOnboardingSeen` flag, and the bundled example plan. Stage 4 is the last small piece of the first-run flow.

## What stage 4 is, and is not

Stage 4 adds one inline **"Start her"** pill next to the first Program FAB, so a user who chose "Start en tom plan" and landed on an empty Program tab gets a single nudge toward creating their first exercise. It shows once, ever, and disappears for good the moment the user creates anything or taps it.

**In scope:**

- A small **inline pill** reading **"Start her"** (`nb`) / **"Start here"** (`en`), placed **next to the first FAB** — the Øvelser segment's "Ny øvelse" FAB (`_buildExercisesFAB` in `lib/views/program_view.dart`). It is an inline widget in the Scaffold's `floatingActionButton` region (e.g. the FAB wrapped in a `Row`/`Column` with the pill adjacent), **not** an overlay, scrim, tooltip, or coachmark.
- A **dedicated** `AppConfig.keyStartHereSeen` (`'app:startHereSeen:v1'`). It must **not** reuse `keyOnboardingSeen` — that one is already `true` by the time the user reaches the Program tab (the primer writes it on dismissal), so the cue would never show. Start unset; the cue shows while it is unset.
- **Show condition:** the flag is unset **and** the Øvelser segment is showing its teaching empty state (no exercises). Only on the Øvelser "Ny øvelse" FAB — never on the Spill "+" FAB or any other segment, even if the user switches to an empty segment.
- **Dismissal (one-way, permanent):** set the flag `true` and remove the pill for good when the user (a) taps the pill, or (b) creates anything (the first exercise). After dismissal it never returns, on any segment. Tapping the pill should also open the create-exercise flow (it sits on the FAB, so the natural behaviour is "act like the FAB"), or simply dismiss and let the user press the FAB — decide and note it, but a tap must not leave the pill on screen.
- New `nb` / `en` localization key for the pill label.

**Out of scope (do not touch):**

- **No Help / FAQ** (stage 5) and **no notification priming** (stage 6).
- **No change to the primer, the example plan, the seen flag, or the teaching empty states.** Stage 4 only adds the cue on top of what stage 1–3 built.
- **No overlay / coachmark / tooltip / scrim.** Inline pill only. (Per the spec: if review finds even this too tutorial-like, the empty-state copy carries the path alone and the pill is dropped — so keep it cheap to remove.)
- **No new persistence mechanism.** `shared_preferences` is already a dependency and already holds `keyOnboardingSeen`; add the sibling key the same way.
- **No data-model fields, no codegen** beyond the l10n regeneration that editing the `.arb` files triggers.

## Ground rules

Read `AGENTS.md` and follow every numbered rule. The ones that bite here:

- **Localize every user-visible string.** Add the pill label to both `app_en.arb` and `app_nb.arb`; run `make build`.
- **CLI must stay Flutter-free.** Widget layer only.
- **Do not edit `*.freezed.dart`, `*.g.dart` or `app_localizations*.dart`.** Only `make build` regenerates l10n.
- **Mobile-safe imports.** No `dart:html` / `package:web`.
- **No new Sentry/analytics calls.**
- **Match existing Dart style.** No new lint suppressions without an inline reason.
- **Verify before claiming green.** `flutter analyze` and `flutter test` at the end of each step.

## Investigate before you wire (do this first, no commit)

1. **The first FAB.** `_buildExercisesFAB` (`lib/views/program_view.dart`, ~line 1158) returns the Øvelser FAB — `FloatingActionButton.extended` on medium/expanded, compact `FloatingActionButton` on phones — wired to `_navigateToCreateExercise`. The per-segment FAB is chosen in `buildFAB`/the segment switch (~line 1140–1156) and handed to the Scaffold's `floatingActionButton` slot. Work out where to wrap it so the pill sits beside it on **both** FAB variants without overlapping the list (the compact FAB already exists because the extended one covers list rows on phones — keep the pill clear of the same rows).
2. **Empty-Øvelser detection.** How the Øvelser segment decides it is empty (it renders `TeachingEmptyState` via `emptyExercises*` keys). The cue's show condition must match "Øvelser empty", and the active segment is tracked via the program page controller's `activeSegment` (see `MainScreen.initState` listening to `activeSegment`).
3. **"Created anything" signal.** `ProgramService` emits events (e.g. `ProgramEvent.added` / `programCreated` — confirm the exact type in `lib/services/program_service.dart`). Use the first-exercise-created event to set the flag, so the pill also clears if the user creates via the FAB without tapping the pill.
4. **Reading/writing the flag.** Boot reads `keyOnboardingSeen` in `lib/main.dart`; runtime writes use `SharedPreferences.getInstance()` (as `ConceptPrimerScreen._dismiss` does). Decide whether the cue's visibility is a captured bool read once when the Program tab mounts, or a small `ValueNotifier<bool>` — it only needs to flip off, never on, so a one-shot read plus local state is enough.

Append a short note of what you found to `docs/prompts/DESIGN-007-stage-4-handoff.md` (create it) before step 1.

### Recommended approach (adopt unless investigation shows a cheaper path)

Read `keyStartHereSeen` once when the Program tab mounts into local state. Build a `StartHerePill` widget (small rounded label, colours from `ColorScheme`, an arrow/`Icons.arrow_downward`-style hint optional). In the FAB region, when the flag is unset and the active segment is Øvelser-empty, return the FAB wrapped with the pill adjacent (a `Column`/`Row` with `mainAxisSize: min`); otherwise return the bare FAB. Tapping the pill calls the same create path as the FAB and sets the flag; a `ProgramService` create event also sets it. Once set, `setState` drops the pill and it never rebuilds in.

## Copy

| Key (suggested) | `nb` | `en` |
|---|---|---|
| `startHereCue` | Start her | Start here |

## Commits

Conventional Commits, scope `onboarding`. One commit per step, `git status` clean between steps (commit every changed file each step, including the regenerated l10n and any test files). Do not squash.

## Steps

### Step 1 — `feat(onboarding)`: `keyStartHereSeen` flag + `StartHerePill` widget + l10n

Add `AppConfig.keyStartHereSeen`, the pill label keys, and a `StartHerePill` widget covered by a minimal render check (light + dark, no exceptions). Run `make build`. Not wired into the FAB yet.

Gates green. Commit.

### Step 2 — `feat(onboarding)`: show the cue on the first FAB and dismiss it

Show `StartHerePill` beside the Øvelser "Ny øvelse" FAB when `keyStartHereSeen` is unset and the Øvelser segment is empty. Tapping it opens the create-exercise flow and sets the flag; the first exercise created (via the FAB or the pill) also sets the flag. Once set, the pill is gone for good, on every segment. No pill on Spill or other FABs.

Gates green. Commit.

### Step 3 — `test(onboarding)`: cover the cue's show, hide, and dismissal

Widget tests under `test/`: the pill shows on the Øvelser FAB when the flag is unset and Øvelser is empty; it does not show when the flag is set, when Øvelser has exercises, or on the Spill segment; tapping it writes the flag and removes the pill; creating the first exercise writes the flag. Reuse the harness style in `test/views/concept_primer_screen_test.dart` (mock prefs, `ProgramService().init()`).

Gates green. Commit.

## When you finish or get stuck

- Append a closing entry to `docs/prompts/DESIGN-007-stage-4-handoff.md` with the final key name, the pill's tap behaviour, and where it is anchored.
- Off-scope findings go to `docs/prompts/DESIGN-007-followups.md` (one line each). New defects become their own numbered follow-up, not extra steps here ([[feedback_new_findings_own_prompt]]).
- If a step is blocked by an ambiguous spec or unmet precondition, stop and write a one-paragraph note to `docs/prompts/DESIGN-007-stage-4-blockers.md`, then exit rather than guessing.
- Smoke-test a fresh install: clear `shared_preferences` (or `Upgrader.clearSavedSettings` in debug), launch, pick "Start en tom plan", confirm the "Start her" pill sits on the Øvelser FAB, and that it disappears for good after the first exercise is created (and stays gone on relaunch), before pushing.

## Note on remaining stages

Stage 5 (Help / FAQ) and stage 6 (notification priming) are deliberately deferred and out of scope here. Do not start them, and do not leave scaffolding for them beyond what already exists.
