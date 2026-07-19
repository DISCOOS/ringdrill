---
id: DESIGN-013
title: Actionable field chips (tap-to-call, open-in-maps), per output format
status: Accepted
started: 2026-07-19
accepted: 2026-07-19
owners: ["kengu"]
related_code:
  - lib/services/brief/field_resolver.dart
  - lib/services/brief/brief_renderer.dart
  - lib/views/widgets/brief_markdown.dart
  - lib/views/widgets/resolve_scoped_field.dart
  - lib/views/widgets/station_scope.dart
  - lib/views/widgets/roleplay_scope.dart
  - lib/views/shell/open_form_surface.dart
  - lib/views/roleplays_view.dart
  - lib/views/roleplay_screen.dart
  - lib/views/widgets/ringdrill_text.dart
  - lib/views/widgets/ringdrill_text_field.dart
  - assets/templates/ringdrill-standard-v1.nb.md.mustache
  - assets/templates/ringdrill-standard-v1.en.md.mustache
related_designs:
  - brief-template.md
  - 009-scenario-locations-and-persons.md
  - 010-inline-preview-and-resolve-scope.md
related_adrs:
  - 0048-flutter-free-field-resolver.md
  - 0023-brief-theme-tokens.md
  - 0022-markdown-content-as-files.md
---

# Actionable field chips (tap-to-call, open-in-maps), per output format

> This document is in English (AGENTS.md rule 12). Norwegian words appear only
> where they are UI labels quoted from the app. Status: **Accepted**
> (2026-07-19); recorded in [ADR-0050](../adrs/0050-per-output-format-chip-formatting.md).
> Reference docs for the token/chip machinery: [`variables.md`](../variables.md),
> [`template.md`](../template.md).

## Problem

Copyable field values — positions, addresses, phone numbers — render as
inline-code **copy chips** (`briefCopyChip` → `` `value` `` → the `_CodeChip`
pill in `brief_markdown.dart`, tap = copy). They are inert beyond copying. A
leader reading a station in the app cannot tap a coordinate to open a map, or a
phone number to call.

Phone is also handled inconsistently:

- `roleplays_view.dart` shows the cast actor's phone as **plain text** with an
  ad-hoc `launchUrl('tel:…')` tap (not a chip, no copy affordance).
- The roleplay (Spill) viewer does not show the phone at all.
- The brief's station chapter already renders the roleplays and, for the
  director audience, `**Markør:** {realName} {phone}` — but the phone is plain
  text, not a copy chip (`brief_renderer` builds a `briefCopyChip('($phone)')`
  value under the `phone` context key, yet the template consumes it with the
  escaped `{{phone}}`, which is not the chip path).

Separately, the brief will grow additional output formats (HTML, PDF, DOCX).
Interactivity (a tappable map/phone) makes sense for the app preview and HTML;
PDF and DOCX have no interactivity and want a plain code chip. So chip
rendering must become a choice made **per output format**, not a global.

## Decision

### 1. A `ChipFormatter` strategy, chosen per output format

Introduce a strategy in the flutter-free resolver
(`lib/services/brief/field_resolver.dart`):

```dart
abstract class ChipFormatter {
  const ChipFormatter();
  String position(String display, LatLng? latLng);
  String phone(String display, String number);
  String address(String value);
}
```

- `CopyChipFormatter` (the **default**) — every value is a plain backtick code
  chip, i.e. today's `briefCopyChip` output. Used by the brief and by the
  non-interactive exports (PDF, DOCX).
- `ActionChipFormatter` — the app preview and HTML. A position carries a map
  launch target and a phone a `tel:` target, encoded as a markdown link with a
  structured **`ringdrill://chip` URI**, built with `Uri(...)` so values are
  properly encoded —
  `[display](ringdrill://chip?action=map&lat=<lat>&lng=<lng>)`,
  `[display](ringdrill://chip?action=call&tel=<number>)`. A value with no
  coordinate/number degrades to a plain copy chip. An address stays a copy
  chip (no reliable action). This refines an earlier terse `rdchip:` sentinel
  scheme to a legible, extensible query form (see "Implementation status"
  below).

`resolveField` gains `ChipFormatter chips = const CopyChipFormatter()`,
threaded through the scenario facet resolvers (`_resolveLocationFacet`,
`_resolvePersonFacet`, `_locationDefault`, `substituteTypedVariables`'s
location-typed variable path). Because the default is the copy formatter and
`BriefRenderer` never passes another, **the brief output stays byte-identical**
and its existing tests are untouched.

