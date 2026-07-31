---
status: proposed
date: 2026-07-31
deciders: ["kengu"]
consulted: []
informed: []
---

# ADR-0067: Give tokens a searchable browser sheet, and leave the caret menu as the fast path

## Context and problem statement

The `/` and `{{` insertion menu (DESIGN-008) is a caret-anchored overlay card:
280 logical pixels wide, 240 tall, one dense `ListTile` per entry. Each row has
three slots — a leading icon, a name, and one trailing string — and that is the
entire budget for describing a token.

It has run out of room, in four separate ways.

**The row cannot hold a value and a name at the same time.** `ListTile` lays its
trailing out at whatever width the text wants and gives the title the remainder,
so a real value from the first converted plan — the talegruppe
`RK-VFOLD-ØV4 / DMO-ANDRE-1`, or a location preview
`LSOR kurslokale, 32V 0580465E 6551894N` — takes the whole tile. `ListTile` then
asserts *"Trailing widget consumes the entire tile width"* and the tile is left
with no size at all. In a release build there is no assert to catch it: the tile
needs layout every frame, its name paints as nothing, and the menu's full-screen
tap barrier keeps swallowing input. That is not a cosmetic bug — it is how the
picker froze a whole app. Capping the value's width fixes the freeze and is the
right immediate answer, but it fixes it by *truncating the value harder*, which
is the opposite of what an author looking at that row needs.

**There is no room for a description.** A token's meaning is currently carried
entirely by its label. "Rundetabell" and "Faseinndeling" are honest labels and
still do not tell an author that the first is a multi-row GFM table and the second
is `15 | 10 | 5`. The one place that explains this is the authoring skill, which
an app user does not have. The picker is where the decision is made, and it says
the least.

**The trailing slot is overloaded.** It holds a variable's effective value, a
location's or person's preview, and — for a plan field — a scope hint. Three
different kinds of information in one slot, distinguishable only by style. Until
this change every plan field showed the same hint whatever scope it read from, so
an `{{exercise.*}}` token claimed to be a plan field, and nobody noticed for as
long as the slot has existed.

**Discovery is filter-first.** Typing narrows the list, which is excellent when
the author knows roughly what they want and useless when they do not. The
inventory is now 26 facets at roleplay scope, plus every declared variable, plus
every station location and person with their own facet paths. There is no way to
*look* at that, only to guess at it.

Meanwhile the same information is already published elsewhere and is richer
there: `schema` emits `x-ringdrill-tokens.resolvableAt` per scope (ADR-0064,
ADR-0065), and the resolver can produce a live value for any facet in scope.
The app is the one surface that cannot show either.

## Decision drivers

* Keep the fast path fast. An author who knows the token types `/` plus three
  letters and takes the first hit; that must not get slower or gain a step.
* A token should be explainable where it is chosen, not only in a skill file an
  app user has never seen.
* Show the real resolved value, not a truncated preview. "What will this actually
  print?" is the question authors ask, and the resolver can already answer it.
* One inventory. The browser must read `PlanFieldNames` and the ambient scopes,
  not a hand-kept list — the drift between the declaration and a second copy is
  exactly what let `{{exercise.roundTable}}` resolve in the brief and not in the
  editor.
* No new failure mode from long content. A sheet has room; that is the point.
* Nothing about the format, the archive or `contentHash` changes. This is a
  picker.

## Considered options

* **Option A — Keep the caret menu only, and keep tightening it.** Cap the value
  width, shorten labels, accept that a row cannot explain itself.
* **Option B — A searchable browser sheet, opened from the caret menu.** The
  caret menu keeps its filter-first behaviour and gains one entry — "Browse all
  tokens…" — that opens a modal sheet with a search field, scope sections, and a
  row per token carrying name, description and live resolved value.
* **Option C — Replace the caret menu with the sheet.** `/` opens the sheet
  directly.
* **Option D — Widen the caret menu and add a second line per row.** No sheet;
  the overlay grows to fit a description.
* **Option E — A hover/long-press detail popover on a caret-menu row.** The list
  stays as it is; detail appears on demand next to it.

## Decision outcome

**Recommended: Option B.** Not decided here — it is a new surface with its own
layout, empty states and localisation, and it should be designed with the section
editor's own navigation in view (`SectionNavigatedForm`, DESIGN-010) rather than
bolted onto the overlay.

The shape being proposed:

* **Entry point.** The caret menu gains a persistent last entry, "Browse all
  tokens…", shown whatever the filter matches — including when it matches nothing,
  where it replaces "no matches" with something the author can actually do. The
  section editor's overflow menu (`⋮`) gets the same action, so the sheet is
  reachable without typing a trigger character at all.
