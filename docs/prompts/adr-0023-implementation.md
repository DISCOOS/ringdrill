# Implement ADR-0023

You are working in the RingDrill repository. Implement ADR-0023 ("Render the Brief view with a dedicated `BriefTheme` token set inspired by docs-site typography, independent of Material `ColorScheme`") end-to-end. The ADR lives at `docs/adrs/0023-brief-theme-tokens.md` and is **Accepted**. It is the authoritative spec for tokens, layout, slim app bar, drag handle, template changes and renderer signature. DESIGN-004 at `docs/design/brief-template.md` ("Visual design", "Presentation" and "Implementation notes" sections) is the authoritative reference for what belongs in this round of work.

This prompt covers ADR-0023 only. Stages 4 and 5 of DESIGN-004 (form-side markdown editors, print stylesheet) are out of scope. Do not start them here. If you find new defects that are not part of ADR-0023 (e.g. broken navigation in a sibling screen, l10n drift), record them and surface them at the end; do not bundle them into the same commits.

## Ground rules

Read `AGENTS.md` and follow every numbered rule. The non-negotiable ones for this change:

* `BriefTheme` is view-layer only. It lives under `lib/views/widgets/` and does not leak into `lib/services/`, `lib/models/`, `lib/data/`, `bin/` or `netlify/`.
* CLI must stay Flutter-free. `bin/ringdrill.dart` and `lib/data/drill_client.dart` must not import the new theme or the new wrapper.
* Mobile-safe imports. `BriefScreen` is reachable on every platform including web. No `dart:html` or `package:web` in any code path this prompt touches.
* Match existing Dart style. Run `dart format` before each commit. No new lint suppressions without an in-line `// ignore: ...` comment explaining why.
* Localize every user-visible string. The two new visible labels in this round are the close-button tooltip and the drag-handle semantics label. Add them to `lib/l10n/app_en.arb` **and** `lib/l10n/app_nb.arb` together. Norwegian translations are listed under Step 5.
* `test/widget_test.dart` is the known-broken default-template smoke test (counter app). Flag it as such at the end, never claim "all tests pass".

## Commits

Five logical commits, in order, on the same working branch. Use Conventional Commits with scope `brief`. Allowed types from history: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`. Suggested subjects:

1. `feat(brief): add BriefTheme tokens with light and dark factories`
2. `feat(brief): add BriefMarkdown wrapper composing BriefTheme into markdown_widget`
3. `feat(brief): gate in-doc TOC and demote one-line headings in nb template`
4. `refactor(brief): adopt BriefTheme and BriefMarkdown in BriefScreen with slim app bar`
5. `feat(brief): present brief as fullscreen modal bottom sheet from /brief route`

### Commit discipline (non-negotiable)

A recurring failure mode in past rounds has been agents leaving regenerated files, new test files, l10n changes or one-off scratch files uncommitted in the working tree. Avoid this:

* After every step below, run `git status` and `git diff --stat` and confirm there are no untracked or unstaged paths before claiming the step done. Untracked files count as failure.
* Each step lists the **files expected in that commit**. The commit must include every listed path. Anything beyond the list also belongs in the commit unless explicitly punted. If you see a path you do not recognize in `git status`, do not delete it. Inspect it, then either include it or stop and ask.
* Regenerated files from `make build` (`app_localizations*.dart`) are part of the commit that triggered them. Do not park them in a "regen" follow-up commit.
* Never close a step with `git stash` or `git restore`. If something is in the working tree, it ships with the commit.
* The final Verification gate requires `git status` to print a clean tree on the working branch with no untracked or unstaged files. The work is not done until this is true.

## Scope

Five steps. Do them in order. Each step is one commit.

### Step 1. `BriefTheme` value-class

Create `lib/views/widgets/brief_theme.dart`. Follow the `LiveAccent` pattern in `lib/views/widgets/live_accent.dart`: immutable value-class, private const constructor, named factories. Encode the exact palette and typography numbers from ADR-0023 "Palette (hardcoded values)" and "Typography". Do **not** read `Theme.of(context).colorScheme` inside the factories; that is the bug ADR-0023 removes. The only environmental input the factory accepts is brightness.

Token shape (use these class names verbatim so future grep finds them):

```dart
@immutable
class BriefTheme {
  const BriefTheme._({ ... });

