# Render markdown (including tables) in the plan overview card

You are working in the RingDrill repository, on the branch Kengu points you at
(currently `design-014`). **Another agent is committing on the same branch** —
pull/rebase before you start and before each commit, and never `git add -A`.
The working tree contains changes that are **not yours** and must stay
uncommitted: `bin/ringdrill.dart`, `lib/services/brief/brief_summary.dart`,
`netlify/functions/lib/mcp-compiler-bundle.js`, `tools/mcp_js_entry.dart`,
`assets/example/*` and `.claude/settings.local.json`. Commit only the files
each step below names, and do not run `make mcp-bundle`, `make build` or
`make format` (whole-tree) — nothing here changes a `@freezed` class, an
`@JsonValue` enum, an `.arb` file or the compiler.

Read `AGENTS.md` first: rule 9 (test-loop discipline), rule 10 (format only the
files you touched), rule 12 (docs in English), rule 14 (verify visual changes by
rendering to a PNG).

## The problem

A GFM pipe table authored in a plan-scope markdown field renders correctly in
the brief — `_briefMarkdownConfig` sets a `TableConfig`
(`lib/views/widgets/brief_markdown.dart:612-619`) and `markdown_widget` defaults
to `ExtensionSet.gitHubFlavored`. The plan overview card does not: it renders
the same fields as plain `Text`, so the LSOR plan's "Talegrupper" table arrives
as literal pipe soup on one line:

```
| Rolle | Talegruppe | |---|---| | LSOR Deltakere | RK-VFOLD-ØV4 / DMO-ANDRE-1 | | LSOR Stab | RK-VFOLD-ØV5 / DMO-ANDRE-2 |
```

Two causes, both in `_PlanOverview` (`lib/views/plan_view.dart:672-925`):

1. `description` goes through `RingDrillText.plain` (line 838) and the brief
   sections through bare `Text` (lines 845-859). Neither parses markdown, so
   every block marker shows up verbatim.
2. `_firstParagraphText` (lines 912-924) splits on `\n\n` and joins the
   remaining lines with a space. A pipe table is one blank-line-delimited block,
   so it survives the filter and gets flattened — that is the exact string
   above.

There is also a latent third defect: `TableConfig` sets no `wrapper`,
`columnWidths` or `defaultColumnWidth`, and `markdown_widget`'s `TableNode`
builds a `Table` with `IntrinsicColumnWidth` inside a `WidgetSpan` with no
horizontal scroll. Wide enough on a desktop brief, but a phone-width brief — and
the overview card at any width — will overflow rather than scroll.

## The design

**Collapsed** stays a plain-text teaser: three lines, one `Text`, measured by
`_exceedsLines`. That measurement is `TextPainter`-based and cannot survive a
markdown widget tree, and a three-line teaser is the wrong place for a table
anyway. What changes is that the teaser is produced by a table-aware
markdown-to-plain-text helper instead of `_firstParagraphText`, so the pipe soup
never reaches the screen.

**Expanded** renders real markdown — the same `BriefMarkdownBlock` the rollups
and the roleplay detail already use, so tables, bold, lists and copy chips look
exactly as they do in the brief. Drop the first-paragraph truncation from this
path: the whole point of "Vis mer" is to show what is in the field, and a table
as the first block of `commsMd` has no readable first-paragraph form.

Keep the two existing resolution paths exactly as they are — this change is
about rendering, not about resolution:

- `description` keeps resolving through `RingDrillText` against the ambient
  `PlanScope` (switch `.plain` → `.rich` for the expanded branch).
- the brief sections keep resolving through `_resolvePlanText(plan, md, l10n)`
  with an explicit plan, and the resolved string goes straight into
  `BriefMarkdownBlock(data: …, theme: BriefTheme.of(context), gutter: 0)`.

Do **not** add a `richForPlan` constructor to `RingDrillText` for this;
`ResolvedMarkdownText.resolve` and `resolvePlanText` are not the same entry
point, and swapping one for the other would silently change what the card
resolves. Note the asymmetry in a comment instead.

No new user-visible strings, so no ARB edits and no `make i18n`.

## Commit 1 — a table-aware markdown teaser

Add `lib/utils/markdown_text.dart`. Pure Dart, **no `package:flutter/*`
import** — `lib/utils/` is inside the CLI closure (rule 7).

```dart
/// A markdown field reduced to a one-paragraph plain-text teaser.
typedef MarkdownTeaser = ({String text, bool truncated});

/// Returns null when nothing in [md] can be shown as prose.
MarkdownTeaser? markdownTeaser(String? md);
```

Behaviour:

- Strip fenced code blocks and HTML comments before splitting.
- Split into blank-line-delimited blocks. **Skip** blocks that are a pipe table
  (a line beginning with `|`, or a `---|`-style delimiter row), a horizontal
  rule, or an image-only block. Keep heading blocks, with the leading `#`
  removed — that is today's behaviour and it reads fine in a teaser.
- Take the first surviving block; strip per-line markers (`#`, `>`, `-`, `*`,
  `1.`), collapse `**bold**` / `_em_` / `` `code` `` / `[text](url)` to their
  text, and join its lines with a single space.
- `truncated` is true when anything was skipped or when a block follows the one
  returned — the overview card uses it to decide whether "Vis mer" is needed.
- Return null when no block survives (a field holding only a table).

Tests in `test/utils/markdown_text_test.dart` (pure `flutter_test`, no widgets):
table dropped in favour of the following paragraph; table-only field returns
null; `truncated` false for a single plain paragraph and true otherwise; inline
markers collapsed; heading kept without its `#`; null and whitespace-only input
return null.

Files: `lib/utils/markdown_text.dart`, `test/utils/markdown_text_test.dart`.
Also run `flutter test test/bin/cli_flutter_free_test.dart` (rule 7).
Commit: `feat(utils): reduce a markdown field to a table-aware plain teaser`.

