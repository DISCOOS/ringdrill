/// Normalizes older `.drill` content into the shape the current model reads —
/// the ordered migration ladder of ADR-0059.
///
/// Two readers face the same historical variance: `DrillFile.plan()` and the
/// source format's `decompile`. Before this existed the handling was per-call-site
/// branches inside `DrillFile`, invisible from anywhere else and impossible to
/// enumerate; `decompile` would have had to duplicate them or silently diverge.
///
/// **The invariant** (ADR-0059), which every rung obeys and which the tests
/// check:
///
/// > A rung may fill a field that is absent, or rename a key. A rung may never
/// > rewrite an authored value.
///
/// That is what keeps normalization compatible with the `contentHash` round trip
/// in DESIGN-014. `signalement → description` is a key rename, so it is allowed.
/// Stripping a baked-in numbering label out of a name ("#6 Førsteinnsats") would
/// be a value rewrite, so it is refused: numbering comes from order, names are
/// opaque, and a round trip preserves them byte for byte.
///
/// ## Two kinds of rung
///
/// [ArchiveMigration] rewrites the archive's entry index — the map of path to
/// bytes — before anything is classified or parsed. [ManifestMigration] rewrites
/// one already-parsed JSON manifest. The split follows where the variance
/// actually lives: a renamed folder and a value that moved out of JSON into a
/// companion file are archive-shaped, while a renamed field is manifest-shaped.
///
/// The ladder is **ordered**, and at least one pair depends on it:
/// [RenameActorsFolderToStaff] must run before
/// [InlineMarkdownToCompanionFiles], which addresses entries by their `staff/`
/// path. Rungs are individually idempotent — applying one twice changes nothing
/// the second time — but they are not order-independent, so run them through
/// [DrillMigrations.archive] rather than picking them out of [all].
///
/// ## What is deliberately not here
///
/// Most historical variance needs no code at all, because `@Default` on the
/// additive model fields already absorbs it — a 1.0 archive with no `tags`,
/// `variables`, `locations` or `persons` key reads fine today (ADR-0018,
/// ADR-0043, ADR-0046, ADR-0047). The ladder is only for what the model cannot
/// absorb.
///
/// The `programId → planId` fallback is **out of scope**. It is not archive
/// content: it is a field on the Netlify API's JSON responses, handled in
/// `drill_client.dart`, with its own Sentry-tracked deprecation
/// ([ADR-0055](../../docs/adrs/0055-programid-planid-wire-back-compat.md)).
/// Folding it in here would put an HTTP concern behind an archive-reading
/// abstraction and obscure the telemetry that decides when it can be dropped.
///
/// There is no supported-version floor. Measured against the live catalog, the
/// schema string does not identify the content shape: every published plan is
/// schema `1.2`, yet they differ in whether they carry `actors` or `staff`,
/// `variables` or not, `languageCode` or not. Raising a floor later means
/// deleting the bottom rung and its test.
///
/// Free of `package:flutter/*` (AGENTS.md rule 7).
library;

import 'dart:convert';

/// What a rung changed, for reporting rather than control flow.
class MigrationNote {
  const MigrationNote({
    required this.rung,
    required this.path,
    required this.message,
  });

  /// The rung's [DrillMigration.name].
  final String rung;

  /// Where in the archive, e.g. `exercises/abc123.json`.
  final String path;

  final String message;

  Map<String, dynamic> toJson() => {
    'rung': rung,
    'path': path,
    'message': message,
  };

  @override
  String toString() => '[$rung] $path: $message';
}

/// One step of the ladder — a **rung**.
///
/// The term is used throughout ADR-0059, this library and its tests, so: a rung
/// is one migration handling exactly one historical shape, named and
/// self-describing; the ladder is the ordered list of them
/// ([DrillMigrations.all]). Two consequences follow from the metaphor and both
/// are real: rungs have an order (see the library doc), and dropping support for
/// the oldest archives is deleting the bottom rung plus its test rather than
/// auditing branches spread across a reader.
abstract class DrillMigration {
  const DrillMigration();

  /// Stable identifier, used in notes and tests.
  String get name;

  /// What historical shape this handles, and why the model cannot.
  String get describes;
}

/// A rung that rewrites the archive's entry index.
///
/// Runs before classification, so downstream code sees only current paths. The
/// map is path to bytes, mutated in place and returned for chaining.
abstract class ArchiveMigration extends DrillMigration {
  const ArchiveMigration();

  Map<String, List<int>> apply(
    Map<String, List<int>> entries, {
    required List<MigrationNote> notes,
  });
}

