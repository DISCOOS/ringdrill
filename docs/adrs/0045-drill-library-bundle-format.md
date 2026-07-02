---
status: accepted
date: 2026-07-02
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0045: Drill library bundle format for multi-program export and import

## Context and problem statement

A `.drill` file (ADR-0007) carries exactly one program. The Phase 3 migration tooling (ADR-0039) already needs to move a whole library at once, so both the in-app export (`lib/data/bulk_export.dart`) and the client-side `/migrate` exporter (`site/src/lib/migrate.ts`) bundle every program into a single outer ZIP named `ringdrill-eksport-YYYY-MM-DD.zip`, with one `.drill` per program inside.

That bundle can be produced but not consumed. The import pipeline only understands a single `.drill`: `DrillFile.program()` requires a top-level `program.json`, so picking the outer ZIP fails with `missingProgram`. The file picker is also locked to the `.drill` extension, so a `.zip` cannot be selected at all. Finally, the `https://web.ringdrill.app/?import=guide` link that `/migrate` sends users to after download does nothing in the app: the `import` query parameter is not handled anywhere.

The result is a one-way street. We can export a library but not import one, which breaks the migration hand-off and blocks device-to-device library transfer as an ongoing feature. This ADR names the bundle format, defines how it is detected and parsed, and decides the import semantics and the surfaces that produce and consume it.

## Decision drivers

* The bundle already exists on the wire (in-app export and the site exporter). This ADR must describe that same format, not invent a new one.
* Import must be robust: one corrupt `.drill` inside a bundle must not sink the whole import.
* Detection must be unambiguous between a single `.drill` and a bundle, without relying on the file extension.
* The mechanism should outlive the migration. Exporting and importing a whole library is useful for backup and for moving a library to a new device.
* The migration link (`?import=guide`) and the permanent library feature should share one code path, not two.

## Considered options

* A ZIP whose entries are `.drill` files, one per program, detected by content (the format already produced today).
* A single fat `.drill` extended to hold multiple programs.
* A dedicated file extension and UTI for the bundle (e.g. `.drills`) with OS-level open/dispatch.

## Decision outcome

Chosen option: **a ZIP of `.drill` entries, one per program, detected by content**, formalised as the RingDrill *drill library* format. This is the format the export side already emits, so no producer changes are forced and existing exported bundles remain importable.

The format is a thin container. It carries no schema of its own; each inner `.drill` carries its own schema per ADR-0007. Detection is content-based, so the file extension does not matter for import:

```
<name>.zip            RingDrill drill library (outer ZIP)
  <slug>.drill        one program, itself a .drill archive (ADR-0007)
  <slug>-1.drill      slug collisions are disambiguated with a counter
  ...
```

A byte buffer is classified by sniffing, not by extension:

* Not a ZIP (no `PK` magic bytes) → invalid.
* ZIP containing a top-level `program.json` → a single `.drill` (existing path, `DrillFile`).
* ZIP containing at least one `*.drill` entry anywhere in the archive, at any nesting depth, and no top-level `program.json` → a drill library (new path).
* ZIP that is neither → invalid.

A single `.drill` and a library are therefore always distinguishable, because a `.drill` has `program.json` at its root and a library never does.

`program.json` is checked at the literal root only — that is the `.drill` format's own invariant (ADR-0007), not a container concern. The `.drill` entries that make up a library are matched at any depth on purpose: the bundle can be repacked by any tool (Finder, Explorer, a plain `zip` command) before it reaches the app, and those commonly wrap everything in an extra folder or add metadata cruft (`__MACOSX/`, `.DS_Store`). That cruft is ignored; a `.drill` entry still counts wherever it sits.

Implementation lives in a new `lib/data/drill_library.dart`, mirroring `DrillFile`:

* `DrillLibrary.fromPrograms(List<Program>)` — the encoder. `lib/data/bulk_export.dart`'s `exportAllPrograms` is moved here so encode and decode live together; `bulk_export.dart` keeps a thin re-export so `MigrationPage` and the banner do not change behaviour.
* `DrillLibrary.entries()` — yields one `DrillFile` per inner `.drill`, each parseable with the existing `DrillFile.program()`.
* `DrillArchiveKind sniff(List<int> bytes)` — the shared classifier returning `single`, `library` or `invalid`, reused by the picker flow.
* A typed `DrillLibraryFormatException` for library-level problems (not a ZIP, no `.drill` entries), sibling to `DrillFormatException`. Per-entry parse failures are not fatal; see import semantics.

