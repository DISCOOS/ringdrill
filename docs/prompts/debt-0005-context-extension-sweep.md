# Finish DEBT-0005: sweep call sites onto the context extension

Authoritative spec: [`docs/debts/0005-repeated-context-lookups-no-extension.md`](../debts/0005-repeated-context-lookups-no-extension.md). Read it first.

The helper already exists (`lib/utils/context_extensions.dart`, providing `l10n`, `colors`, `texts`). This prompt is the remaining mechanical adoption across existing call sites. It is purely textual and behaviour-preserving — no logic changes.

## The three replacements

For any in-scope `BuildContext` (named `context` or otherwise, e.g. `sheetContext`, `scopeContext`):

- `AppLocalizations.of(<ctx>)!` → `<ctx>.l10n`
- `Theme.of(<ctx>).colorScheme` → `<ctx>.colors`
- `Theme.of(<ctx>).textTheme` → `<ctx>.texts`

Where the call sits on the right-hand side of an alias, keep the alias and rewrite the RHS, e.g. `final localizations = AppLocalizations.of(context)!;` becomes `final localizations = context.l10n;`. Do not inline or rename existing alias variables — that is churn beyond this debt.

Add `import 'package:ringdrill/utils/context_extensions.dart';` to every file you change that does not already have it. Remove the now-unused `import 'package:ringdrill/l10n/app_localizations.dart';` only when no `AppLocalizations` reference remains in the file (it often stays, since types like `AppLocalizations localizations` in signatures still need it — leave the import then).

## Do NOT touch — exclusions

`Theme.of(context)` is also used for things the extension does not cover. Leave these exactly as they are:

- `Theme.of(context).brightness`, `.platform`, `.dividerColor`, `.appBarTheme`, and any other member that is not `colorScheme` or `textTheme`.
- Concretely, do not convert these lines: `lib/views/main_screen.dart` (brightness ~1029/1039/1082, platform ~1051), `lib/views/widgets/brief_theme.dart` (~297), `lib/views/widgets/expandable_tile.dart` (~114), `lib/views/widgets/live_accent.dart` (~82), `lib/views/widgets/ringdrill_sheet.dart` dividerColor (~121).
- Leave `lib/theme.dart` untouched entirely; it is theme plumbing.
- `bin/` and `lib/data/`, `lib/services/`, `lib/models/`, `netlify/` are out of scope. The extension must never become reachable from the Flutter-free CLI.

Note: `expandable_tile.dart` has one `colorScheme` use (convert) plus one `brightness` use (leave). Read the line, do not blanket-replace the file.

## Worklist and commit grouping

Generate the authoritative list before each step and after, to confirm nothing was missed:

```bash
grep -rn "AppLocalizations.of(" lib --include=*.dart
grep -rn "Theme.of(.*)\.colorScheme\|Theme.of(.*)\.textTheme" lib --include=*.dart
```

Split into three commits by area so each diff stays reviewable. One area = one commit.

### Step 1 — `lib/views/*.dart` (top-level screens)

All direct children of `lib/views/`. Highest-volume files: `station_screen.dart`, `active_plan_actions.dart`, `library_view.dart`, `coordinator_screen.dart`, `roleplays_view.dart`, `stations_view.dart`, `map_view.dart`, `add_exercises_dialog.dart`, `brief_screen.dart`, `station_list_view.dart`, `settings_page.dart`, `program_view.dart`, plus the remaining smaller ones the grep reports. Respect the `main_screen.dart` exclusions above (convert its `AppLocalizations`/`colorScheme`/`textTheme` uses, leave its brightness/platform uses).

Commit: `refactor: adopt context extension across views screens (DEBT-0005)`

### Step 2 — `lib/views/widgets/`, `lib/views/drill_player/`, `lib/views/shell/`

The shared widgets and sub-foldered views. Respect the `expandable_tile.dart`, `live_accent.dart`, `brief_theme.dart`, `ringdrill_sheet.dart` exclusion lines.

Commit: `refactor: adopt context extension across view widgets (DEBT-0005)`

### Step 3 — `lib/main.dart` and `lib/web/`

`main.dart` (its `AppLocalizations`/`textTheme` uses) and the web variants `settings_page.dart`, `mobile_app_nudge.dart`. Keep web-safe imports — `context_extensions.dart` pulls in `material.dart` and `app_localizations.dart` only, both already used on web, so this is safe.

Commit: `refactor: adopt context extension in app bootstrap and web (DEBT-0005)`

## Per-commit discipline

- Start from a clean tree (`git status`).
- Before each commit: `flutter analyze` must be clean, run `flutter test` and report. `make build` is not needed — no codegen inputs change.
- After each commit: run the two grep commands scoped to that area and confirm zero remaining convertible sites (only the listed exclusions should match). Then `git status` must be clean before the next step.
- One step = one commit. Do not bundle areas together or fold in unrelated changes.

## After the sweep

Final commit: set `lib/utils/context_extensions.dart`'s adoption as complete by flipping DEBT-0005 to `status: resolved` with today's `resolved:` date in [`docs/debts/0005-repeated-context-lookups-no-extension.md`](../debts/0005-repeated-context-lookups-no-extension.md) (replace the `## Progress` note with a one-line resolution), and switch its row in [`docs/debts/README.md`](../debts/README.md) to `Resolved`.

Commit: `docs(debts): mark DEBT-0005 resolved`

## Constraints

- View/bootstrap layer only. No `lib/models/`, `lib/data/`, `lib/services/`, `bin/`, `netlify/`.
- No behavioural change. This is a rename of how the same values are fetched.
- Match `dart format`. No new lint suppressions.
- Per AGENTS.md rule 9, a clean `flutter test` run is the expected baseline. If a test fails, fix or flag it rather than asserting green.

## Expected diff scope

Around 45 files under `lib/views/`, `lib/web/`, and `lib/main.dart`, plus `docs/debts/0005-...md` and `docs/debts/README.md` in the final commit. Each touched file gains the `context_extensions.dart` import. No `*.g.dart`, `*.freezed.dart`, `*.arb`, or `app_localizations*.dart` should change.
