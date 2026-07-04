---
id: DESIGN-008
title: Plan variables and the section-navigated editor
status: Proposed
started: 2026-07-03
owners: ["kengu"]
related_code:
  - lib/models/program.dart
  - lib/models/exercise.dart
  - lib/models/station.dart
  - lib/views/program_form_screen.dart
  - lib/views/exercise_form_screen.dart
  - lib/views/station_form_screen.dart
  - lib/views/widgets/optional_field_sections.dart
  - lib/views/widgets/brief_markdown.dart
  - lib/services/brief/brief_renderer.dart
related_designs:
  - brief-template.md
  - 006-program-tab-consolidation.md
  - wide-screen-layout.md
related_adrs:
  - 0046-plan-variables.md
  - 0030-wide-screen-master-detail-layout.md
  - 0022-markdown-content-as-files.md
---

# Plan variables and the section-navigated editor

> This document is in English. Field, helper and component names are English throughout. Norwegian strings are the user-facing labels the app ships in `nb`.

## TL;DR

Two changes that arrive together. First, **variables**: author-defined values (`{{var.frekvens}}`) declared once on the plan and reusable in any markdown field, with per-exercise and per-station value overrides. The data model, namespace, resolution and validation rules are fixed in [ADR-0046](../adrs/0046-plan-variables.md); this doc specifies how they are authored. Second, a **section-navigated editor**: the entity forms stop being one long scroll and become a set of sections reached through a switcher, so a long markdown field gets the whole screen and the token-aware editing surface variables need. The switcher is a dropdown on compact and a master/detail rail on wide ([ADR-0030](../adrs/0030-wide-screen-master-detail-layout.md)). The same pattern applies to `Program`, `Exercise`, `Station` and `RolePlay`.

Mockups: [`mockups/variables-mobile.html`](./mockups/variables-mobile.html) (compact, four states), [`mockups/variables-wide.html`](./mockups/variables-wide.html) (expanded master/detail).

## Rationale

DESIGN-004 gave every entity a set of long-form markdown fields (`Station` alone has eight). They are edited today as plain multi-line `TextFormField`s stacked in one scrolling form. Two problems follow. A single long field is cramped in a small box inside a taller form, and there is no good way to insert a value that repeats across the plan except to retype it.

Variables solve the repetition. A radio channel or operation name is declared once and referenced everywhere; change it in one place and every brief updates. But a variable is only useful if the author can insert it without memorising `{{var.…}}` syntax and can see immediately when a reference is wrong. That wants a richer editing surface than a bare text box, and a richer surface wants room. The two changes are therefore one design: give each long field its own screen, and make that screen token-aware.

This revisits the editor-library question DESIGN-004 parked. That doc rejected a full document editor (`appflowy_editor`, `super_editor`) and shipped plain text fields. We are **not** reopening that. The token-aware field here is a targeted enhancement of `TextField` — colored spans and an insertion menu — not a block/WYSIWYG editor. Markdown stays the storage format and the plain-text direction stands for everything except token rendering.

## Goals

1. Let an author declare a variable once and reference it from any markdown field, with the effective value visible at the point of insertion.
2. Make insertion discoverable: a `/` command and a `{{` autocomplete, never hand-typed syntax as the only path.
3. Show reference problems immediately and stop a broken plan from being saved.
4. Give each long markdown field the full screen, using one navigation pattern shared by every entity editor.
5. Keep the compact and wide layouts the same model, folding into [ADR-0030](../adrs/0030-wide-screen-master-detail-layout.md) on wide.

## Non-goals

* **No local-only variables in v1.** Every variable is plan-global (ADR-0046, option A). Adding one from within an exercise still creates a global variable.
* **No document/WYSIWYG editor.** The field is a token-aware `TextField`, not a block editor.
* **No live brief preview in the form.** The brief opens in its own route, as in DESIGN-004.
* **No typed variables.** Values are strings in v1. No number, date, or enum types.
* **No template/variable sharing across plans.** Variables belong to one plan.

