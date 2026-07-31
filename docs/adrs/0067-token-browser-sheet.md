---
status: accepted
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
  tokens…" — that opens the existing picker primitive with a search field, scope
  filter chips, scope sections, and a row per token carrying name, description
  and live resolved value.
* **Option C — Replace the caret menu with the sheet.** `/` opens the sheet
  directly.
* **Option D — Widen the caret menu and add a second line per row.** No sheet;
  the overlay grows to fit a description.
* **Option E — A hover/long-press detail popover on a caret-menu row.** The list
  stays as it is; detail appears on demand next to it.

## Decision outcome

Chosen option: **Option B**, and built.

It held together in one respect worth recording: the two open questions the proposal
flagged both answered themselves once the shape was pinned to the picker primitive.
There was no new layout to design, because `showRingdrillPicker` already had one; and
the descriptions, which were the reason to hesitate, turned out to be the only part
that was genuinely new work.

The shape, drawn in
[`docs/design/mockups/token-browser-sheet.html`](../design/mockups/token-browser-sheet.html):

* **Entry point.** The caret menu gains a persistent last entry, "Browse all
  tokens…", shown whatever the filter matches — including when it matches nothing,
  where it replaces "no matches" with something the author can actually do. The
  section editor's overflow menu (`⋮`) gets the same action, so the sheet is
  reachable without typing a trigger character at all.
* **Surface.** Not a new one. The browser is one call to
  `showRingdrillPicker<TokenBrowserEntry>` (ADR-0049), which already is the
  app's "pick one from a list" primitive: a bottom sheet on compact, a dialog on
  medium/expanded, a title row, a search field past a threshold, section headers
  computed over the *filtered* list, `footerActions`, and pop-with-the-chosen-item.
  Adding a third bespoke layout for a task the app already has one shape for is
  exactly what ADR-0049 was written to stop.

  On medium/expanded the dialog is laid out master/detail — scopes in the master
  pane, rows in the detail — which is ADR-0030's wide-screen idiom rather than a
  new one. The plan tab, the station list and the roleplay list already read that
  way on a wide window, so the browser reads as part of the app instead of as a
  dialog that happens to be wide, and the scope the author is in stays visible
  while she reads a row.
* **Content.** Sections by scope, in cascade order (plan → exercise → station →
  roleplay), then variables, then the station's own locations and persons —
  `sectionLabel` only asks that the list is ordered by group, which it is.
  A scope with nothing in context is its own entry variant that renders as a
  muted note with no `onTap`, so it is shown, saying why, without teaching the
  primitive about disabled rows.
* **Row.** Three lines, in the order the author asks: label first with the token
  beside it as a code chip, then the value it resolves to *right now* in this
  field's scope, then the description. `itemBuilder` belongs to the call site, so
  a three-line row needs no change to the primitive. The value gets a wrapping
  block rather than a trailing slot, which is what removes the failure mode.
  The row starts on the section header's left edge, with no leading icon: the
  scope is already in the header and in the token's own prefix, so an icon would
  only push every line 30px in and take that width off the long values.

  An ellipsised token carries a `Tooltip` with the full string. Truncation is
  from the right, and the right is exactly where a chained token differs from its
  neighbours — `{{station.person.anne.loc.position}}` and
  `{{station.person.anne.loc.name}}` are the same row until the tail. Hover on
  desktop, long-press on touch, which `Tooltip` does on its own; the row's tap is
  insertion and its long-press is otherwise unused.
* **Example values.** A facet with nothing to resolve gets an example instead of
  an empty box, in a dashed block marked as one. Three cases need it: aggregated
  facets built at render time (`exercise.roundTable` is a whole GFM table, not a
  value the editor holds), derived facets whose inputs are missing
  (`exercise.endTime` with no start time), and facets that are simply empty. The
  question the row answers is "what shape of thing does this produce", and an
  empty box answers nothing. Examples live beside the descriptions in
  `PlanFieldTokens`; the structural ones need no translation.
* **Search.** The primitive's own field, with `searchText` joining name, label
  and description and `searchThreshold: 0` since the list is always long.
  Filtering keeps the section headers, so the result still says which scope a hit
  belongs to — the thing the caret menu's flat list cannot say.
