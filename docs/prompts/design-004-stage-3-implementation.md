# Implement DESIGN-004 Stage 3

You are working in the RingDrill repository. Implement Stage 3 of DESIGN-004 ("Exercise brief template") end-to-end. DESIGN-004 at `docs/design/brief-template.md` is the authoritative spec. Stages 1a, 1b and 2 have shipped and are merged. Read the earlier prompts at `docs/prompts/adr-0022-stage-1a-implementation.md`, `docs/prompts/adr-0022-stage-1b-implementation.md` and `docs/prompts/design-004-stage-2-implementation.md` for the conventions they established.

Stage 3 introduces the brief route and the in-app viewer. It adds the `markdown_widget` dependency, registers `/brief/:exerciseUuid` and `/brief/program/:programUuid` routes, ships a `BriefScreen` that calls `BriefRenderer` and renders the markdown with a table of contents, an audience toggle, search-in-page and a print button, and wires up the two screen-level entry points (`CoordinatorScreen` and `ProgramView`). No form-field editors and no print stylesheet land in this stage. Stages 4 and 5 cover those.

The "Brief" action on existing list rows (station list, roleplay list, team rows) stays deferred per DESIGN-004. Only the two screen-level entry points ship in Stage 3.

## Ground rules

Read `AGENTS.md` and follow every numbered rule. The non-negotiable ones for this change:

* The CLI must stay Flutter-free. `bin/ringdrill.dart` transitively imports `lib/data/`, never `lib/views/`. Confirm before adding new code that nothing under `lib/views/` ends up imported from `bin/`. Use `rg "package:ringdrill/views" bin/ lib/data/` to verify.
* Mobile-safe imports. `BriefScreen` is reachable on web, Android, iOS, macOS and desktop. Do not import `dart:html` or `package:web` from `BriefScreen` itself. Web-only behaviour (browser print, in-page find) goes behind a `lib/web/brief_print.dart` stub + `lib/web/brief_print_web.dart` web implementation, mirroring the pattern in `lib/web/pwa_update_stub.dart` / `lib/web/pwa_update_web.dart`.
* User-visible UI strings (screen title, audience labels, button tooltips, empty-state messages, error messages) go in `lib/l10n/app_en.arb` and `lib/l10n/app_nb.arb`. No raw English in widgets. Rendered brief content (section headings like "Tid", "Metode") comes from the template asset and is not touched here.
* `BriefAudience` IDs are English (`participant`, `instructor`, `director`). Norwegian labels come from ARB per DESIGN-004 and prior memory: `participant` → "Deltaker", `instructor` → "Veileder" (not "Instruktør"), `director` → "Øvelsesleder". English ARB labels are "Participant", "Instructor" and "Director".
* No new lint suppressions. Match existing Dart style.
* Run `flutter analyze` and `flutter test` before claiming the change is green. `test/widget_test.dart` is the known-broken default-template smoke test. Flag it as such rather than asserting all tests pass.
* Routes are defined in `lib/views/main_screen.dart`. Route path constants live in `lib/views/app_routes.dart`. Follow the existing convention: a `const String` constant per top-level path, named `routeBrief` for the new path.
* The brief route is **not** a tab. It must not appear in `MainScreen._buildDestinations`, must not appear in the `routes` list passed to `MainScreen`, and must be registered with `parentNavigatorKey: key` so navigation pushes onto the root navigator instead of the shell navigator. This matches how the nested per-tab detail routes (`StationExerciseScreen`, `RolePlayScreen`) are wired today.

## Commits