## Commit 2 — let a table scroll instead of overflow

In `_briefMarkdownConfig` (`lib/views/widgets/brief_markdown.dart:612-619`) give
`TableConfig` a `wrapper` that puts the built table in a horizontally
scrollable, left-aligned box. Check the actual field name and signature in the
installed `markdown_widget` (`^2.3.2+8`) before writing it — `wrapper` takes the
built `Table` widget and returns a replacement.

Keep it a `SingleChildScrollView(scrollDirection: Axis.horizontal, child: …)`
inside something that does not stretch the table to the full line width, and
verify the result renders (a horizontal scroll view inside a `WidgetSpan` is
exactly the combination that asserts if the constraints are wrong). If it does
assert, fall back to `defaultColumnWidth: IntrinsicColumnWidth()` plus a
`ClipRect` and say so in a comment rather than leaving an overflow.

Test in `test/views/widgets/brief_markdown_test.dart`: a two-column pipe table
at a narrow width (say 320 px) renders a `Table` with the header and body cells
findable (`findRichText: true`), produces no overflow error, and is inside a
horizontal `Scrollable`.

Files: `lib/views/widgets/brief_markdown.dart`,
`test/views/widgets/brief_markdown_test.dart`.
Commit: `fix(views): scroll a wide markdown table instead of overflowing it`.

## Commit 3 — the overview card renders markdown when expanded

In `_PlanOverview` (`lib/views/plan_view.dart`):

- Compute `hasContent` from the **raw** fields (`description`,
  `plan.briefIntroMd`, `plan.commsMd`, `plan.beforeRoundMd`), not from the
  teasers. A field holding only a table now teases to null, and deriving
  `hasContent` from that would make the whole card — table included — disappear
  and replace itself with the empty-state edit row.
- Replace `_firstParagraphText` with `markdownTeaser`, applied **after**
  `_resolvePlanText`, so the resolved values are what gets measured and shown.
  Delete `_firstParagraphText`.
- Collapsed branch, unchanged in shape: `RingDrillText.plain` for the
  description teaser, or the promoted first brief section's label + `Text`
  teaser when `description` is empty. Feed both the teaser text, not the raw
  markdown.
- Expanded branch: `RingDrillText.rich(description)` when there is a
  description, then for every brief section its label plus a
  `BriefMarkdownBlock` over the resolved markdown. No `maxLines`, no
  first-paragraph truncation. Keep the label styling (`labelStyle`) and the
  8 px spacing between sections.
- Toggle visibility: show it when the teaser exceeds `_collapsedLines`, **or**
  the teaser is `truncated`, **or** there are sections hidden while collapsed.
  A description that is a single short paragraph with no brief sections must
  still show no toggle.
- The card keeps its `InkWell(onTap: onEdit)`. `BriefMarkdownBlock` deliberately
  has no `SelectionArea` for exactly this reason, but its action chips have
  their own gesture recognizers — confirm tapping the card body still opens
  `PlanFormScreen` and that a copy chip inside the expanded card still copies.

Tests to touch:

- `test/views/plan_overview_test.dart` — the existing
  `find.text('Plan description text')` assertions (lines 264, 283, 300, 345,
  353, 371) all observe the **collapsed** card, so they should keep passing
  against the plain teaser. If any needs `findRichText: true`, that is a signal
  the collapsed state changed shape; fix the code, not the test. Add: a plan
  whose `commsMd` is a pipe table renders a `Table` after tapping "Vis mer" and
  shows no `|` character while collapsed; a table-only `commsMd` still renders
  the card (not the empty-state row) and still offers the toggle.
- `test/views/plan_view_overview_test.dart` — these have an empty `description`
  and only `briefIntroMd`, i.e. the promoted-teaser path, so the
  `find.textContaining` assertions should also survive. Add one expanded-state
  case asserting the same resolution holds through `BriefMarkdownBlock`
  (`findRichText: true`), and update the file's header comment: the card is no
  longer "a stripped first-paragraph extract" in its expanded state.

Files: `lib/views/plan_view.dart`, both test files above.
Commit: `fix(views): render plan markdown, tables included, in the overview card`.

## Commit 4 — verify and close out

Render the card with `skills/flutter-widget-preview/` (rule 14) and inspect the
PNGs: collapsed with a table-bearing `commsMd` (no pipes, three lines, toggle
present), expanded with the table (borders, header weight, no overflow stripe),
expanded at 360 px width with a table wide enough to need scrolling, and dark
mode. `assets/example/lsor-ovelseshefte-2026.yaml` holds the real "Talegrupper"
table this bug came from — read it for the fixture, but leave the file alone, it
is another agent's uncommitted work.

Final gate, once: `flutter analyze`, full `flutter test`, `make cli-check`, and
`dart format` on the files you touched.
Commit: `test(views): verify markdown tables render in the plan overview`.

## Guardrails

- Per-commit: `flutter analyze` plus the targeted tests only. Full
  `flutter test` and `make cli-check` **once**, at the end (rule 9).
- Every commit leaves `git status` clean *for your files*; the not-yours list at
  the top stays untracked and unstaged.
- Do not change `RingDrillText.plain`'s stripping behaviour or
  `_stripChipMarkup` — they serve titles, list rows and names everywhere, and
  widening them to swallow block markdown would change surfaces this prompt
  never looked at. Block-level stripping belongs in `markdownTeaser`.
- Do not restyle `BriefTheme`, the card container, or the segmented switcher.
  The card's chrome is correct; only its text rendering is wrong.
- Do not turn the overview card into a second brief reading surface: no TOC, no
  search, no independent scroll. It is a block inside the plan view's
  `CustomScrollView`.
