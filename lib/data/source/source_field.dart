/// Field descriptors for the DESIGN-014 source format: what a field is called
/// on each side, what shape its value takes, and whether an author writes it.
///
/// The types here are the vocabulary; the actual table is
/// [SourceScopes] in `source_fields.dart`. Everything that moves between the
/// source document and the `.drill` wire format reads that one table —
/// `source_parser.dart`, `plan_builder.dart`, `plan_decompiler.dart`,
/// `source_emitter.dart`, `source_analyzer.dart` and `source_schema.dart` — so
/// the schema cannot describe a field `build` does not accept, and `decompile`
/// cannot emit one `build` will reject.
///
/// Free of `package:flutter/*` (AGENTS.md rule 7): the CLI is the primary
/// caller.
library;

/// Whether an author writes a field, and what happens when they do not.
enum SourceFieldKind {
  /// Written by a person or an agent. The source format's whole content.
  authored,

  /// Written by `decompile`, optional for everyone else.
  ///
  /// Only `uuid`. It is not derivable from anything else, and exercise,
  /// role-play and team uuids are inside `PlanX.computeContentHash` (via
  /// `toJson`) *and* are its sort keys — so minting fresh ones would make
  /// `build(decompile(d))` produce a different hash and a different ordering.
  /// `build` mints one only when the field is absent (DESIGN-014).
  identity,

  /// Computed by `build`; rejected as input, never emitted by `decompile`.
  ///
  /// Listed in the table anyway, so `schema` can document the exclusion and
  /// `analyze` can say "that is derived" instead of "unknown key".
  derived,
}

/// How a value is written in the source document versus on the wire.
enum SourceShape {
  /// Plain string, both sides.
  string,

  /// Integer, both sides.
  integer,

  /// Boolean, both sides.
  boolean,

  /// `[a, b]` of strings, both sides.
  stringList,

  /// `{key: value}` of strings, both sides. Used for `variableOverrides`.
  stringMap,

  /// `"HH:MM"` in source; `{hour, minute}` on the wire (`SimpleTimeOfDay`).
  time,

  /// `{lat, lng}` in source; GeoJSON `{coordinates: [lng, lat]}` on the wire.
  ///
  /// The flip is the entire reason this shape is named rather than passed
  /// through: it is the swap bug, killed at the boundary (worked example
  /// decision 3).
  position,

  /// A markdown body. Lives in a `.md` companion file in the archive rather
  /// than in JSON (ADR-0022), so it never round-trips through `toJson` — see
  /// [SourceField.mdFileName].
  markdown,

  /// A string constrained to a fixed set. The source uses the same tokens the
  /// wire does (worked example decision 2), so no mapping is needed — the
  /// values exist here for `schema` and `analyze`.
  enumeration,

  /// Passed through untouched; the builder validates its structure.
  ///
  /// For the two shapes a scalar vocabulary cannot describe: a
  /// `location`-typed variable's `{place, position}` value, and derived fields
  /// like `schedule` that are never read from a document at all. Deliberately
  /// rare — a growing list here would mean the table has stopped describing the
  /// format.
  raw,
}

/// One field of one scope.
class SourceField {
  const SourceField(
    this.sourceKey, {
    String? wireKey,
    required this.shape,
    this.kind = SourceFieldKind.authored,
    this.enumValues = const [],
    this.mdFileName,
    this.description,
  }) : _wireKey = wireKey;

  /// The key an author writes.
  ///
  /// Mirrors the wire key unless a value-shape or storage difference makes that
  /// misleading: markdown fields drop the `Md` suffix and take the name of
  /// their archive file (`directorNotesMd` ↔ `director-notes.md` ↔
  /// `director_notes`), because for those the archive path *is* the wire key.
  final String sourceKey;

  final String? _wireKey;

  /// The key in `program.json` / an entity manifest. Defaults to [sourceKey].
  String get wireKey => _wireKey ?? sourceKey;

  final SourceShape shape;
  final SourceFieldKind kind;

  /// Permitted tokens when [shape] is [SourceShape.enumeration].
  final List<String> enumValues;

  /// Archive file name when [shape] is [SourceShape.markdown], e.g.
  /// `director-notes.md`. The relationship is mechanical —
  /// `sourceKey == mdFileName without '.md', '-' → '_'` — and
  /// `test/data/source/source_fields_test.dart` asserts it, so the pair cannot
  /// drift into two unrelated names.
  final String? mdFileName;

  /// One line for the generated JSON Schema. Not user-facing UI text, so it is
  /// English and not localized (AGENTS.md rule 12 governs docs, rule 4 governs
  /// app strings; this is neither).
  final String? description;

  bool get isAuthored => kind == SourceFieldKind.authored;
  bool get isDerived => kind == SourceFieldKind.derived;
  bool get isIdentity => kind == SourceFieldKind.identity;

  /// Whether an author may write this key at all.
  bool get isWritable => !isDerived;
}

/// A level of the source document: the plan, an exercise, a station, and so on.
class SourceScope {
  const SourceScope({
    required this.name,
    required this.fields,
    this.children = const [],
    this.description,
  });

  /// Stable identifier, used in diagnostics paths and schema definition names.
  final String name;

  final List<SourceField> fields;

  /// Nested collections, e.g. a plan's `exercises` or a station's `persons`.
  final List<SourceChild> children;

  final String? description;

  SourceField? field(String sourceKey) {
    for (final f in fields) {
      if (f.sourceKey == sourceKey) return f;
    }
    return null;
  }

  /// Every key an author may write here, including child collections.
  Set<String> get writableKeys => {
    for (final f in fields)
      if (f.isWritable) f.sourceKey,
    for (final c in children) c.sourceKey,
  };

  Set<String> get derivedKeys => {
    for (final f in fields)
      if (f.isDerived) f.sourceKey,
  };

  Iterable<SourceField> get markdownFields =>
      fields.where((f) => f.shape == SourceShape.markdown);

  SourceChild? child(String sourceKey) {
    for (final c in children) {
      if (c.sourceKey == sourceKey) return c;
    }
    return null;
  }
}

/// How a nested collection is written in the source versus stored on the wire.
enum SourceCollection {
  /// A YAML list of objects, stored as a list. `exercises`, `stations`,
  /// `locations`, `persons`, `teams`.
  list,

  /// A YAML map keyed by the child's identifying field, stored as a list
  /// carrying that field. `variables` is written
  /// `{talegruppe: {value: …}}` and stored `[{name: talegruppe, value: …}]` —
  /// the map form reads better and makes duplicate names impossible.
  keyedMap,

  /// A YAML list nested under its logical parent but stored at the *plan*
  /// level with derived back-references. Only `roleplays`, which nest under
  /// their station and are stored with `exerciseUuid` + `stationIndex`
  /// (DESIGN-009, worked example decision 4). The relocation is explicit code
  /// in the builder and decompiler; this value marks it so the schema and the
  /// analyzer know the shape.
  relocatedList,
}

/// A nested collection on a [SourceScope].
class SourceChild {
  const SourceChild(
    this.sourceKey, {
    required this.scope,
    this.collection = SourceCollection.list,
    this.keyField,
    this.description,
  });

  final String sourceKey;
  final SourceScope scope;
  final SourceCollection collection;

  /// For [SourceCollection.keyedMap], the child field the map key becomes.
  final String? keyField;

  final String? description;
}
