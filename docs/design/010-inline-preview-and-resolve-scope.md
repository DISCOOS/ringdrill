---
id: DESIGN-010
title: Inline preview and the resolve-context scope cascade
status: Proposed
started: 2026-07-08
owners: ["kengu"]
related_code:
  - lib/services/brief/brief_renderer.dart
  - lib/views/widgets/ringdrill_text.dart
  - lib/views/widgets/ringdrill_text_field.dart
  - lib/views/widgets/token_text_editing_controller.dart
  - lib/views/widgets/plan_scope.dart
  - lib/views/widgets/station_scope.dart
  - lib/views/widgets/section_navigated_form.dart
  - lib/views/widgets/brief_markdown.dart
  - lib/views/exercise_form_screen.dart
  - lib/views/station_form_screen.dart
  - lib/views/roleplay_form_screen.dart
  - lib/views/location_form_screen.dart
  - lib/views/person_form_screen.dart
related_designs:
  - 008-plan-variables-and-section-navigated-editor.md
  - 009-scenario-locations-and-persons.md
  - brief-template.md
related_adrs:
  - 0048-flutter-free-field-resolver.md
  - 0046-plan-variables.md
  - 0047-scenario-locations-and-persons.md
  - 0030-wide-screen-master-detail-layout.md
  - 0032-program-scoped-routing.md
  - 0044-render-preview-on-site.md
---

# Inline preview and the resolve-context scope cascade

> This document is in English. Field, model and helper names are English throughout. Norwegian strings are the user-facing labels the app ships in `nb`.

## TL;DR

Token-aware fields render tokens as chips while editing, but the author can only see the *resolved* result by saving and opening the brief. This adds an in-editor **preview**: a per-section toggle that flips a section's token-aware fields between edit (chips) and rendered markdown, and an optional read-only **rollup** under the default section's fields that shows the whole entity's active sections resolved. Both are faithful to the brief.

The enabler is a **resolve-context scope cascade**. Full resolution (`{{var.*}}`, `{{station.loc/person.*}}`, and the mustache cross-references `program.*`/`exercise.*`/`station.*`/`roleplay.*`) lives only inside `BriefRenderer`. Rather than thread `Program` and `Exercise` through editor constructors, we expose them from the build tree the same way `PlanScope` exposes variables and `StationScope` exposes locations/persons. A small set of `InheritedWidget` scopes mirrors the renderer's `refContext` cascade — each level contributes its layer, a widget reads them and hands plain data to a **flutter-free field resolver** extracted from `BriefRenderer`. `RingDrillText` and the preview both read the same scopes, so the display surfaces gain full resolution for free. DESIGN-009's leaf-field token support (follow-up 4e) becomes a consumer of the same mechanism.

No model change, no schema bump. The resolver moves down into a Flutter-free layer; the renderer keeps calling it.

## Rationale

The chip layer only knows what its controller was handed: `var.*` (from `PlanScope`) and `station.loc/person.*` (from `StationScope`). It cannot show `{{exercise.name}}` or `{{station.position.utm}}` resolved, because those are the renderer's mustache pass. So "does this read right?" costs a save and a brief open, every time. That is the friction this removes.

We considered threading the ancestors through constructors (bigger surface, per-editor plumbing) and a two-string ancestor map (cheap but partial). Reading ancestors from the build tree is the better fit: it is the pattern already in use (`PlanScope`, `StationScope`), it composes as a cascade exactly like the renderer, and `Program`/`Exercise` already sit high in the tree under program-scoped routing ([ADR-0032](../adrs/0032-program-scoped-routing.md)). The ancestor levels are already-saved and stable; only the entity being edited is live, and that comes from the editor's own controllers, not a scope.

## The resolve-context cascade

Mirror `BriefRenderer`'s `refContext` layering in the widget tree. Each scope carries one level's contribution; a resolver walks up and merges them, program → exercise → station → roleplay, the same order `_buildStationContext` merges its maps:

* **`PlanScope`** (exists, DESIGN-008) — the program level. It already carries the declared variables; extend it to also expose the program's cross-reference facets (`program.name`, `program.description`). There is **no** separate `ProgramScope`: `Program` (the model) and "Plan" (the UI term) are one concept, and the scope keeps the established `PlanScope` name. Provided once, high in the tree, at the program-scoped route ([ADR-0032](../adrs/0032-program-scoped-routing.md)).
* **`ExerciseScope`** (new) — the exercise's facets (`exercise.*`, per DESIGN-009 4b's `PlanFieldTokens.exercise`) plus the exercise-level variable overrides that shadow the program defaults.
* **`StationScope`** (exists, DESIGN-009 follow-up 4) — locations, persons, portrayer-aware effective identity, and the station's own facets (`station.*`).
* **RolePlay** contributes its own facets (`roleplay.*`) at the roleplay editor; small enough to fold into the field's own context rather than a separate scope.

