---
status: accepted
date: 2026-05-20
deciders: ["@kengu"]
consulted: []
informed: []
---

# ADR-0007: `.drill` files are versioned ZIP archives of JSON parts

## Context and problem statement

RingDrill programs must be shareable across devices, platforms and tools. A drill program holds nested data (a program shell, metadata, lists of exercises, teams and sessions), and the format must be able to evolve over time without breaking older clients in the wild.

The format is consumed by the Flutter app on every platform, by the Dart CLI, and by the Netlify backend. The OS dispatch story matters too: Android intent filters, iOS UTIs, web download handling and the share sheet all need a stable MIME type and file extension.

## Decision drivers

* Must round-trip the full domain model without lossy conversions.
* Must support schema evolution (new fields, new optional sections, eventual embedded assets).
* Must work via Android intents, iOS share sheets and web downloads.
* Must be parseable on every platform we target (mobile, web, CLI, Netlify functions).
* Must be small enough for typical drill programs (kilobytes), without precluding larger payloads later.

## Considered options

* A custom `.drill` ZIP archive with internal JSON files plus a schema version.
* A single JSON file with a top-level `schema` field.
* A SQLite database file.
* Protocol Buffers or FlatBuffers.

## Decision outcome

Chosen option: **a ZIP archive containing JSON parts**, served as `application/vnd.ringdrill+zip` with the file extension `.drill`. The schema version is held as a constant in code (`DrillFile.drillSchema1_0 = '1.0'`) and Netlify forces `Content-Disposition: attachment` for `*.drill` so the OS dispatches the file to the app.

Archive layout (current, schema 1.0):

```
.drill (zip)
  metadata.json              ProgramMetadata
  program.json               Program (shell, no nested lists)
  exercises/<uuid>.json      one Exercise per file
  teams/<uuid>.json          one Team per file
  sessions/<uuid>.json       one Session per file
```

Implementation lives in `lib/data/drill_file.dart` (`DrillFile.fromFile`, `fromBytes`, `fromProgram`, `program()`). The Netlify side enforces MIME and disposition through `netlify.toml` headers and is consumed by `netlify/functions/drills-upload.js`, `drills-head.js` and `deep-link.js`. The Dart CLI talks to those endpoints through `lib/data/drill_client.dart`.

### Consequences

* Good: Easy to extend with new sections or with embedded assets (icons, station media) without breaking schema 1.0 readers, which simply ignore unknown files.
* Good: One MIME type unifies Android intents, iOS UTIs, web downloads and Netlify routing.
* Good: Versioned schema gives a clear upgrade path. Older clients can detect a mismatch and refuse politely.
* Good: Compresses well, which matters for programs with many exercises.
* Bad: Schema bumps require coordinated changes across the Flutter app, the CLI, and the Netlify functions. The rule "schema bumps are coordinated changes" lives in [`AGENTS.md`](../../AGENTS.md).
* Bad: Slight overhead vs. a single JSON file for very small programs.
* Bad: The Netlify `attachment` header is not negotiable. Changing it would break OS dispatch on mobile.

## Pros and cons of the options

### ZIP of JSON parts (chosen)
* Good: Extensible without breaking older clients.
* Good: Standard tooling on every platform.
* Bad: Multiple parts to keep consistent during read/write.

### Single JSON file with a `schema` field
* Good: Simplest possible format.
* Bad: No room for embedded assets without base64-bloat.
* Bad: Large programs become a single unwieldy JSON blob.

### SQLite database file
* Good: Queryable in place.
* Bad: Heavyweight for what is essentially a snapshot. Web support and CLI portability suffer.
* Bad: Schema migrations are SQL-shaped rather than file-shaped.

### Protocol Buffers / FlatBuffers
* Good: Compact, fast, schema-versioned by design.
* Bad: Tooling weight and a non-trivial build pipeline.
* Bad: Less inspectable for ops and debugging than JSON inside a ZIP.

## Links

* Related code: `lib/data/drill_file.dart`, `lib/data/drill_client.dart`, `netlify/functions/drills-upload.js`, `netlify/functions/drills-head.js`, `netlify/functions/deep-link.js`, `netlify.toml`
* Operating rule (in [`AGENTS.md`](../../AGENTS.md)): "Drill file format is versioned."
* Note: `DrillFile.drillMimeType` carries a TODO to register the MIME type with IANA. Until then we use the `vnd.` vendor tree convention.
