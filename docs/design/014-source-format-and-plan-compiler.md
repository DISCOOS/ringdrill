---
id: DESIGN-014
title: Source format and the plan compiler
status: Accepted
started: 2026-07-28
accepted: 2026-07-28
owners: ["kengu"]
related_code:
  - bin/ringdrill.dart
  - lib/data/drill_file.dart
  - lib/models/plan.dart
  - lib/utils/plan_variables.dart
  - lib/utils/plan_variable_refs.dart
  - lib/utils/station_scenario_tokens.dart
  - lib/services/brief/field_resolver.dart
  - lib/services/brief/brief_renderer.dart
  - netlify/functions/market-feed.js
related_designs:
  - 008-plan-variables-and-section-navigated-editor.md
  - 009-scenario-locations-and-persons.md
  - 010-inline-preview-and-resolve-scope.md
  - brief-template.md
  - source-format-worked-example.md
related_adrs:
  - 0007-drill-file-format.md
  - 0022-markdown-content-as-files.md
  - 0040-catalog-feed-schema-extension.md
  - 0045-drill-library-bundle-format.md
  - 0046-plan-variables.md
  - 0047-scenario-locations-and-persons.md
  - 0048-flutter-free-field-resolver.md
  - 0055-programid-planid-wire-back-compat.md
---

# Source format and the plan compiler

> This document is in English. Field, model and helper names are English
> throughout. It concerns a tooling/format surface, not a screen, so it pairs
> with companion **ADR-0058** (accepted), which records the format and compiler
> as an architectural decision. The concrete, worked example lives in
> [`source-format-worked-example.md`](./source-format-worked-example.md).

## TL;DR

A **source format** (NO: *kildeformat*) — one human- and agent-writable YAML
document — is the thing an author or an LLM writes; a deterministic **compiler**
turns it into a `.drill` (the build artifact) and fills in everything that can be
derived. `decompile` goes the other way. The compiler lives as pure Dart in
`lib/`, reusing the existing model and `DrillFile`, and is driven by new
Flutter-free CLI commands: `build`, `decompile`, `analyze`, `schema` — and
`render`, which is one small resolver decoupling away (§ Enabling render), not a
distant follow-on. This is the foundation for AI-assisted generation of whole plans —
from scratch and from templates — deployed first as an MCP server plus a skill,
with the open catalog as the generation corpus.

The point of the split: an LLM produces one coherent document well; it should
never hand-author derived, structural bookkeeping (`schedule`, indices, uuids,
`contentHash`, numbering labels, rotation math). The source format carries intent
only; the compiler owns everything mechanical.

## Rationale

RingDrill already has every piece a generator needs except the seam an LLM can
aim at: a complete model (DESIGN-008 variables, DESIGN-009 scenario
locations/persons, plans/exercises/stations/roleplays), a deterministic
`.drill` serializer with a content hash, a published catalog with a feed
([ADR-0040](../adrs/0040-catalog-feed-schema-extension.md)), and a CLI that can
already list and download from it. What is missing is a representation a model
can emit and a compiler can validate without running the app.

`.drill` itself is the wrong target for an LLM: it is a ZIP of uuid-keyed JSON
plus markdown files, with derived arrays (`schedule`) and index bookkeeping. A
model emits a single structured document far more reliably. So the seam is:

> agent emits **source document** (intent) → deterministic **compiler** fills
> derived/structural fields → `.drill`

Because the derived fields are pure functions of the authored ones, `decompile`
is near-lossless (the round-trip is guaranteed by `contentHash`), which makes the
source format usable in both directions: decompile catalog plans into it for
reading and few-shot examples, compile it into `.drill` for writing. Source and
`.drill` are two representations of the same data — closer to
serialization/bundling than to true compilation.

## The source format

The full worked example (exercise #2 of the real published plan
`lsor-eidene-2026`) is in
[`source-format-worked-example.md`](./source-format-worked-example.md). The
shape in brief:

* **One YAML file, markdown inline in block scalars** (`|`). A single string is a
  clean contract for an LLM and for the MCP tools. The directory form already
  exists — it is the unzipped `.drill`. Block-scalar content is literal, so
  markdown needs no escaping. RingDrill has *many* markdown bodies per plan, which
  is exactly the case a front-matter-plus-markdown container handles poorly and
  block scalars handle well.
* **Names mirror the frozen `.drill` wire keys**, not the Dart class names — so
  the landed `Program → Plan` rename does not touch the source format. Only value
  *shapes* are source-friendly (times as `"HH:MM"`, coordinates as `{lat, lng}`
  which the builder flips to the stored `[lng, lat]`).
* **Authored fields only, never derived ones.** The authored/derived split is the
  contract; it is enumerated in the worked example's table.