  final BriefSurfaces surfaces;
  final BriefTextColors text;
  final BriefBorders borders;
  final BriefCodeStyle code;
  final BriefLinkStyle link;
  final BriefAccent accent;
  final BriefTypography typography;
  final BriefSpacing spacing;

  factory BriefTheme.light();
  factory BriefTheme.dark();
  factory BriefTheme.of(BuildContext context, {Brightness? override});
}

class BriefSurfaces   { final Color canvas, sidebar, appBar; ... }
class BriefTextColors { final Color heading, body, muted; ... }
class BriefBorders    { final Color subtle; ... }
class BriefCodeStyle  { final Color background, foreground, border; ... }
class BriefLinkStyle  { final Color color; final double underlineOpacity; ... }
class BriefAccent     { final Color activeStripe; ... }
class BriefTypography { final TextStyle h1, h2, h3, h4, body, code; ... }
class BriefSpacing    { final double readingColumnMax, gutter, sidebarWidth, appBarHeight; ... }
```

Light and dark hex values are listed in ADR-0023. Use them exactly. Typography sizes/weights/line-heights are also in the ADR; do not invent your own. `BriefTypography.code` should resolve to a monospaced family — read `Theme.of(context).textTheme` inside `BriefTheme.of` if you want a context-aware fallback, otherwise hardcode `'monospace'`.

Add a widget test at `test/views/widgets/brief_theme_test.dart` that asserts:

* `BriefTheme.light().surfaces.canvas` is `#FFFFFF` and dark is `#0B0F17`.
* `BriefTheme.of(context, override: Brightness.dark)` returns the dark variant.
* `BriefTheme.light().link.color == BriefTheme.light().text.body` (link matches body, distinction is the underline).
* `BriefTheme.light().typography.body.height` equals `1.65`.

Files expected in this commit:

* `lib/views/widgets/brief_theme.dart`
* `test/views/widgets/brief_theme_test.dart`

Run `git status`. Confirm only those two paths are staged. Commit: `feat(brief): add BriefTheme tokens with light and dark factories`.

### Step 2. `BriefMarkdown` wrapper

Create `lib/views/widgets/brief_markdown.dart`. The wrapper takes the theme and the markdown string and returns a `MarkdownWidget` (or `MarkdownBlock` if a tighter shell fits the call site) with a fully populated `MarkdownConfig`:

```dart
class BriefMarkdown extends StatelessWidget {
  const BriefMarkdown({
    super.key,
    required this.data,
    required this.theme,
    this.tocController,
  });

  final String data;
  final BriefTheme theme;
  final TocController? tocController;
}
```

Inside `build`, compose `MarkdownConfig.defaultConfig.copy(configs: [...])` populated from `theme`:

* `H1Config(style: theme.typography.h1.copyWith(color: theme.text.heading))`
* `H2Config(style: theme.typography.h2.copyWith(color: theme.text.heading))`
* `H3Config(style: theme.typography.h3.copyWith(color: theme.text.heading))`
* `H4Config(style: theme.typography.h4.copyWith(color: theme.text.heading))`
* `PConfig(textStyle: theme.typography.body.copyWith(color: theme.text.body))`
* `LinkConfig` with text style equal to body color and an underline decoration painted at `Color.fromRGBO(R,G,B, theme.link.underlineOpacity)` where RGB comes from `theme.link.color`.
* `CodeConfig(style: theme.typography.code.copyWith(color: theme.code.foreground, backgroundColor: theme.code.background))`
* `PreConfig` for fenced code blocks (background + padding + border using `theme.borders.subtle`).
* `BlockquoteConfig` with left border in `theme.borders.subtle` and body text in `theme.text.muted`.
* `TableConfig` with header row in `theme.text.heading`, body in `theme.text.body`, borders in `theme.borders.subtle`.

