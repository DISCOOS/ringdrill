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
  - 0058-source-format-and-plan-compiler.md
  - 0059-drill-schema-migration-ladder.md
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
never hand-author derived, structural bookkeeping (`schedule`, indices,
`contentHash`, numbering labels, rotation math). The source format carries intent
only; the compiler owns everything mechanical. The one carve-out is **identity**:
`uuid` is optional on input and always emitted on output, because it is not
derivable and it is inside the content hash — that is what makes the round trip an
identity rather than an approximation.

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
* **Authored fields only, never derived ones** — with one carve-out. The
  authored/derived split is the contract; it is enumerated in the worked
  example's table. The carve-out is **identity**: `uuid` on plan, exercise,
  roleplay and team is *optional on input, always emitted on output*. It is not
  derivable from anything else, and `Exercise`/`RolePlay`/`Team` uuids are inside
  `computeContentHash` (via `toJson`) *and* are its sort keys, so minting fresh
  ones would make `build(decompile(d))` produce a different hash and a different
  ordering. An author or an agent omits them and `build` mints `nanoid(8)`;
  `decompile` emits them so a rebuild lands on the same identities. `Plan.uuid`
  is outside the hash but is what the app keys an installed plan on, so
  preserving it is what makes a decompile-edit-rebuild cycle an *update* to the
  installed plan rather than a duplicate.
* **Names are opaque.** Numbering is derived from the number format and the
  item's position; an item with no explicit number gets one from its ordering.
  The format makes no assumptions about what a name contains — a legacy baked-in
  label ("#6 Førsteinnsats søk") is authored content, decompile emits it
  verbatim, and a round trip preserves it byte for byte. Nothing strips such a
  prefix and nothing warns about one; see worked example decision 5 and
  [ADR-0059](../adrs/0059-drill-schema-migration-ladder.md).
* **`teams:` is authored but optional.** `Plan.teams` carries free-text names
  (glossary, **Team**) plus optional `numberOfMembers`/`position`, and the
  worked example does not show it. When omitted, `build` derives the roster the
  way the app already does — as many teams as the largest `numberOfTeams` across
  the exercises, with generated names — and when authored it wins. A station's
  `variantSuffix` is likewise authored and unshown; `sessions` are run records,
  always `[]` in a published plan, and never authored.
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
  derived fields (`schedule`, `endTime`, indices, uuids where absent, numbering,
  `contentHash`), serialize via `DrillFile.fromPlan`. Tokens are stored raw and
  resolved only at render, so `build` never touches the resolver.

  One small extraction is needed first, and it is *extraction, not
  reimplementation*. The canonical rotation math lives in
  `PlanService.generateSchedule`, which is unreachable from the CLI because its
  signature is `TimeOfDay` (`package:flutter/material.dart`) — not because of
  l10n, so the ARB pivot below does not address it. `tools/generate_example_drills.dart`
  proves the *output* is Flutter-free, but only by hand-rolling a second copy of
  the math; a third copy in the compiler is the thing to avoid. Retype the pure
  arithmetic onto `SimpleTimeOfDay` in a Flutter-free helper and have
  `PlanService` delegate to it. `generateSchedule` also carries a `calcFromTimes`
  flag with two different schedule semantics; nothing in the repo passes `false`,
  so pin the `true` behaviour and drop the branch rather than porting a dead one.

  A second, smaller l10n consequence: `build` needs exactly two localized
  strings — `l10n.team(1)` and `l10n.station(1)`, for generated default team and
  station names — and both are ICU plurals. So a *minimal* version of the
  headless ARB label provider (§ Enabling render) is wanted in stage 1, with two
  keys, and stage 5 extends the same class to the nine brief keys. Cheaper than
  hardcoding an `nb`/`en` pair in stage 1 and replacing it in stage 5.
* **`decompile <.drill>` → source.** The inverse: read via `DrillFile`, strip the
  derived fields, emit the source document. Historical variance in the corpus is
  normalized by the migration ladder in
  [ADR-0059](../adrs/0059-drill-schema-migration-ladder.md), shared with
  `DrillFile.plan()`, under one invariant: a rung may fill an absent field or
  rename a key, never rewrite an authored value. Most of the variance needs no
  code at all — `@Default` on the additive model fields already absorbs it (see
  Open questions 1).
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

`render` is blocked only by a narrow dependency, though the file list is not the
one stated when this was drafted. `utils/variable_values.dart` and
`utils/plan_variables.dart` are **already** Flutter-free (they only name
`AppLocalizations` in comments). The actual closure is five files:
`field_resolver.dart` and `brief_renderer.dart` (both import
`app_localizations.dart`), `utils/exercise_share_format.dart` (five uses), and
`template_registry.dart` → `utils/locale_utils.dart`, which imports
`package:flutter/widgets.dart` for `Locale`. Plus one dependency not previously
noted: `brief_renderer.dart` loads its mustache templates through
`rootBundle`/`AssetBundle`, so it needs a template-source abstraction alongside
the label one.

The resolver already takes `l10n` as an explicit parameter (not via
`BuildContext`), so no call-graph surgery is needed — only the *type* leaks
Flutter. The brief layer uses just nine distinct l10n members (verified). The fix
is a small dependency inversion: a plain-Dart `BriefLabels` interface those files
depend on, with an app-side adapter over `AppLocalizations`
(behaviour-preserving) and a headless implementation that **reads the ARB JSON
directly** (`app_en.arb`/`app_nb.arb` are JSON), formatting ICU messages with the
already-Flutter-free `package:intl`. Two nuances: several messages are ICU
plurals rather than plain `{name}` substitution, and `localeName` must come from
the plan's `languageCode` or the ARB filename — **neither ARB file has an
`@@locale` key**, so the source this originally named does not exist. This is an
**amendment to
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
nested under the station; numbering from order with names left opaque; structured
markdown fields; UTM via a location token; effective identity by inheritance;
staff/PII stripped on decompile. Beyond those:

1. **`build` + `decompile` + `analyze` + `schema` are the immediate
   deliverables**, and they need two small, behaviour-preserving extractions
   rather than none as first drafted: the rotation math off `TimeOfDay` (§ The
   compiler and the CLI, `build`), and a two-key headless ARB label provider for
   generated default names. **`render` is one further prerequisite away** (the
   ADR-0048 amendment below, extending the same label provider to nine keys plus
   a template source), behaviour-preserving, and belongs in the same v1 effort —
   ordered after the other commands, not deferred.
2. **The compiler is pure Dart in `lib/`, wrapped by the CLI; the MCP server
   wraps the CLI.** One source of truth for the format — avoid a third
   reimplementation beyond Dart `drill_file.dart` and the JS the Netlify publish
   path already has.
3. **The source format carries its own version**, decoupled from the `.drill`
   schema. Historical variance in the corpus is normalized by a shared migration
   ladder ([ADR-0059](../adrs/0059-drill-schema-migration-ladder.md)) rather than
   a per-reader tolerance map, under one invariant — a rung may fill an absent
   field or rename a key, never rewrite an authored value — which is what keeps
   normalization compatible with the `contentHash` round trip. **No `.drill`
   schema bump and no support floor**: measured against the live catalog, the
   version string does not identify the content shape (open question 1).

## Open questions

1. **Legacy wire keys on decompile — settled, and smaller than feared.** Scoped
   against what the live catalog actually contains: it holds **three plans, all
   schema `1.2`**, and they still differ in shape (two carry `actors`, one
   `staff`; one has `variables`, two do not; one has no `languageCode`). That is
   the additive-without-a-bump policy working as intended, and it is why a
   version *floor* was considered and rejected — the version string does not
   identify the content shape, so a floor would reject archives it can read while
   admitting shapes it cannot fully interpret, at the cost of a rule-8 coordinated
   bump this design does not otherwise need. What absorbs the variance is
   `@Default` on the additive model fields: `Plan.fromJson` reads all three today,
   and since `decompile` reads a `Plan` rather than raw JSON, almost no tolerance
   code is required. The residue is value-level, not key-level, and is handled by
   the migration ladder in
   [ADR-0059](../adrs/0059-drill-schema-migration-ladder.md): `signalement →
   description` (a key rename — the one genuine silent-data-loss path today, since
   `DrillFile` does not read the old key at all), prose in `description` that
   belongs in `situation`, and an absent `exercise.index` in schema 1.0 archives,
   where index comes from arrival order exactly as `PlanService` already assigns
   it on import. Baked-in numbering labels in names are *not* in scope — see
   "Names are opaque" above. `test/fixtures/test-7x.drill` is a stale schema-1.0
   archive and is worth keeping precisely for that: it is the repo's only pre-1.2
   artifact and the natural bottom-rung test. Add the real `lsor-eidene-2026`
   archive as a current 1.2 fixture for the round-trip golden.
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
5. **Companion ADRs.** The source format and the Flutter-free compiler are
   recorded in [ADR-0058](../adrs/0058-source-format-and-plan-compiler.md)
   (accepted). Legacy normalization is
   [ADR-0059](../adrs/0059-drill-schema-migration-ladder.md) (proposed), which
   supersedes ADR-0058's "the compiler owns a legacy-wire-key tolerance map" with
   a ladder shared by both readers. The `render` enabler remains an amendment to
   ADR-0048, not a new ADR.

## Implementation notes

Staged, each a separate PR; all additive, no schema bump. **All five stages have
landed** (branch `design-014`), plus a `create` scaffold that was not in the
original plan — see the branch's commits for what each stage actually did and
where it deviated.

1. **Source model + `build`.** Define the source document parse/emit against the
   current model, fill the derived fields, `DrillFile.fromPlan`. Rather than a
   second typed model of the document (a third representation after `Plan` and the
   wire JSON, and a guaranteed source of drift between the four commands), drive
   all four from **one declarative field table** — per field: source key, wire key,
   value-shape converter (`"HH:MM"` ↔ `{hour,minute}`, `{lat,lng}` ↔ `[lng,lat]`),
   authored/derived/identity, and scope. Parse normalizes YAML to a wire map,
   injects the derived fields, and hands it to the existing `Plan.fromJson` /
   `Exercise.fromJson`, patching markdown in via `copyWith` the way
   `DrillFile.plan()` already does; `decompile` reads the same table backwards; and
   `schema` cannot then describe something `build` will not accept. Includes the
   schedule extraction and the two-key ARB label provider above. Golden test:
   `build(decompile(d))` preserves `contentHash` (lands with stage 2; a
   build-only golden here). Companion **ADR-0058**. Add a CI guard for AGENTS.md
   rule 7 while here (`dart compile exe bin/ringdrill.dart`): the CLI's import
   closure is `drill_client` + `drill_file` today, this design grows it
   substantially, and there is currently no check that fails on a stray Flutter
   import.
2. **`decompile` + the migration ladder.** Emit the source document from a
   `.drill`; introduce the ADR-0059 ladder and move the existing scattered
   back-compat branches onto it. Deterministic output is a requirement of the
   golden test, so decompile tie-breaks ordering on archive entry name where
   arrival order is arbitrary.
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
