# ADR-0045 implementation — Drill library bundle format (multi-program export/import)

You are working in the RingDrill repository. Implement [ADR-0045](../adrs/0045-drill-library-bundle-format.md). The ADR is `accepted`. Do not change its status.

Read ADR-0045 and [ADR-0007](../adrs/0007-drill-file-format.md) in full before starting. Skim `lib/data/drill_file.dart`, `lib/data/bulk_export.dart`, `lib/views/library_view.dart`, `lib/views/active_plan_actions.dart`, `lib/services/program_service.dart` and `lib/views/shell/app_router.dart` so the new code matches existing patterns.

## Ground rules

* Run `make build` after any change to a `@freezed` class, a `json_serializable` model, or an enum with `@JsonValue`. This work adds no such changes, so codegen should not be needed — but if it is, run it.
* User-visible strings go in `lib/l10n/app_en.arb` and `lib/l10n/app_nb.arb`. After editing an ARB, run `make i18n` (`flutter gen-l10n`). `make build` does NOT regenerate `app_localizations*.dart`.
* English in code, identifiers and comments. Norwegian only in `app_nb.arb` values. Use "station", never "post", in English text and code.
* `flutter analyze` and `flutter test` must be clean before a step is considered done.
* Each step is its own commit. Commit messages are English, conventional-commits, lowercase, imperative. List the exact files you touch in the commit. Run `git status` after each commit and confirm it is clean before moving on.

## Scope

Eight steps, ordered for clean commits:

1. `DrillLibrary` format class + architecture docs
2. File picker accepts `.zip`
3. Multi-program install in `ProgramService`
4. Wire the "Fra fil" tab to detect and import a bundle
5. "Last ned alle planer" action in the "Mine planer" tab
6. `?import=guide` route handling
7. Localized strings (nb + en)
8. Tests and verification

No new dependencies. No backend, Netlify or GHA changes. No changes to `site/`.

### Step 1 — `DrillLibrary` format class + docs

Create `lib/data/drill_library.dart`. Mirror the shape and doc-comment style of `lib/data/drill_file.dart`.

Provide:

```dart
/// How a byte buffer is classified before import.
enum DrillArchiveKind { single, library, invalid }

/// Why a drill-library bundle could not be parsed at the container level.
/// Per-entry parse failures are NOT represented here — those are handled
/// by skipping the entry during install (see ProgramService).
enum DrillLibraryReason { empty, notArchive, noDrillEntries }

class DrillLibraryException implements FormatException { /* mirror DrillFormatException */ }

class DrillLibrary {
  /// Classify a buffer without fully parsing it. Cheap magic-byte + entry-name
  /// inspection. `single` = top-level program.json present; `library` = one or
  /// more `*.drill` entries and no top-level program.json; `invalid` otherwise.
  static DrillArchiveKind sniff(List<int> content);

  /// Decode a bundle into one DrillFile per inner `.drill`. Throws
  /// DrillLibraryException for container-level problems. Does NOT parse the
  /// inner programs — callers use DrillFile.program() per entry so a single
  /// bad entry can be skipped.
  static List<DrillFile> entries(List<int> content, {String? sourceName});

  /// Encode a library: one `.drill` per program inside an outer ZIP, slug
  /// collisions disambiguated with a counter. This is the mechanism
  /// `bulk_export.exportAllPrograms` uses today.
  static Uint8List fromPrograms(List<Program> programs);
}
```

Move the body of `exportAllPrograms` (in `lib/data/bulk_export.dart`) into `DrillLibrary.fromPrograms`, byte-for-byte. Keep `bulk_export.dart` as a thin delegate so `MigrationPage` and the migration banner are untouched:

```dart
Uint8List exportAllPrograms(List<Program> programs) =>
    DrillLibrary.fromPrograms(programs);
```

`sniff` and `entries` use the same `ZipDecoder` and the same "PK magic bytes first" guard as `DrillFile.program()`. A single `.drill` is recognised by a top-level `program.json`; a library by top-level entries ending in `.drill`. Ignore nested paths when deciding (only top-level entry names matter for the `.drill` test, matching what `DrillLibrary.fromPrograms` writes).

Extend the "Drill file format" section of `docs/architecture.md` with a "Drill library format" subsection: describe the outer-ZIP layout, that it is content-detected (not extension-detected), that it carries no schema of its own (each inner `.drill` does), and point at `lib/data/drill_library.dart` and ADR-0045.

Unit-testable, pure Dart, no Flutter imports beyond what `drill_file.dart` already uses.

Commit: `feat(data): add DrillLibrary bundle format for multi-program archives`.

### Step 2 — File picker accepts `.zip`