Commit as you progress, not in one giant blob. Each step below is a natural commit boundary. The project uses Conventional Commits with a scope. Allowed types from history: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`. Relevant scopes already in use: `data`, `models`, `services`, `views`, `assets`, `deps`. Suggested subjects:

* `chore(deps): add markdown_widget for brief viewer`
* `feat(l10n): add brief screen and audience-toggle strings`
* `feat(views): add /brief routes and BriefScreen`
* `feat(views): add Brief action to CoordinatorScreen and ProgramView app bars`
* `test(views): cover BriefScreen audience toggle and template asset loading`

All five logical commits land together as one continuous series on the same branch.

### Commit discipline (non-negotiable)

A recurring failure mode in past rounds has been agents leaving regenerated files or test files uncommitted in the working tree. Avoid this:

* After every step below, run `git status` and `git diff --stat` and confirm there are no untracked or unstaged paths before claiming the step done. Untracked files count as failure.
* Each step lists the **files expected in that commit**. The commit must include every listed path. Anything beyond the list also belongs in the commit unless explicitly punted. If you see a path you do not recognize in `git status`, do not delete it. Inspect it, then either include it or stop and ask.
* Regenerated l10n files (`lib/l10n/app_localizations*.dart`) ship in the same commit as the `.arb` change that triggered them. Do not park them in a follow-up regen commit.
* Never close a step with `git stash` or `git restore`. If something is in the working tree, it ships with the commit.
* The final Verification gate requires `git status` to print a clean tree on the working branch with no untracked or unstaged files. The work is not done until this is true.

## Scope

Five steps. Do them in order.

### Step 1. Add markdown_widget dependency

Edit `pubspec.yaml`. Add `markdown_widget: ^2.3.2+8` (or the latest 2.x version compatible with the rest of the dependency tree) under `dependencies:`. Match the alphabetical ordering used in the rest of the section. Run `flutter pub get` to refresh `pubspec.lock`. Confirm the package resolves on Dart 3 / Flutter `^3.8.0`.

`markdown_widget` is selected because it renders raw markdown with built-in heading anchors and a `TocController` that drives a side-panel table of contents. The alternative `flutter_markdown` package is unmaintained as of 2025 and lacks the TOC controller surface. If `markdown_widget` cannot be added for a structural reason (e.g. it pulls a `dart:html` transitive that breaks the CLI build), stop and write an ADR before substituting another package — do not silently swap.

Files expected in this commit:

* `pubspec.yaml`
* `pubspec.lock`

Run `git status`. Commit: `chore(deps): add markdown_widget for brief viewer`.

### Step 2. Add l10n strings

Add the following keys to both `lib/l10n/app_en.arb` and `lib/l10n/app_nb.arb`. The English values are listed first, the Norwegian values second. Match the existing JSON style in each ARB file (the en file uses descriptions, the nb file does not).

Keys to add:

* `briefScreenTitle` — "Brief" (en) / "Brief" (nb). The Norwegian word is the same loanword as English in LSOR practice; do not translate to "Sammendrag".
* `briefAudienceParticipant` — "Participant" (en) / "Deltaker" (nb).
* `briefAudienceInstructor` — "Instructor" (en) / "Veileder" (nb). **Do not** use "Instruktør" in nb.
* `briefAudienceDirector` — "Director" (en) / "Øvelsesleder" (nb).
* `briefAudienceLabel` — "Audience" (en) / "Målgruppe" (nb). Label above the toggle on mobile.
* `briefPrint` — "Print" (en) / "Skriv ut" (nb). Tooltip on the print button.
* `briefSearch` — "Search in brief" (en) / "Søk i brief" (nb). Tooltip on the search button.
* `briefSearchHint` — "Search" (en) / "Søk" (nb). Placeholder inside the search field.
* `briefSearchNoMatches` — "No matches" (en) / "Ingen treff" (nb). Shown next to the search field when the query has no hits.
* `briefRenderError` — "Could not render brief: {error}" (en) / "Kunne ikke lage brief: {error}" (nb). Placeholder `{error}` typed as `String`.
* `briefMissingProgram` — "No active program" (en) / "Ingen aktiv plan" (nb). Empty-state when the route is opened with no program loaded.
* `briefMissingExercise` — "Exercise not found" (en) / "Øvelse ikke funnet" (nb). Empty-state when `:exerciseUuid` resolves to nothing.
* `briefToc` — "Contents" (en) / "Innhold" (nb). Heading above the TOC sidebar on wide screens.
* `briefAction` — "Open brief" (en) / "Åpne brief" (nb). Label/tooltip for the entry-point action that lives on `CoordinatorScreen` and `ProgramView` app bars.

Run `flutter gen-l10n` (or the project's usual `make build` step that regenerates l10n). Inspect `lib/l10n/app_localizations.dart` and `lib/l10n/app_localizations_*.dart` to confirm the new getters appear.

Files expected in this commit:

* `lib/l10n/app_en.arb`
* `lib/l10n/app_nb.arb`
* `lib/l10n/app_localizations.dart`
* `lib/l10n/app_localizations_en.dart`
* `lib/l10n/app_localizations_nb.dart`

Run `git status`. Commit: `feat(l10n): add brief screen and audience-toggle strings`.

### Step 3. Routes and BriefScreen

Edit `lib/views/app_routes.dart`. Add:

```dart
/// Brief route — read-mode renderer of an exercise or program as a
/// markdown document. Reachable as `/brief/program/:programUuid` for
/// the whole program and `/brief/:exerciseUuid` for a single exercise.
/// Not in the bottom navigation; pushed onto the root navigator from
/// the Brief action on `CoordinatorScreen` and `ProgramView`. See
/// DESIGN-004.
const String routeBrief = '/brief';
```

Edit `lib/views/main_screen.dart`. Add two `GoRoute` entries directly under the top-level routes list (siblings of the `ShellRoute`, not children of it). Both use `parentNavigatorKey: key` so the screen pushes over the tab shell:

```dart
GoRoute(
  path: '$routeBrief/program/:programUuid',
  parentNavigatorKey: key,
  builder: (BuildContext context, GoRouterState state) => BriefScreen(
    programUuid: state.pathParameters['programUuid']!,
  ),
),
GoRoute(
  path: '$routeBrief/:exerciseUuid',
  parentNavigatorKey: key,
  builder: (BuildContext context, GoRouterState state) => BriefScreen(
    exerciseUuid: state.pathParameters['exerciseUuid']!,
  ),
),
```

The exercise route comes after the program route so go_router matches the more specific `program/` path first. Do not add `routeBrief` to the `routes:` list passed to `MainScreen` and do not add a destination for it in `_buildDestinations`. The route is reachable by `context.push` only.

Create `lib/views/brief_screen.dart`. Public surface:

```dart
class BriefScreen extends StatefulWidget {
  const BriefScreen({super.key, this.exerciseUuid, this.programUuid})
      : assert(
          (exerciseUuid == null) != (programUuid == null),
          'exactly one of exerciseUuid or programUuid must be provided',
        );