A field resolver reads whichever scopes are present (`maybeOf`, degrading gracefully outside a program context, as `RingDrillText` already does) and builds the merged context. Absent a level, its tokens resolve to the same placeholder the brief uses — honest, and now rare, since the ancestors are in the tree.

## Crossing the `openFormSurface` boundary

Editor forms open via `openFormSurface` ([ADR-0030](../adrs/0030-wide-screen-master-detail-layout.md)) — a full-screen route on narrow, a dialog on wide. Both push a new subtree under `Navigator`, which an `InheritedWidget` ancestor does **not** cross. So the resolve scopes must be **re-provided** inside the pushed surface, seeded from the same data. This is a single concern with two consumers: the preview needs the ancestors to resolve cross-references, and DESIGN-009's leaf forms (Location/Person) need `PlanScope`/`StationScope` for their now-token-aware fields. `openFormSurface` captures the ancestor scopes at the call site and re-wraps the pushed child, so any form opened through it inherits the same resolve context without each call site re-plumbing it.

## The flutter-free field resolver

Extract `BriefRenderer._resolveField` (and the `_resolveFieldOnce` pipeline: `{{var.*}}` → `{{station.loc/person.*}}` → mustache, fixpoint-bounded by `_maxResolvePasses`) into a reusable, Flutter-free function in the brief layer. Signature takes a field string plus the merged context (variables, `refContext` maps, optional scenario station + roleplays for `station.loc/person.*` and effective identity) and returns resolved markdown. `BriefRenderer` calls it, unchanged in behaviour; widgets call it with data read from the scopes. The resolver stays free of `package:flutter/*` (it already only touches `AppLocalizations`), matching the "widget reads scope, resolver stays pure" split the token controller uses. Whether this warrants its own ADR is an open question.

## Preview mode (per-section toggle)

`RingDrillTextField`/`RingDrillTextArea` gain a `preview` state. A small toggle in the section chrome (a `SectionNavigatedForm` affordance, e.g. an eye in the section bar) flips that section's token-aware fields:

* **Edit** — today's behaviour: chips + insertion menu.
* **Preview** — the same content run through the field resolver and rendered read-only via `BriefMarkdown` (`markdown_widget`), so headings, bold and the inline-code UTM look exactly like the brief. A single-line field previews as resolved `Text`.

Preview reacts live to edits with a debounce (field resolution is cheap string work). The default section, having several fields, flips them together.

## Section rollup under the default section

The default (base) section of the exercise, station and roleplay editors gains an optional read-only **rollup**: each active section's field, resolved via the field resolver and stacked in order, so the author sees the whole post/exercise/marker as it will read without leaving the editor. Behind its own toggle, default off, to keep the default section compact. On narrow it is an inline continuation beneath the structural fields (one scroll: fields, then the resolved sections); on wide it is a side-by-side live-preview pane (edit left, preview right) using the master/detail split ([ADR-0030](../adrs/0030-wide-screen-master-detail-layout.md)). It is built from the field resolver per section, not from `BriefRenderer.render()` (which is program/exercise-scoped and cannot target a single station or roleplay). Because it renders resolved content, it inherits the audience caveat below.

Each rendered section in the rollup is **tap-to-edit**: tapping it jumps to that section in the section-navigated switcher (reusing the existing navigation rather than inline editing that would duplicate the editor). The station **detail sheet** is this rollup — the station's lead description plus its sections, resolved (see DESIGN-009, "The station description as the default section").

## Detail sheets — the Post and Spill viewers

The station (Post) and roleplay (Spill) read-only detail sheets are this rollup made concrete, and stage 3's most visible payoff. Both call the field resolver, so every token resolves and renders as markdown. Today `station_screen.dart` prints `station.description` through `substitutePlanVariables` in a `SelectableText`, so `{{station.position.utm}}` shows as literal text; the resolver closes that, and the same fix reaches the roleplay sheet, which currently renders only its own (often inherited-empty) identity fields.

