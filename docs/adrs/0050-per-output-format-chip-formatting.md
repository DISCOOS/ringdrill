---
status: accepted
date: 2026-07-19
deciders: ["kengu"]
consulted: []
informed: []
---

# ADR-0050: Per-output-format chip formatting via a ChipFormatter strategy

## Context and problem statement

Copyable field values — positions, addresses, phone numbers — resolve to
inline-code **copy chips** (`briefCopyChip` → `` `value` `` → the pill in
`brief_markdown.dart`, tap = copy). They are inert beyond copying: in the app a
leader cannot tap a coordinate to open a map or a phone number to call. The
same resolver ([ADR-0048](./0048-flutter-free-field-resolver.md)) feeds both the
brief and the app, so any change must not regress the brief.

Two further pressures point the same way. The brief will grow additional output
formats (HTML, PDF, DOCX): interactivity makes sense for the app preview and
HTML, but PDF and DOCX have none and want a plain code chip — so chip rendering
must be chosen **per output format**, not globally. And the coordinate is
represented twice and named narrowly: the resolve scopes carry a pre-formatted
`positionUtm` **string** while an action chip needs the raw `LatLng`, and the
facets are `utm` / `latlng` rather than a format-agnostic `position`.

## Decision drivers

* One resolver, one behaviour (ADR-0048) — the app preview must keep matching
  the brief; no second, drifting chip implementation.
* The brief (and PDF/DOCX) output must stay byte-identical by default.
* The resolver stays free of `package:flutter/*` (ADR-0005), so the encoding is
  pure string/`LatLng` logic and the widget layer does the launching.
* Extensible: multiple output formats, multiple chip actions (a future
  context menu), and multiple coordinate formats without reworking the seam.
* App-only now; full app/brief parity (HTML action chips) later.

## Considered options

* **A: A `ChipFormatter` strategy selected per output format.** The resolver
  takes a formatter; `CopyChipFormatter` (default) emits today's code chip,
  `ActionChipFormatter` emits an interactive chip encoded as a markdown link
  with a `ringdrill://chip?action=...` URI the app renderer wires to a tap
  action.
* **B: A boolean `actionableChips` flag on the resolver.** App passes true.
* **C: Detect chip type in the render layer by content heuristics** and convert
  UTM→LatLng there to build the map link.

## Decision outcome

Chosen option: **A**, because a strategy object carries the per-format decision
cleanly (copy for brief/PDF/DOCX, action for app/HTML), defaults to the copy
chip so the brief is byte-identical, stays Flutter-free, and generalizes to
more formats and actions where a boolean (B) would not; heuristic detection (C)
cannot recover the exact coordinate for a map link and re-derives type
fragilely.

### The strategy

```dart
abstract class ChipFormatter {
  const ChipFormatter();
  String position(String display, LatLng? latLng);
  String phone(String display, String number);
  String address(String value);
}
```

