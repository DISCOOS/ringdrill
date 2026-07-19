# Implement DESIGN-013: actionable field chips (tap-to-call, open-in-maps)

You are working in the RingDrill repository. Create a branch `design-013` off
`main`. Read `docs/design/013-actionable-field-chips.md` first, plus
`docs/variables.md` and `docs/template.md` (the chip/token machinery) and
`AGENTS.md` (especially rule 9 test discipline, rule 11 ADR-on-architecture,
rule 12 docs-in-English, rule 14 verify visual changes by rendering).

Goal: make copyable field chips **actionable in the app** — a position opens a
map, a phone dials — while the brief and future non-interactive exports keep
plain copy chips. The mechanism is a `ChipFormatter` strategy chosen per output
format. The brief output must stay **byte-identical** (the default formatter is
the copy chip; `BriefRenderer` never passes another).

Key existing pieces: `briefCopyChip` and the resolver in
`lib/services/brief/field_resolver.dart` (ADR-0048); the `_CodeChip` pill and
`_briefMarkdownConfig` in `lib/views/widgets/brief_markdown.dart`; the app
resolvers `resolveScopedField` / `resolveModelField` in
`lib/views/widgets/resolve_scoped_field.dart`; `StationScope` / `RoleplayScope`
and `openFormSurface._reprovideScopes`. `url_launcher` is already a dependency
(`roleplays_view.dart` already launches `tel:`).

Per-commit discipline (AGENTS.md rule 9): run `flutter analyze` and the
**targeted** tests for what you touched on each commit; run the full
`flutter test` and `dart build cli` **once at the end**. Every commit must
leave `git status` clean — list the files you touched and commit them all,
excluding `.claude/settings.local.json`. i18n strings go in **both**
`app_en.arb` and `app_nb.arb` (rule 12); run `make i18n` after ARB edits.
Verify the chip visuals with `skills/flutter-widget-preview/` before claiming
the render commit done (rule 14).

## Commit 1 — the `ChipFormatter` strategy (flutter-free), brief unchanged

In `field_resolver.dart` add:

```dart
abstract class ChipFormatter {
  const ChipFormatter();
  String position(String display, LatLng? latLng);
  String phone(String display, String number);
  String address(String value);
}
class CopyChipFormatter extends ChipFormatter { /* all → briefCopyChip(display|value) */ }
class ActionChipFormatter extends ChipFormatter { /* rdchip: links; degrade to copy without coord/number */ }
```

`ActionChipFormatter` encodes `[display](rdchip:geo:<lat>,<lng>)` and
`[display](rdchip:tel:<number>)`; a null `latLng` / empty `number` falls back to
`briefCopyChip(display)`. `address` stays `briefCopyChip(value)` in both.

Thread `ChipFormatter chips = const CopyChipFormatter()` through
`resolveField` → `_resolveFieldOnce` → `substituteTypedVariables` (its
`locationFacetResolver` closure) and `_resolveStationScenarioTokens` →
`_resolveLocationFacet` / `_resolvePersonFacet` / `_locationDefault`. Replace
their internal `briefCopyChip(...)` calls with `chips.position/…/address(...)`,
preserving the *exact* current output under the default formatter (the
`_locationDefault` parens-folded `` `($utm)` `` must be reproduced —
`chips.position('($utm)', pos)` under `CopyChipFormatter` returns
`` `($utm)` ``). Keep `briefCopyChip` public; `BriefRenderer` keeps using it and
passes no formatter.

Tests: existing `BriefRenderer` tests stay green (byte-identical); add unit
tests for both formatters (position with/without coord, phone, address, the
`rdchip:` encoding).

Commit: `feat(brief): add a per-output-format ChipFormatter strategy`.

The design and its ADR are written and **Accepted** up front:
`docs/design/013-actionable-field-chips.md` and
`docs/adrs/0050-per-output-format-chip-formatting.md`. Implement against them;
do not re-open the decision. If implementation forces a change to the recorded
decision, update the ADR in the same change set and flag it.

