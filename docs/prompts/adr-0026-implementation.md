# Implement ADR-0026

You are working in the RingDrill repository. Implement ADR-0026 ("Replace push-navigation between station/team/role detail screens with replace-semantics bottom sheets") end-to-end. The ADR lives at `docs/adrs/0026-sheet-based-context-navigation.md` and is **Accepted**. It is the authoritative spec for navigation grammar, sheet semantics, the sites being changed and the Brief copy-to-share link.

This prompt covers ADR-0026 only. The standalone fullscreen Brief viewer is documented in the ADR as future work and is **not** in scope here. The Copy action's appended viewer link **is** in scope.

If you find defects outside ADR-0026 scope (e.g. a misrendered station label, an l10n drift), record them at the end as follow-ups. Do not bundle.

## Ground rules

Read `AGENTS.md` and follow every numbered rule. The non-negotiable ones for this change:

* `ContextSheet`, its controller and the sheet container are view-layer only. They live under `lib/views/widgets/` and do not leak into `lib/services/`, `lib/models/`, `lib/data/`, `bin/` or `netlify/`.
* CLI must stay Flutter-free. Nothing this prompt touches is imported from `bin/ringdrill.dart` or `lib/data/drill_client.dart`.
* Mobile-safe imports. The sheet is reachable on every platform including web. No `dart:html` or `package:web` in any code path this prompt touches.
* No third-party state-management or routing library beyond GoRouter ([ADR-0004](../adrs/0004-no-third-party-state-management.md)). The controller is an `InheritedNotifier` plus a small `ValueNotifier`.
* Localize every user-visible string. The visible labels added in this round are listed under each step that introduces them. Norwegian translations are listed alongside.
* `test/widget_test.dart` is the known-broken default-template smoke test. Flag it as such at the end, never claim "all tests pass".

## Commits

Five logical commits, in order, on the same working branch. Use Conventional Commits with scope `nav` for steps 1, 2, 3, 4 and `brief` for step 5. Allowed types from history: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`. Suggested subjects:

1. `feat(nav): add ContextSheet controller and sealed sheet targets`
2. `feat(nav): mount ContextSheet in MainScreen and fold in BriefSheetLauncher`
3. `refactor(nav): route station, team and role taps through ContextSheet`
4. `refactor(nav): keep deep links opening the right sheet on the right tab`
5. `feat(brief): append viewer link to copied brief markdown`

### Commit discipline (non-negotiable)

A recurring failure mode in past rounds has been agents leaving regenerated files, new test files, l10n changes or one-off scratch files uncommitted in the working tree. Avoid this:

* After every step, run `git status` and `git diff --stat` and confirm there are no untracked or unstaged paths before claiming the step done. Untracked files count as failure.
* Each step lists the **files expected in that commit**. The commit must include every listed path. Anything beyond the list also belongs in the commit unless explicitly punted. If you see a path you do not recognize in `git status`, inspect it; do not delete it.
* Regenerated files from `make build` (`app_localizations*.dart`) are part of the commit that triggered them. Do not park them in a "regen" follow-up commit.
* Never close a step with `git stash` or `git restore`. If something is in the working tree, it ships with the commit.
* The final Verification gate requires `git status` to print a clean tree on the working branch with no untracked or unstaged files. The work is not done until this is true.

## Scope

Five steps. Do them in order. Each step is one commit.

### Step 1. `ContextSheet` controller and targets

Create `lib/views/widgets/context_sheet.dart`. Public shape:

```dart
sealed class ContextSheetTarget { const ContextSheetTarget(); }
class StationSheetTarget extends ContextSheetTarget {
  const StationSheetTarget({required this.exerciseUuid, required this.stationIndex});
  final String exerciseUuid;
  final int stationIndex;
}
class TeamSheetTarget extends ContextSheetTarget {
  const TeamSheetTarget({required this.exerciseUuid, required this.teamIndex});
  final String exerciseUuid;
  final int teamIndex;
}
class RoleSheetTarget extends ContextSheetTarget {
  const RoleSheetTarget({required this.rolePlayUuid});
  final String rolePlayUuid;
}
class BriefSheetTarget extends ContextSheetTarget {
  const BriefSheetTarget({this.programUuid, this.exerciseUuid, this.audience});
  final String? programUuid;
  final String? exerciseUuid;
  final BriefAudience? audience;
}

