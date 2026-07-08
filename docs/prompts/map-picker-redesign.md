# Reflow the map picker — bottom confirm bar and anchored coordinate

You are working in the RingDrill repository. This is a **layout** change to the
location picker (`MapPickerScreen`): move confirmation into thumb reach, anchor
the live coordinate at the bottom, and clarify the centre pin. Read `AGENTS.md`
rule 9 (test-loop discipline) and [ADR-0020](../adrs/0020-map-label-and-marker-clutter.md)
(`MapView` marker/label model — stays domain-agnostic).

**Visual reference:** `docs/design/mockups/map-picker.html` (the redesigned
picker, plus a change list against today's screen).

## The problem

`MapPickerScreen` today confirms with a small `check` action in the AppBar
(top-right, out of one-handed reach), floats the live coordinate in a top bar
away from where the eye is (the centre), and shows both a centre crosshair and a
separate marker so it is unclear which point is "the answer".

## What changes

The selection model stays the same: the camera centre is the selected point
(`_selected = e.camera.center`). Only the presentation moves.

1. **Bottom action bar.** Add an overlay bar anchored to the bottom of the map
   with the live UTM coordinate (reuse `UtmWidget`, unwrapped/one-line) and a
   primary "Velg her" button that pops `_selected`. Remove the AppBar `check`
   action. Keep a close/back affordance (AppBar leading or a top-left button per
   the mockup).
2. **One clear centre pin.** Render the centre indicator as a single fixed pin
   with a small ground dot (the point being set). Context markers passed in via
   `markers` are shown dimmed so it is obvious they are not the selection.
3. **Coordinate anchored, not floating.** The coordinate lives in the bottom bar
   near the crosshair, not in a top floating strip.
4. **Scale as a chip.** Present the scale bar as a semi-transparent chip so it
   does not fight the map labels. (If the scale comes from `MapView`, style it
   there behind the existing knob rather than duplicating it.)

## Out of scope (do not touch)

- The coordinate text/order stays exactly as `UtmWidget` renders it. No format
  change.
- Reverse-geocoded place name in the bar is **optional** and not required here:
  only show a place line if a geocoder is already available to the screen;
  otherwise show coordinate only. Do not add a geocoding dependency to
  `MapPickerScreen` in this prompt.
- The position field itself (`PositionFormField`) — its own prompt
  (`docs/prompts/position-card-reflow.md`).

## Ground rules

- No raw English in widgets. Reuse `select` / `pickALocation` where they fit;
  the "Velg her" button needs a string — reuse an existing "select/choose" key
  if one reads right, otherwise add one ARB key (en + nb) and run `make i18n`.
- `MapView` stays domain-agnostic: drive the centre-pin styling and any overlays
  through its existing slot props / flags (`withCross`, `withCenter`, …), not a
  feature-specific hack.
- Commit messages in English, conventional-commits.
- **Test-loop discipline (rule 9):** per commit `flutter analyze` +
  `flutter test test/views/`; `make i18n` only if ARB changed; full
  `flutter test` + `dart build cli` **once at the end**. Each commit lists its
  files and ends with a clean `git status`.

## Scope

Two commits.

### Commit 1. Bottom bar + confirm

Add the bottom action bar (coordinate + "Velg her"), move confirmation off the
AppBar, keep the close affordance. Wire "Velg her" to `Navigator.pop(context,
_selected)`.

Files: `lib/views/map_picker_screen.dart`, `lib/l10n/*.arb` (+ regenerated
localizations) only if a string is added, its test (search `test/views/`).
`flutter analyze` + `flutter test test/views/`. Commit:
`feat(views): map picker confirm in a bottom bar with anchored coordinate`.

### Commit 2. Centre pin + context markers + scale chip

Render one fixed centre pin with a ground dot; dim context `markers`; present
the scale as a chip. Keep changes that touch shared `MapView` behind its
existing slot props / flags.

Files: `lib/views/map_picker_screen.dart`, `lib/views/map_view.dart` if a slot
prop is needed, tests. `flutter analyze` + `flutter test test/views/`. Commit:
`refactor(views): single centre pin, dimmed context markers, scale chip in picker`.

### Final gate

`flutter analyze`, full `flutter test`, `dart build cli` once. Fix or flag any
failure. Confirm `git status` clean.

## Acceptance

- Picker confirms from a bottom "Velg her" bar within thumb reach; no AppBar
  check.
- One clear centre pin = the selection; other markers dimmed.
- Live coordinate reads from the bottom bar in the unchanged format.
- `MapView` gains no domain-specific flag; changes ride existing slots.
- `flutter analyze` clean, `flutter test` green, CLI builds.
