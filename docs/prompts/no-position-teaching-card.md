# Replace the "no position" fallback with a teaching empty state

You are working in the RingDrill repository, on the branch Kengu points you at
(currently `design-014`). **Another agent may be committing on the same
branch** — pull/rebase before you start and before each commit, and never
`git add -A`. The working tree already contains changes that are **not yours**
and must stay uncommitted: `skills/ringdrill-plan-authoring/reference/format.md`,
`assets/example/2026 LSOR øvelseshefte.docx`,
`assets/example/lsor-ovelseshefte-2026.{drill,yaml}` and
`.claude/settings.local.json`. Commit only the files each step below names.

Read `AGENTS.md` first (rule 9 test discipline, rule 10 formatting, rule 12
docs-in-English, rule 14 verify visual changes by rendering) and the mockup
[`docs/design/mockups/no-position-teaching-card.html`](../design/mockups/no-position-teaching-card.html),
which is the design this prompt implements.

## The problem

A station or markør with no position renders three different empty states
depending on the surface, none of them useful:

- `StationPositionPanel._buildNoPositionRow` (`lib/views/widgets/station_position_panel.dart:138`)
  and `RolePositionPanel._buildNoPositionRow`
  (`lib/views/widgets/role_position_panel.dart:150`) emit a bare
  `Posisjon … Ingen posisjon` row. In the expanded (≥840) detail pane that row
  is stretched to the pane's full height by `fillHeight`, so a single label sits
  marooned in an otherwise empty half-screen — mockup panel 1.
- `station_screen.dart:470` and `roleplay_screen.dart:614` instead swap in
  `MapPlaceholder` (icon + one-line caption). No explanation, no way forward.

Nothing tells the author *why* it matters (the station is missing from the map
and the brief chapter gets no coordinate) or offers to fix it.

## The design

No position renders as the **same `PositionCardShell`** as a set position —
same 8px radius, same tonal map chrome, same collapse chevron (`sectionId`) and
legend slot — with a teaching empty state in the `thumbnail` slot and
"Ikke satt" instead of the UTM string in the coordinate bar (mockup panels 2–4).
Inline call sites inside `ExpansionTile` bodies keep today's one-line row
(mockup panel 5): the teaching card is for slots that own a real map height.

## Commit 1 — `PositionEmptyState`

`MapPlaceholder` (`lib/views/widgets/map_placeholder.dart`) already owns the
card-shaped tonal box that visually stands in for the map card. Keep it as the
single source of that chrome: give it an optional `child` slot that replaces its
default `EmptyState` body (`message`/`icon` stay, and stay required when
`child` is null), so its existing call sites and
`test/views/widgets/map_placeholder_test.dart` keep working.

Add `lib/views/widgets/position_empty_state.dart` with `PositionEmptyState`,
built on `MapPlaceholder` + the existing `TeachingEmptyState` vocabulary
(`lib/views/widgets/teaching_empty_state.dart` — reuse it if it fits the slot,
otherwise lift its icon-disc/title/body/tonal-button shape into the new widget
rather than restyling it in place; `TeachingEmptyState`'s current call sites
must not change appearance):

```dart
PositionEmptyState({
  required String title,
  required String body,
  IconData icon,               // default Icons.add_location_alt_outlined
  double? height,              // forwarded to MapPlaceholder
  String? actionLabel,         // null → no button
  VoidCallback? onAction,      // null → button rendered disabled
  String? disabledTooltip,     // why the action is unavailable
})
```

Wrap the whole thing in a `LayoutBuilder`: at a usable height (say ≥ 160 px)
render the full column (icon disc, title, body, action); below that fall back to
the compact icon + `title` caption, so a short slot cannot overflow.

New ARB keys, in **both** `lib/l10n/app_nb.arb` and `lib/l10n/app_en.arb`, each
with an `@`-description (check first whether a suitable key already exists —
`noLocation`, `placement` and `setPositionFor` do, `positionNotSet` does not):

| key | nb | en |
| --- | --- | --- |
| `positionNotSet` | Ikke satt | Not set |
| `noPositionTitle` | Ingen posisjon satt | No position set |
| `noPositionStationBody` | Posten vises ikke i kartet, og heftet får ingen koordinat. | This station isn't shown on the map, and the brief gets no coordinate. |
| `noPositionRolePlayBody` | Markøren følger posten, men posten har ingen posisjon. Sett posisjon på posten, eller gi markøren sin egen. | This markør follows its station, but the station has no position. Set a position on the station, or give the markør its own. |
| `setPosition` | Sett posisjon | Set position |
| `setOwnPosition` | Sett egen posisjon | Set own position |

Run `make i18n` after editing the ARBs (`make build` does **not** regenerate
`app_localizations*.dart`).

Tests: a widget test for `PositionEmptyState` (full column above the height
floor, compact caption below it, button absent when `actionLabel` is null,
disabled with a tooltip when `onAction` is null).

