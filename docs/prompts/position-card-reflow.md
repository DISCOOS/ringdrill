# Reflow the position field into a shared PositionCard (station + location forms)

You are working in the RingDrill repository. This is a **layout** change: the
position UI in the station form and the location form should use horizontal
space instead of stacking or cramming, and both screens should share one
position component. Read `AGENTS.md` rule 9 (test-loop discipline),
[ADR-0030](../adrs/0030-wide-screen-master-detail-layout.md) (forms full-screen
on narrow / dialog on wide), and [ADR-0031](../adrs/0031-row-edit-affordances.md)
(row affordances).

**Visual reference:** `docs/design/mockups/position-card.html` (two screens: the
station-form `row` variant and the location-form `card` variant, plus a note on
the shared component API).

## The problem

- `station_form_screen.dart` (`_buildStationSectionBody`) lays the name field in
  an `Expanded` next to a fixed `SizedBox(width: 230)` wrapping a bordered
  `PositionFormField`. On a phone that box steals ~230px from the name and the
  coordinate wraps to two lines.
- `location_form_screen.dart` stacks three elements about the same thing: the
  "Oppdater fra kart" `TextButton`, a 92px map thumbnail (`_LocationPositionField`),
  and the `PositionFormField` readout row.

## Out of scope (do not touch)

- The coordinate text/order stays exactly as `UtmWidget` renders it today
  (`32V 0580345E 6551796N`). No format change.
- The map picker (`MapPickerScreen`, `map_view.dart`) — its own prompt
  (`docs/prompts/map-picker-redesign.md`).
- Wide-screen side-by-side is deliberately not built: the position control is
  full width in both forms at all widths. (Possible later follow-up.)

## What changes

Extend `PositionFormField` (keep it a `FormField<LatLng>` — it must keep taking
part in `Form` save/validate and keep its `onChanged`/`validator`/empty-state)
to render one of two variants, matching the mockup:

1. **`PositionFieldVariant.row`** — horizontal: a live mini-map thumbnail on the
   left (~76px wide, matched to the row height), a single-line UTM coordinate in
   the middle, a trailing `chevron_right`. Used by the station form.
2. **`PositionFieldVariant.card`** — stacked: a live mini-map thumbnail on top
   (full width, ~120px), a coordinate bar below with a trailing chevron. Used by
   the location form.

Both variants:

- Render the thumbnail with `MapView` inside an `IgnorePointer` (the existing
  `_LocationPositionField` pattern), reusing `MapConfig.layers`, the passed
  `markers`, and a marker at the current position.
- Make the whole surface an `InkWell` that opens the picker — move the existing
  `IconButton(Icons.map)` `onPressed` logic (centre/`CameraFit` computation +
  `openFormSurface` → `MapPickerScreen`, then `state.didChange` + `onChanged`)
  onto that tap, and remove the standalone map `IconButton`. The chevron is the
  affordance; no `Icons.edit` in the row (ADR-0031).
- Accept `overlayActions: List<Widget> = const []`, rendered top-right over the
  thumbnail in a `Stack`. Empty by default.
- Keep the empty state (`pickALocation`) and the validator/error text.

`MapView` stays domain-agnostic (see `feedback`/ADR-0020 lineage): the
location form's reverse-geocode action arrives via `overlayActions`, never a new
`MapView` flag.

## Ground rules

- No raw English in widgets. This change should need **no new ARB keys** — reuse
  `position` for the label and `locationsSectionUpdatePlaceFromMapAction` as the
  reverse-geocode icon's tooltip. If you add a key, run `make i18n`
  (`flutter gen-l10n`); never hand-edit `app_localizations*.dart`.
- Commit messages in English, conventional-commits.
- **Test-loop discipline (rule 9):** per commit `flutter analyze` +
  `flutter test test/views/`; full `flutter test` + `dart build cli` **once at
  the end**. Each commit lists its files and ends with a clean `git status`.

## Scope

Three commits.

### Commit 1. PositionFormField variants

Add the `variant`, `showThumbnail`, and `overlayActions` params; render the
`row` and `card` layouts per the mockup; move picker-open onto a surface
`InkWell`; drop the standalone map `IconButton`; keep all `FormField` plumbing.
Split the pure layout into `lib/views/widgets/position_card.dart` if that reads
cleaner, but the public entry stays `PositionFormField`.

Files: `lib/views/position_form_field.dart` (+ optional
`lib/views/widgets/position_card.dart`), the targeted widget test (search
`test/views/` first — add one if none exists). `flutter analyze` +
`flutter test test/views/`. Commit:
`feat(views): PositionFormField row/card variants with thumbnail and tap-to-pick`.

### Commit 2. Station form — drop the 230px sidecar

Replace `Row[Expanded(name), SizedBox(width:230, Container(PositionFormField))]`
with a full-width name `RingDrillTextField`, a `SizedBox(height: 16)`, then a
full-width `PositionFormField(variant: row)` carrying the same `markers` logic.
Remove the grey `Container`/border wrapper.

Files: `lib/views/station_form_screen.dart`, its test. `flutter analyze` +
`flutter test test/views/`. Commit:
`refactor(views): station form position as full-width row, drop 230px box`.

### Commit 3. Location form — collapse to one card

Replace `_LocationPositionField`'s thumbnail-`ClipRRect` + separate
`PositionFormField` stack, and the standalone "Oppdater fra kart" `TextButton`,
with a single `PositionFormField(variant: card, showThumbnail: true,
overlayActions: [...])`. Pass the reverse-geocode action (icon `Icons.refresh`,
tooltip `locationsSectionUpdatePlaceFromMapAction`, calling `_updatePlaceFromMap`)
in `overlayActions`, gated on the existing `canUpdateFromMap`. Keep keying the
field on `_position` so a forward-geocode pick still remounts it.

Files: `lib/views/location_form_screen.dart`, its test. `flutter analyze` +
`flutter test test/views/`. Commit:
`refactor(views): location form position as single map card with overlay action`.

### Final gate

`flutter analyze`, full `flutter test`, `dart build cli` once. Fix or flag any
failure. Confirm `git status` clean.

## Acceptance

- Station form: name full width; position a full-width single-line row with a
  thumbnail; tapping anywhere on it opens the picker.
- Location form: place field, then one map card (thumbnail + coordinate bar +
  reverse-geocode icon); no separate link or duplicate readout row.
- Coordinate text unchanged; no new ARB keys (or `make i18n` run if any added).
- `flutter analyze` clean, `flutter test` green, CLI builds.
