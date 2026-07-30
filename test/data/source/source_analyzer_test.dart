// `analyze`: the mistakes that build cleanly and then fail in front of a reader.
//
// Every case here compiles to a valid .drill. That is the point — a
// {{var.typo}} is stored raw and only resolves at render, where the brief shows
// "‹missing variable: typo›" to whoever is holding it. These are also exactly the
// mistakes a generating agent makes, which is why analyze exists as its own
// command rather than as a build flag.
import 'package:flutter_test/flutter_test.dart';
import 'package:ringdrill/data/source/source_analyzer.dart';
import 'package:ringdrill/data/source/source_compiler.dart';
import 'package:ringdrill/data/source/source_diagnostic.dart';

/// Analyzes [yaml], returning every diagnostic from build *and* analysis.
List<SourceDiagnostic> _analyze(String yaml) {
  final result = SourceCompiler.toPlan(yaml, now: DateTime.utc(2026, 1, 1));
  final sink = DiagnosticSink()..addAll(result.diagnostics);
  SourceAnalyzer.analyze(result.plan, sink);
  return sink.items;
}

List<SourceDiagnostic> _errors(String yaml) =>
    _analyze(yaml).where((d) => d.isError).toList();

List<SourceDiagnostic> _warnings(String yaml) =>
    _analyze(yaml).where((d) => !d.isError).toList();

/// One exercise, one station, with [station] extending the station body.
String _doc({String plan = '', String station = '', String exercise = ''}) =>
    '''
plan:
  name: "Test"
$plan
exercises:
  - name: "Ex"
    startTime: "09:00"
    numberOfTeams: 1
    numberOfRounds: 1
    executionTime: 15
    evaluationTime: 5
    rotationTime: 2
$exercise
    stations:
      - name: "Post"
$station
''';

