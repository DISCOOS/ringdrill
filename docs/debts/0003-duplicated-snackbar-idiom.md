---
status: open
severity: low
discovered: 2026-05-31
resolved: null
related_adrs: []
---

# DEBT-0003: Duplicated SnackBar notice idiom

## What

The standard notice look — `SnackBar(showCloseIcon: true, dismissDirection: DismissDirection.endToStart, content: Text(...))` — is copied inline 26 times across 14 files instead of living behind a single helper.

## Where

`lib/` files containing the idiom include `main.dart`, `views/stations_view.dart`, `views/open_file_widget.dart`, `views/station_screen.dart`, `views/map_view.dart`, `views/add_exercises_dialog.dart`, `views/active_plan_actions.dart`, `views/install_link_handler.dart`, `views/exercise_form_screen.dart`, `views/about_page.dart`, `views/exercise_control_button.dart`, `views/publish_plan_dialog.dart`, `views/main_screen.dart`, and `views/library_view.dart`.

## Why it is debt

Every call site re-specifies the same flags, so it is easy to produce an inconsistent variant (for example forgetting `dismissDirection`). A future change to the agreed notice style has to be applied in 26 places. The cost today is contributor cognitive load and drift risk, not a user-visible bug.

## Suggested fix

Add one helper, for example `context.showRingdrillSnack(String message, {bool persistent})` or a free function `showRingdrillSnackBar(messenger, text)`, and route call sites through it. Preserve the established pattern of capturing `ScaffoldMessenger.of(context)` before any `await` where `mounted` is uncertain.

## Links

* Related ADRs: none
* Related code: `lib/views/*`, `lib/main.dart`