No call site that uses `BriefMarkdown` should need to reach into `markdown_widget` configs directly afterwards. If you cannot express a styling decision through the wrapper, add a parameter or a token rather than letting the call site bypass it.

Add a widget test at `test/views/widgets/brief_markdown_test.dart` that pumps a `BriefMarkdown` with a small fixture (`# H1\n\nbody [link](https://example.com) and `code`.`) and asserts:

* Heading text is rendered in `BriefTheme.light().text.heading` color.
* Link text uses the body color (not Material blue) and is decorated with `TextDecoration.underline`.
* Inline code has the code-background color applied.

Files expected in this commit:

* `lib/views/widgets/brief_markdown.dart`
* `test/views/widgets/brief_markdown_test.dart`

Run `git status`. Confirm only those two paths are staged. Commit: `feat(brief): add BriefMarkdown wrapper composing BriefTheme into markdown_widget`.

### Step 3. Renderer parameter and template fixes

Edit `lib/services/brief/brief_renderer.dart`:

* Add an optional named parameter `bool wideTocSidebar = false` to `BriefRenderer.render`.
* Forward it into the mustache context as `'if_in_doc_toc': !wideTocSidebar`. Place the entry next to the existing `'if_director'` / `'if_instructor_or_director'` booleans so the context shape stays grouped.

Edit `assets/templates/ringdrill-standard-v1.nb.md.mustache`:

* Wrap the current `## Innholdsfortegnelse` block (heading + bullet list + trailing blank line) in `{{#if_in_doc_toc}} ... {{/if_in_doc_toc}}`. The `if_in_doc_toc` boolean is the mustache section. The horizontal rule (`---`) that follows the TOC and precedes the exercises loop must stay outside the section so the divider is unconditional.
* Replace the per-station `#### Tid` heading and its following `{{durationLabel}}` line with a single inline-bold line: `**Tid:** {{durationLabel}}`. Delete the now-empty line that used to separate the heading from its value.
* `#### Utstyrsbehov` and every other `#### ` section heading stays as-is. Only `#### Tid` is one-liner metadata; the rest carry multi-paragraph content and earn their outline entry.
* The exercise-level `| Tid | {{durationLabel}} |` table row at the top of each exercise stays untouched.

Update existing renderer tests (likely under `test/services/brief/`) so the snapshot expectations match. If a snapshot fixture file (`.md`) exists, regenerate it deliberately and inspect the diff line by line — do not rubber-stamp a `--update-goldens`-style flag. The diff must show only the two changes above (in-doc TOC wrapped, `#### Tid` → inline bold).

Add one new renderer test that verifies the gating behavior: render the same fixture with `wideTocSidebar: false` and with `wideTocSidebar: true`, assert that the second output does **not** contain the substring `## Innholdsfortegnelse` and that the first does.

Files expected in this commit:

* `lib/services/brief/brief_renderer.dart`
* `assets/templates/ringdrill-standard-v1.nb.md.mustache`
* Any test files under `test/services/brief/` that hold renderer fixtures or assertions.

Run `git status` and verify all relevant paths are staged. Commit: `feat(brief): gate in-doc TOC and demote one-line headings in nb template`.

### Step 4. `BriefScreen` adopts theme, wrapper and slim app bar

This step keeps `BriefScreen` as a regular routed widget. The sheet wrapping comes in Step 5. Splitting it this way means Step 4 is reviewable on its own and Step 5's diff is contained to routing plus sheet chrome.

Edit `lib/views/brief_screen.dart`:

* Replace the existing Material `AppBar` with a `PreferredSize` widget that builds a slim bar. Surface uses `theme.surfaces.appBar`, bottom 1 px border in `theme.borders.subtle`, height `theme.spacing.appBarHeight`. Title text style follows `theme.typography.h4.copyWith(color: theme.text.heading)`. Leading slot stays as the default back arrow for now (Step 5 swaps it to a close X). Search and print `IconButton`s lose any tinting; `color: theme.text.heading`.
* The `SegmentedButton` audience selector: pass it a local `Theme` override that maps unselected segments to `theme.text.body` and the selected segment to `theme.surfaces.sidebar` fill with `theme.text.heading` foreground. No Material primary fill. On narrow screens the selector still drops to the body's top per the existing layout.
* Replace the body's `MarkdownWidget(...)` call with `BriefMarkdown(data: markdown, theme: theme, tocController: _tocController)`.
* Wrap the markdown widget in a `Center(child: ConstrainedBox(maxWidth: theme.spacing.readingColumnMax, child: ...))`. Apply `theme.spacing.gutter` horizontal padding on both sides of the constrained column.
* Sidebar: keep the existing `TocWidget(controller: _tocController)` shell but restyle the header label using `theme.text.muted` for "Innhold". The sidebar background is `theme.surfaces.sidebar`. Active TOC item gets a 2 px left stripe in `theme.accent.activeStripe`; inactive items use `theme.text.body`. Sidebar width is `theme.spacing.sidebarWidth`.
* Add a `_wideTocSidebar` field derived from the `LayoutBuilder`'s `constraints.maxWidth >= _kWideBreakpoint`. When the value flips across rebuilds, regenerate `_renderFuture` exactly like `_setAudience` already does for the audience field. Suggested helper: extract `_buildRenderFuture()` to take both `audience` and `wideTocSidebar` as parameters, then call it from `setState` callbacks in both `_setAudience` and a new `_setWideTocSidebar`. Do **not** rebuild the future unconditionally on every layout pass; only when the breakpoint actually flips.
* The narrow-screen audience selector banner that today sits above the markdown stays as-is structurally, but its container background switches to `theme.surfaces.appBar` and the divider below it becomes 1 px in `theme.borders.subtle`.

Pass `wideTocSidebar: _wideTocSidebar` into `BriefRenderer.render`.

Wrap everything in a `Theme` widget at the top of `build` so the slim app bar styling stays local:

```dart
final theme = BriefTheme.of(context);
return Theme(
  data: Theme.of(context).copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: theme.surfaces.appBar,
      foregroundColor: theme.text.heading,
      elevation: 0,
    ),
    scaffoldBackgroundColor: theme.surfaces.canvas,
  ),
  child: Scaffold( ... ),
);
```

Update widget tests under `test/views/` (or add new ones at `test/views/brief_screen_test.dart`) to assert:

* The page background equals `BriefTheme.light().surfaces.canvas` in a light-theme test pump, and `BriefTheme.dark().surfaces.canvas` in a dark-theme test pump.
* `_wideTocSidebar` is `true` when the test pumps at 1024 px width and `false` at 600 px width, and the rendered markdown does not contain `Innholdsfortegnelse` in the wide case.

Files expected in this commit:

* `lib/views/brief_screen.dart`
* `test/views/brief_screen_test.dart` (new or updated)

Run `git status` and verify only those paths are staged. Commit: `refactor(brief): adopt BriefTheme and BriefMarkdown in BriefScreen with slim app bar`.

### Step 5. Sheet presentation from the `/brief` route

This step changes how the `/brief` route surfaces the brief. The screen content built in Step 4 is reused verbatim inside the sheet. No re-theming work in this step.

Edit `lib/views/main_screen.dart` (the GoRouter setup). For both `/brief/:exerciseUuid` and `/brief/program/:programUuid`:

* Replace the `builder: ... BriefScreen(...)` with a `pageBuilder:` that returns a transparent `CustomTransitionPage` whose `child` is a small launcher widget (e.g. `_BriefSheetLauncher`) carrying the same `exerciseUuid` / `programUuid` argument.
* The transition uses `opaque: false`, `barrierColor: Colors.transparent`, no transition animation. The launcher renders `const SizedBox.shrink()` for the route's own page contents because the visible UI is the modal sheet on top of it.

