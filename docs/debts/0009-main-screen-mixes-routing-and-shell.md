---
status: open
severity: low
discovered: 2026-05-31
resolved: null
related_adrs: []
---

# DEBT-0009: `main_screen.dart` mixes routing and shell

## What

`main_screen.dart` (1300 lines) holds three distinct concerns: the full go_router tree (`buildRouter`), two nearly identical deep-link launcher widgets, and the `MainScreen` shell (drawer, nav rail, responsive master/detail).

## Where

* `lib/views/main_screen.dart`:
  * `buildRouter` (line 44) — entire route tree.
  * `_BriefDeepLinkLauncher` (line 335) and `_ContextSheetDeepLinkLauncher` (line 376) — almost identical; the brief variant is just the case where the target is a `BriefSheetTarget`.
  * `_buildDrawer` (line 714) — a long sequence of near-identical `_drawerTile` calls against `active_plan_actions`.
  * Around line 1136 the indentation on `ValueListenableBuilder` looks off relative to the sibling `Expanded`; worth a `dart format` check to confirm the tree is as intended.

## Why it is debt

Routing config, navigation glue, and shell UI in one 1300-line file raise the cost of changing any one of them and obscure the others. The duplicated launchers and the hand-listed drawer tiles are avoidable repetition.

## Suggested fix

* Move `buildRouter` and the launcher widgets to a dedicated `lib/views/app_router.dart`. Merge the two launchers into one generic launcher parameterized by target.
* Data-drive `_buildDrawer` from a list of `(icon, title, enabled, action)` entries.
* Run `dart format` and verify the `ValueListenableBuilder` nesting near line 1136.

## Links

* Related ADRs: none
* Related code: `lib/views/main_screen.dart`, `lib/views/active_plan_actions.dart`, `lib/views/widgets/context_sheet.dart`