Files: `lib/views/widgets/map_placeholder.dart`,
`lib/views/widgets/position_empty_state.dart`, both ARBs, the regenerated
`lib/l10n/app_localizations*.dart`, `test/views/widgets/position_empty_state_test.dart`.
Commit: `feat(views): add a teaching empty state for a missing position`.

## Commit 2 — wire it into the station surfaces

`StationPositionPanel` gets an explicit style parameter — do **not** derive it
from `fillHeight`:

```dart
enum PositionEmptyStyle { row, card }
// field: final PositionEmptyStyle emptyStyle;  // default PositionEmptyStyle.row
```

`row` keeps `_buildNoPositionRow` exactly as it is today, so
`station_list_view.dart:451`, `plan_view.dart:1362` and
`coordinator_screen.dart:1658` are untouched (only the value text changes there
if you switch it to `positionNotSet` — do that, mockup panel 5, and update
`test/views/widgets/station_position_panel_test.dart:168` accordingly).

`card` builds the same `PositionCardShell` as `_buildPositionCard`, with:

- `thumbnail:` a `PositionEmptyState` (`noPositionTitle` +
  `noPositionStationBody`, action `setPosition` → the panel's `onTap`),
- `thumbnailHeight`/`fillHeight`/`sectionId`/`asCard` forwarded unchanged
  (`legend` is meaningless with no markers — omit it),
- `barChild:` `positionNotSet` in `onSurfaceVariant`, `barLabel` as today.

Gate the action the same way the AppBar pencil is gated
(`station_screen.dart:269-289`): wrap in `IfEditable(target: EditTarget.station)`
so a viewer gets the explanation with no button, and pass a null `onAction` +
`stopExerciseFirst(...)` tooltip while the exercise is running instead of hiding
it (mockup panel 4). The gate belongs at the `station_screen` call site, not
inside `StationPositionPanel` — the panel takes `actionLabel`/`onAction`-shaped
inputs or a prebuilt empty-state child, whichever keeps the shared widget free
of permission logic.

In `station_screen.dart`: pass `emptyStyle: PositionEmptyStyle.card` from
`_buildMapCard`, and **delete the `station.position == null` branch** at line
469-476 so the Map segment renders `_buildMapCard` unconditionally. Also fix
`initialSectionId: 'id'` (line 383) → `'station'`, which is the actual section
id in `station_form_screen.dart:816`; the CTA must land on the section holding
the position field.

Tests: extend `station_position_panel_test.dart` (card variant shows title,
body and CTA; row variant unchanged) and
`test/views/station_screen_expanded_layout_test.dart` (expanded pane with no
position shows the card, not the bare row; tapping the CTA opens the station
form on the `station` section).
Commit: `feat(views): teach the missing position on the station map surfaces`.

## Commit 3 — the same for markør surfaces

Mirror commit 2 in `RolePositionPanel` and `roleplay_screen.dart`: reuse the
`PositionEmptyStyle` enum, `noPositionRolePlayBody` for the copy,
`setOwnPosition` for the CTA, `IfEditable(target: EditTarget.rolePlay)` for the
gate, and `Icons.mood` (matching the marker-icon convention: a face means one
markør) for the icon. Remove `_buildMapPlaceholder`
(`roleplay_screen.dart:608-615`) and its call sites in favour of the panel's own
card. `roleplay_list_view.dart:388` keeps the row.

`roleCentralPosition` returns null only when neither the markør nor its station
has a position, so the copy must point at both — do not imply the markør alone
is at fault.

Tests: `test/views/widgets/role_position_panel_test.dart` plus
`test/views/roleplay_screen_expanded_layout_test.dart:196`, which currently
asserts the `noLocation` text.
Commit: `feat(views): teach the missing position on the markør map surfaces`.

## Commit 4 — verify and close out

Render the new states with `skills/flutter-widget-preview/` (rule 14) and
confirm against the mockup: expanded pane card, markør card, viewer variant
(no button), running variant (disabled button), and the untouched inline row.
Attach/mention the PNGs in the commit body.

If `noLocation` is now unused, remove it from both ARBs and regenerate;
if `MapPlaceholder` is left without a caller, keep it (it is the shared chrome
`PositionEmptyState` builds on) and say so in its doc comment.

Final gate: `flutter analyze`, full `flutter test`, `make cli-check`,
`dart format` on the files you touched.
Commit: `test(views): verify the no-position teaching card renders`.

## Guardrails

- Per-commit discipline (rule 9): `flutter analyze` + the **targeted** tests on
  each commit; full `flutter test` and `make cli-check` **once** at the end.
- Every commit leaves `git status` clean *for your files* — the pre-existing
  changes listed at the top stay untracked/unstaged.
- No raw English (or Norwegian) strings in widgets: every user-visible string
  goes through the ARBs, both languages, conceptually equivalent.
- Do not restyle `PositionCardShell`, `TeachingEmptyState` or the set-position
  card. This change only fills the empty state.
- No new `Icons.edit` affordances in rows — the CTA is a tonal button inside the
  empty state, nothing else changes.
