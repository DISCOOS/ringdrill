---
status: accepted
date: 2026-07-30
deciders: ["kengu"]
consulted: []
informed: []
---

# ADR-0061: Accept a UTM string wherever the source format takes a position

## Context and problem statement

The source format takes every coordinate as `{lat, lng}` in decimal degrees
(ADR-0058). The domain it serves does not use decimal degrees. Norwegian SAR
plans are written in UTM — zone 32V for the whole of eastern Norway — and every
source document the format is meant to replace carries UTM strings such as
`32V 0580083E 6551794N`. The brief renders positions back as UTM, and the app's
own position widget displays UTM. So UTM is the notation on the way in from the
author's source material and on the way out to the reader; decimal degrees exist
only in the middle, in the one place a human has to type.

That gap has to be closed by hand, outside the toolchain, and it cannot be
checked. Converting the 2026 LSOR course booklet to a source document required 37
UTM-to-lat/lng conversions performed by an external script. A transposed digit, a
wrong zone or a swapped axis in any one of them yields a syntactically valid
coordinate that lands in the wrong place, and nothing downstream objects: the
only guard is `PlanBuilder._position`'s range check, which accepts anything on
Earth, and `analyze` cannot know where a station was supposed to be. The single
largest correctness risk in that conversion was arithmetic the toolchain already
knows how to do.

It already does it, in fact, just not on this path. `projection.dart` carries the
UTM implementation including the Norway 32V extension, and
`parseCoordinateInput` (`lib/utils/variable_values.dart`) accepts either a
lat/lng pair or a UTM string — explicitly including the app's own
`32V 0580414E 6552008N` display form, whose `E`/`N` suffixes it strips before
parsing. That function is used for app-side coordinate entry (the position forms,
`location`-typed variable overrides) and it is already Flutter-free and already
inside the CLI's import closure via `lib/services/brief/field_resolver.dart`. The
source compiler simply never reaches it: `PlanBuilder._position` requires a map
with numeric `lat` and `lng`, and every `SourceShape.position` site in
`source_fields.dart` funnels through it.

## Decision drivers

* An author should be able to write the notation they read. Round-tripping a
  position through a brief currently changes notation twice.
* A mis-conversion is silent. Range checks cannot catch a coordinate that is
  valid but wrong, and this is the one error class in the format with no
  detection at all.
* No new dependency and no new math: the parse exists, is tested, and is already
  reachable from the compiler.
* The CLI must stay free of Flutter imports (ADR-0005).
* The archive must not change. Positions are stored as GeoJSON `[lng, lat]`
  (ADR-0007) and the round-trip `contentHash` invariant (ADR-0059) must hold.
* The format stays authored-fields-only: a coordinate is authored input, not
  something derived, so this is a widening of one input shape rather than a new
  concept.

## Considered options

* Option A — Status quo: the author converts to decimal degrees before writing.
* Option B — Accept either a `{lat, lng}` map or a coordinate string at every
  position site, parsed through the existing `parseCoordinateInput`.
* Option C — Add a sibling `utm:` field next to `position:`, mutually exclusive
  with it.
* Option D — Keep the format lat/lng-only and add a `ringdrill convert` command
  that turns UTM into decimal degrees for the author to paste.

## Decision outcome

Chosen option: **Option B**, because the choke points that govern every
coordinate in the format can route through a parser that already accepts both
notations, removing an entire error class without adding a field, a dependency or
a concept.

Implementation note: there are **two** such choke points, not one as first
written — `SourceParser._position`, which handles a document's own `position:`
keys and owns the GeoJSON flip, and `PlanBuilder._position`, which handles a
`location`-typed variable's. Both delegate to one shared
`coordinateFromString`.

A position may then be written either way, and the two are interchangeable
everywhere `SourceShape.position` appears — station `position`, location
`position`, roleplay `position`, team `position`, and a `location`-typed
variable's `position`:

```yaml
position: { lat: 59.097921, lng: 10.397940 }
position: "32V 0580083E 6551794N"
```

`SourceShape.position` emits a `oneOf` of the object form and a string form in
the generated JSON Schema, so the schema keeps describing exactly what the
compiler accepts.

### Consequences

* Good: the notation an author reads in a brief is a notation they can paste
  back into the source, so a coordinate can be copied out of a course booklet
  unchanged and verified by eye against it.
* Good: removes the format's only silent, undetectable error class — no external
  conversion step means no un-reviewable arithmetic between the source material
  and the document.
* Good: no new dependency, no second UTM implementation, and one shared parse
  for app-side entry and compiler input, so the two cannot drift.
* Good: the archive, the wire format and the `contentHash` round trip are
  untouched — the change is entirely in how input is read.
* Bad: one field now has two accepted shapes, which widens the schema and means
  an author reading it sees a `oneOf` where there used to be a single object.
* Bad: `decompile` keeps emitting `{lat, lng}`, because UTM is metre-precision
  and re-emitting it would either lose precision or have to guess a zone. A
  document authored in UTM therefore comes back in decimal degrees. The rebuild
  is still byte-identical in the archive and preserves `contentHash`, but the
  source text is not what the author wrote.
* Bad: a string position is validated later than a malformed map is, so the
  diagnostic for a typo'd UTM string is "not a coordinate" rather than a
  field-level complaint about `lat` or `lng`.

## Pros and cons of the options

### Option A — Status quo
* Good: one shape per field; the schema stays minimal.
* Good: no ambiguity about which notation a document is in.
* Bad: pushes the conversion outside the toolchain, where it is neither
  reviewable nor testable, on the single most error-prone value in the format.
* Bad: the author never works in the notation the format demands, so every real
  authoring session starts with a scripted bulk conversion.

### Option B — Accept both shapes at every position site
* Good: one choke point, one existing parser, no new field or concept.
* Good: symmetric with the app, which already accepts both forms on entry.
* Bad: two shapes for one field; `oneOf` in the schema.
* Bad: does not round-trip the authored notation through `decompile`.

### Option C — A sibling `utm:` field
* Good: keeps `position` single-shaped, and makes the notation explicit in the
  document.
* Bad: two fields that mean the same thing, with a mutual-exclusion rule to
  validate and explain, repeated at five sites.
* Bad: `decompile` has to choose which of the two to emit, so the ambiguity the
  extra field was meant to avoid reappears anyway.

### Option D — A `ringdrill convert` helper
* Good: no format change at all; the schema and compiler stay as they are.
* Bad: keeps the conversion a separate manual step, so the error class survives —
  it just moves into copy-paste.
* Bad: a new command whose entire purpose is to work around an input restriction
  the compiler could simply lift.

## Links

* Related ADRs: [ADR-0058](./0058-source-format-and-plan-compiler.md),
  [ADR-0059](./0059-drill-schema-migration-ladder.md),
  [ADR-0007](./0007-drill-file-format.md),
  [ADR-0005](./0005-cli-must-remain-flutter-free.md),
  [ADR-0046](./0046-plan-variables.md),
  [ADR-0047](./0047-scenario-locations-and-persons.md)
* Related code: `lib/data/source/plan_builder.dart` (`_position`),
  `lib/data/source/source_fields.dart` (`SourceShape.position`),
  `lib/utils/variable_values.dart` (`parseCoordinateInput`),
  `lib/utils/projection.dart` (`Utm`, `toLatLngFromUtm`)
* Origin: converting `assets/example/2026 LSOR øvelseshefte.docx` to a source
  document, which needed 37 external UTM conversions.