## Concepts

### Sections and the default section

An entity form is a list of **sections** reached through a switcher. The **default section** carries the entity's short structural fields and is named after the entity: **Plan** for `Program`, **Øvelse** for `Exercise`, **Post** for `Station`, **Rolle** for `RolePlay`. Short fields (name, description, tags, number format, language) never leave the default section. Each optional markdown field, once added, becomes its own section that fills the screen when selected.

### Variable declaration versus override

A variable's identity is declared once, at plan level: name, default value, optional hint. `Exercise` and `Station` can **override the value** for their subtree but cannot declare new names (ADR-0046). Declaration can be *initiated* from any editor for convenience — the "+ Ny variabel" action and the slash-menu "Opprett variabel" both create a plan-global variable, wherever they are triggered. The value typed at creation becomes the global default; local differences are set afterward in an override table.

### Derived tokens versus variable tokens

The slash menu inserts two kinds of token. **Variable tokens** (`{{var.name}}`) come from the registry and carry an author-set value. **Plan-field tokens** are the derived context DESIGN-004 already exposes (`{{exercise.name}}`, `{{station.position.utm}}`, station count, date). Both are inserted the same way and both render as chips; only variable tokens participate in the registry and its validation.

## Anatomy

```
compact (dropdown)                     expanded (master/detail, ADR-0030)
┌───────────────────────────┐         ┌──────────────┬───────────────────────┐
│ ✕   Plan ▾           Lagre │         │ Plan         │ Kommunikasjon      ⋮   │
├───────────────────────────┤         │ Variabler  3 │                       │
│ (selected section fills    │         │ ───────────  │ Samband på {frekvens} │
│  the screen)               │         │ Introduksjon │ … token-aware field … │
│                            │         │ Kommunikasjon│                       │
│                            │         │ + Legg til   │                       │
└───────────────────────────┘         └──────────────┴───────────────────────┘
```

On compact the switcher is the AppBar title, a dropdown that opens the section list. On expanded the list is a persistent left rail and the section renders in the detail pane; because forms are already modal dialogs on wide (ADR-0030), the dialog hosts the rail and detail internally rather than pushing a route.

## Component specs

### SectionSwitcher

Lists active sections in order: the default section, then Variabler, then each added markdown section, then a trailing "Legg til seksjon" that reveals the unused optional fields. On compact it is a dropdown anchored to the AppBar title with a chevron; the current section is checked. On expanded it is the master rail. This generalises `OptionalFieldSections` (DESIGN-006) from "reveal inline" to "register as a navigable section". Removing an added section is an action in the section's own overflow menu (`⋮` in the AppBar on compact, in the detail-pane header on wide), never a per-row pencil, per the row-affordance rule.

### VariablesSection

Two shapes of the same section, chosen by scope.

On `Program` it is the **declaration** surface: rows of `name` / `value`, each with a `⋮` menu for rename and delete, and a "+ Ny variabel" action. Rename runs the plan-wide reference rewrite; delete is blocked while referenced (ADR-0046). A single amber note sits at the top: *"Publiseres med planen. Ikke legg inn reelle persondata."*

On `Exercise` and `Station` it is the **override** surface: one row per declared variable showing the inherited value dimmed, with an optional local value field. Leaving the local value empty inherits. It also carries "+ Ny variabel", which creates a plan-global variable (not a local one) and drops focus into its default value.

### TokenAwareField

A multi-line markdown field that renders known tokens as inline chips while keeping the underlying text as raw `{{var.name}}` (so the brief renderer sees plain mustache and never normalises the braces away — the DESIGN-004 constraint). Implemented as a custom `TextEditingController` overriding `buildTextSpan` to emit a `WidgetSpan` chip per token. Chip states:

| State | Meaning | Style |
|-------|---------|-------|
| known | declared variable or valid plan field | blue chip, value previewed in the picker |
| empty | declared variable resolving to empty everywhere | amber chip |
| unknown | `{{var.x}}` with `x` not declared | red dashed chip, blocks save |

