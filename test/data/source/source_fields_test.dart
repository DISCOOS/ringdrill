// Invariants of the DESIGN-014 field table.
//
// The table is the single description of the source format, which only holds if
// it is internally consistent: markdown keys derivable from their archive file
// names, no duplicate keys within a scope, enum shapes carrying their values.
// These are the properties the four commands assume without checking.
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/data/source/source_field.dart';
import 'package:ringdrill/data/source/source_fields.dart';
import 'package:ringdrill/services/brief/brief_audience.dart';
import 'package:ringdrill/models/location.dart';
import 'package:ringdrill/models/drill_variable.dart';
import 'package:ringdrill/models/numbering.dart';

void main() {
  group('field table', () {
    test('every scope has unique source keys', () {
      for (final scope in SourceScopes.all) {
        final keys = <String>[];
        for (final field in scope.fields) {
          keys.add(field.sourceKey);
        }
        for (final child in scope.children) {
          keys.add(child.sourceKey);
        }
        expect(
          keys.toSet().length,
          keys.length,
          reason: 'scope "${scope.name}" has a duplicate key: $keys',
        );
      }
    });

    test('markdown source keys are derivable from their archive file names', () {
      // The relationship is mechanical — `director-notes.md` ↔ `director_notes`
      // (worked example decision 6). Asserting it keeps the pair from drifting
      // into two unrelated names, which would make the format's naming rule a
      // lie and leave an author guessing.
      for (final scope in SourceScopes.all) {
        for (final field in scope.markdownFields) {
          expect(
            field.mdFileName,
            isNotNull,
            reason: '${scope.name}.${field.sourceKey} is markdown with no file',
          );
          final derived = field.mdFileName!
              .replaceAll('.md', '')
              .replaceAll('-', '_');
          expect(
            field.sourceKey,
            derived,
            reason:
                '${scope.name}: "${field.sourceKey}" does not match '
                '"${field.mdFileName}"',
          );
        }
      }
    });

    test('markdown wire keys match the model field names', () {
      // The wire key is what plan_builder's copyWith switch keys off, so a typo
      // here silently drops a markdown body rather than failing.
      expect(
        SourceScopes.station.field('director_notes')!.wireKey,
        'directorNotesMd',
      );
      expect(SourceScopes.station.field('situation')!.wireKey, 'situationMd');
      expect(SourceScopes.exercise.field('method')!.wireKey, 'methodMd');
      expect(
        SourceScopes.exercise.field('learning_goals')!.wireKey,
        'learningGoalsMd',
      );
      expect(SourceScopes.plan.field('intro')!.wireKey, 'briefIntroMd');
      expect(SourceScopes.plan.field('before_round')!.wireKey, 'beforeRoundMd');
      // behavior/background are stored under their own names, not suffixed.
      expect(SourceScopes.roleplay.field('behavior')!.wireKey, 'behavior');
      expect(SourceScopes.roleplay.field('props')!.wireKey, 'propsMd');
    });

    test('enumeration fields list exactly the model\'s values', () {
      // A missing token would reject a document the model accepts; a stale one
      // would accept a document the model silently coerces (both LocationKind and
      // VariableType decode unknown values to a fallback).
      expect(
        SourceScopes.location.field('kind')!.enumValues,
        LocationKind.values.map((v) => v.name).toList(),
      );
      expect(
        SourceScopes.variable.field('type')!.enumValues,
        VariableType.values.map((v) => v.name).toList(),
      );
      expect(
        SourceScopes.plan.field('stationNumberFormat')!.enumValues,
        StationNumberFormat.values.map((v) => v.name).toList(),
      );
      expect(
        SourceScopes.plan.field('exerciseNumberFormat')!.enumValues,
        ExerciseNumberFormat.values.map((v) => v.name).toList(),
      );
    });

    test('every enumeration field carries its values', () {
      for (final scope in SourceScopes.all) {
        for (final field in scope.fields) {
          if (field.shape == SourceShape.enumeration) {
            expect(
              field.enumValues,
              isNotEmpty,
              reason: '${scope.name}.${field.sourceKey} has no enum values',
            );
          }
        }
      }
    });

    test('uuid is the only identity field, and only where uuids exist', () {
      final withUuid = <String>{};
      for (final scope in SourceScopes.all) {
        for (final field in scope.fields) {
          if (field.isIdentity) {
            expect(
              field.sourceKey,
              'uuid',
              reason:
                  'unexpected identity field ${scope.name}.'
                  '${field.sourceKey}',
            );
            withUuid.add(scope.name);
          }
        }
      }
      // Stations have no uuid — identity is (exercise, index) — and neither do
      // locations, persons or variables, which are addressed by slug/name.
      expect(withUuid, {'plan', 'exercise', 'roleplay', 'team'});
    });

    test('derived keys are not writable', () {
      for (final scope in SourceScopes.all) {
        for (final key in scope.derivedKeys) {
          expect(
            scope.writableKeys,
            isNot(contains(key)),
            reason: '${scope.name}.$key is both derived and writable',
          );
        }
      }
    });

    test('the relocated collection is only roleplays', () {
      final relocated = <String>[];
      for (final scope in SourceScopes.all) {
        for (final child in scope.children) {
          if (child.collection == SourceCollection.relocatedList) {
            relocated.add('${scope.name}.${child.sourceKey}');
          }
        }
      }
      expect(relocated, ['station.roleplays']);
    });

    test('keyed collections name the field their key becomes', () {
      for (final scope in SourceScopes.all) {
        for (final child in scope.children) {
          if (child.collection == SourceCollection.keyedMap) {
            expect(child.keyField, isNotNull);
            expect(child.scope.field(child.keyField!), isNotNull);
          }
        }
      }
    });
  });

  group('brief visibility (ADR-0063)', () {
    test('every markdown field declares who may see it', () {
      // The declaration is required rather than defaulted, because a permissive
      // default is how the participant brief came to carry every marker's script:
      // a field nobody wrapped in the template was public. An empty set here
      // fails closed — the field renders for nobody — so this test is what turns
      // "forgot to decide" into a failure instead of a leak.
      final undeclared = <String>[];
      for (final scope in SourceScopes.all) {
        for (final field in scope.fields) {
          if (field.shape == SourceShape.markdown && field.audiences.isEmpty) {
            undeclared.add('${scope.name}.${field.sourceKey}');
          }
        }
      }
      expect(undeclared, isEmpty);
    });

    test('a participant never sees an instructor-facing field', () {
      // The classification itself, asserted on the table rather than by rendering
      // and grepping. Names the fields so a reclassification is a deliberate edit
      // here, not a quiet change in behaviour.
      const staffOnly = {
        'training_focus',
        'execution_tips',
        'critical_questions',
        'leader_answers',
        'director_notes',
        'behavior',
        'background',
        'props',
      };
      for (final scope in SourceScopes.all) {
        for (final field in scope.fields) {
          if (field.shape != SourceShape.markdown) continue;
          expect(
            field.visibleTo(BriefAudience.participant),
            !staffOnly.contains(field.sourceKey),
            reason: '${scope.name}.${field.sourceKey}',
          );
        }
      }
    });

    test('an actor gets the role play but not the control material', () {
      const rolePlayFields = {'behavior', 'background', 'props'};
      const controlFields = {
        'training_focus',
        'execution_tips',
        'critical_questions',
        'leader_answers',
        'director_notes',
      };
      for (final scope in SourceScopes.all) {
        for (final field in scope.fields) {
          if (field.shape != SourceShape.markdown) continue;
          if (rolePlayFields.contains(field.sourceKey)) {
            expect(
              field.visibleTo(BriefAudience.actor),
              isTrue,
              reason: field.sourceKey,
            );
          }
          if (controlFields.contains(field.sourceKey)) {
            expect(
              field.visibleTo(BriefAudience.actor),
              isFalse,
              reason: field.sourceKey,
            );
          }
        }
      }
    });

    test('`other` sees exactly what a participant sees', () {
      for (final scope in SourceScopes.all) {
        for (final field in scope.fields) {
          if (field.shape != SourceShape.markdown) continue;
          expect(
            field.visibleTo(BriefAudience.other),
            field.visibleTo(BriefAudience.participant),
            reason: '${scope.name}.${field.sourceKey}',
          );
        }
      }
    });
  });
}