## Commit 2 — carry the coordinate; app resolvers emit action chips

**Replace** the pre-formatted `positionUtm` **string** on `StationScope` and
`RoleplayScope` with a single `LatLng? position` — do not keep both (one
coordinate, not two representations). Format it at resolve time (default UTM) —
the `place`/`position` facet model and the `CoordinateFormat` seam are defined
in Commit 3 below.

Rename touches every call site that builds/copies these scopes:

- `station_scope.dart` (field + `forStation`), `roleplay_scope.dart` (field +
  `forRoleplay`): store `station.position` / `rolePlay.position` directly
  instead of `formatUtm(...)`.
- `open_form_surface.dart` `_reprovideScopes`: copy `.position` instead of
  `.positionUtm`.
- `roleplay_form_screen.dart`, `station_form_screen.dart`,
  `roleplay_screen.dart`: pass the `LatLng?` to `StationScope` instead of the
  formatted string.
- `resolve_scoped_field.dart` `_stationFacets` / `_roleplayFacets`: build the
  `position` facet (Commit 3) from the coordinate, feeding both the formatted
  display and the raw coordinate to the chip — `chips.position(format(coord), coord)`.

Then in `resolve_scoped_field.dart` pass `const ActionChipFormatter()` to
`resolveField` / `resolveModelField` (model path formats from the model's own
`.position`). Scenario location chips need no extra wiring — the threaded
formatter plus `Location.position` already make them actionable.

`BriefRenderer` is untouched (it does its own UTM formatting with the default
copy formatter). Tests: extend the resolver/scope tests so a station/roleplay
position and a `station.loc.*` position resolve to an `rdchip:` link under the
app resolvers, and to a plain copy chip under the brief default.

Commit: `feat(views): carry the coordinate on the resolve scopes and resolve app position chips as actionable`.

## Commit 3 — coordinate facet model (`place` + `position`, `CoordinateFormat`)

Fold the coordinate facets into one model (DESIGN-013 §5, ADR-0050): keep
**`place`** (the string address text) and introduce **`position`** (the raw
`LatLng`, formatted to a string via a new `CoordinateFormat`, default **UTM**),
replacing the flat `utm` / `latlng` facets.

- `field_resolver.dart`: `_resolveLocationFacet` keeps `place`; its `utm` /
  `latlng` cases collapse into a single `position` facet formatted through
  `CoordinateFormat` (default UTM); the bare/default location token still
  renders place + position. The `location`-typed variable facets (ADR-0046) and
  the person `.loc` path use the same names. `CoordinateFormat` is a new
  flutter-free enum with **UTM only** implemented — the `format` parameter
  (default UTM) is the seam for MGRS / DD / DM / DMS / LatLng later.
- `BriefRenderer`: its `refContext` `position` facet becomes the formatted
  coordinate string (still wrapped with `briefCopyChip`), replacing the nested
  `{'utm': …}` shape, so `{{station.position}}` / `{{roleplay.position}}`
  resolve. Non-position brief content stays byte-identical.
- `plan_field_tokens.dart`: offer `station.position` / `roleplay.position` (and
  the location `position` facet) in place of the `…position.utm` entries.
- Migrate the `nb`/`en` example content and any tests using the old
  `utm`/`latlng`/`position.utm` tokens to `position`.
- Update the token tables in `docs/variables.md` and `docs/template.md` to the
  `place` / `position` model.

Tests: a coordinate resolves to `position` in the configured (UTM) format
across a station cross-reference, a `station.loc.*` facet and a location
variable; `place` is unchanged.

Commit: `feat(brief): unify coordinate facets as place + position with a CoordinateFormat seam`.

## Commit 4 — render the action chip