  /// When non-null, the brief is scoped to this single exercise.
  final String? exerciseUuid;

  /// When non-null, the brief covers the whole program. Currently a marker
  /// only; the active program is resolved via `ProgramService` because the
  /// app holds at most one active program at a time.
  final String? programUuid;

  @override
  State<BriefScreen> createState() => _BriefScreenState();
}
```

Implementation outline:

1. **Resolve inputs.** Read the active program from `ProgramService().activeProgram`. If null, show a centered `Text(localizations.briefMissingProgram)`. If `widget.exerciseUuid` is non-null, look up the exercise via `program.exercises.firstWhereOrNull(...)`. If not found, show `Text(localizations.briefMissingExercise)`. The `programUuid` form does not require a matching uuid lookup — the active program is the only program — but log a debug warning if `programUuid != program.uuid`.
2. **Audience state.** Hold `BriefAudience _audience = BriefAudience.participant` in state. The default participant choice is the safest read for someone opening the route by accident.
3. **Render call.** Invoke `BriefRenderer().render(program: ..., exercise: ..., audience: _audience)` inside a `FutureBuilder<String>`. Re-key the future when `_audience` changes so the builder re-runs. The render result is the markdown string passed into `MarkdownWidget`.
4. **Layout.** Use a `LayoutBuilder`. Two breakpoints:
   * `wide` (>= 900 px): Row with a left-side TOC sidebar (width 240, scrollable) and the main `MarkdownWidget` filling the rest. The audience toggle and print button sit in the app bar.
   * `narrow` (< 900 px): Column with a `SegmentedButton<BriefAudience>` at the top (height ~48), the `MarkdownWidget` filling the rest, and no TOC sidebar. The print button stays in the app bar.

   The 900 px breakpoint matches the existing `_wideScreen = width > 600` rule in `MainScreen` only loosely — the brief reads better with more horizontal room because of the table of contents, so a higher threshold is correct here. Document the threshold in a code comment.
5. **TOC.** `markdown_widget` exposes a `TocController` and a `TocWidget`. Construct one `TocController` per state instance, dispose it on `dispose()`. Pass the same instance to both `MarkdownWidget(tocController: ...)` and the sidebar's `TocWidget(controller: ...)`.
6. **Search-in-page.** An `IconButton(Icons.search)` in the app bar toggles a `_searchOpen` bool. When open, the app bar's `bottom` slot hosts a `TextField` with a clear button. Filter strategy: re-render the markdown with matched substrings wrapped in HTML `<mark>...</mark>` tags before passing it to `MarkdownWidget`. `markdown_widget` renders inline HTML, so this works without a separate widget. Show `localizations.briefSearchNoMatches` next to the field when the query has length > 0 and produces zero matches. Search is case-insensitive. Empty query renders the unhighlighted markdown unchanged.
7. **Print button.** An `IconButton(Icons.print)` in the app bar, visible only on web. Use a `lib/web/brief_print.dart` stub + `lib/web/brief_print_web.dart` web implementation, exposing `void printBrief()` that calls `web.window.print()` on web and is a no-op elsewhere. Import the stub with the conditional pattern already used by `pwa_update_stub.dart` (`if (dart.library.io)`). Wrap the `IconButton` in `if (kIsWeb)` so it disappears on native. The native equivalent (PDF export, share-sheet) is deferred to Stage 5 per DESIGN-004.
8. **App bar.** Title: `localizations.briefScreenTitle`. On wide screens, the audience toggle (`SegmentedButton<BriefAudience>`) sits in the app bar's `actions` left of the search and print buttons. On narrow screens, the toggle is hidden from the app bar (it lives at the top of the body instead). Use the same `localizations.briefAudience*` keys for both placements.
9. **Loading and error states.** While the render future is pending, show a `CircularProgressIndicator` centered. If the future throws, show `Text(localizations.briefRenderError(error.toString()))`. Do not log to Sentry from this screen — the renderer's failure modes are content-driven, not infrastructure-driven, and DESIGN-004 wants authors to see the failure rather than have it absorbed silently.

Create `lib/web/brief_print.dart`:

```dart
/// Stub for non-web platforms. The brief print button calls into this
/// surface; on native it is a no-op because system-level print is not
/// part of v1 (DESIGN-004 Stage 5 covers the web print stylesheet; a
/// native PDF export is explicitly deferred).
void printBrief() {}
```

Create `lib/web/brief_print_web.dart`:

```dart
import 'package:web/web.dart' as web;