class ContextSheetController {
  void show(BuildContext context, ContextSheetTarget target);
  void replace(ContextSheetTarget target);   // asserts a sheet is open
  void close();
  ValueListenable<ContextSheetTarget?> get target;
}

class ContextSheet extends InheritedNotifier<ValueNotifier<ContextSheetTarget?>> {
  static ContextSheetController of(BuildContext context);
}
```

`ContextSheetController.show`:

* If no sheet is open, calls `showModalBottomSheet<void>(context: context, isScrollControlled: true, useSafeArea: true, backgroundColor: Colors.transparent, builder: ...)` with a `_ContextSheetHost` widget that listens to the controller's `target` and rebuilds its inner body when the target changes. The sheet itself does **not** animate dismiss/open on replace. After `await showModalBottomSheet`, the controller resets `target` to `null` and clears its open-state flag.
* If a sheet is already open, just updates the `ValueNotifier`. The `_ContextSheetHost` cross-fades between bodies in 120 ms (`AnimatedSwitcher`).

`_ContextSheetHost` resolves each target to its body widget:

* `StationSheetTarget` → existing `StationExerciseScreen` content extracted into a `StationSheetBody` widget that does not own a `Scaffold`.
* `TeamSheetTarget` → existing `TeamExerciseScreen` content extracted similarly.
* `RoleSheetTarget` → existing `RolePlayScreen` content extracted similarly.
* `BriefSheetTarget` → the body the existing `BriefSheetLauncher` builds today (folded in fully in Step 2).

Sheet chrome (drag handle, close X, slim app bar) mirrors the Brief sheet from [ADR-0023](../adrs/0023-brief-theme-tokens.md). Each `*SheetBody` widget supplies its own title and trailing actions slot; the host renders the chrome around them.

Wide-screen layout. When `MediaQuery.sizeOf(context).width >= 600`, the host wraps the body in `Center(child: ConstrainedBox(maxWidth: 720, child: ...))`. Below 600 px, the body fills the width.

Add unit/widget tests at `test/views/widgets/context_sheet_test.dart`:

* `show` opens a sheet whose body matches the initial target.
* `replace` from inside an open sheet swaps the body without dismissing the route (assert the `ModalBottomSheetRoute` is the same instance before and after).
* `close` dismisses the sheet and resets `target` to `null`.
* `show` after `close` opens a new sheet.

Files expected in this commit:

* `lib/views/widgets/context_sheet.dart`
* `test/views/widgets/context_sheet_test.dart`

No call sites change yet. The new controller has zero callers after this commit — that is intentional.

Run `git status`. Commit: `feat(nav): add ContextSheet controller and sealed sheet targets`.

### Step 2. Mount the controller and fold in `BriefSheetLauncher`

Edit `lib/views/main_screen.dart`:

* Wrap the `Scaffold` returned from `MainScreen.build` in a `ContextSheet` `InheritedNotifier` whose controller is held as a `late final` field on `_MainScreenState`. Dispose it in `dispose()`.
* The `/brief/:exerciseUuid` and `/brief/program/:programUuid` route definitions stay where they are, but their `pageBuilder` returns a transparent `CustomTransitionPage` whose `child` is a `_BriefDeepLinkLauncher` that, on first frame, calls `ContextSheet.of(context).show(BriefSheetTarget(...))` and pops the launcher route when the sheet closes. The old `BriefSheetLauncher` widget is deleted; its sheet body is moved into the `BriefSheetTarget` branch of `_ContextSheetHost` in Step 1's host file.

Edit `lib/views/brief_screen.dart`:

* Extract the body the old `BriefSheetLauncher` rendered into a reusable `BriefSheetBody` widget that takes `programUuid` / `exerciseUuid` / `audience` and renders the existing slim app bar + reading column. Wire it into `_ContextSheetHost`'s `BriefSheetTarget` branch from Step 1.
* `BriefScreen` (the routed widget) stays in place for any in-test direct usage but is no longer reached from the running app. Add a `// ignore: deprecated_member_use_from_same_package`-style comment if needed, but do not delete it in this step.

Manually QA: with no other call-site changes yet, the Brief still works end-to-end through `/brief/...` deep links. Open the brief from `CoordinatorScreen`'s brief action; confirm it sheet-presents identically to before.

Files expected in this commit:

* `lib/views/main_screen.dart`
* `lib/views/brief_screen.dart`
* `lib/views/widgets/context_sheet.dart` (host gains `BriefSheetTarget` branch)
* `test/views/widgets/context_sheet_test.dart` (brief target case)

