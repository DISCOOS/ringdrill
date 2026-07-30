---
status: accepted
date: 2026-07-28
deciders: ["kengu"]
consulted: []
informed: []
---

# ADR-0058: Introduce a source format compiled to `.drill` by a Flutter-free CLI

## Context and problem statement

RingDrill has every piece an AI plan generator needs except a target a model can aim at. The model is complete (DESIGN-008 variables, DESIGN-009 scenario locations/persons, plans/exercises/stations/roleplays), the `.drill` serializer is deterministic with a content hash, and the catalog has a feed the CLI can already list and download. What is missing is a representation an LLM can emit and a tool can check without running the app.

`.drill` is the wrong thing for a model to write. It is a ZIP of uuid-keyed JSON plus markdown files, carrying derived arrays (`schedule`), index bookkeeping, generated uuids and a content hash. A model produces one coherent document reliably; it should never hand-author derived, structural fields. We need a seam: the agent emits intent, a deterministic tool fills in everything mechanical.

DESIGN-014 specifies that surface. This ADR records the architectural decision behind it: that authoring happens in a **source format** distinct from `.drill`, and that a deterministic **compiler** — pure Dart in `lib/`, driven by the Flutter-free CLI — is the single tool that moves between them.

## Decision drivers

* An LLM emits one structured document far more reliably than a ZIP of many files; the authoring surface must be that document.
* Derivation (`schedule`, indices, uuids, numbering labels, `contentHash`, rotation math) is mechanical and must stay out of the model's hands.
* One source of truth for the format — avoid a third reimplementation beyond Dart `DrillFile` and the JS the Netlify publish path already has.
* The compiler must run headless, so it stays free of `package:flutter/*` (ADR-0005) and the app can reuse it.
* The round-trip must be verifiable: `build(decompile(d))` preserves `contentHash`.
* Additive only — no `.drill` schema bump.

## Considered options

* **Option A — A source format plus a deterministic compiler in `lib/`, driven by the CLI.** One YAML document mirroring the frozen `.drill` wire keys; commands `build` (source → `.drill`), `decompile` (`.drill` → source), `analyze` (structural + reference checks), `schema` (JSON Schema), and `render` (once a small resolver decoupling lands). The compiler is pure Dart reusing the model and `DrillFile`; the MCP server wraps the CLI; a skill carries the schema and gold examples.
* **Option B — Let the agent emit `.drill` directly.** No new format; the model writes the archive's JSON + markdown and computes the derived fields itself.
* **Option C — A rich DSL with generative constructs** (loops, conditionals, expressions) that expands into many plans.

## Decision outcome

Chosen option: **Option A**, because it gives the model one coherent document to author, keeps all derivation deterministic and testable in one Flutter-free place the app also uses, and reuses the existing model, `DrillFile` and catalog rather than adding a parallel implementation.

Three decisions follow from it and are load-bearing:

* **Mirror the frozen `.drill` wire keys, not the Dart class names.** The `Program → Plan` rename changed Dart identifiers but not the archive's JSON keys or its `program.json` root, so binding the source format to the wire keys insulates it from such renames.
* **The source format carries its own version, decoupled from the `.drill` schema, and the compiler owns a legacy-wire-key tolerance map.** The envelope is frozen, but content keys have changed (`signalement → description` clean break; `programId → planId` with a fallback, ADR-0055), so `decompile` of the older catalog corpus must tolerate historical variants. *Amended by [ADR-0059](./0059-drill-schema-migration-ladder.md): the tolerance map is replaced by an ordered migration ladder shared with `DrillFile.plan()`, since `decompile` is a second reader of the same variance and a per-command map would duplicate or diverge from the existing back-compat branches.*
* **`render` is enabled by finishing ADR-0048, not by a new decision.** `build`, `decompile` and `analyze` are Flutter-free today; `render` needs `field_resolver`/`brief_renderer` decoupled from `AppLocalizations` via a plain-Dart `BriefLabels` interface whose headless implementation reads the ARB JSON directly. That is an amendment to ADR-0048.

### Consequences

* Good: the model authors one document; the compiler owns all mechanical derivation, so generated plans cannot get schedules, indices or hashes wrong.
* Good: one compiler in `lib/`, reused by the app and wrapped by the CLI and MCP; no drift from a second format implementation.
* Good: `decompile` turns the live catalog into a reading and few-shot corpus in the same format the agent writes.
* Good: additive — no `.drill` schema bump; the `program.json` envelope stays frozen.
* Bad: a new authored surface with its own version, JSON Schema and legacy-key tolerance to maintain alongside the model.
* Bad: full-fidelity `analyze` needs a small Flutter-free facet list extracted from the views layer (`PlanFieldTokens`), and `render` needs the ADR-0048 amendment before it can run headless.

## Pros and cons of the options

### Option A
* Good: one document to author; deterministic derivation; one Flutter-free compiler shared by app, CLI and MCP; catalog becomes corpus via `decompile`.
* Bad: a new format surface to version and validate; some residual extraction for full-fidelity `analyze` and for `render`.

### Option B
* Good: no new format.
* Bad: LLMs author a ZIP of uuid-keyed JSON and derived arrays badly; the model would compute `schedule`/indices/`contentHash` itself and get them wrong; couples generation to the wire format so every schema change breaks prompts.

### Option C
* Good: parametric generation lives in the format.
* Bad: the LLM is already the generative engine, so a DSL duplicates it and adds a language to maintain; scope creep for no gain in the agentic setting.

## Links

* Related design: [DESIGN-014](../design/014-source-format-and-plan-compiler.md), [source-format worked example](../design/source-format-worked-example.md)
* Related ADRs: [ADR-0005](./0005-cli-must-remain-flutter-free.md), [ADR-0007](./0007-drill-file-format.md), [ADR-0022](./0022-markdown-content-as-files.md), [ADR-0046](./0046-plan-variables.md), [ADR-0047](./0047-scenario-locations-and-persons.md), [ADR-0048](./0048-flutter-free-field-resolver.md) (amended by the `render` enabler), [ADR-0055](./0055-programid-planid-wire-back-compat.md), [ADR-0059](./0059-drill-schema-migration-ladder.md) (amends the legacy-tolerance decision above)
* Related code: `bin/ringdrill.dart`, `lib/data/drill_file.dart`, `lib/models/plan.dart`, `lib/utils/plan_variable_refs.dart`, `lib/utils/station_scenario_tokens.dart`, `lib/services/brief/field_resolver.dart`
