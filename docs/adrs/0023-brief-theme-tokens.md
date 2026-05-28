---
status: accepted
date: 2026-05-27
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0023: Render the Brief view with a dedicated `BriefTheme` token set inspired by docs-site typography, independent of Material `ColorScheme`

## Context and problem statement

[DESIGN-004](../design/brief-template.md) introduced the Brief view, a read-mode for an exercise or whole program. Stage 3 wires `lib/views/brief_screen.dart` to `markdown_widget` with a `TocController`, a `TocWidget` sidebar on wide screens and a `SegmentedButton` audience toggle in the app bar. The screen inherits the app's Material 3 `ColorScheme`.

The result reads as a generic Flutter Material screen, not a documentation surface. Concretely:

* Headings render in `colorScheme.primary` blue because `markdown_widget`'s default `H1Config`/`H2Config` derive from the active theme's primary color. In light mode the page title becomes bright Material blue on white; in dark mode every heading turns cyan against a near-black surface.
* The app bar fills with `colorScheme.primary` in light mode, dominating a screen whose purpose is sustained reading.
* Inline links are rendered in bright underlined cyan in both modes, drawing the eye away from the body text.
* `TocWidget` mirrors every `<h2>`/`<h3>`/`<h4>` from the rendered markdown into the left sidebar. The mustache template currently emits `#### Tid` under each station, so the outline tree shows a "Tid" row for every station and balloons in height.
* The same template emits a full in-document table of contents under `## Innholdsfortegnelse`, which on wide screens duplicates the sidebar's TOC verbatim.
* The reading column has no maximum width, so on a desktop window text runs edge-to-edge in lines well past the comfortable measure.

The Brief is the only screen in RingDrill whose purpose is reading. Every other screen (`StationsView`, `ExerciseScreen`, `RolePlayScreen`, the player, the forms) is a working surface that benefits from the app's Material accent appearing where actions live. The Brief benefits from the opposite: low chrome weight, generous typographic rhythm, calm color and a constrained measure. Forcing the Brief through the same `ColorScheme` as the working surfaces is the root cause of the issues above.

