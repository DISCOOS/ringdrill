---
status: accepted
date: 2026-08-03
deciders: ["Kenneth Gulbrandsøy"]
consulted: []
informed: []
---

# ADR-0069: Render the brief through a lazy viewport, and navigate it without relying on mounted headings

## Context and problem statement

Until now every brief the app had to open was small. The onboarding examples run
to a few kilobytes, and `brief_screen_test.dart`'s fixture is a single exercise
with one station. The first real plan — the 2026 LSOR øvelseshefte, 7 exercises
and 25 stations — renders a director brief of ~69 KB of markdown: 1,939 lines,
737 top-level blocks, some 72,000 px tall. Opening it visibly stalled, and
because the brief opens as a modal sheet the stall landed on top of the sheet's
slide-in animation, so it read as jank rather than as a slow load.

Measurement located the cost squarely in the widget layer, not the renderer:

| Stage | Cost |
| --- | --- |
| `BriefRenderer().render()` — producing the markdown | 3.5 ms |
| `MarkdownGenerator.buildWidgets` — parse and construct blocks | 50 ms |
| First pump of `BriefMarkdown` — layout and paint | ~590 ms |
| Full `BriefScreen` open, wide viewport | ~1,650 ms |

(`flutter test`, JIT, so absolute numbers are pessimistic; the proportions are
the point.) Three separate causes:

1. `BriefMarkdown` put all 737 blocks in a `Column` inside a
   `SingleChildScrollView`. There is no lazy viewport in that shape, so the
   whole 72,000 px document — 20,862 elements — was built, laid out and painted
   before the first frame. That eager `Column` was deliberate: it existed so a
   `SelectionArea` could sit *inside* the scrollable, working around the
   framework's `!_selectionStartsInScrollable` assertion on long-press scroll
   ([flutter#115787](https://github.com/flutter/flutter/issues/115787)).
2. `buildWidgets` ran inside `build()` with no memoisation, so every `setState`
   re-parsed and re-laid out the entire document. A frame-by-frame trace of one
   open showed the document built **twice** with byte-identical data, because
   `_onRenderCompleted` called `setState` purely to cache the markdown string
   for the search bar and the copy button.
3. On wide viewports the render future was created in `didChangeDependencies`
   for the narrow layout, then discarded and recreated when the `LayoutBuilder`
   post-frame callback discovered the pane was wide — a whole render thrown
   away plus a spinner flash.

## Decision drivers

* The brief is the app's primary read surface for the exact plans it is meant to
  handle. A real plan must open without a visible stall.
* Whatever replaces the eager `Column` must not silently break the brief's
  navigation. The outline (TOC sidebar and sheet), in-document anchor links and
  search-match cycling all currently work by holding a `GlobalKey` per heading
  and calling `Scrollable.ensureVisible` — which requires the target to be
  mounted, and in a lazy viewport it usually is not.
* No new dependency for scroll-to-index if the problem can be solved with
  framework primitives.
* Text selection must keep working, including long-press-then-drag on touch.

## Considered options

* **A — Keep the eager `Column`, reduce per-block cost.** There is nothing to
  reduce: the cost is `RichText` layout of ~700 paragraphs, and the framework
  offers no way to defer layout for off-screen boxes inside a `Column`.
* **B — Lazy `SliverList` over the 737 individual blocks.** Maximum laziness,
  but 737 potential scroll targets to estimate offsets for, and the block
  granularity does not line up with anything the reader navigates to.
* **C — Lazy `SliverList` over *sections*, split at each H2/H3 heading.** ~33
  items for the LSOR brief, and each section boundary is exactly a navigation
  target the outline already offers.
* **D — Add `scrollable_positioned_list` (or similar) for scroll-to-index.**
  Solves navigation directly, at the cost of a dependency on a package that
  reimplements the sliver protocol.

## Decision outcome

Chosen option: **C**, because the section boundaries the reader already
navigates by are also the right granularity to build and discard, which makes
laziness and navigation the same problem rather than two competing ones.

`BriefMarkdown` becomes a `StatefulWidget` that parses its markdown once into a
flat block list plus a section grouping, caches that, and rebuilds it only when
an input the parse actually consumes changes. It renders
`SelectionArea` → `Scrollbar` → `CustomScrollView` → `SliverList.builder`, one
item per section, with the reading-column cap and gutter moved onto a
`SliverPadding` so the scrollbar stays at the pane's right edge as before.

`SelectionArea` moving *outside* the scrollable is what makes any of this
possible, and it is only available because `!_selectionStartsInScrollable` no
longer fires on the Flutter version this app pins (3.44) for either touch or
mouse drag. That is not a fact to take on trust across upgrades, so
`test/views/widgets/brief_markdown_selection_test.dart` drives the exact gesture
and fails with the reason if a future Flutter brings the assertion back.

Navigation no longer assumes the target is mounted.
`BriefMarkdownController.jumpToWidgetIndex` first maps the heading to its owning
section and, if that section is outside the built window, jumps to an estimated
offset built from the extents of sections that *have* been laid out, letting one
frame build before re-estimating. Each attempt measures more sections, so it
converges rather than guessing once; an already-built target skips the loop
entirely and animates exactly as before. `ensureKeyVisible` does the same for the
active search match, driven by where the match sits in the markdown source as a
fraction of its length — with the extra wrinkle that a lazy viewport's own
`maxScrollExtent` is an estimate until every section has been measured, so the
fraction is a moving target and the iteration matters more.

Active-heading tracking changes shape too: sections above the built window have
no render object to measure, so the controller infers that the last section
before the built window has been passed, instead of reporting the first
*visible* heading (which is what a naive loop over mounted headings does).

`BriefScreen` stops discarding renders: the future is created inside the
`LayoutBuilder`, memoised on `(audience, isWide)`, so the wide layout renders
once for the layout it is actually in. And `_onRenderCompleted` no longer calls
`setState` unconditionally — only when the search bar is showing a match count
that actually changed.

### Consequences

* Good: opening the LSOR plan brief goes from 20,862 elements to 1,216, from two
  document builds to one, and from a ~590 ms first layout to ~50 ms. No spinner
  flash on wide viewports.
* Good: search stops re-laying out the whole document per keystroke. The parse
  still re-runs (the markdown genuinely changes when `<mark>` tags are added),
  but only the built sections are laid out.
* Good: the sections a lazy viewport builds are the same units the outline
  navigates by, so there is one concept to reason about rather than two.
* Bad: selection reach is now bounded. Text scrolled out of the built window
  leaves the selection tree, so a drag cannot select much more than a screenful
  either side. Copying the whole document is the copy-markdown button's job, and
  always was; dragging across 80 screens was never a real workflow.
* Bad: jumping to a section that has never been on screen is an estimate that
  converges over a few frames rather than one exact scroll. It lands correctly,
  but a long jump can show a brief settle instead of a single smooth glide.
* Bad: the controller now carries state that only makes sense for a lazy
  viewport (measured section extents), and `_handleScroll` infers rather than
  measures the active heading above the built window. Both are covered by
  `test/views/widgets/brief_markdown_performance_test.dart`.
* Bad: a document with no H2/H3 heading is a single section, i.e. eager. That is
  correct for the short previews `BriefMarkdownBlock` serves, but it means the
  laziness is a property of brief-shaped content rather than a guarantee.

## Pros and cons of the options

### A — Keep the eager `Column`, reduce per-block cost

* Good: no change to navigation, selection or the controller's contract.
* Bad: does not work. The cost is text layout of every block, and nothing about
  a `Column` lets that be deferred.

### B — Lazy `SliverList` over individual blocks

* Good: the finest possible laziness; only the blocks on screen are laid out.
* Bad: 737 items whose extents must be estimated for navigation, versus ~33.
* Bad: block indices are not navigation targets, so the mapping from "the
  heading the reader tapped" to "the item to scroll to" is an extra layer with
  nothing to anchor it.

### C — Lazy `SliverList` over H2/H3 sections

* Good: ~16× less layout on open for a real brief, which is ample; the remaining
  cost is the parse.
* Good: section starts *are* the outline's targets, so offset estimation and
  heading navigation share one index space.
* Good: no new dependency.
* Bad: coarser than per-block, so a single very long section is laid out whole.
  In practice a station's section is a few hundred pixels.

### D — Add a scroll-to-index package

* Good: exact scrolling to an unbuilt index, no estimation loop.
* Bad: a dependency that reimplements the sliver protocol, for one screen.
* Bad: does not remove the need to decide the laziness granularity; it only
  changes how the jump is performed.