Run `git status`. Commit: `feat(nav): mount ContextSheet in MainScreen and fold in BriefSheetLauncher`.

### Step 3. Route station, team and role taps through `ContextSheet`

This step removes every internal `context.push`/`Navigator.push` to a station, team or role detail and replaces it with a `ContextSheet.of(context).show(...)` or `.replace(...)`. The deep-link routes themselves stay in place; they are wired in Step 4.

Concrete edits, by file:

**`lib/views/station_list_view.dart`** — the tap at line ~369 calls `ContextSheet.of(context).show(StationSheetTarget(...))` instead of `context.push('$routeStations/...')`. Keep the `Navigator.push<Station>` at line ~376 (form push) as-is.

**`lib/views/stations_view.dart`** — three sites:

* Line ~179, the role cross-link: `ContextSheet.of(context).show(RoleSheetTarget(rolePlayUuid: rp.uuid))`.
* Line ~656 and ~669, the marker / list taps: `ContextSheet.of(context).show(StationSheetTarget(...))`.

**`lib/views/teams_view.dart`** — line ~67, team tap: `ContextSheet.of(context).show(TeamSheetTarget(...))`.

**`lib/views/roleplays_view.dart`** — line ~457, role tap: `ContextSheet.of(context).show(RoleSheetTarget(rolePlayUuid: rolePlay.uuid))`.

**`lib/views/team_screen.dart`** — the raw `Navigator.push` at lines 67–90 is removed entirely along with the surrounding comment block. Replace it with `ContextSheet.of(context).replace(StationSheetTarget(exerciseUuid: exercise.uuid, stationIndex: stationIndex))`. The whole "Pure Navigator.push on purpose ... cross GoRouter branches" comment is dissolved by the new model; do not preserve it.

**`lib/views/station_screen.dart`** — the cross-reference taps (the role list around line ~415 and any team cross-references) switch to `ContextSheet.of(context).replace(...)`. The `Navigator.push<RolePlay>` at line ~399 / ~478 (role form push from inside the station) stays as a form push.

**`lib/views/coordinator_screen.dart`** — line ~932 (the station description `InkWell`) and line ~1148 (whichever station/team affordance lives there) call `ContextSheet.of(context).show(StationSheetTarget(...))` / `show(TeamSheetTarget(...))`. The `context.push('$routeBrief/${widget.uuid}')` at line ~257 stays unchanged; deep-link entry into `/brief` still works and is the canonical way to open the brief.

**`lib/views/program_view.dart`** — the `context.push('$routeProgram/${exercise.uuid}')` at line ~129 is **not** changed. `CoordinatorScreen` is a full surface, not a sheet target.

Audit pass. Run `grep -rn "context.push\|Navigator.push" lib/views/` and walk every remaining call. Confirm each is either:

* A form push (`station_form_screen.dart`, `exercise_form_screen.dart`, `actor_form_screen.dart`, `roleplay_form_screen.dart`, settings) — keep as-is.
* A navigation to `CoordinatorScreen` from `ProgramView` — keep as-is.
* The brief deep-link push — keep as-is.

Any other push is a bug introduced by this step or a missed migration. Fix it before commit.

Audit pass 2. Run `grep -rn "ModalRoute.of(context)" lib/views/` and walk every result. Any code that calls `.canPop` on a station / team / role detail surface needs revision since those surfaces are no longer routes; record exact line + fix or, if non-trivial, list as a follow-up.

Tests. Update or add widget tests under `test/views/` so:

* Tapping a row in `StationListView` opens a sheet, not a new route. Assert no new `MaterialPageRoute` for the station detail is pushed; assert a `ModalBottomSheetRoute` appears.
* Same for `TeamsView` and `RolePlaysView`.
* From an open station sheet, tapping a role cross-reference replaces the sheet body without dismissing the route (no `ModalBottomSheetRoute` pop).
* From the team sheet, tapping a station replaces the body. This is the cycle the old code produced; assert it does not produce a second push.

Files expected in this commit:

* `lib/views/station_list_view.dart`
* `lib/views/stations_view.dart`
* `lib/views/teams_view.dart`
* `lib/views/roleplays_view.dart`
* `lib/views/team_screen.dart`
* `lib/views/station_screen.dart`
* `lib/views/coordinator_screen.dart`
* Any widget tests under `test/views/` that touched the above

Run `git status`. Commit: `refactor(nav): route station, team and role taps through ContextSheet`.