* Layers, all authored: plan (name, description, tags, language, number formats);
  DESIGN-008 `variables` (declared on the plan) with `variableOverrides` on
  exercise and station; DESIGN-009 station-owned `locations` and `persons`
  referenced by slug in prose (`{{station.loc.<slug>.utm}}`,
  `{{station.person.<slug>}}`); roleplays nested under their station, portraying a
  person via `personRef`, identity inherited-by-omission or overridden.

## The compiler and the CLI

The compiler is **pure Dart in `lib/`** (alongside `DrillFile` in `lib/data/`),
so the app can reuse it, and it is driven by new commands on the existing
Flutter-free, `--json`-friendly CLI (`bin/ringdrill.dart`, which already has
`feed` and `download`). All commands stay free of `package:flutter/*`
(AGENTS.md rule 7).

* **`build <source>` → `.drill`.** Parse the YAML, construct the model, fill
  derived fields (`schedule`, `endTime`, indices, uuids, numbering, `contentHash`),
  serialize via `DrillFile.fromProgram`. This is provably Flutter-free today:
  `tools/generate_example_drills.dart` already builds a `.drill` from model
  objects under `dart run`. Tokens are stored raw and resolved only at render, so
  `build` never touches the resolver.
* **`decompile <.drill>` → source.** The inverse: read via `DrillFile`, strip the
  derived fields, emit the source document. It must tolerate **legacy wire-key
  variants** in the older catalog corpus (see Open questions).
* **`analyze <source>` → errors/warnings.** Structural checks plus
  reference integrity (red = unresolved reference blocks; amber = declared-but-empty
  warns), reusing the already-Flutter-free `lib/utils/plan_variable_refs.dart` and
  `lib/utils/station_scenario_tokens.dart`. One small residual: the facet registry
  (`PlanFieldTokens`) lives in the views layer; a small Flutter-free facet list
  should be extracted for full-fidelity validation.
* **`schema` → JSON Schema** of the source format, so the schema doubles as the
  validator contract and as the tool schema a generating agent calls against.
* **`render <source|.drill>`.** Headless brief rendering needs
  `field_resolver.dart` and `brief_renderer.dart`, which today import
  `AppLocalizations` (and so transitively Flutter). That is one small,
  well-scoped decoupling away — not a distant follow-on. See "Enabling render"
  below.

A **golden test** anchors the round-trip early: `build(decompile(d))` must
produce a plan with the same `contentHash` as `d`.

### Enabling render (a small prerequisite)

