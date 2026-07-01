# Pull-to-refresh: which lists need it, and which do not

**Date:** 2026-07-01

## Context

Concern raised that "we have quite a few lists now that do not support drag
to reload". We audited every scrollable list in `lib/views` to decide where a
`RefreshIndicator` actually adds value, rather than adding it everywhere.

## What we found

The list architecture is stream-driven. Most list views subscribe to
`ProgramService.events` and/or `ExerciseService.events` (some via
`StreamBuilder`) and rebuild themselves when local data changes. For those,
pull-to-refresh has no real "re-fetch from source" operation to trigger — it
would only re-read the same local files and show the same data.

The lists worth distinguishing:

**Backed by external data (pull-to-refresh is meaningful)**

* `lib/views/widgets/catalog_browser.dart` — the online catalog feed. Already
  has a `RefreshIndicator` (`catalog_browser.dart:112`) plus a manual refresh
  button in the footer. This is the reference pattern.
* `lib/views/library_view.dart` — "My Plans" (ListView ~147-199). The one real
  gap. Catalog-installed plans can change server-side (wiki model), and today
  the only refresh path is the hidden long-press action `refreshCatalogItem`
  (`library_view.dart:446-470`). A `RefreshIndicator` here would fit user
  expectations for a library screen.

**Stream-driven, local-only (pull-to-refresh not useful today)**

* `program_view.dart` (exercises)
* `station_list_view.dart` (stations)
* `roster_view.dart` (actors)
* `teams_view.dart` (teams)
* `roleplays_view.dart` (roles)
* `team_screen.dart` and `team_exercise_screen.dart` (via `StreamBuilder`)

**No external source at all (never a candidate)**

* `settings_page.dart` (SharedPreferences)
* Short-lived sheets and dialogs: `add_exercises_dialog.dart`,
  `exercise_picker_sheet.dart`, `cast_picker_sheet.dart`,
  `cast_roster_sheet.dart`

## Implications

* We deliberately did **not** add pull-to-refresh anywhere in this pass.
  "My Plans" was the only reasonable candidate, and we chose to leave it as-is
  for now.
* When shared/public sync lands (ADR-0024/0025), the program, roster and teams
  lists become genuine pull-to-refresh candidates, because their data can then
  change from another device. Revisit at that point, not before.
* If we ever do add it, copy the `catalog_browser.dart` pattern
  (`RefreshIndicator` + a footer refresh affordance) rather than inventing a
  new one.

## Related

* [ADR-0024/0025](../adrs/) — Account+Identity model, source of future
  shared/public sync
* `lib/views/widgets/catalog_browser.dart` — the existing pull-to-refresh
  reference implementation