Add the launcher widget in `lib/views/brief_screen.dart` (or a new file `lib/views/brief_sheet_launcher.dart` if you prefer to keep the screen file slim):

* `StatefulWidget` with `exerciseUuid` / `programUuid` arguments.
* `initState` schedules `WidgetsBinding.instance.addPostFrameCallback((_) => _openSheet())`.
* `_openSheet` calls `showModalBottomSheet<void>(context: context, isScrollControlled: true, useSafeArea: true, backgroundColor: Colors.transparent, builder: (sheetContext) => _BriefSheetBody(exerciseUuid: ..., programUuid: ...))` and then on `.then((_) => Navigator.of(context).pop())` to pop the route when the sheet closes.

Build `_BriefSheetBody` as a `DraggableScrollableSheet` at `initialChildSize: 1.0`, `minChildSize: 0.5`, `maxChildSize: 1.0`, `expand: false`. The sheet has its own `ScrollController` (provided by `DraggableScrollableSheet.builder`) but only the drag-handle row uses it to react to drag-to-dismiss. Pass a separate inner `ScrollController` to `BriefMarkdown`/`TocWidget` so vertical drags inside the reading column scroll content rather than dismissing.

Layout of the sheet body:

```
ClipRRect(
  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  child: ColoredBox(
    color: theme.surfaces.canvas,
    child: Column(
      children: [
        _DragHandleArea(controller: outerController),     // 16 px tall, drag here = dismiss
        SlimBriefAppBar(...),                              // close X on the left, audience + actions on the right
        Expanded(child: _BriefBody(scrollController: innerController, ...)),
      ],
    ),
  ),
);
```

`_DragHandleArea`:

* A `GestureDetector` on a 32 px tall area, with a centered 4×40 px pill in `theme.borders.subtle`.
* `onVerticalDragUpdate` forwards into the outer controller so the sheet follows the finger.
* `onVerticalDragEnd` decides whether to dismiss (drag > 1/3 of viewport or velocity > 700 px/s) or snap back to `initialChildSize: 1.0`.

Slim app bar in the sheet:

* Reuses the slim bar built in Step 4 but the leading slot becomes a close button (`IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.of(sheetContext).pop())`). The close-button tooltip uses the new `briefClose` ARB key (Step 5 l10n below).
* The drag handle sits **above** the slim bar in the column. Its semantics label uses the new `briefDragHandle` ARB key.

Localization. Add to both `lib/l10n/app_en.arb` and `lib/l10n/app_nb.arb`:

* `briefClose` → "Close" / "Lukk".
* `briefDragHandle` → "Drag to close" / "Dra for å lukke".

Run `make build` to regenerate `app_localizations*.dart`.

Edit `lib/views/app_routes.dart` doc comment for `routeBrief` to mention the sheet presentation: "Pushed onto the root navigator as a transparent route that opens the brief in a fullscreen modal bottom sheet."

Add a widget test at `test/views/brief_sheet_test.dart` that:

* Navigates to `/brief/<exerciseUuid>` with a fixture program loaded into `ProgramService`.
* Pumps and asserts that a `DraggableScrollableSheet` is in the tree and that the underlying route's `Scaffold` background is transparent.
* Taps the close button and asserts the route pops (no `Brief` text remains in the tree).
* Pumps a vertical drag of 600 px on the drag-handle area and asserts the sheet dismisses.
* Pumps a vertical drag of 600 px on the markdown body and asserts the sheet does NOT dismiss (innerController scrolls instead).

Files expected in this commit:

* `lib/views/main_screen.dart`
* `lib/views/brief_screen.dart` (launcher + sheet body) — or `lib/views/brief_sheet_launcher.dart` (new) if you split it out
* `lib/views/app_routes.dart` (doc comment only)
* `lib/l10n/app_en.arb`
* `lib/l10n/app_nb.arb`
* `lib/l10n/app_localizations.dart` (regenerated)
* `lib/l10n/app_localizations_en.dart` (regenerated)
* `lib/l10n/app_localizations_nb.dart` (regenerated)
* `test/views/brief_sheet_test.dart`