`render` is blocked only by a narrow dependency: four files import
`AppLocalizations` — `field_resolver.dart`, `brief_renderer.dart`,
`utils/variable_values.dart`, `utils/plan_variables.dart`. The resolver already
takes `l10n` as an explicit parameter (not via `BuildContext`), so no call-graph
surgery is needed — only the *type* leaks Flutter. The brief layer uses just nine
distinct l10n members. The fix is a small dependency inversion: a plain-Dart
`BriefLabels` interface those files depend on, with an app-side adapter over
`AppLocalizations` (behaviour-preserving) and a headless implementation that
**reads the ARB JSON directly** (`app_en.arb`/`app_nb.arb` are JSON), formatting
ICU messages with the already-Flutter-free `package:intl`. Two nuances: `localeName`
comes from the ARB `@@locale` (or the plan's `languageCode`), and a few messages
are ICU plurals, not plain `{name}` substitution. This is an **amendment to
[ADR-0048](../adrs/0048-flutter-free-field-resolver.md)** — finishing its stated
"resolver stays free of `package:flutter`" — not a new ADR. Once done, both
`render` and full-fidelity `analyze` are Flutter-free, and one resolver serves
app, CLI and any future server-side rendering.

## Deployment: MCP server plus a skill

The first deployment is an **MCP server** wrapping the CLI plus a **skill**
carrying the domain knowledge, so the three layers separate cleanly: the skill
holds the authored schema, the vocabulary and gold examples; the MCP tools are
the deterministic primitives; the agent (e.g. Claude) reads the corpus, emits the
source document, and calls analyze/build.

Minimal v1 tool surface: `search_catalog` (over the existing feed —
tags/place/lang are already there, no vector store needed day one), `get_plan`
(returns the *source document*, i.e. decompiled, not raw `.drill`),
`analyze_plan`, `build_plan`, and `schema`. **`publish` is held human-gated in
v1** — the catalog is a wiki model, and an agent should not write to the shared
corpus unattended.

The catalog is the generation corpus. Cold-start caveat: it is only as rich as
what is published, so a small **curated gold-example library** in the skill
matters most early, with the live catalog taking over as it grows.

**Provenance.** Record which plans a generation drew on and that it was machine
made, as additive fields (`derivedFrom: [slug]`, `generatedBy`), so hand vs.
generated is traceable and lineage is kept — no schema bump.

## Settled decisions

The nine format decisions are stated with their rationale in the worked example
(§3, "Decided"): single YAML file with inline markdown; mirror the frozen wire
keys; `{lat, lng}` coordinates; references by array position with roleplays
nested under the station; numbering out of names; structured markdown fields;
UTM via a location token; effective identity by inheritance; staff/PII stripped
on decompile. Beyond those:

1. **`build` + `decompile` + `analyze` + `schema` are the immediate
   deliverables** — they need no change to existing app code. **`render` is one
   small prerequisite away** (the ADR-0048 amendment below: a headless ARB-JSON
   label provider), behaviour-preserving, and belongs in the same v1 effort —
   ordered after the zero-refactor commands, not deferred.
2. **The compiler is pure Dart in `lib/`, wrapped by the CLI; the MCP server
   wraps the CLI.** One source of truth for the format — avoid a third
   reimplementation beyond Dart `drill_file.dart` and the JS the Netlify publish
   path already has.
3. **The source format carries its own version**, decoupled from the `.drill`
   schema, and the compiler owns a legacy-wire-key tolerance map (below).

## Open questions

1. **Legacy wire keys on decompile.** The `.drill` *envelope* is frozen
   (`program.json` root, folder layout, extension), but content keys have changed:
   `signalement → description` (a clean break, no back-compat read) and
   `programId → planId` ([ADR-0055](../adrs/0055-programid-planid-wire-back-compat.md),
   with a fallback). `DrillFile` back-compat-reads `actors/` and `programId` but
   not `signalement`. `decompile` of the older catalog corpus therefore needs a
   tolerance map; scope it against what the live catalog actually contains (in
   today's corpus, `signalement` is largely null, so the loss is marginal).
2. **Station-owned locations duplicate shared points.** DESIGN-009 chose
   station-owned data over a central registry (roll-up deferred). A point every
   station references — one IPP for the exercise — is declared once per station.
   Watch for authoring pain; an exercise-level shared-location surface may follow.
3. **Descendant addressing** (a plan-intro referencing "post 2's location") is
   **DESIGN-008 open question 4**, unresolved in the app. The source format must
   not get ahead of it; mirror whatever the app lands on (today: up-the-chain
   only).
4. **Which markdown fields are effectively required** for a usable brief
   (`situation`? `mission`?) — a generation/validation guideline for the skill,
   not a format rule.
5. **Companion ADR — recorded.** The source format and the Flutter-free compiler
   are recorded in [ADR-0058](../adrs/0058-source-format-and-plan-compiler.md)
   (accepted); the `render` enabler is an amendment to ADR-0048, not a new ADR.

## Implementation notes

Staged, each a separate PR; all additive, no schema bump.

1. **Source model + `build`.** Define the source document parse/emit against the
   current model, fill the derived fields, `DrillFile.fromProgram`. Golden test:
   `build(decompile(d))` preserves `contentHash`. Companion **ADR-0058**.
2. **`decompile` + legacy tolerance.** Emit the source document from a `.drill`,
   with the legacy-wire-key map for the catalog corpus.
3. **`analyze` + `schema`.** Structural + reference-integrity analysis on the
   Flutter-free ref utils; extract a Flutter-free facet list from `PlanFieldTokens`
   for full fidelity; emit the JSON Schema.
4. **MCP server + skill.** Wrap the CLI (`search_catalog`, `get_plan`,
   `analyze_plan`, `build_plan`, `schema`); the skill carries the schema, the
   vocabulary and the gold examples. `publish` stays human-gated.
5. **`render`.** The ADR-0048 amendment: `BriefLabels` interface, app adapter,
   headless ARB-JSON provider; then `render <source|.drill> [--audience]
   [--lang]` and full-fidelity `analyze`. Small and behaviour-preserving; fits
   in v1 after stages 1–3.

## References

* [source-format-worked-example.md](./source-format-worked-example.md) — the concrete example and the nine settled format decisions.
* [DESIGN-008](./008-plan-variables-and-section-navigated-editor.md) — variables and overrides the source format carries.
* [DESIGN-009](./009-scenario-locations-and-persons.md) — station-owned locations/persons and `personRef`.
* [DESIGN-010](./010-inline-preview-and-resolve-scope.md) / [ADR-0048](../adrs/0048-flutter-free-field-resolver.md) — the field resolver whose decoupling enables `render`.
* [ADR-0007](../adrs/0007-drill-file-format.md), [ADR-0022](../adrs/0022-markdown-content-as-files.md) — the `.drill` archive and markdown-as-files.
* [ADR-0040](../adrs/0040-catalog-feed-schema-extension.md), [ADR-0045](../adrs/0045-drill-library-bundle-format.md) — the catalog feed (corpus) and bundle format.
* [ADR-0055](../adrs/0055-programid-planid-wire-back-compat.md) — the `programId → planId` wire transition informing the legacy-key tolerance.