void main() {
  group('variable references', () {
    test('an undeclared variable is an error listing what is declared', () {
      final errors = _errors(
        _doc(
          plan: '  variables:\n    talegruppe: {value: "RK-1"}',
          station: '        situation: "Samband på {{var.talegrupe}}."',
        ),
      );
      expect(errors.single.message, contains('no variable named "talegrupe"'));
      expect(errors.single.hint, contains('talegruppe'));
      expect(errors.single.path, endsWith('situation'));
    });

    test('with nothing declared, the hint says where to declare it', () {
      final errors = _errors(
        _doc(station: '        situation: "{{var.talegruppe}}"'),
      );
      expect(errors.single.hint, contains('plan.variables'));
    });

    test('a declared variable with a facet resolves', () {
      expect(
        _errors(
          _doc(
            plan: '  variables:\n    ipp: {value: "x", type: location}',
            station: '        situation: "IPP {{var.ipp.utm}}"',
          ),
        ),
        isEmpty,
      );
    });

    test('declared but never referenced warns', () {
      final warnings = _warnings(
        _doc(plan: '  variables:\n    unused: {value: "x"}'),
      );
      expect(warnings.single.message, contains('never referenced'));
      expect(warnings.single.hint, contains('{{var.unused}}'));
    });

    test('a reference in a name counts as a reference', () {
      // Names and descriptions resolve too (DESIGN-008 follow-ups 05/09), so a
      // variable used only in an exercise name is not unused.
      expect(
        _warnings('''
plan:
  name: "Test"
  variables:
    sted: {value: "Eidene"}
exercises:
  - name: "Øvelse ved {{var.sted}}"
    startTime: "09:00"
    numberOfTeams: 1
    numberOfRounds: 1
    executionTime: 15
    evaluationTime: 5
    rotationTime: 2
    stations: [{name: "Post"}]
'''),
        isEmpty,
      );
    });
  });

  group('scenario references', () {
    test('a location slug the station does not own is an error', () {
      final errors = _errors(
        _doc(
          station:
              '        locations: [{slug: lkp, label: "LKP"}]\n'
              '        situation: "Sist sett {{station.loc.ipp.utm}}"',
        ),
      );
      expect(errors.single.message, contains('has no loc "ipp"'));
      expect(errors.single.hint, contains('lkp'));
    });

    test('a person slug the station does not own is an error', () {
      final errors = _errors(
        _doc(
          station:
              '        persons: [{slug: magnus, name: "Magnus"}]\n'
              '        situation: "{{station.person.mangus}} savnet"',
        ),
      );
      expect(errors.single.message, contains('has no person "mangus"'));
      expect(errors.single.hint, contains('magnus'));
    });

    test('a station token above station scope cannot resolve anywhere', () {
      // Scenario data is station-owned (DESIGN-009), so this is not a typo — the
      // text is in a place where no station is in context.
      final errors = _errors(
        _doc(plan: '  intro: "Sist sett {{station.loc.lkp.utm}}"'),
      );
      expect(
        errors.single.message,
        contains('cannot resolve outside a station'),
      );
      expect(errors.single.hint, contains('owned by a station'));
    });

    test('a slug the station owns resolves', () {
      expect(
        _errors(
          _doc(
            station:
                '        locations: [{slug: lkp, label: "LKP", position: {lat: 59.1, lng: 10.4}}]\n'
                '        situation: "Sist sett {{station.loc.lkp.utm}}"',
          ),
        ),
        isEmpty,
      );
    });

    test("a person's locSlug must name a location on the same station", () {
      final errors = _errors(
        _doc(
          station:
              '        locations: [{slug: lkp, label: "LKP"}]\n'
              '        persons: [{slug: magnus, name: "M", locSlug: ipp}]',
        ),
      );
      expect(errors.single.message, contains('no location "ipp"'));
      expect(errors.single.path, endsWith('locSlug'));
    });
  });

  group('facet references', () {
    test('a misspelled facet is an error listing what resolves', () {
      final errors = _errors(
        _doc(station: '        situation: "{{exercise.phasebreakdown}}"'),
      );
      expect(errors.single.message, contains('not a resolvable reference'));
      expect(errors.single.hint, contains('exercise.phaseBreakdown'));
    });

    test(
      'a real facet in the wrong scope explains the scope, not the spelling',
      () {
        // {{exercise.name}} is a real facet — it just cannot resolve in a
        // plan-level field, which has no exercise in context. Telling the author
        // "not resolvable" here would send them hunting for a typo.
        final errors = _errors(_doc(plan: '  intro: "Se {{exercise.name}}"'));
        expect(errors.single.message, contains('cannot resolve here'));
        expect(errors.single.hint, contains('plan scope'));
      },
    );

    test('facets cascade downwards', () {
      // A plan facet resolves in a station field; the reverse does not hold.
      expect(
        _errors(_doc(station: '        situation: "Plan: {{plan.name}}"')),
        isEmpty,
      );
      expect(
        _errors(_doc(station: '        situation: "{{exercise.startTime}}"')),
        isEmpty,
      );
    });

    test('station.description is deliberately not resolvable', () {
      // DESIGN-009 follow-up 4c: it is the field the author edits, so offering it
      // would recurse on itself through the fixpoint pass.
      final errors = _errors(
        _doc(station: '        situation: "{{station.description}}"'),
      );
      expect(errors.single.message, contains('not a resolvable reference'));
    });
  });

  group('overrides', () {
    test('overriding an undeclared variable warns rather than fails', () {
      // Resolution ignores an unknown key (ADR-0046), so nothing breaks — but the
      // author wrote it expecting an effect.
      final warnings = _warnings(
        _doc(
          plan: '  variables:\n    talegruppe: {value: "RK-1"}',
          station:
              '        variableOverrides: {talegrupe: "RK-2"}\n'
              '        situation: "{{var.talegruppe}}"',
        ),
      );
      expect(warnings.single.message, contains('not a declared variable'));
      expect(warnings.single.hint, contains('cannot declare one'));
    });

    test('an override of a declared variable is silent', () {
      expect(
        _warnings(
          _doc(
            plan: '  variables:\n    talegruppe: {value: "RK-1"}',
            station:
                '        variableOverrides: {talegruppe: "RK-2"}\n'
                '        situation: "{{var.talegruppe}}"',
          ),
        ),
        isEmpty,
      );
    });
  });

  group('identity', () {
    test('a duplicate exercise uuid is an error', () {
      // Only reachable when a document hand-writes uuids or a decompiled one is
      // copy-pasted — which is exactly when it happens. It makes role-play
      // ownership ambiguous and perturbs the hash's uuid-sorted ordering.
      final errors = _errors('''
plan:
  name: "Test"
exercises:
  - name: "A"
    uuid: same
    startTime: "09:00"
    numberOfTeams: 1
    numberOfRounds: 1
    executionTime: 15
    evaluationTime: 5
    rotationTime: 2
    stations: [{name: "P"}]
  - name: "B"
    uuid: same
    startTime: "10:00"
    numberOfTeams: 1
    numberOfRounds: 1
    executionTime: 15
    evaluationTime: 5
    rotationTime: 2
    stations: [{name: "P"}]
''');
      expect(errors.single.message, contains('duplicate exercise uuid'));
    });

    test('a duplicate team uuid is an error', () {
      final errors = _errors('''
plan:
  name: "Test"
exercises:
  - name: "A"
    startTime: "09:00"
    numberOfTeams: 1
    numberOfRounds: 1
    executionTime: 15
    evaluationTime: 5
    rotationTime: 2
    stations: [{name: "P"}]
teams:
  - {name: "One", uuid: same}
  - {name: "Two", uuid: same}
''');
      expect(
        errors.map((e) => e.message),
        contains(contains('duplicate team uuid')),
      );
    });
  });

  group('the reference example', () {
    test('analyzes clean', () {
      // The document the design uses as its example must survive the checks the
      // same design specifies. It exercises variables, a station-owned location
      // and person, a token in prose, and an override.
      expect(
        _analyze(
          const String.fromEnvironment('unused', defaultValue: '') +
              _referenceExample,
        ),
        isEmpty,
      );
    });
  });
}

/// Inlined rather than read from disk so this file stays runnable in isolation;
/// the on-disk copy is covered by plan_builder_test.dart.
const _referenceExample = '''
plan:
  name: "LSOR Eidene 2026"
  language: nb
  variables:
    talegruppe: { value: "RK-VFOLD-ØV2", hint: "Talkgroup" }
exercises:
  - name: "Førsteinnsats søk"
    startTime: "09:45"
    numberOfTeams: 1
    numberOfRounds: 6
    executionTime: 15
    evaluationTime: 10
    rotationTime: 5
    stations:
      - name: "Barn 4-6 år"
        variableOverrides: { talegruppe: "RK-VFOLD-ØV3" }
        locations:
          - slug: lkp
            kind: lkp
            label: "Sist kjent posisjon"
            position: { lat: 59.09672, lng: 10.40201 }
        persons:
          - slug: magnus
            name: "Magnus Damslet"
            age: 6
            locSlug: lkp
        situation: |
          {{station.person.magnus}} ({{station.person.magnus.age}} år).
          Sist sett {{station.loc.lkp.utm}}. Samband på {{var.talegruppe}}.
        roleplays:
          - personRef: magnus
            behavior: |
              Gjemmer seg.
''';