Run `git status` and verify all paths are staged. Regenerated localization files MUST be in this commit, not a follow-up. Commit: `feat(brief): present brief as fullscreen modal bottom sheet from /brief route`.

## Verification

1. `flutter analyze` is clean.
2. `flutter test` produces no new failures. `test/widget_test.dart` remains broken (default counter template). Do not try to fix it. Report it as known-broken in the final write-up.
3. `make build` completes cleanly. Re-run `git status` after it. If any regenerated file is suddenly dirty after analyze and test passed, that file was missing from an earlier commit. Stop and amend the relevant commit before continuing.
4. **Clean tree gate.** `git status` on the working branch prints `nothing to commit, working tree clean`. `git ls-files --others --exclude-standard` prints nothing. No untracked, no unstaged, no stashed work. The work is not done until this is true. Do not invoke `git stash` or `git restore` to satisfy it.
5. **Diff sanity.** Run `git log --stat origin/main..HEAD` and walk every changed path. Confirm each file appears in exactly the commit you intended. If a regenerated `app_localizations*.dart` shows up in a different commit than the ARB edit that triggered it, fix the history with `git rebase -i` before declaring the work done.
6. Manual QA matrix. Record results in the final commit body or in a `docs/notes/` file if that matches existing convention:
   * **Light mode, wide.** Open the brief on a desktop window ≥ 900 px. Confirm white canvas, near-black headings (no Material blue), slim near-flat app bar with 1 px bottom border, body text in slate-700, links in body color with thin underline, code spans in light-gray pill. Sidebar visible with two-level outline (exercise + station), no "Tid" rows, no `Innholdsfortegnelse` heading anywhere in the body.
   * **Dark mode, wide.** Same as above but on the dark palette: near-black `#0B0F17` canvas, slate-300 body, slate-200 headings.
   * **Light mode, narrow.** Resize to ≤ 600 px. Sidebar hidden. In-doc `## Innholdsfortegnelse` block visible. Audience selector at top of body. Same color treatment.
   * **Sheet drag.** Open the brief. Drag the handle pill 600 px downward; sheet dismisses, URL returns to the previous route. Re-open. Drag inside the markdown body 600 px downward; text scrolls, sheet stays.
   * **Web print.** On the web build, open the brief and hit the print icon. `window.print` fires. The print preview shows the same markdown rendering (print stylesheet is Stage 5, out of scope; this QA just confirms no regression on the existing print hook).
7. No follow-up defects bundled in. If during the work you found anything that does not fit the five steps (e.g. an audience-selector accessibility bug on small screens, a missed Norwegian translation in an unrelated screen), record it at the bottom of the final commit body under a `## Follow-ups` heading and create a fresh prompt file under `docs/prompts/` named `adr-0023-followup-NN-<slug>.md` for each. Do not silently bundle.

## Out of scope

Everything below is **not** in this round, even if tempting:

* DESIGN-004 Stage 4 (form-side markdown editors with `appflowy_editor`).
* DESIGN-004 Stage 5 (print stylesheet).
* Any further markdown editor / preview pipework.
* Renaming or relocating files under `lib/views/`. [[file grouping is deferred]] per the existing convention.
* Refactoring `markdown_widget` away. The wrapper is the abstraction layer; the underlying package stays.
* Theming any other screen with `BriefTheme`. The Brief is intentionally a design island.

## Deliverables

A series of five Conventional Commits as outlined above, all on the same working branch, with a clean tree at the end. The final commit body should include:

* A one-line summary of what now looks different on the Brief screen (light + dark).
* The manual QA matrix filled out.
* A `## Follow-ups` section, even if empty, so reviewers can see at a glance whether new defects surfaced.

ADR-0023 is the authoritative spec. DESIGN-004 is the authoritative reference for what belongs in this round vs later stages. If you find yourself contradicting either, stop and ask. Do not write a new ADR.
