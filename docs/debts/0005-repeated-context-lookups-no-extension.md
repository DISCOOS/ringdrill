---
status: open
severity: low
discovered: 2026-05-31
resolved: null
related_adrs: []
---

# DEBT-0005: Repeated `AppLocalizations`/`Theme` context lookups, no shared extension

## What

`AppLocalizations.of(context)!` appears 154 times and `Theme.of(context)` 99 times across `lib/`. The boilerplate is re-typed in nearly every `build` method instead of going through a shared `BuildContext` extension.

## Where

Pervasive across `lib/views/` and `lib/web/`. Highest concentration is in the large screens (`coordinator_screen.dart`, `main_screen.dart`, `stations_view.dart`, `brief_screen.dart`).

## Why it is debt

The ceremony obscures the substance of each `build` method and raises the reading cost of the already-large screens. The cost is purely contributor cognitive load; there is no user-visible impact and no correctness risk.

## Suggested fix

Add `lib/utils/context_extensions.dart`:

```dart
extension RingdrillContextX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get texts => Theme.of(this).textTheme;
}
```

Call sites become `context.l10n.briefAction` and `context.colors.primaryContainer`. Introduce incrementally; no behavioural change.

## Links

* Related ADRs: none
* Related code: `lib/views/*`, `lib/web/*`