Caret behaviour around `WidgetSpan`s is the one real risk and is called out as a prototype gate below.

### SlashMenu

Typing `/` opens a command menu anchored at the caret; typing `{{` opens the same picker directly. The picker is a **single flat list**, not split into groups. Variable entries show their effective value in the current scope with an "arvet"/"overstyrt" tag; derived plan-field entries (`{{exercise.name}}`, station count, date) instead carry a subtle muted "planfelt" hint in place of a value, so the two kinds stay distinguishable without a group header. If the typed filter matches no variable, the menu offers **Opprett variabel «x»**, which creates a plan-global variable inline and inserts it. Selecting an entry inserts the token as a chip.

## Behavior

Insertion goes through the slash menu or `{{` autocomplete; raw typing still works for power users. On save, the form validates every field against the registry and refuses to save while any red (unknown) token exists; amber (empty) tokens warn but do not block. In an exercise or station field the picker previews the *effective* value for that scope, so the author sees what will actually render. Renaming a variable rewrites references across the whole plan behind a confirmation; deleting a referenced variable is blocked with the usages listed. Imported archives may contain tokens authored elsewhere: those cannot be caught at save time, so the brief renderer shows an unknown `{{var.x}}` as a visible placeholder rather than dropping it silently (ADR-0046).

### Sections per editor

| Editor | Default section | Variabler section | Markdown sections |
|--------|-----------------|-------------------|-------------------|
| `ProgramFormScreen` | Plan (name, description, tags, formats, language) | declaration | `briefIntroMd`, `commsMd`, `beforeRoundMd` |
| `ExerciseFormScreen` | Øvelse | override + create | `methodMd`, `learningGoalsMd`, `trainingFocusMd`, `orderFormatMd`, `executionTipsMd`, `commsMd` |
| `StationFormScreen` | Post | override + create | `equipmentMd`, `situationMd`, `missionMd`, `logisticsMd`, `criticalQuestionsMd`, `leaderAnswersMd`, `directorNotesMd` |
| `RolePlayFormScreen` | Rolle | none in v1 (references and create via slash menu only) | `behavior`, `background`, `propsMd` |

`RolePlay` can reference and create variables from its fields but gets no override table in v1; a roleplay reads through its station's overrides at render time.

## Formfaktor

Compact and expanded are one model. On compact (window class < 600) the switcher is the AppBar dropdown and one section fills the screen. On medium and expanded the form is a modal dialog (ADR-0030) whose body is a master rail plus detail pane; selecting a section in the rail swaps the detail pane in place. The slash menu and token chips are identical in both. The Map tab exception in ADR-0030 does not apply here since these are forms, not the map surface.

## Deferred decisions

1. **Local-only variables.** ADR-0046 option B. Revisit if the plan-level list grows noisy with single-use variables.
2. **Typed variables.** Number, date and enum values with formatting. Strings only in v1.
3. **Live preview.** A split preview of the rendered field. The brief route is the v1 escape hatch.
4. **Variable groups or namespaces.** A flat list per plan in v1.
5. **Cross-plan variable libraries.** Out of scope until Teams accounts (ADR-0024/0025).

## Open questions