Two reference looks were considered side by side during the design conversation that produced this ADR: [Zudoku](https://zudoku.dev) and [Mintlify](https://mintlify.com). Both follow the same family of typographic and chromatic choices: near-monochrome body text, low-saturation neutrals, accent reserved for navigation state, and a constrained reading column. Zudoku is the closer match because it also ships a dark mode with a near-black canvas and slate-tinted neutrals, which fits an app that already has a dark theme as a first-class target.

This ADR also folds in the visual-language additions to DESIGN-004 itself so we do not need a separate ADR for the template-level changes (drop in-doc TOC on wide screens, demote `#### Tid`). The DESIGN-004 doc is updated in the same change set with a "Visual design" section pointing back here.

## Decision drivers

* The Brief view is a reading surface, distinct from every other screen in the app. Its visual language can and should diverge from the rest of the Material 3 theme.
* Both light and dark mode must look intentional, not "auto-inverted". Light-mode failure is the worst current case and is the gating criterion.
* The token set should be one place a future contributor (or designer) can tweak. The pattern already used for `LiveAccent` in `lib/views/widgets/live_accent.dart` — value-class with named factory variants — has worked well and should be reused.
* `markdown_widget` configuration is verbose and easy to drift. Tokens must flow into the renderer through a single thin wrapper widget, not be spread across call sites.
* The CLI ban from [ADR-0005](./0005-cli-must-remain-flutter-free.md) is unaffected: `BriefTheme` lives in `lib/views/widgets/` and is only consumed by the Brief screen.
* Reuse `markdown_widget` and its `TocController`/`TocWidget` rather than swap renderers. The package is already in `pubspec.yaml` and powers the only markdown surface we ship.
* Keep mobile-safe imports mobile-safe per AGENTS.md rule 3. The Brief is mobile-first as well as desktop-first.

## Considered options

* **Option A: Dedicated `BriefTheme` value-class with hardcoded light/dark palettes, plus a `BriefMarkdown` thin wrapper around `markdown_widget`, plus template-side cleanups (drop in-doc TOC on wide, demote `#### Tid` to bold). The Brief screen also gets a constrained reading-column layout and a custom slim app bar. (chosen)**
* **Option B: Derive Brief palette from `Theme.of(context).colorScheme` with selective overrides.** Same wrapper widget, but tokens are computed from the active `ColorScheme` with a fixed offset table. Smaller diff but defeats the goal: the look is still chained to the app's Material primary.
* **Option C: Swap `markdown_widget` for `gpt_markdown` or `flutter_markdown_plus`.** Replaces the renderer entirely. Larger surface area, churns code that already works, and the underlying problem (Material primary leaking in) would still apply unless a token layer is added on top.
* **Option D: Status quo plus targeted tweaks in `BriefScreen` (e.g. force `H1Config.style = TextStyle(color: Colors.black)`).** Inline overrides at the call site. Solves the worst symptoms but spreads style decisions across the screen file with no shared token; the next maintainer will not know where to change a color.
* **Option E: Keep Material defaults, accept that the Brief looks like the rest of the app.** Cheapest. Does not meet the read-surface goal.

## Decision outcome

Chosen option: **Option A**, because it removes the Material-primary leak at its source, encodes the docs-site reference look in a single readable token block, keeps `markdown_widget` (and its `TocController`) untouched, and lands the template-side changes (TOC, "Tid") in the same change set so DESIGN-004 stays the single source of truth for the brief's structure.

### `BriefTheme` value-class

New file `lib/views/widgets/brief_theme.dart`. The shape mirrors `LiveAccent` (see [`live_accent.dart`](../../lib/views/widgets/live_accent.dart)):

```dart
@immutable
class BriefTheme {
  const BriefTheme._({
    required this.surfaces,
    required this.text,
    required this.borders,
    required this.code,
    required this.link,
    required this.accent,
    required this.typography,
    required this.spacing,
  });

  final BriefSurfaces surfaces;
  final BriefTextColors text;
  final BriefBorders borders;
  final BriefCodeStyle code;
  final BriefLinkStyle link;
  final BriefAccent accent;
  final BriefTypography typography;
  final BriefSpacing spacing;

  factory BriefTheme.light() => const BriefTheme._( ... );
  factory BriefTheme.dark()  => const BriefTheme._( ... );

  /// Resolves a `BriefTheme` for the current `MediaQuery.platformBrightness`
  /// (or, when present, an explicit override the screen passes in).
  factory BriefTheme.of(BuildContext context, {Brightness? override}) {
    final brightness = override ?? Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? BriefTheme.dark()
        : BriefTheme.light();
  }
}
```

The named factories return `const` instances so the theme is cheap to read in `build`. The factories do **not** consult `Theme.of(context).colorScheme`; the palette is hardcoded. The only environmental input is brightness.

### Palette (hardcoded values)

Light mode:

| Token                  | Value     | Notes                                              |
|------------------------|-----------|----------------------------------------------------|
| `surfaces.canvas`      | `#FFFFFF` | Reading-column background.                         |
| `surfaces.sidebar`     | `#FAFAFA` | TOC sidebar background.                            |
| `surfaces.appBar`      | `#FFFFFF` | Slim app bar, no Material primary fill.            |
| `borders.subtle`       | `#E5E7EB` | App-bar bottom 1px, sidebar right edge, hr.        |
| `text.heading`         | `#0F172A` | All headings (H1..H4) and emphasized body.         |
| `text.body`            | `#334155` | Default paragraph color.                           |
| `text.muted`           | `#64748B` | Captions, sidebar labels, audience hint text.      |
| `link.color`           | `#334155` | Same as body. Distinction is the underline only.   |
| `link.underlineOpacity`| `0.4`     | Painted as `Color.fromRGBO(51,65,85,0.4)`.         |
| `code.background`      | `#F4F4F5` | Inline and block code.                             |
| `code.foreground`      | `#0F172A` | Inline and block code.                             |
| `code.border`          | `#E5E7EB` | 1px around inline code chips and block code.      |
| `accent.activeStripe`  | `#0F172A` | Active sidebar item 2px left stripe.               |

Dark mode:

| Token                  | Value     | Notes                                              |
|------------------------|-----------|----------------------------------------------------|
| `surfaces.canvas`      | `#0B0F17` | Near-black with slight blue tint, Zudoku-style.    |
| `surfaces.sidebar`     | `#0F1623` | One step lighter than canvas.                      |
| `surfaces.appBar`      | `#0B0F17` | Same as canvas, divider on the bottom.             |
| `borders.subtle`       | `#1F2937` |                                                    |
| `text.heading`         | `#E5E7EB` |                                                    |
| `text.body`            | `#CBD5E1` |                                                    |
| `text.muted`           | `#94A3B8` |                                                    |
| `link.color`           | `#CBD5E1` |                                                    |
| `link.underlineOpacity`| `0.6`     | Slightly stronger than light to retain affordance. |
| `code.background`      | `#1F2937` |                                                    |
| `code.foreground`      | `#E5E7EB` |                                                    |
| `code.border`          | `#1F2937` | Same as bg = no visible border.                    |
| `accent.activeStripe`  | `#E5E7EB` |                                                    |

The palette is sourced from a Tailwind-style slate ramp because both Zudoku and Mintlify converge there in practice. The hardcoded values matter: deriving them from `colorScheme` is exactly the bug this ADR removes.

### Typography

| Role     | Size | Weight | Line-height | Top margin |
|----------|-----:|-------:|------------:|-----------:|
| H1       | 32   | 700    | 1.20        | 0          |
| H2       | 24   | 600    | 1.30        | 32         |
| H3       | 18   | 600    | 1.40        | 24         |
| H4       | 16   | 600    | 1.40        | 20         |
| Body     | 16   | 400    | 1.65        | 0          |
| Code (mono) | 14 | 400    | 1.50        | 0          |

`BriefTypography` exposes one `TextStyle` per role, ready to drop into `markdown_widget`'s `H1Config`/`H2Config`/`H3Config`/`H4Config`/`PConfig`/`CodeConfig`. Font family stays the app default for body and headings; code uses `Theme.of(context).textTheme` monospace if available, otherwise `'monospace'`.

### Reading-column layout

`BriefSpacing`:

* `readingColumnMax` — 720 px. The widget wraps the markdown in a `ConstrainedBox(maxWidth: 720)`, centered horizontally within the available space.
* `gutter` — 24 px on each side of the reading column for breathing room.
* `sidebarWidth` — 240 px.
* `appBarHeight` — 56 px (slim).

On wide screens (`>= 900 px` per the existing `_kWideBreakpoint`), the layout is:

```
+--------+-----------------------------+--------+
| Side   |  Reading column (max 720)   |  flex  |
| bar    |                             |        |
| 240    |                             |        |
+--------+-----------------------------+--------+
```

On narrow screens, the sidebar is hidden and the reading column expands to the viewport minus `2*gutter`.

### `BriefMarkdown` thin wrapper

New file `lib/views/widgets/brief_markdown.dart`. Wraps `markdown_widget` with a single `MarkdownConfig` that pulls every style from a `BriefTheme`. Existing `MarkdownWidget(...)` calls in `lib/views/brief_screen.dart` are replaced by `BriefMarkdown(...)`. The screen no longer constructs `MarkdownConfig` inline.

The wrapper takes:

```dart
BriefMarkdown({
  required String data,
  required BriefTheme theme,
  TocController? tocController,
});
```

It composes `MarkdownConfig.defaultConfig.copy(configs: [...])` with `H1Config`, `H2Config`, `H3Config`, `H4Config`, `PConfig`, `LinkConfig`, `CodeConfig`, `PreConfig`, `BlockquoteConfig` and `TableConfig` populated from the theme. No call site reaches into `markdown_widget` configs directly.

### Slim app bar

The Brief screen drops `AppBar` for a custom `PreferredSize` slim bar that sits at the top of the brief content. The brief is presented as a fullscreen modal bottom sheet ([DESIGN-004 "Presentation"](../design/brief-template.md#presentation)), so the slim bar is the top of the sheet, not of a route page. The styling is the same in either context.

* Surface: `theme.surfaces.appBar`.
* Bottom border: 1 px in `theme.borders.subtle`.
* Title: `text.heading` style at H4 weight/size.
* Audience selector: `SegmentedButton` themed to use `theme.text.body` for unselected segments and a soft `theme.surfaces.sidebar` fill for the selected segment, with `theme.text.heading` text on the selected segment. No primary fill.
* Search and print actions become text-color `IconButton`s with no tinting.
* Leading slot: a close button (`Icons.close`) styled in `theme.text.heading`, replacing the back arrow. Tapping it closes the sheet and pops the underlying route.
* A drag-handle pill (4×40 px in `theme.borders.subtle`) is centered above the title row. The handle is the only surface wired to drag-to-dismiss; the markdown body uses its own scroll controller so vertical drags in the reading column scroll text rather than dismiss the sheet.

The screen passes `Theme(data: Theme.of(context).copyWith(appBarTheme: ...))` only locally so the rest of the app remains untouched.

### Template changes (folded in, no separate ADR)

`assets/templates/ringdrill-standard-v1.nb.md.mustache`:

1. The static `## Innholdsfortegnelse` block (current lines 6–10) is moved behind a renderer-side flag `includeInDocToc`. The `BriefRenderer` sets it to `false` when the caller passes `wideTocSidebar: true` and `true` otherwise. `BriefScreen` decides this based on the breakpoint at render time (see "Renderer signature change" below).
2. The station-level `#### Tid` heading (current line 46) becomes inline bold text: `**Tid:** {{durationLabel}}`. Same for any other `#### ` heading that is one-liner metadata. The exercise-level `| Tid | {{durationLabel}} |` table row stays as-is.
3. The `## {{name}}` exercise heading and `### {{exerciseNumber}}{{stationLetter}} – ...` station heading remain as the only two levels that appear in the sidebar TOC.

The net effect: the sidebar outline is at most two levels (exercise -> station), no "Tid" rows, no `Innholdsfortegnelse` duplicate.

### Renderer signature change

`BriefRenderer.render(...)` gains an optional `bool wideTocSidebar = false` parameter that is forwarded into the mustache context as `if_in_doc_toc = !wideTocSidebar`. The template wraps the in-doc TOC block in `{{#if_in_doc_toc}}...{{/if_in_doc_toc}}`. `BriefScreen` computes the value from its `LayoutBuilder` and rebuilds the render future when the breakpoint crosses.

### Public API summary

```dart
// lib/views/widgets/brief_theme.dart
class BriefTheme { ... factory .light(), .dark(), .of(context) }
class BriefSurfaces { ... }
class BriefTextColors { ... }
class BriefBorders { ... }
class BriefCodeStyle { ... }
class BriefLinkStyle { ... }
class BriefAccent { ... }
class BriefTypography { ... }
class BriefSpacing { ... }

// lib/views/widgets/brief_markdown.dart
class BriefMarkdown extends StatelessWidget {
  const BriefMarkdown({
    required this.data,
    required this.theme,
    this.tocController,
  });
  final String data;
  final BriefTheme theme;
  final TocController? tocController;
}

// lib/services/brief/brief_renderer.dart  (signature change only)
Future<String> render({
  required Program program,
  Exercise? exercise,
  required BriefAudience audience,
  bool wideTocSidebar = false,
});
```

### Localization

No new ARB keys. The label "Innholdsfortegnelse" already exists in the template; the existing sidebar header uses `briefToc` from `app_en.arb` / `app_nb.arb`.

### Consequences

* Good: Light mode stops looking like a Material screen and reads as a docs page.
* Good: Dark mode acquires a near-black canvas and slate-tinted neutrals instead of the default Material 3 dark surface, matching the Zudoku reference.
* Good: Headings stop borrowing `colorScheme.primary`, so the Brief view's look is unaffected by future Material seed-color tweaks.
* Good: The sidebar TOC collapses to two clean levels, and the in-doc TOC stops duplicating it.
* Good: A future template author tweaks one file (`brief_theme.dart`) to restyle every Brief surface. The pattern matches `LiveAccent`, so it should be familiar to anyone who has touched the live-row treatment.
* Good: `markdown_widget` and its `TocController` stay in place. No package swap.
* Bad: The Brief view becomes a small design island. A future maintainer who changes the app's Material seed color will not see the Brief follow along. This is intentional but worth flagging in onboarding docs.
* Bad: The hardcoded palette is two more places (light and dark) to keep in sync if we ever rebrand. A `BriefBrand` extension hook is a follow-up if Teams accounts demand it.
* Bad: The `wideTocSidebar` plumbing adds a render-time parameter that crosses the screen/renderer boundary. `BriefScreen` must rebuild the render future on breakpoint changes, not only on audience changes.
* Bad: Inline-bold `**Tid:**` loses the in-doc anchor that `#### Tid` provided. If a future feature needs to deep-link to a station's time row, the template will need to add an explicit anchor.

## Pros and cons of the options

### Option A — Dedicated `BriefTheme`, `BriefMarkdown` wrapper, template cleanups

* Good: One token set, two factories, one wrapper widget. Future changes have an obvious home.
* Good: Renderer change is small (one optional parameter), template change is small (two edits), screen change is contained.
* Good: Removes Material primary leak at the source rather than masking it.
* Bad: New file pair plus accompanying tests, plus a renderer parameter that is only used by the wide layout.

### Option B — Derive Brief palette from `ColorScheme` with offsets

* Good: Smaller diff. Re-uses existing palette infrastructure.
* Bad: The Brief still drifts with the app's seed color, which is what produces today's failure.
* Bad: An offset table is harder to reason about than two hardcoded factories.

### Option C — Swap `markdown_widget` for another renderer

* Good: A renderer with stronger built-in theming (e.g. `gpt_markdown`) could simplify the wrapper.
* Bad: Replaces a working dependency. Larger blast radius.
* Bad: The Material-primary leak would still need explicit overrides regardless of the renderer.

### Option D — Status quo plus targeted overrides in `BriefScreen`

* Good: No new files.
* Bad: Style decisions are scattered across the screen file. The next maintainer has no single place to tweak the theme.
* Bad: Light-mode app-bar fill and link color still come from Material defaults.

### Option E — Accept Material defaults

* Good: Zero work.
* Bad: Does not meet the reading-surface goal that motivated DESIGN-004 in the first place.

## Revisions

### 2026-05-28

- **Reverses the "demote `#### Tid` to inline bold" decision** from the initial implementation. The sidebar TOC is now filtered to H2+H3 entries by a `level > 3` short-circuit in `BriefScreen`'s `TocWidget.itemBuilder`; `####` headings are restored throughout the template for all station-level and exercise-level metadata fields.
- **`_durationLabel` split into three focused helpers**: `_exerciseTimeLabel` (clock-time span "HH:MM–HH:MM"), `_exerciseDurationLabel` (total duration with per-round breakdown, e.g. "2 timer (60 min pr oppdrag)"), `_stationDurationLabel` (per-round with phase breakdown "N min (e | v | r)"). "Tid" = clock-time; "Varighet" = duration — the two concepts no longer share a helper.
- **Exercise-level markdown table removed** in favour of standalone `####` section headings per field. The `setupLabel <br>`-in-table escaping bug is dissolved as a consequence. `Program.beforeRoundMd` (ADR-0022 shape) is added to hold the "Før hver post" prose injected into the Organisering block.

## Links

* Related ADRs:
  * [ADR-0004](./0004-no-third-party-state-management.md) — keeps the brief screen's theming local, no app-wide provider.
  * [ADR-0005](./0005-cli-must-remain-flutter-free.md) — `BriefTheme` is view-layer only; the CLI is unaffected.
  * [ADR-0022](./0022-markdown-content-as-files.md) — the file format that supplies the markdown the renderer styles.
* Related design docs:
  * [DESIGN-004](../design/brief-template.md) — the brief feature. This ADR extends its "Render targets" and "Behavior" sections with a Visual design section.
* Related code:
  * `lib/views/widgets/brief_theme.dart` (new) — token set and factories.
  * `lib/views/widgets/brief_markdown.dart` (new) — thin wrapper over `markdown_widget`.
  * `lib/views/widgets/live_accent.dart` — pattern reference.
  * `lib/views/brief_screen.dart` — adopts `BriefTheme`/`BriefMarkdown`, gains slim app bar and reading-column layout.
  * `lib/services/brief/brief_renderer.dart` — gains optional `wideTocSidebar` parameter.
  * `assets/templates/ringdrill-standard-v1.nb.md.mustache` — gates the in-doc TOC; all metadata fields use `####` headings; sidebar TOC filtered to H2+H3 in `BriefScreen`.
* External references:
  * [Zudoku docs](https://zudoku.dev) — typography and palette reference for the dark mode and overall feel.
  * [Mintlify](https://mintlify.com) — secondary reference for the slim app bar and sidebar style.
  * [markdown_widget configuration](https://pub.dev/packages/markdown_widget) — the renderer the wrapper composes.
