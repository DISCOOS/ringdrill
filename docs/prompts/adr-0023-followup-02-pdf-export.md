# ADR-0023 Follow-up 02 — Pivot from browser print to PDF export

You are working in the RingDrill repository. This follow-up replaces the current `window.print()`-based print path for the Brief view with native, cross-platform PDF generation. DESIGN-004 originally specced Stage 5 as a web-only print stylesheet that hid chrome and forced page breaks between exercises. In practice that produces a screenshot of the current viewport rather than a polished printed document. The pivot moves to PDF as the canonical export format on every platform (web, iOS, Android, macOS, Windows, Linux), generated from the same markdown the brief renders on screen.

This prompt is the authoritative work order for the pivot. DESIGN-004 stays the spec for *what* the brief contains and the visual language; this prompt covers *how* the PDF is produced.

## Ground rules

Read `AGENTS.md` and follow every numbered rule. The non-negotiable ones for this change:

* CLI must stay Flutter-free. The PDF generator lives in `lib/services/brief/` and depends on `package:pdf` (pure Dart) and `package:printing` (Flutter). The `printing` import is the cross-platform print/share entry point; the CLI must not pull it in. Verify nothing transitively reachable from `bin/ringdrill.dart` adds `package:printing` or `package:pdf`.
* Mobile-safe imports. `printing` is platform-aware and works on all targets including web. The previous `lib/web/brief_print*.dart` conditional-import pair becomes redundant once the new path is in place — remove both files in the same commit that wires up the new entry point.
* Localize. New ARB keys land in `lib/l10n/app_en.arb` and `lib/l10n/app_nb.arb` together. Suggested keys are listed under Step 4.
* No new lint suppressions. `dart format` before each commit.
* `test/widget_test.dart` is the known-broken default-template smoke test. Flag it as such, never claim "all tests pass".
* Honour [[feedback_design_tokens_pattern]] — the PDF document's visual language reuses `BriefTheme` colors and typography numbers via a parallel `BriefPdfTheme` value-class, not by re-deriving from Material `ColorScheme`.

## Commits

Five logical commits, in order, on the same working branch. Use Conventional Commits with scope `brief`. Suggested subjects:

1. `chore(deps): add printing and pdf for cross-platform PDF export`
2. `feat(brief): add BriefPdfGenerator that walks markdown into pw widgets`
3. `feat(brief): replace web-only window.print with cross-platform PDF action`
4. `docs(brief): pivot DESIGN-004 stage 5 from print CSS to PDF generation`
5. `test(brief): cover BriefPdfGenerator for headings, lists and code spans`

### Commit discipline (non-negotiable)

* After every step below, run `git status` and `git diff --stat` and confirm there are no untracked or unstaged paths before claiming the step done. Untracked files count as failure.
* Each step lists the **files expected in that commit**. The commit must include every listed path. Anything beyond the list also belongs in the commit unless explicitly punted. If you see a path you do not recognize in `git status`, do not delete it. Inspect it, then either include it or stop and ask.
* Regenerated `app_localizations*.dart` files are part of the commit that triggered them. Do not park them in a "regen" follow-up commit.
* Never close a step with `git stash` or `git restore`.
* The final Verification gate requires `git status` to print a clean tree on the working branch with no untracked or unstaged files.

## Scope

Five steps. Do them in order.

### Step 1. Dependencies

Edit `pubspec.yaml`. Add two packages alongside the existing `markdown_widget` entry:

```yaml
  printing: ^5.13.0
  pdf: ^3.11.0
```

Pin to the latest stable releases the resolver allows. `printing` provides the cross-platform print and share entry points; `pdf` provides the document model and `pw.Widget` tree the generator emits into.

Run `flutter pub get`.

Confirm nothing reachable from `bin/ringdrill.dart` (currently only `lib/data/drill_client.dart`) transitively imports `package:printing` or `package:pdf`. Both new packages must stay isolated to the brief feature.

Files expected in this commit:

* `pubspec.yaml`
* `pubspec.lock`

Run `git status`. Confirm only those two paths are staged. Commit: `chore(deps): add printing and pdf for cross-platform PDF export`.

### Step 2. `BriefPdfGenerator`

Create `lib/services/brief/brief_pdf_generator.dart`. The generator takes the same inputs as `BriefRenderer.render` and returns a fully-built `pw.Document`:

```dart
class BriefPdfGenerator {
  BriefPdfGenerator({BriefPdfTheme? pdfTheme});

  final BriefPdfTheme _pdfTheme;

  Future<pw.Document> generate({
    required Program program,
    Exercise? exercise,
    required BriefAudience audience,
    required AppLocalizations l10n,
  }) async { ... }
}
```

Internal pipeline:

1. Reuse `BriefRenderer().render(...)` to produce the same markdown the on-screen brief renders. Pass `wideTocSidebar: true` so the in-doc TOC is suppressed (PDF gets its own table-of-contents page via `pw.PageTheme` features).
2. Parse the markdown via `package:markdown`'s `Document.parseLines(...)` (this is what `markdown_widget` already does internally, so the AST shape is familiar).
3. Walk the AST and emit a `pw.Widget` tree using the visitor pattern. Each node type maps to a `pw` widget:
   * `h1` / `h2` / `h3` / `h4` → `pw.Text` with the matching `BriefPdfTheme` text style. Headings start a new flow block with top padding from `BriefPdfTheme.spacing`.
   * `p` → `pw.Paragraph` (or `pw.Text` for single-line content). Inline children (strong, em, links, inline code) are emitted as `pw.RichText` with `pw.TextSpan` children.
   * `ul` / `ol` → `pw.Bullet` rows or a custom `pw.Column` with leading bullet characters. v1 may use a custom column with `•` markers for simplicity.
   * `code` (inline) → `pw.Container` styled like the on-screen chip: padded, rounded background, monospaced font. The "Copy" interactivity from `_CodeChip` is not portable to PDF and is dropped silently.
   * `pre code` (fenced block) → `pw.Container` with `pw.Text` body, scaled to the page width.
   * `blockquote` → left-bordered `pw.Container` with muted body color.
   * `hr` → `pw.Divider` in `BriefPdfTheme.borders.subtle`.
   * `table` → `pw.Table` with header row in `BriefPdfTheme.text.heading`.
   * `<mark>` / `<curr-mark>` — search-highlight tags from BriefScreen — are stripped from the PDF source. Use a pre-walk pass that removes those tags before parsing, since the highlight is a screen-only affordance.
4. Wrap the page content in a `pw.MultiPage` with header (program / exercise name + audience label) and footer (page number / total pages). The `MultiPage` paginates automatically — no manual page-break logic is needed for v1.

Create a sibling `lib/services/brief/brief_pdf_theme.dart` mirroring the `BriefTheme` pattern but with `PdfColor` / `pw.TextStyle` types. Hardcoded light palette only (no dark mode for PDF — paper is always light). Reuse the hex values from `BriefTheme.light()`. Typography numbers are scaled appropriately for A4 / Letter print (e.g. body text 11 pt instead of 16 px).

Helper: a top-level `Future<Uint8List> buildBriefPdf(Program program, Exercise? exercise, BriefAudience audience, AppLocalizations l10n)` that wraps `BriefPdfGenerator().generate(...).save()`. Call sites use this.

Files expected in this commit:

* `lib/services/brief/brief_pdf_generator.dart` (new)
* `lib/services/brief/brief_pdf_theme.dart` (new)

Run `git status` and verify only those paths are staged. Commit: `feat(brief): add BriefPdfGenerator that walks markdown into pw widgets`.

### Step 3. Replace `window.print` with cross-platform PDF action

Delete `lib/web/brief_print_web.dart` and `lib/web/brief_print.dart`. They are no longer used.

Edit `lib/views/brief_screen.dart`:

* Remove the conditional import for the old print stubs.
* Replace the `printBrief()` call with a new `_exportPdf()` method that:
  1. Calls `buildBriefPdf(program, exercise, audience, l10n)` to produce the PDF bytes.
  2. Calls `Printing.layoutPdf(onLayout: (_) async => pdfBytes)` to open the platform print preview. On web this opens the browser's print dialog (now with a real PDF, not a viewport screenshot). On mobile this opens the print sheet. On desktop this opens the print preview window.
* The slim app bar's print `IconButton` becomes always visible (remove the `if (kIsWeb)` guard). Its `tooltip` switches from `briefPrint` to a new `briefExportPdf` ARB key (see Step 4).
* When `_exportPdf` is in flight, the button shows a small `CircularProgressIndicator` instead of `Icons.print` to indicate the PDF is being built. Use a local `bool _exportingPdf` flag and `setState` around the call.
* Error handling: wrap the generation in a try/catch. On error, surface a `SnackBar` with the localized `briefExportPdfError` message and the error message in the body.

Files expected in this commit:

* `lib/web/brief_print_web.dart` (deleted)
* `lib/web/brief_print.dart` (deleted)
* `lib/views/brief_screen.dart`
* `lib/l10n/app_en.arb` (new keys)
* `lib/l10n/app_nb.arb` (new keys)
* `lib/l10n/app_localizations.dart` (regenerated)
* `lib/l10n/app_localizations_en.dart` (regenerated)
* `lib/l10n/app_localizations_nb.dart` (regenerated)

New ARB keys (English / Norwegian):

* `briefExportPdf` → "Export PDF" / "Eksporter PDF" — tooltip on the action button.
* `briefExportPdfError` → "Could not export PDF: {error}" / "Kunne ikke eksportere PDF: {error}" — snackbar body on failure.

The existing `briefPrint` key can stay in the ARB files for backward compatibility but is no longer used; remove it if no other call sites reference it.

Run `git status` and verify all expected paths are staged. Commit: `feat(brief): replace web-only window.print with cross-platform PDF action`.

### Step 4. Update DESIGN-004 and ADR-0023

Edit `docs/design/brief-template.md`:

* In "Implementation notes", replace **Stage 5 — Print stylesheet** with a new **Stage 5 — PDF export** entry that describes the cross-platform path. Reference the `printing` and `pdf` packages, the `BriefPdfGenerator` pipeline, and the always-visible action in the slim app bar.
* In "Non-goals", remove the "No native PDF export in v1" bullet. It is no longer a non-goal.
* In "Deferred decisions", remove "Native PDF export" from the list (now shipped).

Edit `docs/adrs/0023-brief-theme-tokens.md`:

* Add a new entry to the **## Revisions** block at the bottom dated today: "Stage 5 of DESIGN-004 pivoted from browser print stylesheet to cross-platform PDF generation. The `BriefTheme` token-set is mirrored by a print-only `BriefPdfTheme` in `lib/services/brief/brief_pdf_theme.dart`. The two are deliberately separate value-classes because paper has no dark mode and uses point-sized typography rather than logical-pixel."

Files expected in this commit:

* `docs/design/brief-template.md`
* `docs/adrs/0023-brief-theme-tokens.md`

Run `git status` and verify only those paths are staged. Commit: `docs(brief): pivot DESIGN-004 stage 5 from print CSS to PDF generation`.

### Step 5. Tests

Add `test/services/brief/brief_pdf_generator_test.dart`. The tests assert that the generator returns a non-empty `pw.Document` and that the document's metadata reflects the program/exercise inputs.

Cases:

* `generates a non-empty pw.Document from a fixture program`. Pumps a small fixture through `BriefPdfGenerator().generate(...)`, calls `.save()`, asserts the resulting `Uint8List` has length > 1000 bytes (a smoke threshold). PDFs always have a header of at least a few hundred bytes; under 1000 indicates the document body is empty.
* `headings produce pw.Text nodes`. Walks the generator's intermediate AST (expose a `@visibleForTesting` accessor for the parsed tree) and asserts the headings list matches the markdown.
* `inline code is rendered as a padded container`. Generates from a fixture containing `` `32V 0580414E 6552008N` `` and asserts the resulting pw widget tree contains a `pw.Container` with a non-null decoration around the inline code.
* `<mark> and <curr-mark> tags are stripped`. Generates from a fixture markdown containing `<mark>foo</mark>` and asserts the resulting widget tree has plain "foo" text without the marker syntax.
* `audience filter applies in PDF`. Generate twice with `participant` and `director` audience for the same program. Assert the director PDF has more pages or a larger byte length than the participant PDF (the director audience adds notes and PII).

Files expected in this commit:

* `test/services/brief/brief_pdf_generator_test.dart` (new)

Run `git status` and verify only this path is staged. Commit: `test(brief): cover BriefPdfGenerator for headings, lists and code spans`.

## Verification

1. `flutter analyze` is clean.
2. `flutter test` produces no new failures. `test/widget_test.dart` remains broken (default counter template). Do not try to fix it.
3. `make build` completes cleanly. Re-run `git status` afterwards — any newly-dirty regenerated file means an earlier commit was incomplete; fix the history with `git rebase -i` before declaring the work done.
4. **Clean tree gate.** `git status` prints `nothing to commit, working tree clean`. `git ls-files --others --exclude-standard` prints nothing.
5. **Diff sanity.** Run `git log --stat origin/main..HEAD` and walk every changed path.
6. Manual QA matrix:
   * **Web.** Open a brief, hit the PDF action. The print preview shows the rendered brief as multi-page PDF with proper page breaks, not a viewport screenshot. Confirm headings, paragraphs, bullet lists, inline code chips, blockquotes and tables all render. Confirm `<mark>` highlights are absent (search-only).
   * **iOS / macOS / Android.** Same brief, same action. The platform print/share sheet opens with the PDF preview. Save-to-Files / save-to-disk produces a working PDF.
   * **Print pagination.** Generate a brief with at least three exercises. Confirm the PDF paginates without cutting a heading across two pages. The MultiPage layout should handle this automatically; flag if it doesn't.
   * **Audience filter.** Generate participant, instructor, and director PDFs from the same program. Confirm content visibility matches DESIGN-004's audience matrix (no actor PII in participant, etc.).
   * **Empty brief.** Generate a PDF for an exercise with no stations. The PDF should produce a single header page, not error.

## Out of scope

* Custom page numbering / chapter cross-references in the PDF.
* Re-styling on-screen brief during PDF generation (no flash of PDF-theme on screen).
* PDF form fields, signatures, or annotations.
* Server-side PDF generation. v1 is always client-side.
* Removing `markdown_widget` from the on-screen path. The on-screen renderer stays as-is; the PDF generator is a parallel path.

## Deliverables

A series of five Conventional Commits as outlined above, all on the same working branch, with a clean tree at the end. The final commit body should include:

* A one-line summary of the user-visible change (PDF export works on every platform).
* The manual QA matrix filled out.
* A `## Follow-ups` section, even if empty.

ADR-0023 is the authoritative spec for the visual language of the on-screen brief. DESIGN-004 is the authoritative spec for the brief feature and now its PDF export pipeline. If you find yourself contradicting either, stop and ask. Do not write a new ADR.
