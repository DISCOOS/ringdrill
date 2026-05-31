---
status: open
severity: low
discovered: 2026-05-31
resolved: null
related_adrs: ["ADR-0028"]
---

# DEBT-0008: ADR-0028 feature-folder refactor accepted but not executed

## What

ADR-0028 (`Accepted` 2026-05-28) decides a feature-first layout for `lib/views/` but the move has not been run. `lib/views/` remains a flat folder with over 50 files.

## Where

* `lib/views/` — flat folder, 50+ Dart files.
* Target structure per ADR-0028: shell/exercise/team/station/cast/player/library/brief/spatial/settings/widgets.
* `lib/web/` shadow files (`settings_page.dart`, `platform_widget.dart`, `program_page_controller.dart`) are extra confusing without grouping, since they shadow same-named files in `lib/views/` via conditional import.

## Why it is debt

This is an accepted-but-deferred decision. The flat folder makes it hard to see which files belong together as the view layer grows toward higher fidelity, and the conditional-import shadow files compound the confusion. Tracked here so the accepted refactor does not get forgotten.

## Suggested fix

Run the move as specified in ADR-0028. It is mechanical reorganization with a large readability payoff and low risk, but it touches almost every import line, so it should be its own isolated commit with no other change mixed in.

## Links

* Related ADRs: [ADR-0028](../adrs/0028-feature-first-views-layout.md)
* Related code: `lib/views/`, `lib/web/`
