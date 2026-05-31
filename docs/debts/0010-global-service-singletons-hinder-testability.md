---
status: open
severity: medium
discovered: 2026-05-31
resolved: null
related_adrs: []
---

# DEBT-0010: Global service singletons hinder testability

## What

Five services use the `factory X() => _instance` singleton pattern and are fetched as `ProgramService()` directly from UI code. This hardcodes the production instance into every widget, so widget tests cannot substitute a fake without global tricks.

## Where

* `lib/services/program_service.dart` (line 106)
* `lib/services/exercise_service.dart` (line 102)
* `lib/services/notification_service.dart` (line 32)
* `lib/services/shared_file_channel.dart` (line 11)
* `lib/services/catalog_status_service.dart` (line 48)
* Consumed as `ProgramService()` etc. across `lib/views/` (28 files import `program_service.dart` alone).

## Why it is debt

The direct global access couples the UI to concrete production services and limits what can be exercised in widget tests. The app is small enough that singletons currently work, so this is a recorded compromise rather than an urgent problem — but the cost grows as more screens and tests are added.

## Suggested fix

Consider a light service locator (for example `get_it`) or an `InheritedWidget`/scope at the app root. `ScreenController.of` in `lib/views/page_widget.dart` already demonstrates the inherited-scope pattern in this codebase. This is a sizeable lift and should be weighed against current need; do not pursue it unless testability becomes a concrete blocker. Requires an ADR.

## Links

* Related ADRs: none
* Related code: `lib/services/*`, `lib/views/page_widget.dart`