### 2. Carry the coordinate, not a pre-formatted string

The `ActionChipFormatter` needs the raw `LatLng` for a position (for the map
link), not just the formatted UTM string. Today `StationScope` and
`RoleplayScope` carry a pre-formatted `positionUtm` **string**. Rather than add
a second field (the raw `LatLng`) beside it — two representations of the same
value — **replace `positionUtm` with a single `LatLng? position`** and format
it at resolve time.

So the scopes carry the coordinate; the facet builder both formats it for
display (default **UTM**) and hands the raw coordinate to `chips.position`.
The scope now carries the coordinate; §5 defines how it is formatted (the
`place`/`position` facet model and the `CoordinateFormat` seam, default UTM).

Concretely:

- `StationScope.position` / `RoleplayScope.position` become `LatLng?` (seeded
  by `forStation` / `forRoleplay`, copied by
  `openFormSurface._reprovideScopes`); `positionUtm` is removed.
- `resolveScopedField` (scope path) passes `const ActionChipFormatter()` and
  builds `station`/`roleplay` `position.utm` via
  `chips.position(formatUtm(coord), coord)`.
- `resolveModelField` (eager/model path) does the same from the model's own
  `.position`.
- Scenario location chips already carry `Location.position`, so they become
  actionable purely through the threaded formatter.
- `BriefRenderer` keeps `briefCopyChip` and its own UTM formatting (default
  formatter) — unchanged.

### 3. Phone is a first-class chip everywhere

Not plain tappable text — a full chip with the copy icon, like address and
position. It is produced by `ChipFormatter.phone(number, number)` and rendered
through the same markdown pill.

- **`roleplays_view.dart`** — render the cast actor's info **under the marker's
  full name** through `RingDrillText.rich` (fed the phone chip), replacing the
  ad-hoc plain-text `tel:` tap. This is a small UI restructure of the actor
  block.
- **Roleplay (Spill) viewer** (`roleplay_screen.dart`) — show the actor phone
  chip in the **expanded details hint field**; that is the only surface with
  room for it.
- **Brief templates** — the station chapter already renders the roleplays and
  the `**Markør:** {realName} {phone}` line (director only), so no new roleplay
  support is needed there. The change is to render the phone as a **copy chip**:
  consume the pre-built chip value with the unescaped `{{{phone}}}` (not
  `{{phone}}`), and confirm the realName/phone presentation reads well in the
  post chapter. Applies to both the `nb` and `en` templates.

### 4. Rendering the action chip

Add `_ActionChip` to `brief_markdown.dart` plus a link-tag
`SpanNodeGeneratorWithTag` that recognizes hrefs parsing as a
`ringdrill://chip` URI (`Uri.tryParse`, `scheme == 'ringdrill' && host ==
'chip'`); every other link keeps the existing `LinkConfig` behaviour.
`_ActionChip`
reuses the `_CodeChip` pill look. An `InkWell` over **everything except the
copy icon** runs the chip's action; the copy icon always copies the value,
exactly as the copy chip does today. The parens-adornment handling (`(pill)`
kept unbreakable, parens excluded from the copied value) carries over from
`_CodeChip`.

The actions are modelled as a **list**, and the tap follows the count: with a
**single** action (today's case — call, or open map) a tap runs it **directly**
— no menu; with **more than one** a tap opens a **context menu** to choose. So
there is no menu today (every actionable chip has exactly one action), and
adding a second action later (e.g. "Share location") turns the tap into a menu
without reworking the widget.

Only the app surfaces opt in — `RingDrillText.rich` (→ `BriefMarkdownBlock`)
and the in-editor preview (→ `BriefMarkdown` via `RingDrillTextArea`). The
brief reading surface (`BriefScreen`) keeps copy chips and never emits the
`ringdrill://chip` URI, so it is unaffected whether or not the generator is
registered in the shared config.

Map launch URL: a universal `https://www.google.com/maps/search/?api=1&query=<lat>,<lng>`
(opens the maps app on iOS/Android, a browser on web) built from the geo
coordinate; `tel:` via `url_launcher` (already a dependency;
`roleplays_view` already uses it).

### 5. Coordinate facets: `place` (string) and `position` (formatted)

Fold the coordinate representation into one facet model shared by every surface
that resolves a coordinate — the station/roleplay cross-references, station
locations, `location`-typed variables (ADR-0046) and a person's `.loc`
(ADR-0047):

- **`place`** — the string address text. Kept as-is (a good name).
- **`position`** — the raw `LatLng`, formatted to a string at resolve time
  through a `CoordinateFormat` (default **UTM**). This is the single coordinate
  facet, replacing today's flat `utm` / `latlng` facets.

So `{{station.position}}`, `{{roleplay.position}}`,
`{{station.loc.<slug>.position}}` and a location variable's
`{{var.<name>.position}}` all resolve the coordinate in the configured format,
while `{{…loc.<slug>.place}}` stays the address text. The bare location token
(`{{station.loc.<slug>}}`) keeps rendering place + position. The action chip
(§1) uses the same raw `LatLng` for its map link, so the displayed format and
the map target never diverge.

`CoordinateFormat` ships with **UTM only** now — it is the seam. Explicit
per-format sub-facets are addressed under `position`
(`{{…position.utm}}` resolves today as UTM); the other formats (MGRS, DD, DM,
DMS, raw LatLng) come later, à la [ADR-0034](../adrs/0034-configurable-numbering-formats.md)'s
configurable numbering. Renaming the flat `utm`/`latlng` facets to `position`
is a deliberate, unpublished-app change (no migration): update
`plan_field_tokens.dart`, `BriefRenderer`'s `refContext` (its `position` facet
becomes the formatted coordinate, still via `briefCopyChip`), the `nb`/`en`
example content that uses the old tokens, and the `docs/variables.md` /
`docs/template.md` token tables. The `ChipFormatter` change keeps briefs
byte-identical for non-position content; fields that use a position token are
migrated deliberately here.