* **Filters.** Text search narrows by *what it is called*; the filters narrow by
  *what kind of token it is* — Plan, Exercise, Station, Script, Variable,
  Location, Person. Same labels as the section headers, all singular: a filter
  names a category, it does not count one. Three are count nouns the app already
  has (`l.plan(1)`, `l.exercise(1)`, `l.station(1)`); the roleplay one is
  `l.scriptSegment` — the plan tab's own segment name, "Script" / "Spill" —
  rather than `l.roleplay(1)`, which reads "Roleplay" / "Markør" and names the
  role roster inside that segment rather than the layer. Only "Variable" has no
  singular string yet.

  **The scope inventory decides which filters exist.** They are
  `PlanFieldScope`'s cascade for this field (`withAncestors`) plus the registries
  the field actually has — variables always, the station's locations and persons
  when it owns any — in the same order as the sections. A plan-scope field gets
  three; a roleplay-scope field gets eight. The driver that says the browser must
  read one inventory rather than a hand-kept list applies to the filter as much
  as to the content: a new scope should produce a new filter without anyone
  remembering to add one. A scope that exists but has nothing in context stays,
  dimmed and still selectable — picking it shows exactly the one row explaining
  why it does not apply here.

  **One filter, two presentations.** On compact it is a wrapping chip row under
  the search field. Label only, no count: the count is not what an author chooses
  on, and it costs width in the one direction that is short. The row wraps rather
  than scrolling sideways — eight categories take two lines on a phone and all of
  them are visible, where a sideways row would hide the last few behind the edge
  without saying they exist. On medium/expanded the same inventory is the
  master rail described above. Filters with no matches are dimmed rather than
  removed in both, so nothing jumps while typing. One `filters` parameter, two
  layouts, no per-call-site choice — the rule `showRingdrillPicker` already
  applies to its own surface.

  Chips on compact, not a segmented button. The app has already run that
  experiment:
  `StaffRoleFilter` was a `SegmentedButton` until four Norwegian role names made
  every segment as wide as "Øvelsesleder", overflowed a phone, and clipped the
  leading "Ø" when shrunk to fit — its doc comment is the record of why it is a
  `ToggleButtons` now. Here it is worse: up to eight categories, and the set
  varies with what the field has in context. A segmented button does not wrap
  either; it clips. It is also *view selection* in this app (the plan tab's
  segments, the coordinator's three views), not list filtering, and reusing it
  here would blur that.

  This is the one thing the primitive does not already do, and it cannot live in
  `itemBuilder` — chips there would scroll away with the list. It belongs in
  `showRingdrillPicker`'s header beside the search field, as an optional
  `filters` parameter taking a label and a predicate per entry, rendered as chips
  on compact and as the rail on medium/expanded. A picker that passes none looks
  exactly as it does today, and the cast picker gets a place to put
  "all / assigned only" when it wants one.
* **Reaching the ⋮.** One thing the proposal did not think through: the section
  editor's ⋮ sits *above* the field in the tree, and the browse action belongs to
  the field, which holds the controller, the caret and the trigger. An
  `InheritedWidget` only reaches downwards. So the field registers its action on
  focus and the chrome reads the registration — the same shape `MainScreen` already
  uses to let the drawer trigger the visible tab's refresh indicator. Following
  *focus* rather than mounting is the part that matters: a section form has several
  token-aware fields alive at once, and "insert a token here" needs a "here".
* **Insertion.** Tapping a row inserts the literal token at the caret and closes
  the sheet, reusing the caret menu's existing `_select` path so there is one
  implementation of "what text does this entry produce".
* **Descriptions.** New, and the only genuinely new content. They belong next to
  the labels in `PlanFieldTokens`, keyed by facet name, so the existing
  bidirectional assert extends to them: a facet with no description fails the
  same way a facet with no label now does.

Option A shipped first as the stopgap — the freeze had to stop that day — and the
value cap it added stays, because the caret menu still has rows to keep intact. It
was never the resolution: it protects the layout by truncating the value harder,
which is the opposite of what the author reading that row needs.

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
  facets, each needing a line that says something the label does not, and they are
  now written. Half-written descriptions would have been worse than none, so
  `_labelled` asserts them complete the way it asserts the labels: a facet added to
  `PlanFieldNames` without a description fails loudly rather than reaching the
  browser as a row that explains nothing. The location and person facet paths share
  one description per kind rather than one each, since what varies between them is
  the slug, not the meaning. Example values added to the same pile, though a
  smaller one — only the facets that can come back empty have one.
* Bad: the `filters` parameter is a change to a primitive four other call sites
  already depend on. Optional and additive, but a shared widget nonetheless, so
  its tests grow with it.
* Good: it is not a new surface. Building on `showRingdrillPicker` means the
  sheet-on-compact / dialog-on-wide rule, the search field, the section headers
  and the keyboard-in-sheet handling are already built and already tested, and
  the browser is recognisable as the picker the author has met when choosing a
  station or a person.
* Bad: a second *way in* for the same job. Two ways to insert a token means two
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

* Related ADRs: [ADR-0049](./0049-adaptive-selector-surface.md) (the picker
  primitive the browser is a call to),
  [ADR-0027](./0027-unified-bottom-sheet-chrome.md),
  [ADR-0030](./0030-wide-screen-master-detail-layout.md) (the master/detail
  layout the wide path uses),
  [ADR-0046](./0046-plan-variables.md),
  [ADR-0047](./0047-scenario-locations-and-persons.md),
  [ADR-0048](./0048-flutter-free-field-resolver.md),
  [ADR-0065](./0065-authoring-guidance-over-mcp.md),
  [ADR-0066](./0066-team-scope-for-cross-reference-tokens.md)
* Mockup: [`docs/design/mockups/token-browser-sheet.html`](../design/mockups/token-browser-sheet.html)
* Related code: `lib/views/widgets/ringdrill_picker.dart`,
  `lib/views/widgets/token_insertion_menu.dart`,
  `lib/views/widgets/staff_role_filter.dart` (why the filter is chips, not a
  segmented button),
  `lib/views/widgets/plan_field_tokens.dart`,
  `lib/utils/plan_field_names.dart`,
  `lib/views/widgets/resolve_scoped_field.dart`
* Origin: a `ListTile` layout assertion — "Trailing widget consumes the entire
  tile width" — thrown by a real talegruppe value from the 2026 LSOR plan, which
  in a release build left the app unresponsive with the menu invisible.