### Step 4. Deep links open the right sheet on the right tab

Edit `lib/views/main_screen.dart` GoRouter setup. For each detail path:

* `/stations/:exerciseId/:stationIndex` → builder switches the tab to `routeStations`, then on first frame calls `ContextSheet.of(context).show(StationSheetTarget(...))`.
* `/teams/:teamIndex` → builder switches the tab to `routeTeams` and shows `TeamSheetTarget(...)`. The route still needs the `exerciseUuid`; resolve it from `ProgramService().activeProgram` the same way `TeamExerciseScreen` does today.
* `/roleplays/:roleUuid` → builder switches the tab to `routeRolePlays` and shows `RoleSheetTarget(rolePlayUuid: ...)`.

The pattern matches what the `/brief/...` routes do post-Step 2: a `_DeepLinkLauncher` widget that schedules a post-frame callback, calls the controller, and pops itself when the sheet closes.

Internal navigation does **not** update the URL when a sheet replaces. Only deep-link entry and tab switch change the URL. Confirm this with a test: `show` from inside the app does not change `GoRouterState.of(context).matchedLocation`; navigating to `/teams/2` from outside does.

Edit `lib/views/app_routes.dart`. Update the doc comments on `routeStations`, `routeTeams`, `routeRolePlays` to clarify that the `:...` subpaths are deep-link-only entry points that open a `ContextSheet`. Internal callers go through the controller, not `context.push`.

Tests. Add `test/views/deep_link_sheet_test.dart`:

* Navigate to `/stations/<exerciseUuid>/<stationIndex>`; assert the Stations tab is selected and a `ModalBottomSheetRoute` is on the stack with a station body.
* Navigate to `/teams/<teamIndex>`; assert Teams tab + team body.
* Navigate to `/roleplays/<roleUuid>`; assert RolePlays tab + role body.
* From an open station sheet, call `controller.replace(RoleSheetTarget(...))`; assert `GoRouterState.matchedLocation` is unchanged.

Files expected in this commit:

* `lib/views/main_screen.dart`
* `lib/views/app_routes.dart` (doc comments only)
* `test/views/deep_link_sheet_test.dart`

Run `git status`. Commit: `refactor(nav): keep deep links opening the right sheet on the right tab`.

### Step 5. Brief copy action appends a viewer link

Edit the Brief sheet body (post-Step 2 `BriefSheetBody` in `lib/views/brief_screen.dart`).

The Copy action (the existing button that copies the rendered brief markdown to the clipboard) appends a footer to the copied text:

```
\n\n→ {viewerUrl}
```

where `viewerUrl` is built from the current target:

* For an exercise brief: `https://ringdrill.app/brief/<exerciseUuid>?audience=<audience>`.
* For a program brief: `https://ringdrill.app/brief/program/<programUuid>?audience=<audience>`.

`<audience>` is the current `BriefAudience` (`participant`, `instructor` or `director`) serialized as its lowercase id, matching the existing `BriefAudience.id` convention.

The base URL `https://ringdrill.app` is **not** hardcoded inline. Add a single constant in `lib/utils/app_config.dart` (or wherever the existing share-link base lives — search for `ringdrill.app` first; reuse if found, do not duplicate). The constant name: `briefViewerBaseUrl`.

Localization. The `→` arrow stays untranslated. Add a single new ARB key for any visible status the action surfaces (e.g. snackbar text on copy). If an existing `briefCopied` key is already used, reuse it; if not, add `briefCopiedWithLink` → `"Copied — recipients can read the brief at the link"` / `"Kopiert — mottakere kan lese briefen via lenken"`. Search the ARB files first; do not add a duplicate.

Run `make build` to regenerate `app_localizations*.dart` if any new ARB key is introduced.

Tests. Add `test/views/brief_copy_link_test.dart`:

* For a `BriefSheetTarget(exerciseUuid: 'abc', audience: BriefAudience.participant)`, the Copy action puts text ending in `→ https://ringdrill.app/brief/abc?audience=participant` on the clipboard.
* For a `BriefSheetTarget(programUuid: 'xyz', audience: BriefAudience.director)`, the copied text ends in `→ https://ringdrill.app/brief/program/xyz?audience=director`.
* The markdown body above the footer matches what was rendered (one whole-document snapshot is enough; do not assert per-line content).

Files expected in this commit:

* `lib/views/brief_screen.dart` (copy action)
* `lib/utils/app_config.dart` (or wherever the share-link base lives) — only if a new constant is added
* `lib/l10n/app_en.arb`, `lib/l10n/app_nb.arb` — only if a new key is added
* `lib/l10n/app_localizations.dart`, `lib/l10n/app_localizations_en.dart`, `lib/l10n/app_localizations_nb.dart` (regenerated) — only if a new key is added
* `test/views/brief_copy_link_test.dart`

Run `git status`. Regenerated localization files MUST be in this commit, not a follow-up. Commit: `feat(brief): append viewer link to copied brief markdown`.

## Verification

1. `flutter analyze` is clean.
2. `flutter test` produces no new failures. `test/widget_test.dart` remains broken (default counter template). Do not try to fix it. Report it as known-broken in the final write-up.
3. `make build` completes cleanly. Re-run `git status` after it. If any regenerated file is suddenly dirty after analyze and test passed, that file was missing from an earlier commit. Stop and amend the relevant commit before continuing.
4. **Clean tree gate.** `git status` on the working branch prints `nothing to commit, working tree clean`. `git ls-files --others --exclude-standard` prints nothing. No untracked, no unstaged, no stashed work. The work is not done until this is true. Do not invoke `git stash` or `git restore` to satisfy it.
5. **Diff sanity.** Run `git log --stat origin/main..HEAD` and walk every changed path. Confirm each file appears in exactly the commit you intended.
6. Manual QA matrix. Record results in the final commit body:
   * **Stations tab.** Open a station from the list; sheet appears on top of the Stations tab. Tap a role cross-reference inside the sheet; body replaces without animating dismiss/open. Tap Android back (or swipe down on iOS); sheet dismisses, tab returns to Stations.
   * **Teams tab.** Open a team. Tap a station listed inside it; body replaces. Tap another team listed elsewhere; body replaces. Back returns to Teams tab.
   * **RolePlays tab.** Open a role. Tap a station inside it; body replaces. Back returns to RolePlays.
   * **Coordinator tab.** Tap a station description; station sheet opens on top of `CoordinatorScreen` (Program tab). Tap a team inside; replaces. Back returns to coordinator.
   * **Map tab.** Tap a station marker; same sheet appears as from the list. Tap a role marker; role sheet appears. Replace works across both.
   * **Brief.** Open the brief from `CoordinatorScreen`. Confirm it still presents identically to before. Tap Copy; paste the clipboard into a scratch buffer; confirm the trailing `→ https://ringdrill.app/brief/<uuid>?audience=<a>` line is present and well-formed for both exercise and program briefs and for all three audiences.
   * **Deep links.** Cold-start the app and open `/teams/2`; lands on Teams tab with team sheet open. Same for `/stations/<uuid>/<i>` and `/roleplays/<uuid>` and `/brief/...`. Internal `replace` does not change the URL (verify with `flutter run --observatory` and the debug URL display).
   * **Wide screen.** Resize to ≥ 600 px. Sheet centres and constrains to 720 px max width. Tab switch in the nav rail dismisses the sheet first.
7. No follow-up defects bundled in. If during the work you found anything that does not fit the five steps, record it at the bottom of the final commit body under a `## Follow-ups` heading and create a fresh prompt file under `docs/prompts/` named `adr-0026-followup-NN-<slug>.md` for each. Do not silently bundle.

## Out of scope

Everything below is **not** in this round, even if tempting:

* The standalone fullscreen Brief viewer. ADR-0026 documents it as future work that reuses the `/brief/...` URL. The shareable link is wired now, the standalone viewer is a separate prompt later.
* Form pushes (`station_form_screen.dart`, `exercise_form_screen.dart`, `actor_form_screen.dart`, `roleplay_form_screen.dart`, settings) — they stay as pushed routes.
* The full-player overlay (DESIGN-001) — stays push/back.
* `ProgramView` → `CoordinatorScreen` navigation — stays push.
* Renaming or relocating files under `lib/views/`. [[file grouping is deferred]] per the existing convention.
* Re-theming the sheet chrome. The slim bar and drag handle from ADR-0023 are reused as-is.

## Deliverables

Five Conventional Commits as outlined above, all on the same working branch, with a clean tree at the end. The final commit body should include:

* A one-line summary of what now feels different in navigation (no more cycle, single sheet at a time).
* The manual QA matrix filled out.
* A `## Follow-ups` section, even if empty.

ADR-0026 is the authoritative spec. If you find yourself contradicting it, stop and ask. Do not write a new ADR.