## Settled in discussion

- App-only for now; briefs keep `briefCopyChip`. HTML brief action chips and
  full app/brief parity come later, via the same `ChipFormatter` selected per
  format.
- Tap anywhere except the copy icon = action; the copy icon = copy.
- Phone is a full chip (copy icon and all), not plain tappable text.
- Actions are a list; a tap runs the single action directly today, and opens a
  context menu only once a chip has more than one action.

## Deferred

- Address chips stay copy-only.
- The long-press context menu / multiple actions per chip.
- The non-interactive export formats (PDF, DOCX) and the HTML brief — this
  design only builds the `ChipFormatter` seam they will select through.
- **Additional coordinate formats.** §5 wires the `CoordinateFormat` seam with
  **UTM only**; MGRS, the degree variants (DD, DM, DMS) and raw-LatLng output —
  via explicit `position.<fmt>` sub-facets and/or a configurable default, à la
  ADR-0034 — are a follow-up. The `place`/`position` facet model itself ships in
  this design (§5).

## ADR

The per-output-format chip strategy, the `ringdrill://chip` encoding and the
`place` / `position` coordinate facet model are recorded in
[ADR-0050](../adrs/0050-per-output-format-chip-formatting.md) (Accepted).

## Implementation status

Shipped, across six commits on `design-013`:

- The `ChipFormatter` strategy (`CopyChipFormatter` / `ActionChipFormatter`)
  in `field_resolver.dart`, threaded through the resolver with the brief
  staying on the default formatter (byte-identical).
- `StationScope`/`RoleplayScope` carry the raw `LatLng? position`; the app
  resolvers (`resolveScopedField`/`resolveModelField`) pass
  `ActionChipFormatter`, so an app-resolved position is an actionable link.
  `RingDrillText.plain` strips that link markup to its display text, the
  same way it already stripped backtick copy chips.
- The `place`/`position` coordinate facet model with a `CoordinateFormat` seam
  (UTM only); the flat `utm`/`latlng` facets are gone, migrated to
  `position` everywhere (content, tests, docs).
- `_ActionChip` in `brief_markdown.dart`: an actionable link renders as a
  pill matching `_CodeChip`'s look, tap-to-act / icon-to-copy, registered on
  both `BriefMarkdown` and `BriefMarkdownBlock`; every other link is
  unaffected.
- The actor's phone is a first-class chip in `roleplays_view.dart` and
  `roleplay_screen.dart`'s Spill card footer, and the brief templates render
  it unescaped (`{{{phone}}}`) so the pre-built copy chip actually renders.

Follow-up refinement: the action-chip encoding shipped initially as a terse
`rdchip:<action>` sentinel scheme (`[display](rdchip:geo:<lat>,<lng>)` /
`[display](rdchip:tel:<number>)`), then replaced — same decision, refined
encoding, no user-visible change — with the structured `ringdrill://chip`
URI described in §1/§4 above, for legibility and room to grow (a future
`label`, further actions).

Deferred, as recorded above: address action chips, the multi-action context
menu, the non-interactive export formats (PDF, DOCX) and the HTML brief, and
every coordinate format beyond UTM.