In `brief_markdown.dart` add `_ActionChip` (reusing the `_CodeChip` pill,
including the parens adornment) and a `SpanNodeGeneratorWithTag` for the link
tag that renders an `rdchip:` href as `_ActionChip`, falling through to the
existing `LinkConfig` for every other link. `_ActionChip`: an `InkWell` over
everything **except** the copy icon runs the chip's action via `url_launcher`
(open the maps URL for `geo:`, launch `tel:` for phone); the copy icon copies
the value. Build the maps URL as
`https://www.google.com/maps/search/?api=1&query=<lat>,<lng>`. Model the
actions as a **list**: with a single action a tap runs it directly (today's
only case — no menu); with more than one a tap opens a context menu (a `// TODO`
seam — no chip has multiple actions yet).

Register the generator so it is active on the app surfaces (`BriefMarkdown` and
`BriefMarkdownBlock`); `BriefScreen`'s content never contains `rdchip:`, so it
is unaffected. Verify with the widget-preview skill that a position chip and a
phone chip render as pills with the copy icon and that a tap is wired.

Tests: a widget test that an `rdchip:geo:` / `rdchip:tel:` renders a pill,
tapping the body launches (assert via a `url_launcher` mock/`setMockMethodCallHandler`),
and tapping the copy icon copies without launching.

Commit: `feat(views): render actionable rdchip pills in the app markdown`.

## Commit 5 — phone as a first-class chip

- `roleplays_view.dart`: render the cast actor's info **under the marker's full
  name** via `RingDrillText.rich`, fed a phone chip (through the app resolver /
  `ChipFormatter.phone`), replacing the plain-text `tel:` tap. Keep the layout
  balanced; this is a small restructure of the actor block.
- `roleplay_screen.dart`: show the actor phone chip in the **expanded details
  hint field** (the only surface with room).
- `assets/templates/ringdrill-standard-v1.{nb,en}.md.mustache`: render the
  post-chapter `phone` as a copy chip — switch the escaped `{{phone}}` to the
  unescaped `{{{phone}}}` (the `phone` context value is already a
  `briefCopyChip`), and confirm the `**Markør:** {realName} {phone}` line reads
  well. Roleplays are already rendered in the station chapter, so no new
  roleplay support is needed — only the phone-as-chip change.

i18n: any new/changed strings in both ARBs; `make i18n`. Verify the two app
surfaces render the phone pill (widget-preview skill).

Commit: `feat(views): show the marker phone as an actionable chip in the app and brief`.

## Commit 6 — docs and close out

Reconcile the reference docs with what shipped (Commit 3 already updated the
coordinate facet **tables**; this closes out the narrative):

- `docs/variables.md` and `docs/template.md`: update the **copy-chip
  convention** sections to describe the per-format `ChipFormatter` — a plain
  copy chip in the brief and the non-interactive exports (PDF, DOCX), an
  **action chip** (tap-to-call / open-in-maps, copy icon retained) in the app
  preview and HTML. Confirm the `place` / `position` facet model reads
  consistently across both docs. Cross-link DESIGN-013 and ADR-0050.
- Add a short implementation-status note to DESIGN-013 recording what shipped
  and what stayed deferred (address action, context menu, the extra coordinate
  formats, HTML/PDF/DOCX). DESIGN-013 and ADR-0050 are already `Accepted` — do
  not change their status.

Full `flutter test` + `dart build cli` as the final gate.

Commit: `docs: reconcile chip and coordinate-facet reference docs with DESIGN-013`.

## Guardrails

- The brief must stay byte-identical: never pass a non-default `ChipFormatter`
  from `BriefRenderer`, and keep `CopyChipFormatter` output equal to today's
  `briefCopyChip`.
- Do not launch URLs by any means other than `url_launcher` (no raw platform
  channels); guard with `canLaunchUrl`.
- Keep `field_resolver.dart` free of `package:flutter/*` (ADR-0005) — the
  `ChipFormatter` classes are pure string/`LatLng` logic.
- The `rdchip:` scheme is an internal encoding; never let it reach a
  copy/clipboard value or a non-app surface.