### Import semantics

* A drill library imports every contained program into the local library via `ProgramService.installFromFile(activate: false)`. The existing "same `uuid` overwrites the local copy" behaviour is kept unchanged.
* **No program is activated as a result of a bundle import**, and the user is not asked to choose one. The active plan (if any) is left exactly as it was. Activation was considered and deliberately dropped: the extra prompt and the "which counts as an active plan" edge cases (the always-present default onboarding plan) add complexity without a clear win. A user who wants a specific plan active can pick it from the library afterwards.
* Import is best-effort per entry. A `.drill` that fails to parse is skipped and counted, and the flow reports a summary ("Imported N plans", plus "M skipped" when any entry failed) rather than aborting the whole bundle.
* As today, import is refused while an exercise is running (`ExerciseService().isStarted`).

### Surfaces

* **"Mine planer" tab** in the library dialog gains a "Last ned alle planer" action that encodes the current library with `DrillLibrary.fromPrograms` and saves/shares it, reusing the existing bulk-export download path.
* **"Fra fil" tab** accepts both `.drill` and `.zip`. After a pick, `sniff` routes to the single-program install (existing) or the multi-program install (new), with the summary snackbar for bundles.
* **`?import=guide`** is handled in `buildRouter`'s redirect the same way `/i/:slug` is: a post-frame callback opens the library dialog on the "Fra fil" tab, and the query parameter is stripped by redirecting to the active-program path. The migration link and the permanent feature share this one flow.

### Consequences

* Good: The format is exactly what the exporters already emit, so migration bundles downloaded before this change import cleanly.
* Good: Content-based detection means a renamed bundle, or one handed over as a plain `.zip`, still imports.
* Good: Export/import of a whole library becomes a first-class, permanent feature, not migration-only scaffolding.
* Good: One import flow behind both the picker and the `?import=guide` link.
* Bad: The bundle has no OS-level open/dispatch (no dedicated extension or UTI), so it is picked manually rather than opened from a share sheet. Accepted as out of scope; the migration flow only ever picks a downloaded file.
* Bad: `exportAllPrograms` moves, touching `bulk_export.dart` callers even though behaviour is preserved through a re-export.

## Pros and cons of the options

### ZIP of `.drill` entries, content-detected (chosen)
* Good: Already the on-the-wire format; no producer changes.
* Good: Reuses `DrillFile` for every inner program, so schema handling and error typing are inherited.
* Bad: Two ZIP shapes to tell apart, solved by the `program.json`-vs-`.drill` sniff.

### One fat `.drill` holding multiple programs
* Good: A single archive, single detection path.
* Bad: Breaks the ADR-0007 "one program per `.drill`" invariant and every existing reader.
* Bad: Would need a schema bump and coordinated changes across app, CLI and backend.

### Dedicated extension and UTI for the bundle
* Good: Enables "open with RingDrill" for a whole library from the OS.
* Bad: Android intent filters, iOS UTIs and Netlify disposition all need new wiring for a flow that today only ever picks a manually downloaded file.
* Bad: Larger surface for no near-term benefit; can be added later without changing the format.

## Links

* Related ADRs: [ADR-0007](./0007-drill-file-format.md) (`.drill` format), [ADR-0022](./0022-markdown-content-as-files.md) (markdown sidecars inside `.drill`), [ADR-0039](./0039-site-pwa-api-origins.md) (migration and the `/migrate` exporter)
* Related code: `lib/data/drill_file.dart`, `lib/data/bulk_export.dart`, `lib/views/library_view.dart`, `lib/views/active_plan_actions.dart`, `lib/views/shell/app_router.dart`, `lib/services/program_service.dart`, `site/src/lib/migrate.ts`, `site/src/components/MigrateApp.astro`
* Implementation prompt: [`docs/prompts/0045-implementation-prompt.md`](../prompts/0045-implementation-prompt.md)