/// A rung that rewrites one entity manifest in place.
abstract class ManifestMigration extends DrillMigration {
  const ManifestMigration();

  /// Applies to [json], appending to [notes]. Returns the same map, mutated.
  Map<String, dynamic> apply(
    Map<String, dynamic> json, {
    required String path,
    required List<MigrationNote> notes,
  });
}

/// `actors/` → `staff/`.
///
/// DESIGN-011 renamed the folder. A `.drill` exported before that is shared
/// peer-to-peer (USB, AirDrop, email), so it can arrive at any time. Renaming the
/// entries here means the reader has one folder name to know about, and the next
/// person adding a staff-related entry cannot forget the alias.
class RenameActorsFolderToStaff extends ArchiveMigration {
  const RenameActorsFolderToStaff();

  @override
  String get name => 'actors-folder-to-staff';

  @override
  String get describes =>
      'DESIGN-011 renamed the actors/ folder to staff/; archives written before '
      'that are still shared peer-to-peer.';

  @override
  Map<String, List<int>> apply(
    Map<String, List<int>> entries, {
    required List<MigrationNote> notes,
  }) {
    final legacy = entries.keys.where((k) => k.startsWith('actors/')).toList();
    for (final key in legacy) {
      final renamed = 'staff/${key.substring('actors/'.length)}';
      // Only fills what is absent: an archive carrying both folders keeps the
      // current one, since replacing it would discard authored content.
      if (entries.containsKey(renamed)) continue;
      entries[renamed] = entries.remove(key)!;
      notes.add(
        MigrationNote(rung: name, path: key, message: 'renamed to $renamed'),
      );
    }
    // A both-folders archive still needs the stale entries gone, or they get
    // classified twice.
    for (final key in legacy) {
      entries.remove(key);
    }
    return entries;
  }
}

/// Moves markdown that used to live inline in JSON into its companion file.
///
/// Before ADR-0022, a role play's `behavior`/`background` and a staff member's
/// `notes` were string fields in the manifest; now they are `.md` files beside
/// it. The model fields are `includeFromJson: false`, so `fromJson` ignores the
/// inline value entirely — without this rung the content is silently dropped.
///
/// Synthesizing the missing entry rather than patching the entity afterwards is
/// what lets `DrillFile` drop its three legacy branches: once this has run, a
/// value is always where the current format says it is. The manifest bytes are
/// left untouched — the inline key stays, ignored by `fromJson` as it already
/// was — so the rung only ever *adds*.
class InlineMarkdownToCompanionFiles extends ArchiveMigration {
  const InlineMarkdownToCompanionFiles();

  /// Manifest folder → the inline JSON keys and the companion files they became.
  static const _moves = <String, Map<String, String>>{
    'roleplays': {'behavior': 'behavior.md', 'background': 'background.md'},
    'staff': {'notes': 'notes.md'},
  };

  @override
  String get name => 'inline-markdown-to-companion-files';

  @override
  String get describes =>
      'Before ADR-0022 a role play\'s behavior/background and a staff member\'s '
      'notes were inline JSON strings rather than .md companion files; the '
      'model no longer reads them from JSON at all.';

  @override
  Map<String, List<int>> apply(
    Map<String, List<int>> entries, {
    required List<MigrationNote> notes,
  }) {
    for (final entry in _moves.entries) {
      final folder = entry.key;
      for (final path in entries.keys.toList()) {
        if (!path.startsWith('$folder/') || !path.endsWith('.json')) continue;
        final segments = path.split('/');
        // Only `<folder>/<uuid>.json`, not something nested deeper.
        if (segments.length != 2) continue;
        final uuid = segments[1].substring(0, segments[1].length - 5);

        final Map<String, dynamic> json;
        try {
          json =
              jsonDecode(utf8.decode(entries[path]!)) as Map<String, dynamic>;
        } catch (_) {
          // A corrupt manifest is not this rung's problem to report — the
          // reader raises a typed DrillFormatException for it a moment later,
          // with the path and the cause.
          continue;
        }

        for (final move in entry.value.entries) {
          final value = json[move.key];
          if (value is! String) continue;
          final companion = '$folder/$uuid/${move.value}';
          // The companion file wins when both exist, which is the precedence the
          // hand-written branches had.
          if (entries.containsKey(companion)) continue;
          entries[companion] = utf8.encode(value);
          notes.add(
            MigrationNote(
              rung: name,
              path: path,
              message: 'moved inline "${move.key}" into $companion',
            ),
          );
        }
      }
    }
    return entries;
  }
}

