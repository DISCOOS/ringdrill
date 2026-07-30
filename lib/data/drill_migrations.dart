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
/// Note what is deliberately *not* here. Most historical variance needs no code
/// at all, because `@Default` on the additive model fields already absorbs it —
/// a 1.0 archive with no `tags`, `variables`, `locations` or `persons` key reads
/// fine today (ADR-0018, ADR-0043, ADR-0046, ADR-0047). The ladder is only for
/// what the model cannot absorb.
///
/// There is no supported-version floor. Measured against the live catalog, the
/// schema string does not identify the content shape: every published plan is
/// schema `1.2`, yet they differ in whether they carry `actors` or `staff`,
/// `variables` or not, `languageCode` or not. Raising a floor later means
/// deleting the bottom rung and its test.
///
/// Free of `package:flutter/*` (AGENTS.md rule 7).
library;

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

  @override
  String toString() => '[$rung] $path: $message';
}

/// One step of the ladder.
///
/// Rungs are **idempotent** — applying one twice changes nothing the second
/// time — so they compose in any order and re-running normalization on already-
/// normalized content is a no-op. That property is what makes it safe to run the
/// ladder unconditionally rather than gating it on a version check that, as
/// above, would not be reliable anyway.
abstract class DrillMigration {
  const DrillMigration();

  /// Stable identifier, used in notes and tests.
  String get name;

  /// What historical shape this handles, and why the model cannot.
  String get describes;
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

  static const signalement = RenameSignalementToDescription();
  static const exerciseIndex = FillExerciseIndex();

  /// Every rung, for documentation and tests.
  static const all = <DrillMigration>[signalement, exerciseIndex];

  /// Rungs that rewrite an exercise manifest with no extra input.
  static const manifestRungs = <ManifestMigration>[signalement];

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