The **Post viewer** stacks the resolved lead and its labeled sections, then surfaces the station's scenario data — its persons and locations (DESIGN-009) — as list cards and draws those points on the map. The **Spill viewer** presents the marker's order: the effective identity, the play (behavior, background, props), the position, the parent post, and when the marker is active.

Both render according to the **role selected in settings** (default director), not an in-view toggle: role-gated sections (the DESIGN-004 audiences) appear per that role. A role selector may later live in the drawer or navigation bar; there is no per-sheet audience switch.

The map in both sheets is the shared `StationPositionPanel` / `RolePositionPanel` — the same card shell (map, then a "Posisjon" coordinate strip, tap to open the interactive map) — fed the scenario markers as `MapMarkerSpec` styled by `LocationKind` ([ADR-0020](../adrs/0020-map-label-and-marker-clutter.md)) plus a legend through a slot, the same domain-agnostic slot mechanism the position field uses for its overlay actions. It is not a bespoke map. Mockup: `docs/design/mockups/station-and-roleplay-viewers.html`.

## `RingDrillText` upgrade

With the cascade in place, `RingDrillText` moves from `{{var.*}}`-only to full resolution by reading the same scopes and calling the field resolver. Every read-only display surface (lists, headers, the live coordinator UI) then shows the same resolved text the brief does, closing the gap the current variable-only resolver leaves.

Stage 3 must also catch the surfaces that call `substitutePlanVariables` **directly** rather than through `RingDrillText` — notably the station detail view (`station_screen.dart` renders `station.description` in a `SelectableText` via `substitutePlanVariables`, so `{{station.position.utm}}` shows literal today), and likely the station list, coordinator and program views. These are migrated to the field resolver too, so the var-only gap closes everywhere, not just where `RingDrillText` is used.

## DESIGN-009 leaf fields (follow-up 4e) as a consumer

DESIGN-009's token-aware scenario leaf fields (`Location.place`/`note`, `Person.name`/`signalement`/`notes`) depend on exactly the boundary mechanism above: the Location/Person forms open through `openFormSurface`, so they need `PlanScope`/`StationScope` re-provided. Once `openFormSurface` re-wraps the ancestor scopes, 4e is the wiring of `tokenAware: true` (and the self-reference rule) onto those leaf fields — it no longer needs its own scope plumbing. 4e therefore sequences **after** DESIGN-010 stage 1.

## Fidelity and non-goals