/// `signalement` → `description` on a scenario person.
///
/// The rename was a clean break: nothing reads the old key, so a value stored
/// under it is dropped silently on import today. That is the one genuine
/// data-loss path in the corpus (ADR-0059), and it is a key rename, which the
/// invariant permits.
class RenameSignalementToDescription extends ManifestMigration {
  const RenameSignalementToDescription();

  @override
  String get name => 'signalement-to-description';

  @override
  String get describes =>
      'Person.signalement was renamed to description; nothing reads the old '
      'key, so its content was being dropped on import.';

  @override
  Map<String, dynamic> apply(
    Map<String, dynamic> json, {
    required String path,
    required List<MigrationNote> notes,
  }) {
    final stations = json['stations'];
    if (stations is! List) return json;
    for (var s = 0; s < stations.length; s++) {
      final station = stations[s];
      if (station is! Map) continue;
      final persons = station['persons'];
      if (persons is! List) continue;
      for (final person in persons) {
        if (person is! Map) continue;
        if (!person.containsKey('signalement')) continue;
        final legacy = person.remove('signalement');
        // Only fills what is absent: a manifest carrying both keys keeps the
        // current one, since overwriting it would be rewriting an authored
        // value.
        if (person['description'] == null && legacy != null) {
          person['description'] = legacy;
          notes.add(
            MigrationNote(
              rung: name,
              path: '$path stations[$s].persons[${person['slug']}]',
              message: 'moved signalement into description',
            ),
          );
        }
      }
    }
    return json;
  }
}

/// Fills `exercise.index` when the archive has none.
///
/// Schema 1.0 wrote no `index`, so every exercise deserializes to `index: 0` and
/// the plan has no order at all — `Numbering.exercise` would label them all
/// "#1". Order comes from arrival, exactly as `PlanService` assigns it on import
/// (`nextIndex++`); the caller decides what "arrival" means and passes
/// [ordinal].
///
/// This fills an absent field, so the invariant permits it. What it must *not*
/// do is read the order out of a name like "#6 Førsteinnsats" — that would make
/// numbering depend on name content, which the format explicitly does not
/// (ADR-0059).
class FillExerciseIndex extends DrillMigration {
  const FillExerciseIndex();

  @override
  String get name => 'fill-exercise-index';

  @override
  String get describes =>
      'Schema 1.0 archives have no exercise.index, so every exercise reads as '
      'index 0 and the plan has no order.';

  Map<String, dynamic> apply(
    Map<String, dynamic> json, {
    required String path,
    required int ordinal,
    required List<MigrationNote> notes,
  }) {
    if (json.containsKey('index')) return json;
    json['index'] = ordinal;
    notes.add(
      MigrationNote(
        rung: name,
        path: path,
        message: 'assigned index $ordinal from archive order',
      ),
    );
    return json;
  }
}

/// The ladder, in order.
class DrillMigrations {
  const DrillMigrations._();

  static const actorsFolder = RenameActorsFolderToStaff();
  static const inlineMarkdown = InlineMarkdownToCompanionFiles();
  static const signalement = RenameSignalementToDescription();
  static const exerciseIndex = FillExerciseIndex();

  /// Every rung, for documentation and tests.
  static const all = <DrillMigration>[
    actorsFolder,
    inlineMarkdown,
    signalement,
    exerciseIndex,
  ];

  /// Archive-level rungs, in the order they must run.
  ///
  /// [inlineMarkdown] addresses `staff/` paths, so [actorsFolder] comes first.
  static const archiveRungs = <ArchiveMigration>[actorsFolder, inlineMarkdown];

  /// Rungs that rewrite an exercise manifest with no extra input.
  static const manifestRungs = <ManifestMigration>[signalement];

  /// Normalizes the archive's entry index. Call once, before classifying.
  static Map<String, List<int>> archive(
    Map<String, List<int>> entries, {
    List<MigrationNote>? notes,
  }) {
    final sink = notes ?? <MigrationNote>[];
    var out = entries;
    for (final rung in archiveRungs) {
      out = rung.apply(out, notes: sink);
    }
    return out;
  }

  /// Normalizes one exercise manifest.
  ///
  /// [ordinal] is its position in archive order, used only when the manifest has
  /// no `index` of its own.
  static Map<String, dynamic> exercise(
    Map<String, dynamic> json, {
    required String path,
    required int ordinal,
    List<MigrationNote>? notes,
  }) {
    final sink = notes ?? <MigrationNote>[];
    var out = json;
    for (final rung in manifestRungs) {
      out = rung.apply(out, path: path, notes: sink);
    }
    return exerciseIndex.apply(out, path: path, ordinal: ordinal, notes: sink);
  }
}
