---
status: open
severity: low
discovered: 2026-05-31
resolved: null
related_adrs: []
---

# DEBT-0003: Duplicated SnackBar notice idiom

> **Partly paid, 2026-07-29.** The helper this entry asked for now exists —
> `showRingdrillSnackBar` in `lib/views/widgets/plan_text.dart` — and four
> hand-rolled private `_showSnackBar` copies were consolidated onto it, fixing
> roughly 25 call sites at once. What remains is mechanical migration of the sites
> that still build a `SnackBar` inline. Kept open for that.

## What

The standard notice look — `SnackBar(showCloseIcon: true, dismissDirection: DismissDirection.endToStart, content: Text(...))` — was copied inline 26 times across 14 files instead of living behind a single helper.

It is now down to **19 occurrences across 8 files**, with 15 call sites routed
through the shared helper. The remaining copies are the debt.

## Where

The helper: `lib/views/widgets/plan_text.dart` — `showRingdrillSnackBar(context, …)`
and `showRingdrillSnackBarVia(messenger, …)` for callers that post *after* popping
the surface they were triggered from.

Still building the notice inline: `main.dart`, `views/stations_view.dart`,
`views/map_view.dart`, `views/about_page.dart`, `views/publish_plan_dialog.dart`,
`views/catalog_conflict_dialog.dart`, `views/shell/shell_notifications.dart`,
`views/widgets/code_chip.dart`.

## Why it is debt

Every call site re-specifies the same flags, so it is easy to produce an inconsistent variant (for example forgetting `dismissDirection`). A future change to the agreed notice style has to be applied everywhere it was copied. The cost is contributor cognitive load and drift risk, not a user-visible bug.

The helper's arrival added a second reason to finish the migration. It resolves plan
variable tokens before showing the message, because a `SnackBar` is built by the
`ScaffoldMessenger` in an `Overlay` that is a *sibling* of the subtree carrying
`PlanScope` — so an inline `SnackBar` naming a plan or exercise renders
`{{var.year}}` literally. Every call site left un-migrated is one that will show a
raw token the day its message gains an interpolated name.

## Suggested fix

Mechanical now: replace the remaining inline `SnackBar`s with
`showRingdrillSnackBar`. Two things to preserve while doing it:

* Where the notice is posted after an `await` that may dismiss the surface, use
  `showRingdrillSnackBarVia` with a `ScaffoldMessengerState` captured *before* the
  await. `open_file_widget.dart` documents why: the pop deactivates the context.
* Pass `plan:`/`exercise:` when the message names one, so the tokens resolve at the
  right level rather than the plan default.

## Links

* Related ADRs: none
* Related code: `lib/views/*`, `lib/main.dart`