* **Audience.** The brief varies by audience (participant/instructor/director) for audience-gated content. A field preview resolves tokens (mostly audience-independent); the section rollup picks a single audience (default: the editor's working audience, or director for the fullest view). Faithful per-audience preview of gated blocks is out of scope for v1.
* **`program.*` in preview.** With `PlanScope` carrying the program facets, `{{program.name}}`/`{{program.description}}` resolve in preview — closing the gap that constructor-only context would have left.
* **No two-way editing in preview.** Preview is read-only; editing stays in the field's edit state and per section (DESIGN-008 section navigation is unchanged).
* **No new brief output.** This reuses the existing render pipeline and markdown widget; it does not add a brief format or surface.

## Settled decisions

1. **Program level = `PlanScope`.** No `ProgramScope`. The existing `PlanScope` is extended to carry program facets alongside variables (decided 2026-07-08).
2. **Resolver extraction gets its own ADR-0048.** Moving the field resolver out of `BriefRenderer` into a Flutter-free layer is an architectural decision, recorded separately and landed with stage 1.
3. **Preview toggle is per section, not editor-wide.** Each section owns its edit/preview state; the choice is remembered per section within a session, not shared across sections or scopes.
4. **Rollup layout.** ~~Inline continuation of the default section on narrow (one scroll: fields, then the resolved sections), and a side-by-side live-preview pane on wide (edit left, preview right — master/detail, ADR-0030). Decided 2026-07-08.~~ **Revised 2026-07-10:** the default section's rollup is no longer a separate bottom toggle plus a side-by-side/inline pane — it is the default section's own **per-section preview**, driven by the same app-bar eye every other section uses, swapping the *whole* section between its editable fields and the rollup. The side-by-side pane squeezed the fields on the narrower (medium) wide layout, and the bottom toggle sat below the fold on narrow; a full-section swap fixes both, and since the rollup already renders the lead description plus every section it reads as a complete preview. An empty rollup shows a muted placeholder (`rollupEmptyPreview`).

## Naming (`Program` → `Plan`), separate refactor

The model type is `Program`; the UI and these scopes/helpers already lean on "Plan" (`PlanScope`, `PlanVariables`, `PlanFieldTokens`). The chosen direction is to standardize on **Plan**: rename the model `Program → Plan` (and `Program*` helpers) so code matches the UI. This is a large mechanical rename, tracked as its own change, **not** part of DESIGN-010. It does **not** change the `.drill` format: the archive's root manifest stays named `program.json` (ADR-0007) and the JSON field keys are unaffected (they are `uuid`/`name`/`exercises`/…, never "program"). Only Dart identifiers and `nb` labels change; the wire format is frozen.

## Implementation notes

Staged, each a separate PR, all additive and Flutter-layer only except the resolver extraction (which is behaviour-preserving for the renderer). No schema bump.

1. **Resolver + cascade foundation (ADR-0048).** Extract the Flutter-free field resolver from `BriefRenderer` (renderer keeps calling it, unit tests unchanged). Extend `PlanScope` with the program facets, add `ExerciseScope`, provide them at the program-scoped route and the exercise editor, and re-provide all resolve scopes across `openFormSurface`. No visible change yet; tested by a resolver round-trip and a scope-presence test.
2. **Preview and rollup.** One rendering primitive, built together (the rollup is preview applied to every section): the per-section `preview` toggle on token-aware fields (rendered via `BriefMarkdown`, live with debounce), and the read-only section rollup under the default section (narrow inline continuation / wide side-by-side pane, tap-to-edit).
3. **`RingDrillText`, display callers and detail sheets.** Switch `RingDrillText` and the direct `substitutePlanVariables` callers to the field resolver + scopes; the Post and Spill read-only detail sheets become the resolved rollup made concrete.
4. **DESIGN-009 4e.** Make the scenario leaf fields token-aware on top of the re-provided scopes (self-reference rule from DESIGN-009).

(Consolidated from five stages to four: preview and rollup, which share one render-resolved-section primitive, are built together.)

**Progress (2026-07-10).** Stages 1 and 2 have landed on `design-010`; stages 3 and 4 remain.

* *Stage 1* — the Flutter-free field resolver is extracted (`lib/services/brief/field_resolver.dart`, [ADR-0048](../adrs/0048-flutter-free-field-resolver.md), still `proposed`), `PlanScope` carries the program facets, `ExerciseScope` is added, and the resolve scopes are re-provided across `openFormSurface` (`lib/views/shell/open_form_surface.dart`). Covered by resolver-parity and scope-presence tests; no visible change.
* *Stage 2 (including follow-up 2b)* — the per-section preview toggle and the read-only default-section rollup are built (`resolve_scoped_field.dart`, `section_rollup.dart`), with `StationScope` extended to carry the station's own facets. Follow-up 2b wired preview onto the base-section body and relabelled the rollup toggle to "Vis/Skjul detaljer". Tested.
* *Remaining* — **Stage 3**: migrate `RingDrillText` and the direct `substitutePlanVariables` callers to the resolver, and build the Post/Spill detail-sheet rollups (specified above, mockup `mockups/station-and-roleplay-viewers.html`, not yet implemented). **Stage 4** is **DESIGN-009 follow-up 4e** — token-aware scenario leaf fields on the re-provided scopes. DESIGN-008 (variables, section editor) and DESIGN-009 (locations/persons, `personRef`, now *Accepted*) are the foundations these stages consume.

All user-facing strings in `app_en.arb` / `app_nb.arb`; run `make i18n`.

## Norwegian labels (nb)

| English concept | Norwegian UI label |
|-----------------|--------------------|
| Preview (toggle) | Forhåndsvis |
| Edit (toggle, back from preview) | Rediger |
| Show preview under fields | Vis forhåndsvisning |
| Hide preview | Skjul forhåndsvisning |

## References

* [DESIGN-008](./008-plan-variables-and-section-navigated-editor.md) — token fields, `PlanScope`, `RingDrillText`, section-navigated editor.
* [DESIGN-009](./009-scenario-locations-and-persons.md) — `StationScope`, `station.loc/person.*`, leaf fields (4e).
* [ADR-0030](../adrs/0030-wide-screen-master-detail-layout.md) — `openFormSurface`.
* [ADR-0032](../adrs/0032-program-scoped-routing.md) — program context high in the tree.
* [ADR-0044](../adrs/0044-render-preview-on-site.md) — precedent for a preview surface.
