# Follow-up 01: Collapse viewer-sheet header into the body's AppBar

ADR-0027 as implemented gives every viewer-variant sheet two stacked headers and two close-ish affordances: a slim helper header with `Icons.close` on top of each body's own AppBar with `Icons.arrow_back`. ADR-0027 has been amended (see its `## Revisions` section dated 2026-05-28) to drop the helper header entirely and move the close affordance into each body's existing AppBar.

This follow-up implements that amendment.

## Order of work

One commit. Conventional Commits with scope `sheet`. Suggested subject: `refactor(sheet): collapse viewer header into body AppBar`.

1. **Helper drops its header row.** In `lib/views/widgets/ringdrill_sheet.dart`:
   * Remove the `title`, `actions` and `onClose` parameters from `showRingdrillViewerSheet`.
   * Remove the slim header row (title + actions + close-X) that sits below the drag-handle. The viewer variant now renders only: drag-handle pill, then the body builder's result.
   * Drag-handle pill, surface, corners and `DraggableScrollableSheet` are unchanged.

2. **Each viewer body's AppBar swaps back-arrow for close-X.** In each of:
   * `lib/views/station_screen.dart` (`StationExerciseScreen`, around line 93)
   * `lib/views/team_exercise_screen.dart` (around line 36)
   * `lib/views/roleplay_screen.dart` (around lines 53 and 61)
   * `lib/views/brief_screen.dart` (`BriefSheetBody`'s slim AppBar built around line 226 — note this is the body version, not the route version at line 155/168 which is no longer reachable post-ADR-0026 but still has tests against it; leave the route version alone)

   Add `leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context), tooltip: localizations.close)` (or the equivalent named `closeSheet` if that's already in the ARB; reuse, do not duplicate).

   `Navigator.pop(context)` works in both contexts: it pops the modal sheet route the body is hosted in, and (for the brief's still-existing route version) the route itself.

3. **ContextSheet host call site.** In `lib/views/widgets/context_sheet.dart`, the call to `showRingdrillViewerSheet` loses its `title: ...`, `actions: ...` and `onClose: ...` arguments if any were passed. The host returns to its minimal shape: builder that builds the resolved body, nothing else.

4. **Localization.** If a new `close` / `closeSheet` ARB key is needed, add it to both `lib/l10n/app_en.arb` and `lib/l10n/app_nb.arb`:
   * `closeSheet` → `"Close"` / `"Lukk"`

   First grep for existing `close` / `Lukk` keys; reuse whichever already exists. Run `make build` only if a new key is added.

5. **Tests.** Update any widget tests that asserted the helper's header existed:
   * `test/views/widgets/ringdrill_sheet_test.dart` — drop the "viewer renders close-X" assertion; add a positive assertion that the viewer renders only the drag-handle pill above the body builder's output.
   * `test/views/widgets/context_sheet_test.dart` — close test now taps the close-X inside the body's AppBar (find by tooltip or by widget type + position), not at the helper level.
   * Any tests under `test/views/` that pump a station/team/role/brief sheet and tap a close-X may need the finder updated to look inside the body's AppBar.

## Files expected in this commit

* `lib/views/widgets/ringdrill_sheet.dart`
* `lib/views/widgets/context_sheet.dart`
* `lib/views/station_screen.dart`
* `lib/views/team_exercise_screen.dart`
* `lib/views/roleplay_screen.dart`
* `lib/views/brief_screen.dart`
* `lib/l10n/app_en.arb`, `lib/l10n/app_nb.arb` (only if a new key is introduced)
* `lib/l10n/app_localizations*.dart` (regenerated; only if a new key is introduced)
* `test/views/widgets/ringdrill_sheet_test.dart`
* `test/views/widgets/context_sheet_test.dart`
* Any other test files touched

Run `git status` and confirm a clean tree before commit.

## Verification

1. `flutter analyze` clean.
2. `flutter test` no new failures.
3. `git status` prints `nothing to commit, working tree clean`. No `git stash` / `git restore`.
4. Manual QA. Open a station, team, role and brief sheet. Each shows: drag-handle pill on top, then the body's AppBar with an X on the left (no back-arrow), title in the middle, and the body's normal trailing actions on the right. Tap the X; sheet closes. No second close affordance anywhere on the sheet.

## Out of scope

* The action variant (`showRingdrillActionSheet`) is unchanged. Action sheets never had a header row.
* The `BriefScreen` route version (`lib/views/brief_screen.dart` lines 155/168 area) is not reached from the app post-ADR-0026 but stays as-is for tests.
