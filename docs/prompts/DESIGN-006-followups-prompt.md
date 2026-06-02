You are working in the RingDrill repository. Implement the **DESIGN-006 follow-ups**: a set of independent enhancements and hardening fixes surfaced while building the program-tab consolidation. The authoritative context is:

- `docs/design/006-program-tab-consolidation.md` (DESIGN-006, Accepted) — the consolidated Program tab, the segments, the contextual FAB/actions, and the Roster layer.
- `docs/design/brief-template.md` (DESIGN-004, Accepted) — `BriefAudience` (`participant`/`instructor`/`director`, nb "Deltaker"/"Veileder"/"Øvelsesleder") and where the audience selector lives.
- `docs/prompts/DESIGN-006-followups.md` — the running list these steps formalize.

Read DESIGN-006 and the followups list before starting. Skim DESIGN-004 for the audience model and ADR-0018/ADR-0019 for the role-axis distinctions. If this prompt contradicts a spec, the spec wins; stop and ask.

These are **post-consolidation** enhancements. Stages 1 and 2 (the segmented Program tab and the program-scoped routing / nav collapse) have already landed as one release unit. Each step below is additive and main-safe on its own, so they can be done in any order, cherry-picked, or split across sessions. They are **not** a single feature.

## Ground rules

Read `AGENTS.md` and follow every numbered rule. The ones that bite here:

- **Localize every user-visible string.** New labels go in both `app_en.arb` and `app_nb.arb`. Norwegian terminology: roles are "Markører" (segment/roster), "Rolle"/"Markørordre" and "Markør" per the project rule; brief audiences are "Deltaker"/"Veileder"/"Øvelsesleder".
- **CLI must stay Flutter-free.** Widget-layer work only.
- **Mobile-safe imports.** No `dart:html` / `package:web`.
- **No new Sentry/analytics calls.**
- **Do not edit `*.freezed.dart`, `*.g.dart` or `app_localizations*.dart`.** None of these steps need codegen.
- **Match existing Dart style.** No new lint suppressions without an inline reason.
- **Verify before claiming green.** `flutter analyze` and `flutter test` at the end of each step.

## Commits

Conventional Commits with a scope. One commit per step, `git status` clean between steps. Do not squash steps. Off-scope findings go to `docs/prompts/DESIGN-006-followups.md` (one line each) and new defects become their own numbered follow-up rather than extra steps here.

## Steps

### Step 1 — `fix(widget)`: drop fixed hero tags on the filter FABs

`station_list_view.dart` (`_buildFilterFab`, ~line 241) and `roleplays_view.dart` (~line 212) build a `FloatingActionButton` with a fixed `heroTag` (`'stationFilter'` / `'rolePlayFilter'`). When two instances of a view were mounted at once (the stage 1 transitional state), a `PageRoute` push scanned the hero subtree and hit "multiple heroes that share the same tag". Stage 2 removed the duplicate standalone tabs, so the collision is currently resolved, but the fixed global tag is fragile. Set `heroTag: null` on both filter FABs (these FABs do not fly to anything, so no animation is lost), matching the precedent already documented on the exercises FAB in `program_view.dart` (~line 713). If step 2 lands first and moves the roleplay filter off the FAB, this step only needs the station FAB.

Gates green. Commit.

### Step 2 — `feat(roleplay)`: add a "Ny rolle" FAB to the Markører segment

Today roles are created only from the Station screen (a DESIGN-003 non-goal). DESIGN-006 makes the Markører segment the home for roles, and its FAB table calls for a "Ny rolle" create action. Add it.

Catch to handle: `RolePlayFormScreen` is exercise-scoped. Its constructor is `RolePlayFormScreen({required rolePlay, this.exercise})`, the station dropdown is populated from `widget.exercise?.stations`, and there is **no** exercise picker. A `RolePlay` requires an owning `exerciseUuid` and an index (its `stationIndex` is nullable). So a create action from the cross-cutting Markører segment needs an exercise-selection step first.

Approach (lowest churn): the FAB opens a "pick exercise" sheet (reuse the exercise-list pattern), then opens the existing `RolePlayFormScreen` pre-scoped to that exercise with a blank `RolePlay` (new uuid, next index within that exercise's roles), reusing the same blank-`RolePlay` construction the Station screen does today. The station dropdown then works unchanged.

Free the FAB slot: the Markører segment currently shows the body filter FAB. Move filtering to an AppBar action (an icon with a `Badge.count` when active, keeping the existing banner + "Vis alle" recovery) so the FAB is the create action. This also retires the `rolePlayFilter` body FAB (covers the roleplay half of step 1).

Gates green. Commit.

### Step 3 — `fix(brief)`: default the brief audience to Øvelsesleder

The brief opens on `participant`. In practice only staff (øvelsesleder, veileder) use the app — there is no observed case of a participant using it themselves — so default the `BriefAudience` selector to `director` (full content). The PII in the director view is shown to trusted staff on the local device, which is acceptable. This is a small default change in the brief screen's initial audience state. If you are also doing step 4, fold this into it instead.

Gates green. Commit.

### Step 4 — `feat(settings)`: staff-only app-user role, driving the brief default

Add a small local preference for the role the device user holds. Because participants do not use the app, this is **staff-only**: Øvelsesleder and Veileder. `participant` remains a brief audience for export/print, not an app-user role. The selector's real job is gating actor PII: an Øvelsesleder default maps to the `director` brief audience (shows `realName`/`phone`), a Veileder maps to `instructor` (hides actor PII). Use the stored role to set the brief's default audience (subsumes step 3).

Keep the axes distinct and do not merge them: this app-user role is about who holds *this* device, separate from the Roster/Bemanning staffing of *other* people (DESIGN-006) and from the ADR-0019 session role (`coordinator`/`observer`/`roleplayer`). Store it as a local preference for now; it converges with the identity model (ADR-0024/0025) later.

Gates green. Commit.

## When you finish or get stuck

- Append a closing entry to a `docs/prompts/DESIGN-006-followups-handoff.md` (create on first use) summarizing what landed and what stayed open.
- If a step is blocked by an ambiguous spec, stop and write a one-paragraph note to `docs/prompts/DESIGN-006-followups-blockers.md`, then exit rather than guessing.
- These are additive and post-release-unit, so each may be pushed once green. There is no hold-for-release-unit rule here.

## Already resolved (context, do not redo)

For the agent's orientation, these earlier findings are already fixed and are listed so they are not re-opened:

- `RolePlaysController` was leaked in `MainScreen.dispose()` — fixed (`_rolePlaysController.dispose()` added).
- The segmented switcher wrapped the selected label — fixed (label-only segments, `showSelectedIcon: false`, `maxLines: 1`).
- AppBar titles were platform-inconsistent, the Program tab showed a duplicate subtitle, and the status badge sat left of the actions — fixed (`centerTitle: false` app-wide, secondary suppressed when equal to primary, badge pinned rightmost).
- The program-scoped routing redirect ran `setActive` inside an async redirect and tripped `RenderParagraph._scheduleSystemFontsUpdate` mid-frame — fixed (redirect made synchronous, activation deferred to a post-frame callback).
