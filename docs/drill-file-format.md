# Drill file format

`DrillFile` (in `lib/data/drill_file.dart`) is a versioned zip wrapper around the program JSON.

* MIME type: `application/vnd.ringdrill+zip`
* Extension: `.drill`
* Current schema: `DrillFile.drillSchemaCurrent`, currently `'1.2'` (`drillSchema1_0`/`1_1`/`1_2` are still read for backward compatibility).

Bumping the schema requires updating the import code in `lib/data/drill_file.dart`, the Netlify upload handler, and a migration path for existing files.

## Anticipated direction: the catalog carries templates, not runs

The catalog is expected to hold **templates** (prototypes) rather than complete
plans: a drill file with the *structure* of an exercise but not the data that
implements one particular run of it. Nothing depends on this yet, and it is
recorded here because it changes the shape of an existing mechanism rather than
adding a new one.

Today `Plan.toPublishJson` is a **denylist**: start from `toJson()` and remove
what must not be published (`uuid`, `contentHash`, `source`, `metadata`, and
`staff` — the PII, per [ADR-0018](./adrs/0018-roleplayer-data-model.md)). That is
sound while the catalog carries whole plans, because the excluded set is small and
known.

A template projection inverts it. "What belongs in a reusable template" is an
**allowlist**: naming what to keep, so a field added to `Plan` later is excluded
until someone decides it belongs. Under the current denylist, a new
instance-specific field is published the moment it exists — no code change at the
publish site, nothing failing, nothing to notice. The PII strip has exactly this
shape today and survives only because `staff` is explicitly listed; the rename in
DESIGN-011 had to update the denylist entry in the same commit as the field for
precisely that reason.

Two consequences worth carrying forward:

* Deciding what makes a plan a *template* versus a *run* is a modelling question
  that should land before the projection is rewritten — a template presumably
  keeps structure (rounds, station layout, scripts) and drops the specifics
  (dates, staffing, teams, concrete positions), but which side each field falls on
  is not obvious and some fields may need splitting.
* There will then be three destinations with three rules: the catalog (template
  only), account sync (complete, including PII — see
  [the account rollout plan](./plans/account-rollout.md)), and peer-to-peer
  `.drill` (complete, by design). They must not collapse into one upload path.

## Drill library format

A drill library bundles multiple programs into one outer ZIP, for migration export and for backing up or moving a whole library between devices ([ADR-0045](./adrs/0045-drill-library-bundle-format.md)).

* Outer ZIP, one `.drill` per program: `<slug>.drill`, `<slug>-1.drill`, … for slug collisions.
* Detected by content, not extension: a top-level `program.json` means a single `.drill`; one or more `*.drill` entries anywhere in the archive (any nesting depth) with no top-level `program.json` means a library; anything else is invalid. Depth is deliberately not checked for `.drill` entries because the bundle may be repacked by any zip tool before it reaches the app; known packaging cruft (`__MACOSX/`, `.DS_Store`) is ignored.
* Carries no schema of its own — each inner `.drill` carries its own schema per the section above.
* Import is best-effort per entry: a corrupt inner `.drill` is skipped and counted, it does not abort the rest of the bundle. Import never activates a program.

Implementation lives in `lib/data/drill_library.dart` (`DrillLibrary.sniff`, `.entries`, `.fromPrograms`). `lib/data/bulk_export.dart`'s `exportAllPrograms` delegates to `DrillLibrary.fromPrograms`.
