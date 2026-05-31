---
status: resolved
severity: low
discovered: 2026-05-31
resolved: 2026-05-31
related_adrs: []
---

# DEBT-0004: Duplicated destructive-confirm dialog

## What

The same `AlertDialog` with a Cancel button and a red Delete button is reimplemented inline in at least five screens rather than coming from one shared helper.

## Where

* `lib/views/coordinator_screen.dart` line 181
* `lib/views/active_plan_actions.dart` line 87
* `lib/views/actor_form_screen.dart` line 182
* `lib/views/library_view.dart` line 431 (named `_confirmDelete`, but private and not reused)
* `lib/views/exercise_form_screen.dart` line 361

## Why it is debt

Five near-identical blocks define the destructive style independently, so the look can drift and any change (button colour, copy, layout) has to be repeated. `dialog_widgets.dart` already exists as a natural home, so the duplication is avoidable.

## Suggested fix

Add `Future<bool> confirmDestructive(BuildContext, {required String title, required String message, required String confirmLabel})` to `lib/views/dialog_widgets.dart` and replace the inline dialogs with calls to it.

## Links

* Related ADRs: none
* Related code: `lib/views/dialog_widgets.dart`, `lib/views/coordinator_screen.dart`, `lib/views/active_plan_actions.dart`, `lib/views/actor_form_screen.dart`, `lib/views/library_view.dart`, `lib/views/exercise_form_screen.dart`