void printBrief() {
  web.window.print();
}
```

In `brief_screen.dart`, import the stub with the conditional pattern:

```dart
import 'package:ringdrill/web/brief_print.dart'
    if (dart.library.io) 'package:ringdrill/web/brief_print.dart';
```

Wait — the existing pattern in this repo is `if (dart.library.io) <native>` and the unqualified import is the web one. Re-check `program_view.dart`'s `program_page_controller.dart` import for the canonical direction and match it exactly. Get the conditional direction wrong and the web build silently picks up the stub instead of the real implementation, which is hard to spot in CI.

Files expected in this commit:

* `lib/views/app_routes.dart`
* `lib/views/main_screen.dart`
* `lib/views/brief_screen.dart`
* `lib/web/brief_print.dart`
* `lib/web/brief_print_web.dart`

Run `git status`. Commit: `feat(views): add /brief routes and BriefScreen`.

### Step 4. Brief entry-point actions

Add a Brief action on the two screen-level surfaces DESIGN-004 calls out.

**`CoordinatorScreen` (`lib/views/coordinator_screen.dart`).** The app bar already hosts the start/stop control and (per existing code) other actions. Add an `IconButton(Icons.menu_book)` with tooltip `localizations.briefAction` that calls `context.push('${routeBrief}/${widget.uuid}')`. Place it before the start/stop control so the action sits leftward of the run-mode button. Do not change the existing actions in any other way.

**`ProgramView` (`lib/views/program_view.dart`).** This is the Exercise tab. The actions list is built in `ProgramPageController.buildActions(context, constraints)`. Add an `IconButton(Icons.menu_book)` with tooltip `localizations.briefAction` that calls `context.push('${routeBrief}/program/${activeProgram.uuid}')`. The action is only enabled when an active program is loaded — gate it behind the same `activeProgram != null` check that the existing share-and-send actions in `_buildDrawer` use, and either disable the icon button or omit it when there is no active program. Pick whichever matches the surrounding pattern (the drawer disables; the app-bar actions may already omit — inspect before deciding).

Do **not** add Brief actions to:

* `StationListView` rows / `StationExerciseScreen`
* `RolePlaysView` rows / `RolePlayScreen`
* `TeamsView` rows / `TeamScreen`
* `TeamExerciseScreen`

Those are deferred per DESIGN-004 line "A 'Brief' action on existing list rows is deferred until the route works end-to-end." Stage 3 lands the route + the two screen-level entry points only.

Files expected in this commit:

* `lib/views/coordinator_screen.dart`
* `lib/views/program_view.dart` (and possibly its controller if `buildActions` lives in a separate file — the actions live in `ProgramPageController`, which is in `lib/views/program_page_controller.dart`; check before splitting)

Run `git status`. Commit: `feat(views): add Brief action to CoordinatorScreen and ProgramView app bars`.

### Step 5. Tests

Create `test/views/brief_screen_test.dart`. Tests must drive the screen through the production code path. Pump the widget under `MaterialApp.router` with a minimal `GoRouter` so `context.push` works, or pump `BriefScreen` directly under a `MaterialApp` when the test does not exercise navigation.

Tests to add:

* `renders director output by default when audience is director`. Build the DESIGN-004 fixture program in-memory, store it in `ProgramService`, pump `BriefScreen(exerciseUuid: 'ex-3')`, programmatically set `_audience = BriefAudience.director` (either via a public visible-for-testing setter on the state or by tapping the segmented button), await the future, then `expect(find.textContaining('Kari Hansen'), findsOneWidget)`.
* `participant audience hides actor PII`. Same fixture, tap the participant segment, `expect(find.textContaining('Kari Hansen'), findsNothing)` and `expect(find.textContaining('Anne Glemsk'), findsOneWidget)`.
* `instructor audience shows director notes but not actor PII`. Same fixture, tap the instructor segment, `expect(find.textContaining('Notater til instruktør'), findsOneWidget)` and `expect(find.textContaining('99887766'), findsNothing)`.
* `missing program shows empty state`. No active program. Pump `BriefScreen(programUuid: 'whatever')`. `expect(find.text(localizations.briefMissingProgram), findsOneWidget)`.
* `missing exercise shows empty state`. Active program with no matching uuid. Pump `BriefScreen(exerciseUuid: 'does-not-exist')`. `expect(find.text(localizations.briefMissingExercise), findsOneWidget)`.
* `print button is hidden on non-web`. Pump under default platform. `expect(find.byIcon(Icons.print), findsNothing)`. The opposite assertion under a forced `kIsWeb` is hard to fake from a widget test, so skip it; the manual QA matrix below covers the web path.
* `narrow layout puts audience toggle in the body`. Set `MediaQueryData(size: Size(400, 800))`. `expect(find.byType(SegmentedButton<BriefAudience>), findsOneWidget)` and assert it is below the app bar (use `tester.getTopLeft(...)` to compare y-positions).
* `wide layout puts audience toggle in the app bar and shows the TOC sidebar`. Set `MediaQueryData(size: Size(1200, 800))`. `expect(find.byType(SegmentedButton<BriefAudience>), findsOneWidget)` and assert it is inside an `AppBar`, plus `expect(find.text(localizations.briefToc), findsOneWidget)`.
* `search field appears when the search button is tapped`. Tap the search icon. `expect(find.byType(TextField), findsOneWidget)`. Type "Anne". Assert the rendered markdown contains a `<mark>` segment around "Anne" (probe the underlying string passed to `MarkdownWidget`, not the rendered glyphs — `<mark>` rendering varies by platform).

Add `test/views/brief_screen_test.dart` to the test suite. The Flutter test bundle resolves `assets/templates/...` via the pubspec asset list, but only when `TestWidgetsFlutterBinding.ensureInitialized()` is the binding — confirm with a one-line guard at the top of `setUp`.

Files expected in this commit:

* `test/views/brief_screen_test.dart`

Run `flutter analyze`. Run `flutter test test/views/brief_screen_test.dart`. Run the full test suite once to confirm nothing else regressed.

Run `git status`. Commit: `test(views): cover BriefScreen audience toggle and template asset loading`.

## Verification

1. `flutter analyze` clean.
2. `flutter test` produces no new failures. `test/widget_test.dart` remains broken. Do not try to fix it.
3. `flutter build apk --debug` succeeds. This catches asset registration mistakes and conditional-import direction mistakes (a swapped stub/web pair compiles on native but breaks the web build, and vice versa). If a full APK build is too slow on the dev machine, `flutter build bundle` is an acceptable substitute.
4. `flutter build web --no-tree-shake-icons` succeeds. This is the gate that catches a misdirected conditional import on `brief_print.dart`.
5. `dart compile exe bin/ringdrill.dart -o /tmp/ringdrill-cli` succeeds. This catches any accidental Flutter import that made it into the CLI's transitive dependency graph (in particular, do not let `BriefScreen` end up imported from anything `bin/` reaches).
6. **Clean tree gate.** `git status` on the working branch prints `nothing to commit, working tree clean`, and `git ls-files --others --exclude-standard` prints nothing. No untracked, no unstaged, no stashed work. The stage is not complete until this is true.
7. **Diff sanity.** Run `git log --stat origin/main..HEAD` and walk every changed path. Confirm each file appears in exactly the commit you intended.
8. Manual QA matrix (record the result in the final commit body or a `docs/notes/` file, whichever matches existing convention):
   * **Single-exercise brief on mobile.** Run `flutter run -d <ios-or-android-device>`, open an active program with at least one exercise, tap the Brief action in the Coordinator app bar. Confirm the audience selector sits at the top of the body (not in the app bar), the three audience options render their Norwegian labels (`Deltaker` / `Veileder` / `Øvelsesleder`), switching between them swaps the rendered content visibly (PII appears/disappears, director notes appear/disappear), the print button is hidden, and the back button returns to `CoordinatorScreen` with state intact.
   * **Whole-program brief on web.** Run `flutter run -d chrome`, open an active program, tap the Brief action in the Exercise tab's app bar. Confirm the URL is `/brief/program/<uuid>`, the TOC sidebar renders on the left, tapping a TOC entry scrolls to the heading, the audience toggle sits in the app bar, the print button opens the browser print dialog, and the rendered content is correct for the default participant audience.
   * **Search highlighting.** With the brief open, tap the search icon, type a token that appears in the brief (e.g. "Markør" in the LSOR fixture). Confirm matches are visually highlighted by `<mark>`, the no-matches indicator appears for a junk query, clearing the field restores the unhighlighted view.
   * **Unknown exercise.** Manually open `/brief/does-not-exist` in the browser. Confirm the missing-exercise empty state renders and there is no crash.
   * **Print button on native.** Confirm `Icons.print` does not appear in the app bar on macOS, Windows, Linux, Android or iOS.
9. Confirm Stage 4 surfaces (per-section markdown editors on `ProgramFormScreen`, `ExerciseFormScreen`, `StationFormScreen`, `RolePlayFormScreen`) and Stage 5 surfaces (web print stylesheet) are untouched. Stage 3 is route + viewer + two entry points only.

## Deliverables

A series of five Conventional Commits as outlined above, all on the same working branch, with a clean tree at the end. The final commit body should include:

* A short summary of what the brief route does and what surfaces are still missing (Stages 4 and 5 explicitly deferred, plus per-row Brief actions on list views explicitly deferred per DESIGN-004).
* The manual QA matrix filled out.
* A note on which of DESIGN-004's open questions the implementation answered, in particular: whether the `markdown_widget` TOC behaviour matches the design's "TOC sidebar on wide screens" expectation, and whether the `<mark>`-based search highlighting reads acceptably in practice or needs a richer overlay in v2. If the search experience needs follow-up, link the test that locks the current behaviour so a regression in Stage 5 is caught.

DESIGN-004 is the authoritative spec. If you find yourself contradicting it, stop and ask. Do not write a new ADR for viewer-package choices unless something forces a structural deviation from DESIGN-004 (for example, if `markdown_widget` cannot be used and a different package or a hand-rolled renderer becomes necessary).
