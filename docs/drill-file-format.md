# Drill file format

`DrillFile` (in `lib/data/drill_file.dart`) is a versioned zip wrapper around the program JSON.

* MIME type: `application/vnd.ringdrill+zip`
* Extension: `.drill`
* Current schema: `DrillFile.drillSchemaCurrent`, currently `'1.2'` (`drillSchema1_0`/`1_1`/`1_2` are still read for backward compatibility).

Bumping the schema requires updating the import code in `lib/data/drill_file.dart`, the Netlify upload handler, and a migration path for existing files.

## Drill library format

A drill library bundles multiple programs into one outer ZIP, for migration export and for backing up or moving a whole library between devices ([ADR-0045](./adrs/0045-drill-library-bundle-format.md)).

* Outer ZIP, one `.drill` per program: `<slug>.drill`, `<slug>-1.drill`, … for slug collisions.
* Detected by content, not extension: a top-level `program.json` means a single `.drill`; one or more `*.drill` entries anywhere in the archive (any nesting depth) with no top-level `program.json` means a library; anything else is invalid. Depth is deliberately not checked for `.drill` entries because the bundle may be repacked by any zip tool before it reaches the app; known packaging cruft (`__MACOSX/`, `.DS_Store`) is ignored.
* Carries no schema of its own — each inner `.drill` carries its own schema per the section above.
* Import is best-effort per entry: a corrupt inner `.drill` is skipped and counted, it does not abort the rest of the bundle. Import never activates a program.

Implementation lives in `lib/data/drill_library.dart` (`DrillLibrary.sniff`, `.entries`, `.fromPrograms`). `lib/data/bulk_export.dart`'s `exportAllPrograms` delegates to `DrillLibrary.fromPrograms`.
