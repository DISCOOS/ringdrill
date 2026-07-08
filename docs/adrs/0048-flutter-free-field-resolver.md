---
status: proposed
date: 2026-07-08
deciders: ["kengu"]
consulted: []
informed: []
---

# ADR-0048: Extract a Flutter-free field resolver from BriefRenderer

## Context and problem statement

RingDrill resolves the token pipeline — `{{var.<name>}}` (ADR-0046), then `{{station.loc/person.<slug>[.facet]}}` (ADR-0047), then the mustache cross-reference pass (`program.*`/`exercise.*`/`station.*`/`roleplay.*`) — in one place: `BriefRenderer._resolveField` / `_resolveFieldOnce`, a private fixpoint loop bounded by `_maxResolvePasses`. That resolver runs only when the brief is generated. Everywhere else, an author sees a token's *effect* only by saving and opening the brief. `RingDrillText`, the read-only display widget, resolves `{{var.*}}` alone and leaves every other token literal (the "unresolved `{{station.position.utm}}` in the detail sheet" bug).

DESIGN-010 (inline preview, the section rollup, the `RingDrillText` upgrade) and DESIGN-009's token-aware leaf fields all need the *same* faithful resolution the brief uses, driven from the widget layer, over the author's unsaved working state. That means the resolver can no longer be a private method reachable only from a full `BriefRenderer.render()` call. It must be callable on a single field string with an explicit resolution context, from code that is not the brief renderer.

The constraint: the resolver already sits in the brief layer and touches only `AppLocalizations` and pure model types, so it is effectively Flutter-free today, but it is entangled with `BriefRenderer`'s private state. The CLI and other non-Flutter code must be able to depend on the resolver without pulling in Flutter (ADR-0005).

## Decision drivers

* DESIGN-010 preview, rollup and `RingDrillText` need the full pipeline, not just `{{var.*}}`, callable per field.
* One resolver, one behaviour — the in-editor preview must match the brief exactly, so both must call the same code (no second, drifting implementation).
* Must stay free of `package:flutter/*` so the CLI and pure-Dart callers can use it (ADR-0005), and so the "widget reads scope, resolver stays pure" split (already used by `TokenTextEditingController`) holds.
* Behaviour-preserving for the brief: `BriefRenderer` must keep producing byte-identical output, with its existing tests unchanged.

## Considered options

* **Option A — Extract a public, Flutter-free field resolver; `BriefRenderer` calls it.** Move `_resolveField`/`_resolveFieldOnce` (the var → scenario → mustache fixpoint) into a reusable function/class in the brief (or a shared `lib/services`/`lib/utils`) layer that takes a field string plus an explicit resolution context (variables, `refContext` maps, optional scenario station + roleplays). The renderer keeps building the context and delegates each field to it.
* **Option B — Keep the resolver private; expose only `RingDrillText`-level variable resolution, and add facet/cross-ref resolution separately in the widget layer.** A second resolver for the UI.
* **Option C — Render a whole entity via `BriefRenderer.render()` for preview and extract the field from the output.** Reuse the renderer as-is.

## Decision outcome

Chosen option: **Option A**, because it gives every surface one faithful resolver over an explicit context, keeps the brief behaviour-preserving, and stays Flutter-free so the CLI and the DESIGN-010 scope-fed widgets share the same code.

The resolver's public entry takes a field string and a resolution context assembled by the caller. In the brief, `BriefRenderer` assembles that context exactly as it does now. In the editor, the DESIGN-010 scope cascade (`PlanScope` → `ExerciseScope` → `StationScope`) supplies the layers, a widget reads them and hands the resolver plain data. The resolver never reads a `BuildContext` or a scope itself.

### Consequences

* Good: DESIGN-010 preview, the section rollup and the `RingDrillText` upgrade all call one resolver, so the preview is the brief.
* Good: `RingDrillText` can graduate from `{{var.*}}`-only to full resolution with no new logic.
* Good: stays Flutter-free, so the CLI and any pure-Dart caller (e.g. the future authoring-doc compiler) can resolve fields too.
* Good: behaviour-preserving — the brief renderer keeps its output and its tests; this is a move, not a rewrite.
* Bad: a public resolver is a new supported surface with its own tests and a context shape to keep stable.
* Bad: the caller now owns assembling the resolution context; if a widget assembles a partial context, some cross-references resolve to the brief's unknown-reference placeholder rather than their value (an honest, bounded limitation, not a crash).

## Pros and cons of the options

### Option A
* Good: one resolver, one behaviour; Flutter-free; behaviour-preserving for the brief.
* Bad: new public API surface and an explicit context contract to maintain.

### Option B
* Good: smallest immediate change.
* Bad: two resolvers drift; the preview stops matching the brief — the exact problem this is meant to remove.

### Option C
* Good: no extraction; reuses the renderer verbatim.
* Bad: `render()` is program/exercise-scoped and cannot target a single station, roleplay or field; heavy and async per keystroke; still needs the working state assembled into a throwaway model.

## Links

* Related ADRs: [ADR-0046](./0046-plan-variables.md), [ADR-0047](./0047-scenario-locations-and-persons.md), [ADR-0005](./0005-cli-must-remain-flutter-free.md)
* Related designs: [DESIGN-010](../design/010-inline-preview-and-resolve-scope.md), [DESIGN-008](../design/008-plan-variables-and-section-navigated-editor.md)
* Related code: `lib/services/brief/brief_renderer.dart` (`_resolveField`/`_resolveFieldOnce`/`_maxResolvePasses`), `lib/views/widgets/ringdrill_text.dart`, `lib/views/widgets/plan_scope.dart`, `lib/views/widgets/station_scope.dart`, `lib/views/widgets/token_text_editing_controller.dart`
