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

/// Warnings only — not "everything that is not an error". ADR-0071 added
/// `suggestion`, so `!isError` would fold the modelling rules into every
/// expectation in this file. `source_modelling_test.dart` covers those.
List<SourceDiagnostic> _warnings(String yaml) =>
    _analyze(yaml).where((d) => d.isWarning).toList();

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
            station: '        situation: "IPP {{var.ipp.position}}"',
          ),
        ),
        isEmpty,
      );
    });

    test('a stale facet on a location variable warns', () {
      // Same silent degradation as the scenario tokens, one namespace over: a
      // location-typed variable takes the same facets, so `.utm` falls back to
      // place-plus-coordinate where it asked for the coordinate alone.
      const decl = '  variables:\n    ko: {value: "x", type: location}';
      final warnings = _warnings(
        _doc(
          plan: decl,
          station: '        situation: "KO er i {{var.ko.utm}}"',
        ),
      );
      expect(warnings.single.message, contains('has no facet "utm"'));
      expect(warnings.single.hint, contains('renamed to position'));

      // The current facet is silent.
      expect(
        _analyze(
          _doc(
            plan: decl,
            station: '        situation: "KO er i {{var.ko.position}}"',
          ),
        ),
        isEmpty,
      );
    });

    test('a facet on a scalar variable warns that it is dropped', () {
      final warnings = _warnings(
        _doc(
          plan: '  variables:\n    talegruppe: {value: "RK-1"}',
          station: '        situation: "Samband {{var.talegruppe.place}}"',
        ),
      );
      expect(warnings.single.message, contains('is a string variable'));
      expect(warnings.single.hint, contains('ignored'));
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
              '        situation: "Sist sett {{station.loc.ipp.position}}"',
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
        _doc(plan: '  intro: "Sist sett {{station.loc.lkp.position}}"'),
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
                '        situation: "Sist sett {{station.loc.lkp.position}}"',
          ),
        ),
        isEmpty,
      );
    });

    test('a facet the resolvers do not know warns rather than fails', () {
      // An unrecognized facet falls back to the bare rendering, so the brief
      // reads plausibly while saying something else — a warning, not an error.
      // `--strict` is what promotes it, at the command layer.
      const station =
          '        locations: [{slug: lkp, label: "LKP", position: {lat: 59.1, lng: 10.4}}]\n'
          '        situation: "Sist sett {{station.loc.lkp.utm}}"';
      expect(_errors(_doc(station: station)), isEmpty);

      final warnings = _warnings(_doc(station: station));
      expect(warnings.single.message, contains('has no facet "utm"'));
      expect(warnings.single.hint, contains('renamed to position'));
      expect(warnings.single.hint, contains('place, label, position'));
      expect(warnings.single.path, endsWith('situation'));
    });

    test('an unknown person facet warns and lists what resolves', () {
      final warnings = _warnings(
        _doc(
          station:
              '        persons: [{slug: magnus, name: "M"}]\n'
              '        situation: "{{station.person.magnus.alder}}"',
        ),
      );
      expect(warnings.single.message, contains('has no facet "alder"'));
      expect(warnings.single.hint, contains('age'));
    });

    test("a person's loc chains one level into the location facets", () {
      const station =
          '        locations: [{slug: lkp, label: "LKP", position: {lat: 59.1, lng: 10.4}}]\n'
          '        persons: [{slug: magnus, name: "M", locSlug: lkp}]\n';
      expect(
        _analyze(
          _doc(
            station:
                '$station'
                '        situation: "{{station.person.magnus.loc.position}}"',
          ),
        ),
        isEmpty,
      );

      // One level only — anything past the leaf is dropped by both resolvers.
      final warnings = _warnings(
        _doc(
          station:
              '$station'
              '        situation: "{{station.person.magnus.loc.position.zone}}"',
        ),
      );
      expect(warnings.single.message, contains('".zone" is ignored'));
    });

    test('the bare token and a known facet stay silent', () {
      expect(
        _analyze(
          _doc(
            station:
                '        locations: [{slug: lkp, label: "LKP", position: {lat: 59.1, lng: 10.4}}]\n'
                '        persons: [{slug: magnus, name: "M", age: 6}]\n'
                '        situation: "{{station.loc.lkp}} {{station.loc.lkp.place}} '
                '{{station.person.magnus}} {{station.person.magnus.age}}"',
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

  group('derived values in prose', () {
    String docWith(String tips) =>
        '''
plan:
  name: "Test"
exercises:
  - name: "Ex"
    startTime: "17:00"
    numberOfTeams: 2
    numberOfRounds: 4
    executionTime: 15
    evaluationTime: 10
    rotationTime: 5
    execution_tips: |
$tips
    stations:
      - name: "Post A"
      - name: "Post B"
''';

    test('a hand-rolled rotation table warns and names the token', () {
      // The exact mistake made converting the first real booklet: the derived round
      // starts (1700, 1730, 1800, 1830) typed into execution_tips, where they are
      // correct only until someone edits startTime or a duration.
      final warnings = _warnings(
        docWith(
          '      | Runde | Klokke |\n'
          '      |---|---|\n'
          '      | 1 | 1700 |\n'
          '      | 2 | 1730 |\n'
          '      | 3 | 1800 |\n'
          '      | 4 | 1830 |',
        ),
      );
      expect(warnings.single.message, contains('restates every round start'));
      expect(warnings.single.hint, contains('{{exercise.roundTable}}'));
      expect(warnings.single.path, endsWith('execution_tips'));
    });

    test('the colon notation is caught too', () {
      final warnings = _warnings(
        docWith('      Rundene starter 17:00, 17:30, 18:00 og 18:30.'),
      );
      expect(warnings.single.message, contains('restates every round start'));
    });

    test('mentioning one round start is not a copy', () {
      // A sentence saying when the exercise begins is ordinary prose.
      expect(_warnings(docWith('      Moet opp 1700 ved Malerstua.')), isEmpty);
    });

    test('times that disagree with the derived schedule stay silent', () {
      // The legitimate case: recording that the source document's own clock
      // contradicts what the plan computes. Those times cannot all match, which is
      // why the check requires *every* round start before it fires.
      expect(
        _warnings(
          docWith(
            '      Heftet oppgir 1700, 1735, 1810 og 1845, altsaa 20 min runder.',
          ),
        ),
        isEmpty,
      );
    });

    test('the token itself is silent', () {
      expect(_warnings(docWith('      {{exercise.roundTable}}')), isEmpty);
    });
  });

  group('review', () {
    test('layers the analysis on the seed, keeping both', () {
      // `build --strict` refuses on any diagnostic, so it has to see the
      // compiler's warnings *and* the reference checks as one list. Composing
      // them here is what stops `build --strict` from being weaker than
      // `analyze`, which is what it was.
      final result = SourceCompiler.toPlan(
        _doc(
          station:
              '        persons: [{slug: magnus, name: "M"}]\n'
              '        situation: "{{station.person.magnus.alder}} {{var.typo}}"',
        ),
      );
      final seed = SourceDiagnostic.warning('seeded', 'from the compiler');

      final reviewed = SourceAnalyzer.review(result.plan, seed: [seed]);

      expect(reviewed.first, seed, reason: 'the seed comes first, unchanged');
      expect(
        reviewed.where((d) => d.isError).map((d) => d.message),
        contains(contains('no variable named "typo"')),
      );
      expect(
        reviewed.where((d) => !d.isError).map((d) => d.message),
        contains(contains('has no facet "alder"')),
      );
    });

    test('an empty seed is just the analysis', () {
      final result = SourceCompiler.toPlan(_doc());
      expect(SourceAnalyzer.review(result.plan), isEmpty);
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
          Sist sett {{station.loc.lkp.position}}. Samband på {{var.talegruppe}}.
        roleplays:
          - personRef: magnus
            behavior: |
              Gjemmer seg.
''';
