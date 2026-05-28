---
status: accepted
date: 2026-05-28
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0028: Group `lib/views/` by feature and distribute shared domain widgets

## Context and problem statement

`lib/views/` has grown to 49 files at the top level plus 16 in `views/widgets/`. New features land several screen, form and view files next to unrelated ones, and `views/widgets/` mixes pure UI infrastructure with domain-specific widgets used by several features. Finding a file requires scanning the whole directory.

`lib/models/`, `services/`, `data/`, `utils/`, `web/` and `l10n/` are not under the same pressure. The pain is local to `lib/views/`.

## Decision drivers

* File discoverability inside `lib/views/`.
* Layout should mirror how ADRs and DESIGN documents already reason, per feature.
* Must not change `*.freezed.dart` / `*.g.dart` paths.
* CLI (`bin/ringdrill.dart`) must remain Flutter-free per [ADR-0005](./0005-cli-must-remain-flutter-free.md).

## Considered options

* **Option A: Status quo.** Rejected. Pain compounds with every new feature.
* **Option B: Type-first inside views (`screens/`, `forms/`, `dialogs/`, `widgets/`).** Rejected. The scaling problem reappears one level down inside `screens/`, and a single feature change touches many directories.
* **Option C: Full vertical slices (`lib/features/<feature>/{models,services,views}`).** Rejected. `Exercise` aggregate-roots the domain, so per-feature `models/` either duplicates types or creates feature-to-feature import edges. Also moves `*.freezed.dart` / `*.g.dart` paths and risks the build_runner pipeline.
* **Option D: Feature-first inside `lib/views/` only, with shared domain widgets distributed to feature folders. (chosen)**

## Decision outcome

Chosen option: **Option D**.

### New layout

```
lib/views/
  shell/        ← app frame and global navigation
  exercise/
  team/
  station/
  cast/         ← RolePlay + Actor (English umbrella; Norwegian UI stays "Markører")
  player/       ← coordinator + observer player and phase widgets
  library/
  brief/
  spatial/      ← map, position picking, UTM, lat/lng widgets
  settings/
  widgets/      ← pure UI infrastructure only
```

### File assignment

`shell/`
* `main_screen.dart`, `app_routes.dart`, `install_link_handler.dart`, `patch_alert_widget.dart`

`exercise/`
* `exercise_form_screen.dart`, `team_exercise_screen.dart`, `exercise_control_button.dart`

`team/`
* `team_screen.dart`, `teams_view.dart`, `team_station_widget.dart`

`station/`
* `station_form_screen.dart`, `station_screen.dart`, `stations_view.dart`, `station_list_view.dart`
* moved in from `views/widgets/`: `station_code_badge.dart`, `station_mini_map.dart`, `station_position_panel.dart`, `station_role_summary.dart`

`cast/`
* `roleplay_form_screen.dart`, `roleplay_screen.dart`, `roleplays_view.dart`, `actor_form_screen.dart`
* moved in from `views/widgets/`: `cast_picker_sheet.dart`, `cast_roster_sheet.dart`, `role_code_badge.dart`, `role_marker.dart`, `role_mini_map.dart`, `role_position_panel.dart`

`player/`
* `coordinator_screen.dart`, `program_view.dart`, `program_page_controller.dart`, `phase_headers.dart`, `phase_tile.dart`, `phase_widget.dart`

`library/`
* `library_view.dart`, `catalog_conflict_dialog.dart`, `add_exercises_dialog.dart`, `export_plan_dialog.dart`, `publish_plan_dialog.dart`, `plan_status_badge.dart`, `program_diff_widgets.dart`, `active_plan_actions.dart`

`brief/`
* `brief_screen.dart`
* moved in from `views/widgets/`: `brief_markdown.dart`, `brief_theme.dart`

`spatial/`
* `map_screen.dart`, `map_view.dart`, `map_picker_screen.dart`, `position_widget.dart`, `position_form_field.dart`, `latlng_widget.dart`, `utm_widget.dart`

`settings/`
* `about_page.dart`, `settings_page.dart`, `feedback.dart`

`widgets/`
* `context_sheet.dart`, `expandable_tile.dart`, `live_accent.dart`, `ringdrill_sheet.dart`, `page_widget.dart`, `platform_widget.dart`, `dialog_widgets.dart`, `open_file_widget.dart`, `shared_file_widget.dart`, `vertical_divider_widget.dart`

### Naming choices

* **`shell` not `app`.** The whole crate is the app, so `app/` is tautological. `shell` names what is in there (root navigation, install link handling, patch alerts).
* **`cast` not `roleplay`.** Covers both `RolePlay` (role definition) and `Actor` (person, PII-local) per [ADR-0018](./0018-roleplayer-data-model.md). `cast_picker_sheet` and `cast_roster_sheet` already use the term. Norwegian UI keeps "Markører" + "Rolle" + "Markør".
* **`spatial` not `geo` or `map`.** `geo` excludes UTM and pickers. `map` excludes coordinate input. `spatial` covers both.
* **One `widgets/`, not `common/` + `widgets/`.** Two folders both named for "shared widgets" is what created the drift. Pure UI infrastructure lives in `widgets/`. Anything domain-named lives with its domain.

### Ownership rule for shared widgets

A widget that names a domain concept (`station_*`, `role_*`, `cast_*`, `brief_*`) belongs in that feature folder, regardless of who imports it. Cross-feature imports follow the data model.

A widget belongs in `views/widgets/` only if it has no domain reference and could be lifted into any other Flutter project unchanged.

### Consequences

* Good: each feature is one directory. New screens land in an obvious place.
* Good: `views/widgets/` becomes coherent rather than a catch-all.
* Good: `models/`, `services/`, `data/` are untouched, so no `*.freezed.dart` / `*.g.dart` churn and no risk to the CLI Flutter-free boundary.
* Bad: ~65 file moves and several hundred import updates.
* Bad: in-flight branches touching `lib/views/` will conflict heavily during the cutover.

### Migration

* Single-PR refactor. Partial moves leave imports inconsistent.
* No `*.freezed.dart` / `*.g.dart` paths change, so `make build` is not required.
* `flutter analyze` and `flutter test` must pass before merging. The known-broken `test/widget_test.dart` smoke test stays excluded per [CLAUDE.md](../../CLAUDE.md).
* `bin/ringdrill.dart` and `netlify/functions/` are untouched.

## Links

* [ADR-0005](./0005-cli-must-remain-flutter-free.md), [ADR-0017](./0017-decouple-stations-from-rounds.md), [ADR-0018](./0018-roleplayer-data-model.md), [ADR-0019](./0019-roleplayer-participant-role.md), [ADR-0020](./0020-map-label-and-marker-clutter.md), [ADR-0023](./0023-brief-theme-tokens.md), [ADR-0026](./0026-sheet-based-context-navigation.md), [ADR-0027](./0027-unified-bottom-sheet-chrome.md).
* Related code: every file currently under `lib/views/`.