In both `lib/web/program_page_controller.dart` and `lib/views/program_page_controller.dart` (the io/native shadow), update `pickOpenFile` so `allowedExtensions` is `[DrillFile.drillExtension, 'zip']`. Do not change the return type: keep returning a `DrillFile.fromBytes(name, content)` carrying the raw bytes. Classification happens at the call site in Step 4, not here.

Confirm the picked file name and bytes still flow through unchanged for the single-`.drill` case.

Commit: `feat(library): allow picking .zip bundles in the open-file picker`.

### Step 3 — Multi-program install in `ProgramService`

Add to `lib/services/program_service.dart`:

```dart
/// Result of installing a drill-library bundle.
class BundleInstallResult {
  const BundleInstallResult({required this.imported, required this.skipped});
  final int imported; // programs successfully installed
  final int skipped;  // inner .drill entries that failed to parse
  bool get hasFailures => skipped > 0;
  bool get isEmpty => imported == 0 && skipped == 0;
}

/// Install every program in a drill-library bundle into the local library.
/// Never activates anything and never touches the active plan (ADR-0045).
/// Best-effort per entry: a DrillFormatException on one entry increments
/// `skipped` and does not abort the rest. Container-level failures
/// (DrillLibraryException) propagate to the caller.
Future<BundleInstallResult> installBundle(List<int> content, {String? sourceName});
```

Implementation: call `DrillLibrary.entries(content, sourceName: sourceName)`, then for each `DrillFile` call `installFromFile(file, activate: false)` inside a try/catch that catches `DrillFormatException` (increment `skipped`, continue). Count successes into `imported`. Emit the existing `ProgramEvent` for each installed program exactly as `installFromFile` already does — do not add a new event type. Do not call `setActive`. Do not stop the exercise service.

Commit: `feat(programs): install every plan from a drill-library bundle without activating`.

### Step 4 — Detect and import a bundle from the "Fra fil" tab

The picker now returns raw bytes for either format. Route on content.

In `lib/views/active_plan_actions.dart`, extend `installPickedPlanFile`:

* After `pickOpenPlanFile` returns a `DrillFile`, call `DrillLibrary.sniff(drillFile.content)`.
* `single` → existing behaviour (`installFromFile(activate: true)`, returns the installed program in `InstallPickedOutcome`).
* `library` → call `ProgramService().installBundle(drillFile.content, sourceName: drillFile.fileName)`. Return a new outcome shape carrying the `BundleInstallResult` (see below) instead of a single `Program`. No navigation, no activation.
* `invalid` → surface the same wrong-file message the format path uses (`drillFormatMessage` with a `DrillFormatException(notArchive, …)` or a dedicated library message from Step 7).

Extend `InstallPickedOutcome` with an optional `BundleInstallResult? bundle` and an `isBundle` getter, or add a sibling outcome — pick whichever keeps `library_view.dart` readable. Keep `ExerciseService().isStarted` refusal as-is for both formats.

In `lib/views/library_view.dart` `_installFromFile`:

* Single success → unchanged (navigate to the plan, close the dialog).
* Bundle success → do NOT navigate or close. Refresh the "Mine planer" list (`setState`) and show an inline result using the existing `PickerErrorBanner` slot pattern, or a success line: "Imported N plans" (+ "M skipped" when `hasFailures`). Empty bundle → the "no plans found" message.

Commit: `feat(library): import multi-plan .zip bundles from the file picker`.

### Step 5 — "Last ned alle planer" action in the "Mine planer" tab

Add a download-all affordance to the "Mine planer" tab in `lib/views/library_view.dart`. Place it in the `TabFooter` area or as a header action of `_buildMyPlans`, disabled when the library is empty.

Add `downloadAllPlans(BuildContext context)` to `lib/views/active_plan_actions.dart`:

* Load every program shell via `ProgramService().listPrograms()` then `loadProgram`, exactly like `MigrationPage._export`.
* Encode with `DrillLibrary.fromPrograms(...)` and name the file with `bulkExportFileName(DateTime.now())`.
* On web, download via the existing `triggerDownload` conditional import (see `lib/views/migration_page.dart`). On native, share via `SharePlus.instance.share` with an `XFile.fromData(bytes, name: fileName, mimeType: 'application/zip')`, mirroring `_exportProgram` in `library_view.dart`.
* Show the usual success/failure snackbar.

Commit: `feat(library): add download-all-plans action to the library`.

### Step 6 — `?import=guide` route handling

In `lib/views/shell/app_router.dart`, inside `buildRouter`'s top-level `redirect`, handle the `import` query parameter the same way `/i/:slug` is handled:

* Read `state.uri.queryParameters['import']`. When it equals `guide`, schedule a post-frame callback that opens the library dialog on the "Fra fil" tab, using the root navigator `key.currentContext` (same pattern as the `handleInstallLink` block).
* Return `_activeProgramPath()` so the query parameter is stripped from the URL.
* Guard so this only runs on web (`kIsWeb`), consistent with the web-only `/migrate` and `/install` routes.

To land on the correct tab, add an `initialTabIndex` (or an `initialTab` enum) parameter to `showOpenPlanDialog` / `_LibraryBody` in `library_view.dart`, defaulting to the current first tab, and pass the "Fra fil" index from the router. Do not change default behaviour for existing callers.

Optional (nice-to-have, keep minimal): when opened via the guide, show a one-line hint at the top of the "Fra fil" tab pointing at the "Velg fil" button. Use a localized string; do not add a new dependency or a persistent flag.

Commit: `feat(router): open the import flow from the ?import=guide deep link`.

### Step 7 — Localized strings

Add to `lib/l10n/app_en.arb` and `lib/l10n/app_nb.arb` (with `@`-metadata and `placeholders` where a count is interpolated), then run `make i18n`.

Suggested keys and copy (adjust wording to match neighbouring entries):

| Key | en | nb |
|-----|----|----|
| `libraryExportAll` | `Download all plans` | `Last ned alle planer` |
| `importBundleSuccess` (placeholder `count`, int) | `Imported {count} plans` | `Importerte {count} planer` |
| `importBundlePartial` (placeholders `imported`, `skipped`, int) | `Imported {imported} plans, {skipped} skipped` | `Importerte {imported} planer, {skipped} hoppet over` |
| `importBundleEmpty` | `No plans found in the file` | `Fant ingen planer i fila` |
| `importGuideHint` (optional) | `Choose the .zip you downloaded to import your plans.` | `Velg .zip-fila du lastet ned for å importere planene dine.` |

Update `libraryFromFileHint` and `libraryFromFileSubtitle` so they mention that a `.zip` bundle is also accepted, e.g. nb `Velg en .drill-fil eller en eksportert .zip med flere planer`.

Do not hard-code any of these strings in widgets. Reference them through `AppLocalizations`.

Commit: `feat(l10n): add strings for drill-library import and download-all`.

### Step 8 — Tests and verification

Add `test/drill_library_test.dart`:

* `sniff` returns `single` for a `DrillFile.fromProgram(...).content`, `library` for a `DrillLibrary.fromPrograms([...])` output, and `invalid` for ASCII garbage and for a ZIP with neither `program.json` nor `.drill` entries.
* Round-trip: `fromPrograms([a, b])` → `entries(...)` yields two `DrillFile`s whose `program()` reproduce `a` and `b` (assert on `uuid`, `name`, exercise counts).
* Slug-collision disambiguation: two programs with the same name produce distinct `<slug>.drill` and `<slug>-1.drill` entries.

Add a `ProgramService` test (or extend an existing one) for `installBundle`:

* A clean bundle of 2 imports 2, activates nothing (`activeProgramUuid` unchanged), leaves any pre-existing active plan intact.
* A bundle with one corrupt inner entry imports the good ones and reports `skipped == 1`.

If a router test file exists for redirects, add a case asserting `?import=guide` redirects to the active-program path (the dialog side effect need not be asserted there).

Verification:

* `flutter analyze` clean
* `flutter test` clean
* `git status` clean
* Manual (web debug build):
  - Export via the new "Last ned alle planer" action → a `ringdrill-eksport-YYYY-MM-DD.zip` downloads.
  - Re-import that file via "Fra fil" → the same plans appear in "Mine planer", nothing is activated, active plan unchanged.
  - Open `/?import=guide` → the library dialog opens on the "Fra fil" tab.
  - Pick a single `.drill` via "Fra fil" → still installs and activates as before (no regression).
  - Pick a non-archive file → the wrong-file message appears, no Sentry noise.

Commit: `test(data): cover DrillLibrary sniff, round-trip and bundle install`.

## Out of scope

* A dedicated bundle file extension, MIME type or OS open/dispatch (Android intent filter, iOS UTI, Netlify disposition). Bundles are picked manually.
* Any change to `site/` or the `/migrate` exporter — it already emits this format.
* Merging bundle programs into the active plan, or any activation/selection prompt (explicitly dropped in ADR-0045).
* A new `ProgramEvent` type for bundle import (reuse the per-program install event).
* Backend, CLI, Netlify or GHA changes.

## Definition of done

Eight commits in order. `flutter analyze` and `flutter test` clean. Manual verification passes. `git status` clean after every commit.

## Commit message conventions

Conventional commits, lowercase, imperative present tense, English. Match the style of recent commits. Each step is its own commit, listing the files it touches.