1. **Caret and selection around chips.** Validate that `WidgetSpan` chips in a `TextEditingController.buildTextSpan` behave correctly for cursor movement, selection, and backspace-deletes-whole-token on both iOS and Android before committing to the approach. Fallback is styling the `{{…}}` text (colored, boxed) without a true inline widget.
2. **Override table density on `Station`.** With many declared variables the override section could get long. Confirm whether it should list only overridden-or-used variables by default, with a "vis alle" expansion.
3. **Autocomplete trigger conflicts.** `/` and `{{` inside otherwise-literal markdown (a code block, a URL path). Decide whether a preceding word-boundary or an explicit toolbar button is needed to avoid false triggers.
4. **Plan-context cross-references to a specific descendant.** Cross-reference resolution (`{{station.name}}`, `{{exercise.name}}`) currently only walks *up* the ownership chain — a field sees its own entity plus every ancestor (station → exercise → program), never a sibling or an arbitrary other instance. There is a real, named want for `Program`-scope fields (`briefIntroMd`, `commsMd`, `beforeRoundMd`) to look *down* into a specific exercise or station — e.g. "meet at post 2's location" from the plan intro — without opening sibling-to-sibling access (Post 1 must never be able to reach Post 2's data directly; only the root looks down). Mechanically this means the lookup would be exposed solely in the `refContext` built for `Program`'s own fields, never cascaded into `Exercise`/`Station`/`RolePlay` `refContext`s — the same asymmetry that already keeps the "root sees everything, siblings see nothing" property.

   The blocking question is addressing: how does a plan-context reference name *which* exercise or station it wants? `Station` has no `uuid` (only an `index` scoped to its parent `Exercise`, which does have one), and `stationCode` (e.g. "1.1") looks stable but isn't — it's derived from exercise order, station index and `Program.stationNumberFormat`, so it silently points at the wrong thing after a reorder or a numbering-format change. Candidates, roughly in order of robustness vs. cost:
   1. **Positional addressing** (`{{plan.exercises.0.stations.2.position.utm}}` or similar) — no model change, but a reference silently goes stale on reorder, with no error to catch it.
   2. **Name-based lookup** (by `Exercise.name`/`Station.name`) — names are free text, not unique, and a rename breaks every reference with no rewrite support (unlike a `var` rename, which DESIGN-008 already commits to rewriting plan-wide).
   3. **Give `Station` a stable `uuid`** (matching `Exercise`'s existing convention) and address by that — most robust, but a model/schema change, not just a renderer change.

   Not blocking Stages 1–5 as scoped; revisit once there is real authoring pressure for it.

## Implementation notes

Each stage is a separate PR.

**Stage 1 — Model.** Add `DrillVariable` and `Program.variables`; add `variableOverrides` to `Exercise` and `Station` (ADR-0046). `make build`. Extend `ProgramX.computeContentHash`. No schema-max change.

**Stage 2 — Resolution.** Extend `BriefRenderer` to route `var.*` through a scope-chain resolver (station → exercise → program). Render unknown variable tokens as a visible placeholder. Unit-test the chain against a fixture with overrides at each level.

**Stage 3 — Section-navigated editor.** Evolve `OptionalFieldSections` into the `SectionSwitcher` model. Rebuild `ProgramFormScreen` on it first (its base section is the smallest), then `Exercise`, `Station`, `RolePlay`. Compact dropdown and wide rail share one section list. No variables yet.

**Stage 4 — TokenAwareField + SlashMenu.** Behind the prototype gate (open question 1). Custom controller with chip spans, the `/` and `{{` menus, inline create. Reuse the chip look from `brief_markdown.dart`'s code chip.

**Stage 5 — VariablesSection.** Declaration surface on `Program`, override surface on `Exercise`/`Station`, "+ Ny variabel" everywhere, rename-rewrite and blocked-delete, save-time validation of red tokens.

All user-facing strings go in `app_en.arb` and `app_nb.arb`; run `make i18n`.

## References

* [ADR-0046](../adrs/0046-plan-variables.md) — variable data model, `var.` namespace, resolution, validation, format decision.
* [DESIGN-004](./brief-template.md) — brief renderer, inline mustache cross-references, `commsMd` override precedent, the retired document-editor decision this design respects.
* [DESIGN-006](./006-program-tab-consolidation.md) — `OptionalFieldSections`, which the section switcher generalises.
* [ADR-0030](../adrs/0030-wide-screen-master-detail-layout.md) — master/detail and forms-as-modal-dialog on wide.
* [ADR-0022](../adrs/0022-markdown-content-as-files.md) — why markdown is stored as files but variables are not.
