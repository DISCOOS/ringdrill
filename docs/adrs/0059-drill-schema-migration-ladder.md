---
status: accepted
date: 2026-07-30
deciders: ["kengu"]
consulted: []
informed: []
---

# ADR-0059: Normalize legacy `.drill` archives through an ordered migration ladder

## Context and problem statement

Reading an older `.drill` archive is handled today by back-compat branches scattered through `lib/data/drill_file.dart`: the `staff/` folder is also accepted as `actors/`, a role play's `behavior`/`background` fall back to legacy inline JSON values when no `.md` companion exists, `metadata.json` may be absent entirely (schema 1.0), and `programId` is accepted where `planId` is expected ([ADR-0055](./0055-programid-planid-wire-back-compat.md)). Each branch is correct in isolation, sits at the point of use, and is invisible from anywhere else. Nothing enumerates what "old" can mean, and nothing states what a reader is allowed to do about it.

Two things make that arrangement insufficient now. First, [DESIGN-014](../design/014-source-format-and-plan-compiler.md) adds `decompile`, which turns a published archive into an authored source document — a second reader of the same historical variance, with a round-trip contract (`build(decompile(d))` preserves `contentHash`) that constrains what normalization may legitimately change. Second, the field `signalement` was renamed to `description` as a clean break, so an archive still carrying it loses that content silently on read: no branch handles it, and nothing reports the loss.

The schema version cannot be the organizing principle here, and measurement confirms it. Every plan in the live catalog is schema `1.2`, yet the three of them differ in shape: two carry `actors`, one carries `staff`; one has `variables`, two do not; one has no `languageCode`. That is by design — additive fields have deliberately landed without a schema bump ([ADR-0018](./0018-roleplayer-data-model.md), [ADR-0043](./0043-tags-in-drill-format.md), [ADR-0046](./0046-plan-variables.md), [ADR-0047](./0047-scenario-locations-and-persons.md)) — but it means the version string does not identify the content shape, so a version floor would reject archives it can read and accept archives it cannot fully interpret.

## Decision drivers

* Two readers now face the same historical variance (`DrillFile.plan()` and `decompile`); the normalization must be shared, not duplicated per call site.
* The DESIGN-014 round trip must stay an identity: whatever normalization does, `build(decompile(d))` has to preserve `contentHash`.
* The set of historical variants must be enumerable and individually testable, so that raising a support floor later is a deletion rather than an archaeology exercise.
* Silent content loss (`signalement`) is the failure mode worth eliminating; silent content *change* is the failure mode worth preventing.
* The freezed models already absorb absent additive fields via `@Default`, so most variance needs no code at all — the ladder must not re-solve what the model solves.
* Peer-to-peer `.drill` files (USB, AirDrop, email) never reach the backend, so no server-side telemetry can bound which variants are still in circulation.

## Considered options

* **Option A — An ordered ladder of named, idempotent normalizers**, applied before anything is classified or parsed, each rung declaring what it detects and what it rewrites, governed by one invariant on what a rung may do.
* **Option B — Keep the per-call-site back-compat branches** and add the missing cases (`signalement`) where they are needed, once per reader.
* **Option C — Declare a supported schema floor** (e.g. `>= 1.3`, requiring a schema bump) and refuse anything below it, relying on the app's read-then-write cycle to upgrade archives in circulation.

## Decision outcome

Chosen option: **Option A**, because it puts the full set of historical variants in one enumerable, individually-testable place that both readers share, and because a single invariant on what a rung may do is what makes normalization compatible with the round-trip contract.

A **rung** is one migration step — a named, self-describing transform handling exactly one historical shape. The **ladder** is the ordered list of them. The metaphor is load-bearing rather than decorative: order matters (see below), and "raising a support floor" is then literally deleting the bottom rung and its test rather than auditing branches spread across a reader. See also `docs/glossary.md`.

The invariant is load-bearing:

> **A rung may fill a field that is absent, or rename a key. A rung may never rewrite an authored value.**

`signalement` → `description` is a key rename, so it is allowed and fixes real content loss. Stripping a baked-in numbering label out of an exercise or station name — the practice that predates automatic numbering, and which [`source-format-worked-example.md`](../design/source-format-worked-example.md) originally proposed doing on decompile — is a value rewrite, so it is refused: it would change the plan's content and therefore its `contentHash`, breaking the round trip.

**Names are opaque.** The source format makes no assumptions about what a name contains, and neither does any tool built on it: numbering is derived from order and never parsed out of a name, a name is never rewritten, and a round trip preserves it byte for byte. Not even an advisory `analyze` warning inspects one — a "this looks like a numbering label" heuristic is itself an assumption about name content, and it would misfire on `"B2 Bilcamping"`, `"Larvik 21"` or `"1. etasje"` for exactly the reason team naming has no shared scheme (see [`../glossary.md`](../glossary.md), **Team**): conventions are subject-area specific and the name is where they live.

Ordering follows from the same rule. An exercise's `index` is absent in schema 1.0 archives, so every exercise deserializes to `index: 0`; the ladder assigns index from arrival order, which is what `PlanService` already does on import (`nextIndex++`). Where arrival order is itself arbitrary — a ZIP whose entries are uuid-named — `decompile` tie-breaks on archive entry name, so the same input twice yields the same output. That is determinism, not an attempt to recover intent.

### Two kinds of rung

The variance does not all live at the same level, so the ladder has two rung
types rather than forcing one shape:

* An **archive rung** rewrites the entry index — the map of archive path to bytes
  — before classification. This is where a renamed folder belongs (`actors/` →
  `staff/`, DESIGN-011), and also where a value that *moved out of JSON into a
  companion file* belongs: before ADR-0022 a role play's `behavior`/`background`
  and a staff member's `notes` were inline manifest strings, and the model fields
  are now `includeFromJson: false`, so the content is dropped silently exactly as
  `signalement` was. Synthesizing the absent companion entry — rather than
  patching the entity afterwards — is what lets the reader drop its legacy
  branches entirely: once the ladder has run, a value is always where the current
  format says it is.
* A **manifest rung** rewrites one parsed JSON manifest (`signalement →
  description`; filling an absent `exercise.index`).

The ladder is **ordered**, and one pair depends on it: the folder rename must
precede the companion-file synthesis, which addresses `staff/` paths. Rungs are
individually idempotent but not order-independent, which is why they are run
through the ladder rather than picked out of the list.

Normalization is **silent by default and reportable on demand**. Each rung
appends a note; `DrillFile.plan()` takes an optional sink and `decompile` prints
what it collected. The app has nowhere useful to say "this archive predated a
rename", but someone decompiling a file a colleague sent them does want to know —
particularly that the document they are about to edit is not a byte-for-byte view
of the archive.

### Out of scope

The `programId → planId` fallback is **not** absorbed. It is not archive content:
it is a field on the Netlify API's JSON responses, handled in `drill_client.dart`,
with its own Sentry-tracked deprecation
([ADR-0055](./0055-programid-planid-wire-back-compat.md)). Folding it in would put
an HTTP concern behind an archive-reading abstraction and obscure the telemetry
that decides when it can be dropped.

Consequently **no schema bump and no support floor are adopted** (Option C is
rejected below on evidence). The ladder makes a floor a later, cheap decision:
raising it means deleting the bottom rung.

### Consequences

* Good: one enumerable list of what "an older archive" can mean, replacing branches that were only discoverable by reading every call site. `DrillFile.plan()` no longer knows the `actors/` folder exists, and its three legacy-inline fallbacks are gone — the ladder removed reader code rather than adding a layer beside it.
* Good: `signalement` content stops being dropped silently, and so does pre-ADR-0022 inline markdown — two real data-loss paths closed rather than documented.
* Good: normalization is reportable, so a legacy archive announces itself instead of being quietly rewritten.
* Good: the round-trip contract is protected by construction, because the invariant forbids exactly the class of change that would break it.
* Good: each rung is independently testable, and the stale schema-1.0 fixture (`test/fixtures/test-7x.drill`) becomes a genuine asset — the only pre-1.2 artifact in the repo, and the natural bottom-rung test.
* Good: raising a support floor later is a deletion with a test to delete alongside it.
* Bad: a new indirection between archive bytes and `Plan.fromJson` that a reader of `drill_file.dart` must now know about.
* Bad: the rungs must be idempotent and order-independent enough to compose; getting that wrong is a class of bug the scattered branches could not have.
* Bad: normalization on the raw wire maps means the ladder works below the type system, on `Map<String, dynamic>`, where the models offer no help.

## Pros and cons of the options

### Option A
* Good: shared by both readers; enumerable; individually testable; one invariant that keeps it hash-safe; floor becomes a deletion.
* Bad: an extra layer, untyped by nature, with composition requirements the current branches do not have.

### Option B
* Good: no new structure; each branch stays next to the code that needs it.
* Bad: `decompile` would duplicate every branch or silently diverge from `DrillFile.plan()`; nothing enumerates the variants, so `signalement`-style omissions stay invisible until someone loses data; no place to state what normalization may change, which is the property the round trip depends on.

### Option C
* Good: bounds the problem by refusing old input outright.
* Bad: measurably wrong-grained — all three live catalog plans are schema `1.2` yet differ in shape, so a floor rejects readable archives while still admitting shapes it cannot fully interpret; costs a coordinated schema bump ([AGENTS.md](../../AGENTS.md) rule 8: `drill_file.dart`, the Netlify upload handler, a migration path) that [ADR-0058](./0058-source-format-and-plan-compiler.md) explicitly says DESIGN-014 does not need; and peer-to-peer archives never touch the backend, so a floor breaks them invisibly with no telemetry that could have warned.

## Links

* Related design: [DESIGN-014](../design/014-source-format-and-plan-compiler.md), [source-format worked example](../design/source-format-worked-example.md)
* Related ADRs: [ADR-0007](./0007-drill-file-format.md) (the archive format), [ADR-0018](./0018-roleplayer-data-model.md), [ADR-0022](./0022-markdown-content-as-files.md), [ADR-0043](./0043-tags-in-drill-format.md), [ADR-0046](./0046-plan-variables.md), [ADR-0047](./0047-scenario-locations-and-persons.md) (the additive-without-bump precedents), [ADR-0055](./0055-programid-planid-wire-back-compat.md) (the `programId` fallback this ladder absorbs), [ADR-0058](./0058-source-format-and-plan-compiler.md) (the compiler that adds the second reader)
* Related code: `lib/data/drill_migrations.dart` (the ladder), `lib/data/drill_file.dart` (the reader that runs it), `lib/models/plan.dart` (`computeContentHash`), `lib/services/plan_service.dart` (import-time reindexing), `bin/ringdrill.dart` (`decompile` reports the notes)