* **Content.** Sections by scope, in cascade order (plan → exercise → station →
  roleplay), then variables, then the station's own locations and persons. Each
  row: the token as it will be inserted (`{{exercise.roundTable}}`), a one-line
  description, and the value it resolves to *right now* in this field's scope.
  A scope with nothing in context is shown, disabled, saying why — "no station in
  this field's scope" is more useful than an absent section.
* **Search.** One field, matching against name, label and description. Filtering
  keeps the section headers, so the result still says which scope a hit belongs
  to — the thing the caret menu's flat list cannot say.
* **Insertion.** Tapping a row inserts the literal token at the caret and closes
  the sheet, reusing the caret menu's existing `_select` path so there is one
  implementation of "what text does this entry produce".
* **Descriptions.** New, and the only genuinely new content. They belong next to
  the labels in `PlanFieldTokens`, keyed by facet name, so the existing
  bidirectional assert extends to them: a facet with no description fails the
  same way a facet with no label now does.

Option A is what has just been done, and it is the right stopgap — the freeze had
to stop today. It is not a resolution, because it makes the value less readable to
protect the layout.

### Consequences

* Good: the freeze class disappears by construction. A sheet row has the width for
  a full value and can wrap; there is no fixed-width tile to consume.
* Good: a token can explain itself where it is chosen, so the authoring
  conventions stop being knowledge only skill users have.
* Good: the live resolved value answers "what will this print" before insertion
  rather than after.
* Good: the fast path is untouched. One extra row at the bottom of a list costs
  an author who already knows the token nothing.
* Good: the trailing slot in the caret menu can go back to one meaning, since the
  browser is where the other kinds belong.
* Bad: **descriptions for every facet are real writing, in two languages.** 26
  facets plus the location and person facet paths, each needing a line that says
  something the label does not. Half-written descriptions would be worse than
  none, so this is the bulk of the work and the reason the ADR is proposed rather
  than accepted.
* Bad: a second surface for the same job. Two ways to insert a token means two
  places a bug can live, and the mitigation — routing both through `_select` —
  only covers insertion, not presentation.
* Bad: resolving every token for the live-value column runs the resolver once per
  row on open. Cheap for tens of rows, and the resolver is already called per
  field on every preview toggle, but it is work the caret menu does not do.
* Bad: a modal sheet over a full-screen section editor stacks two modals on
  mobile. `showRingdrillPicker` (ADR-0049) already handles that stacking, so the
  precedent exists, but it is a place where mobile navigation gets fiddly.
* Bad: it does not help the CLI or MCP authors at all. They have `schema`, which
  is the right answer for them, and this is deliberately an app affordance.

## Pros and cons of the options

### Option A — Caret menu only
* Good: nothing new to build or localise; the freeze is already fixed.
* Bad: the value column stays truncated, and there is still nowhere for a
  description — so the picker keeps being the place that explains least.

### Option B — Browser sheet, opened from the caret menu
* Good: room for description and full value; discovery by browsing as well as by
  filtering; fast path preserved.
* Bad: a whole new surface, and descriptions for the entire inventory in both
  languages.

### Option C — Sheet replaces the caret menu
* Good: one surface, one implementation, no "which one am I in".
* Bad: turns a three-keystroke insertion into open-search-tap for every author who
  already knows the token. The caret menu's speed is its whole reason to exist.

### Option D — Wider caret menu, two-line rows
* Good: no new surface; descriptions appear where the author already is.
* Bad: an overlay anchored at the caret cannot grow much before it stops fitting
  beside the caret on a phone — and a taller row means fewer rows in 240px, so
  browsing gets worse while explaining gets better.
* Bad: it keeps the fixed-width tile that caused the freeze, just with a larger
  fixed width.

### Option E — Detail popover on a row
* Good: cheap; no layout change to the list.
* Bad: hover is not a thing on touch, and long-press competes with the list's own
  scrolling. Discovery still requires knowing to ask row by row.

## Links

* Related ADRs: [ADR-0049](./0049-adaptive-selector-surface.md),
  [ADR-0046](./0046-plan-variables.md),
  [ADR-0047](./0047-scenario-locations-and-persons.md),
  [ADR-0048](./0048-flutter-free-field-resolver.md),
  [ADR-0065](./0065-authoring-guidance-over-mcp.md),
  [ADR-0066](./0066-team-scope-for-cross-reference-tokens.md)
* Related code: `lib/views/widgets/token_insertion_menu.dart`,
  `lib/views/widgets/plan_field_tokens.dart`,
  `lib/utils/plan_field_names.dart`,
  `lib/views/widgets/resolve_scoped_field.dart`
* Origin: a `ListTile` layout assertion — "Trailing widget consumes the entire
  tile width" — thrown by a real talegruppe value from the 2026 LSOR plan, which
  in a release build left the app unresponsive with the menu invisible.
