// The DESIGN-014 round-trip contract: `build(decompile(d))` produces a plan with
// the same `contentHash` as `d`.
//
// This is the test the whole design hangs on. It is what makes `decompile` safe
// to use on published plans — an author can decompile, edit and rebuild without
// the compiler quietly changing anything they did not touch — and it is what
// enforces the two rules that make it possible: uuids are carried through
// (they are inside the hash and are its sort keys), and no authored value is ever
// rewritten (ADR-0059).
//
// Run against real archives, not synthetic ones. A hand-built fixture only
// exercises the shapes the fixture's author thought of; the published corpus
// exercises what people actually wrote.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/data/drill_file.dart';
import 'package:ringdrill/data/drill_migrations.dart';
import 'package:ringdrill/data/source/plan_decompiler.dart';
import 'package:ringdrill/data/source/source_compiler.dart';
import 'package:ringdrill/models/exercise.dart';
import 'package:ringdrill/models/plan.dart';

/// Decompiles then rebuilds [drillPath], returning both plans.
({Plan before, Plan after, String yaml}) _roundTrip(String drillPath) {
  final original = DrillFile.fromFile(File(drillPath)).plan();
  final document = PlanDecompiler.decompile(original);
  final rebuilt = SourceCompiler.toPlan(
    document.yaml,
    now: DateTime.utc(2026, 1, 1),
    // A round trip must never need to mint anything: every uuid comes from the
    // decompiled document. If this throws, that assumption is broken and the
    // failure names it directly rather than showing up as a hash mismatch.
    mintUuid: () => throw StateError(
      'the round trip minted a uuid, so decompile dropped one',
    ),
  );
  return (before: original, after: rebuilt.plan, yaml: document.yaml);
}