`CopyChipFormatter` (the default) returns `briefCopyChip(...)` for all three —
today's output. `ActionChipFormatter` encodes a launch target as a markdown
link with a structured `ringdrill://chip` URI, built with `Uri(...)` so
values are properly encoded —
`[display](ringdrill://chip?action=map&lat=<lat>&lng=<lng>)`,
`[display](ringdrill://chip?action=call&tel=<number>)` — degrading to a copy
chip when the coordinate/number is absent; an address stays a copy chip. The
query form replaced an earlier terse `rdchip:` sentinel scheme (same
decision, refined encoding — see "Refinements" below): it is legible and
leaves room for a future `label` parameter and further actions. `resolveField`
gains `ChipFormatter chips = const CopyChipFormatter()`, threaded through the
scenario facet resolvers. `BriefRenderer` passes nothing (keeps the default),
so the brief is unchanged. The app resolvers (`resolveScopedField`,
`resolveModelField`) pass `ActionChipFormatter`. The app markdown renderer
recognizes `ringdrill://chip` links (scheme `ringdrill`, host `chip`) and
renders a pill whose body (everything except the copy icon) runs the chip's
action and whose copy icon copies. The actions are a list, and the tap
follows the count: a single action (today's case) runs directly on tap, and a
chip with more than one action opens a context menu — so no menu exists
today. The `ringdrill://chip` URI is internal and never reaches a copied
value or a non-app surface.

### The coordinate facet model

The resolve scopes carry the **coordinate** (`LatLng? position`), replacing the
pre-formatted `positionUtm` string — one representation, and the raw value the
map link needs. The coordinate facet is unified as `place` (the string address
text, kept) plus `position` (the `LatLng`, formatted to a string at resolve
time through a new Flutter-free `CoordinateFormat`, default **UTM**), replacing
the flat `utm` / `latlng` facets across station/roleplay cross-references,
station locations, `location`-typed variables (ADR-0046) and a person's `.loc`
(ADR-0047). `CoordinateFormat` ships **UTM only**; the format parameter is the
seam for MGRS / DD / DM / DMS / raw LatLng later, à la
[ADR-0034](./0034-configurable-numbering-formats.md)'s configurable numbering.

### Consequences

* Good: one resolver and one chip behaviour per format; the app preview stays
  the brief; the brief and PDF/DOCX stay plain by default.
* Good: byte-identical brief for non-position content; Flutter-free encoding.
* Good: a single coordinate representation and a format-agnostic `position`
  facet, with a ready seam for more coordinate formats and chip actions.
* Bad: renaming the flat `utm`/`latlng` facets to `position` is a deliberate
  token migration (example content and tests updated; acceptable — the app is
  unpublished, no archive migration needed).
* Bad: a new internal encoding (`ringdrill://chip`) and a new render path to
  maintain.
* Bad: app/brief parity is deferred — the HTML brief will select the action
  formatter later; until then only the app is interactive.

### Refinements

* **The chip encoding.** Shipped initially as a terse `rdchip:<action>`
  sentinel scheme; refined to the structured `ringdrill://chip?action=...`
  URI above (same decision — a same-format, per-format `ChipFormatter`
  strategy — with a more legible, extensible encoding). See
  [DESIGN-013](../design/013-actionable-field-chips.md#implementation-status)
  for the follow-up detail.

## Pros and cons of the options

### Option A — ChipFormatter strategy (chosen)
* Good: per-format decision, byte-identical default, Flutter-free, extensible to
  formats and actions.
* Bad: a new abstraction and encoding to maintain.

### Option B — boolean flag
* Good: smallest change.
* Bad: a boolean cannot express three-plus output formats or carry
  format/action variation; it would grow into a strategy anyway.

### Option C — render-layer heuristic detection
* Good: no resolver change.
* Bad: cannot recover the exact `LatLng` for a map link from a UTM string
  without a fragile inverse projection; re-derives chip type by regex; drifts
  from the brief.

## Links

* Related design: [DESIGN-013](../design/013-actionable-field-chips.md)
* Related ADRs: [ADR-0048](./0048-flutter-free-field-resolver.md) (the shared
  resolver), [ADR-0046](./0046-plan-variables.md) (typed variables incl.
  `location`), [ADR-0047](./0047-scenario-locations-and-persons.md) (station
  locations/persons facets), [ADR-0034](./0034-configurable-numbering-formats.md)
  (configurable-format precedent), [ADR-0005](./0005-cli-must-remain-flutter-free.md)
  (Flutter-free), [ADR-0023](./0023-brief-theme-tokens.md) (chip/pill styling)
* Related code: `lib/services/brief/field_resolver.dart`,
  `lib/services/brief/brief_renderer.dart`,
  `lib/views/widgets/brief_markdown.dart`,
  `lib/views/widgets/resolve_scoped_field.dart`,
  `lib/views/widgets/station_scope.dart`, `lib/views/widgets/roleplay_scope.dart`,
  `lib/views/widgets/plan_field_tokens.dart`,
  `assets/templates/ringdrill-standard-v1.{nb,en}.md.mustache`
* Reference docs: [`docs/variables.md`](../variables.md),
  [`docs/template.md`](../template.md)