void main() {
  group('round trip preserves the content hash', () {
    // The repo's own fixture is a schema-1.0 archive: no metadata.schema, no
    // tags/variables/languageCode, no markdown files, no role plays, and — the
    // interesting part — no exercise.index at all, so it exercises the migration
    // ladder's bottom rung.
    test('test-7x.drill (schema 1.0, no exercise index)', () {
      final result = _roundTrip('test/fixtures/test-7x.drill');
      expect(
        result.after.computeContentHash(),
        result.before.computeContentHash(),
      );
    });

    // The real published plan the design was written against — schema 1.2, with
    // tags, a languageCode, markdown companion files and a role play. The
    // strongest evidence available, because it is what the app actually wrote
    // rather than what a fixture author thought of.
    test('lsor-eidene-2026.drill (schema 1.2, published)', () {
      final result = _roundTrip('test/fixtures/source/lsor-eidene-2026.drill');
      expect(
        result.after.computeContentHash(),
        result.before.computeContentHash(),
      );
      // Guards against the fixture being swapped for something thinner: these
      // are the features that make it worth having as well as test-7x.
      expect(result.before.tags, isNotEmpty);
      expect(result.before.metadata.languageCode, 'nb');
      expect(result.before.exercises.length, greaterThan(1));
      expect(
        result.before.exercises.any((e) => e.methodMd != null),
        isTrue,
        reason: 'expected markdown companion files',
      );
    });
  });

  group('what the round trip must carry', () {
    late ({Plan before, Plan after, String yaml}) result;

    setUpAll(() => result = _roundTrip('test/fixtures/test-7x.drill'));

    test('the plan uuid, so a rebuild updates rather than duplicates', () {
      expect(result.after.uuid, result.before.uuid);
    });

    test('every exercise and team uuid, in the same order', () {
      expect(
        result.after.exercises.map((e) => e.uuid),
        result.before.exercises.map((e) => e.uuid),
      );
      expect(
        result.after.teams.map((t) => t.uuid),
        result.before.teams.map((t) => t.uuid),
      );
    });

    test('names verbatim, including baked-in numbering labels', () {
      // The fixture's exercises are named "#1 Søk og redning (ringøvelse)" and
      // its stations "1a) Turgåer" — a pre-automatic-numbering practice. Numbering
      // comes from order and names are opaque, so these survive untouched
      // (ADR-0059). Stripping them would change the hash, which is why the
      // contract and the rule are the same rule.
      expect(
        result.after.exercises.map((e) => e.name),
        result.before.exercises.map((e) => e.name),
      );
      expect(
        result.before.exercises.any((e) => e.name.startsWith('#')),
        isTrue,
        reason: 'fixture no longer covers baked-in numbering',
      );
      for (var i = 0; i < result.before.exercises.length; i++) {
        expect(
          result.after.exercises[i].stations.map((s) => s.name),
          result.before.exercises[i].stations.map((s) => s.name),
        );
      }
    });

    test('coordinates, without drifting through the {lat, lng} flip', () {
      final before = result.before.exercises
          .expand((e) => e.stations)
          .where((s) => s.position != null)
          .map((s) => '${s.position!.latitude},${s.position!.longitude}');
      final after = result.after.exercises
          .expand((e) => e.stations)
          .where((s) => s.position != null)
          .map((s) => '${s.position!.latitude},${s.position!.longitude}');
      expect(after, before);
      expect(before, isNotEmpty);
    });

    test('the derived schedule matches what the archive already stored', () {
      // The archive carries a schedule; the compiler recomputes it. They have to
      // agree, or the extracted ExerciseSchedule has diverged from whatever wrote
      // these files.
      for (var i = 0; i < result.before.exercises.length; i++) {
        expect(
          result.after.exercises[i].schedule,
          result.before.exercises[i].schedule,
          reason: 'exercise ${result.before.exercises[i].name}',
        );
        expect(
          result.after.exercises[i].endTime,
          result.before.exercises[i].endTime,
        );
      }
    });

    test('the emitted document is byte-stable', () {
      // Re-decompiling the same plan must produce identical text, or the golden
      // is comparing something that varies run to run.
      final again = PlanDecompiler.decompile(result.before);
      expect(again.yaml, PlanDecompiler.decompile(result.before).yaml);
    });
  });

  group('ADR-0062: mode and station duration survive the round trip', () {
    // Neither is recoverable from the derived schedule — it holds times, not which
    // stations were live or how long each was — so both have to be carried
    // explicitly. A round trip that dropped them would come back as a ring route
    // with a silently different clock, which is the failure mode the contentHash
    // invariant exists to catch.
    ({Plan before, Plan after, String yaml}) tripWith(
      Plan Function(Plan) edit,
    ) {
      final original = edit(
        DrillFile.fromFile(File('test/fixtures/test-7x.drill')).plan(),
      );
      final document = PlanDecompiler.decompile(original);
      final rebuilt = SourceCompiler.toPlan(
        document.yaml,
        now: DateTime.utc(2026, 1, 1),
      );
      return (before: original, after: rebuilt.plan, yaml: document.yaml);
    }

    test(
      'a together exercise stays together, with its derived round count',
      () {
        final result = tripWith(
          (plan) => plan.copyWith(
            exercises: [
              plan.exercises.first.copyWith(mode: ExerciseMode.together),
              ...plan.exercises.skip(1),
            ],
          ),
        );

        expect(result.yaml, contains('mode: together'));
        expect(result.after.exercises.first.mode, ExerciseMode.together);
        // A round is a station in this mode, so the count follows the stations
        // rather than whatever the archive happened to say.
        expect(
          result.after.exercises.first.numberOfRounds,
          result.after.exercises.first.stations.length,
        );
      },
    );

    test('a station keeps its own execution time, and only it emits one', () {
      final result = tripWith((plan) {
        final exercise = plan.exercises.first;
        return plan.copyWith(
          exercises: [
            exercise.copyWith(
              stations: [
                exercise.stations.first.copyWith(executionTime: 100),
                ...exercise.stations.skip(1),
              ],
            ),
            ...plan.exercises.skip(1),
          ],
        );
      });

      expect(result.after.exercises.first.stations.first.executionTime, 100);
      expect(
        result.after.exercises.first.stations
            .skip(1)
            .every((s) => s.executionTime == null),
        isTrue,
        reason: 'an inheriting station must emit nothing, as before ADR-0062',
      );
      // One override, one emitted key: the decompiler must not start writing the
      // inherited value out for every station.
      expect(
        'executionTime'.allMatches(result.yaml).length,
        result.before.exercises.length + 1,
        reason: 'one per exercise, plus the single station override',
      );
    });

    test('a ring route decompiles to the document it always did', () {
      // The default is absent, not written. This is what keeps every published
      // plan round-tripping byte-identically rather than gaining a `mode:` line.
      final result = _roundTrip('test/fixtures/test-7x.drill');
      expect(result.yaml, isNot(contains('mode:')));
      expect(
        result.after.exercises.every((e) => e.mode == ExerciseMode.ring),
        isTrue,
      );
    });
  });

  group('the migration ladder', () {
    test('fills an absent exercise index from archive order', () {
      // Schema 1.0 wrote no index, so all seven exercises in the fixture read as
      // index 0 without this rung — and Numbering.exercise would label every one
      // of them "#1".
      final plan = DrillFile.fromFile(
        File('test/fixtures/test-7x.drill'),
      ).plan();
      expect(plan.exercises.map((e) => e.index).toList()..sort(), [
        0,
        1,
        2,
        3,
        4,
        5,
        6,
      ]);
    });

    test('assigns the same order on every read of the same bytes', () {
      // Manifests are uuid-named files, so "archive order" has to be pinned to
      // something stable or decompile would emit a different document each run.
      final first = DrillFile.fromFile(
        File('test/fixtures/test-7x.drill'),
      ).plan();
      final second = DrillFile.fromFile(
        File('test/fixtures/test-7x.drill'),
      ).plan();
      expect(
        second.exercises.map((e) => '${e.uuid}:${e.index}'),
        first.exercises.map((e) => '${e.uuid}:${e.index}'),
      );
    });

    test('does not renumber an exercise that already has an index', () {
      // Idempotence, and the invariant: the rung fills what is absent and never
      // overwrites what is there.
      final notes = <MigrationNote>[];
      final json = <String, dynamic>{'index': 5, 'name': 'Sixth'};
      DrillMigrations.exercise(json, path: 'x', ordinal: 0, notes: notes);
      expect(json['index'], 5);
      expect(notes, isEmpty);
    });

    test('moves signalement into description', () {
      final notes = <MigrationNote>[];
      final json = <String, dynamic>{
        'stations': [
          {
            'persons': [
              {'slug': 'magnus', 'signalement': 'Rød jakke.'},
            ],
          },
        ],
      };
      DrillMigrations.exercise(json, path: 'x', ordinal: 0, notes: notes);
      final person =
          (json['stations'] as List).first['persons'].first
              as Map<String, dynamic>;
      expect(person['description'], 'Rød jakke.');
      expect(person.containsKey('signalement'), isFalse);
      // Two rungs fire: this one, and fill-exercise-index, since the manifest has
      // no index either. Both are reported — that is the point of the notes.
      expect(
        notes.map((n) => n.rung),
        containsAll(['signalement-to-description', 'fill-exercise-index']),
      );
    });

    test('never overwrites a description that is already there', () {
      // The invariant again: a manifest carrying both keys keeps the current
      // value, since replacing it would be rewriting an authored value.
      final json = <String, dynamic>{
        'stations': [
          {
            'persons': [
              {
                'slug': 'magnus',
                'signalement': 'Old.',
                'description': 'Current.',
              },
            ],
          },
        ],
      };
      DrillMigrations.exercise(json, path: 'x', ordinal: 0);
      final person =
          (json['stations'] as List).first['persons'].first
              as Map<String, dynamic>;
      expect(person['description'], 'Current.');
    });

    test('is idempotent', () {
      final json = <String, dynamic>{
        'stations': [
          {
            'persons': [
              {'slug': 'magnus', 'signalement': 'Rød jakke.'},
            ],
          },
        ],
      };
      DrillMigrations.exercise(json, path: 'x', ordinal: 0);
      final once = json.toString();
      DrillMigrations.exercise(json, path: 'x', ordinal: 3);
      expect(json.toString(), once);
    });

    test('renames actors/ to staff/ before anything is classified', () {
      // DESIGN-011 renamed the folder; a peer-to-peer archive from before that
      // still arrives. The reader no longer knows the old name at all, so this
      // rung is the only thing keeping such an archive readable.
      final notes = <MigrationNote>[];
      final entries = <String, List<int>>{
        'actors/a1.json': utf8.encode('{}'),
        'actors/a1/notes.md': utf8.encode('Local note.'),
        'staff/keep.json': utf8.encode('{}'),
      };
      DrillMigrations.archive(entries, notes: notes);
      expect(entries.keys.toSet(), {
        'staff/a1.json',
        'staff/a1/notes.md',
        'staff/keep.json',
      });
      expect(notes.map((n) => n.rung), everyElement('actors-folder-to-staff'));
    });

    test('a both-folders archive keeps the current one', () {
      // The invariant: fill what is absent, never overwrite. An archive carrying
      // both would otherwise lose whichever the iteration reached second.
      final entries = <String, List<int>>{
        'actors/a1.json': utf8.encode('{"realName":"old"}'),
        'staff/a1.json': utf8.encode('{"realName":"current"}'),
      };
      DrillMigrations.archive(entries);
      expect(utf8.decode(entries['staff/a1.json']!), contains('current'));
      expect(entries.containsKey('actors/a1.json'), isFalse);
    });

    test('lifts inline markdown into companion entries', () {
      // Pre-ADR-0022 archives carried these as JSON strings, and the model's
      // fields are includeFromJson: false — so without this the content is
      // dropped silently, exactly like signalement was.
      final notes = <MigrationNote>[];
      final entries = <String, List<int>>{
        'roleplays/rp1.json': utf8.encode(
          jsonEncode({'behavior': 'Hides.', 'background': 'Lost.'}),
        ),
        'staff/s1.json': utf8.encode(jsonEncode({'notes': 'Has own car.'})),
      };
      DrillMigrations.archive(entries, notes: notes);
      expect(utf8.decode(entries['roleplays/rp1/behavior.md']!), 'Hides.');
      expect(utf8.decode(entries['roleplays/rp1/background.md']!), 'Lost.');
      expect(utf8.decode(entries['staff/s1/notes.md']!), 'Has own car.');
      expect(notes, hasLength(3));
    });

    test('an existing companion file wins over an inline value', () {
      // The precedence the hand-written branch had, preserved.
      final entries = <String, List<int>>{
        'roleplays/rp1.json': utf8.encode(jsonEncode({'behavior': 'inline'})),
        'roleplays/rp1/behavior.md': utf8.encode('companion'),
      };
      DrillMigrations.archive(entries);
      expect(utf8.decode(entries['roleplays/rp1/behavior.md']!), 'companion');
    });

    test('the actors rename runs before the markdown lift', () {
      // Order-dependent pair: the lift addresses `staff/` paths, so a legacy
      // archive's inline notes only move if the folder was renamed first. This
      // is why the ladder is ordered rather than a set.
      final entries = <String, List<int>>{
        'actors/a1.json': utf8.encode(jsonEncode({'notes': 'Legacy note.'})),
      };
      DrillMigrations.archive(entries);
      expect(utf8.decode(entries['staff/a1/notes.md']!), 'Legacy note.');
    });

    test('a corrupt manifest is left for the reader to report', () {
      // The rung must not throw: DrillFile raises a typed DrillFormatException
      // with the path and cause a moment later, which is the better message.
      final entries = <String, List<int>>{
        'roleplays/rp1.json': utf8.encode('not json at all'),
      };
      expect(() => DrillMigrations.archive(entries), returnsNormally);
    });

    test('archive rungs are idempotent', () {
      final entries = <String, List<int>>{
        'actors/a1.json': utf8.encode(jsonEncode({'notes': 'n'})),
        'roleplays/rp1.json': utf8.encode(jsonEncode({'behavior': 'b'})),
      };
      DrillMigrations.archive(entries);
      final once = entries.keys.toList()..sort();
      DrillMigrations.archive(entries);
      expect(entries.keys.toList()..sort(), once);
    });

    test('every rung explains what it handles', () {
      // The ladder's value is being enumerable — a rung with no description is a
      // rung nobody can evaluate for removal when raising a support floor.
      for (final rung in DrillMigrations.all) {
        expect(rung.name, isNotEmpty);
        expect(rung.describes, isNotEmpty);
      }
    });
  });
}
